import Foundation
import CoreData
import CloudKit
import Observation

/// Houdt bij of de iCloud-synchronisatie werkt, en zo niet: waarom niet.
///
/// SwiftData gebruikt onder water `NSPersistentCloudKitContainer`, die bij elke
/// synchronisatiestap (voorbereiden, ophalen, versturen) een melding stuurt.
@MainActor
@Observable
final class SyncMonitor {
    enum Status {
        /// Deze versie van de app is gebouwd zonder iCloud-rechten.
        case off
        /// iCloud staat aan, maar er is nog niets gesynchroniseerd.
        case connecting
        case syncing
        case upToDate
        case problem
    }

    enum Account {
        case unknown, available, noAccount, restricted, temporarilyUnavailable, couldNotDetermine
    }

    struct LogEntry: Identifiable {
        let id = UUID()
        let date: Date
        let text: String
        let succeeded: Bool
    }

    /// De CloudKit-container uit de entitlements, of nil als de app zonder iCloud is gebouwd.
    let containerIdentifier: String?
    /// Foutmelding als de opslag met iCloud niet geopend kon worden.
    let storeError: String?

    private(set) var account: Account = .unknown
    private(set) var lastSuccess: Date?
    private(set) var lastError: String?
    private(set) var lastErrorCode: String?
    private(set) var lastErrorDate: Date?
    private(set) var log: [LogEntry] = []
    private(set) var hasSeenEvents = false

    private var runningEvents = Set<UUID>()
    @ObservationIgnored private var setupSucceeded = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    var isSyncing: Bool { !runningEvents.isEmpty }

    init(containerIdentifier: String?, storeError: String?) {
        self.containerIdentifier = containerIdentifier
        self.storeError = storeError

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            MainActor.assumeIsolated {
                self?.handle(event)
            }
        })
        observers.append(center.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.refreshAccount() }
            }
        })
    }

    var status: Status {
        if storeError != nil { return .problem }
        if containerIdentifier == nil && !hasSeenEvents { return .off }
        switch account {
        case .noAccount, .restricted, .temporarilyUnavailable:
            return .problem
        default:
            break
        }
        if let lastErrorDate, lastErrorDate >= (lastSuccess ?? .distantPast) { return .problem }
        if isSyncing { return .syncing }
        return lastSuccess == nil ? .connecting : .upToDate
    }

    /// Korte uitleg van het probleem, in gewone taal.
    var problemMessage: String? {
        if let storeError {
            return "De iCloud-opslag kon niet worden geopend, dus alles blijft op dit apparaat. (\(storeError))"
        }
        switch account {
        case .noAccount:
            return "Je bent op dit apparaat niet ingelogd bij iCloud, of iCloud staat uit voor Boodschappen."
        case .restricted:
            return "iCloud is op dit apparaat beperkt, bijvoorbeeld door Schermtijd of een beheerprofiel."
        case .temporarilyUnavailable:
            return "Je iCloud-account is tijdelijk niet beschikbaar. Kijk in Instellingen of je opnieuw moet inloggen."
        default:
            break
        }
        if status == .problem { return lastError }
        return nil
    }

    // MARK: - Meldingen verwerken

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        hasSeenEvents = true
        guard let endDate = event.endDate else {
            runningEvents.insert(event.identifier)
            return
        }
        runningEvents.remove(event.identifier)

        let step: String
        switch event.type {
        case .setup: step = "Voorbereiden"
        case .import: step = "Ophalen van iCloud"
        case .export: step = "Versturen naar iCloud"
        @unknown default: step = "Synchroniseren"
        }

        if event.succeeded {
            lastSuccess = endDate
            append(LogEntry(date: endDate, text: step, succeeded: true))
            if event.type == .setup {
                setupSucceeded = true
                Task { await refreshAccount() }
            }
        } else {
            let description = event.error.map(Self.describe) ?? (message: "Onbekende fout", code: "?")
            lastError = description.message
            lastErrorCode = description.code
            lastErrorDate = endDate
            append(LogEntry(date: endDate, text: "\(step) mislukt: \(description.message) [\(description.code)]", succeeded: false))
        }
    }

    private func append(_ entry: LogEntry) {
        log.insert(entry, at: 0)
        if log.count > 12 { log.removeLast(log.count - 12) }
    }

    func refreshAccount() async {
        // Alleen vragen als CloudKit echt is ingesteld; zonder rechten crasht CKContainer.
        guard setupSucceeded, let containerIdentifier else { return }
        do {
            let status = try await CKContainer(identifier: containerIdentifier).accountStatus()
            switch status {
            case .available: account = .available
            case .noAccount: account = .noAccount
            case .restricted: account = .restricted
            case .temporarilyUnavailable: account = .temporarilyUnavailable
            case .couldNotDetermine: account = .couldNotDetermine
            @unknown default: account = .couldNotDetermine
            }
        } catch {
            account = .couldNotDetermine
        }
    }

    // MARK: - Foutmeldingen vertalen

    nonisolated static func describe(_ error: Error) -> (message: String, code: String) {
        let nsError = error as NSError
        guard let cloudKitError = findCloudKitError(nsError) else {
            // Core Data meldt "geen iCloud-account" met deze code.
            if nsError.domain == NSCocoaErrorDomain && nsError.code == 134400 {
                return ("Je bent op dit apparaat niet ingelogd bij iCloud, of iCloud staat uit voor Boodschappen.",
                        "\(nsError.domain) \(nsError.code)")
            }
            return (nsError.localizedDescription, "\(nsError.domain) \(nsError.code)")
        }

        // Bij een gedeeltelijke fout zit de echte oorzaak één laag dieper.
        if cloudKitError.code == CKError.Code.partialFailure.rawValue,
           let partial = cloudKitError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
           let first = partial.values.first {
            return describe(first)
        }

        let code = "CKError \(cloudKitError.code)"
        switch CKError.Code(rawValue: cloudKitError.code) {
        case .notAuthenticated?:
            return ("Je bent op dit apparaat niet ingelogd bij iCloud, of iCloud staat uit voor Boodschappen.", code)
        case .accountTemporarilyUnavailable?:
            return ("Je iCloud-account is tijdelijk niet beschikbaar. Kijk in Instellingen of je opnieuw moet inloggen.", code)
        case .networkUnavailable?, .networkFailure?, .serviceUnavailable?, .requestRateLimited?, .zoneBusy?:
            return ("Geen verbinding met iCloud. De app probeert het vanzelf opnieuw.", code)
        case .quotaExceeded?:
            return ("Je iCloud-opslag is vol.", code)
        case .badContainer?, .missingEntitlement?, .permissionFailure?, .badDatabase?:
            return ("De iCloud-container is niet goed ingesteld in Xcode of in je ontwikkelaarsaccount.", code)
        case .serverRejectedRequest?, .invalidArguments?, .constraintViolation?:
            return ("iCloud weigert de gegevens. Gebruik je een TestFlight- of App Store-versie, zet dan in het CloudKit-dashboard het schema op Production.", code)
        case .incompatibleVersion?:
            return ("Werk iOS of macOS bij om iCloud te kunnen gebruiken.", code)
        case .userDeletedZone?, .zoneNotFound?:
            return ("De iCloud-gegevens van de app zijn verwijderd; ze worden opnieuw aangemaakt.", code)
        default:
            return (cloudKitError.localizedDescription, code)
        }
    }

    nonisolated private static func findCloudKitError(_ error: NSError) -> NSError? {
        if error.domain == CKError.errorDomain { return error }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return findCloudKitError(underlying)
        }
        return nil
    }

    // MARK: - Diagnose om te delen

    var diagnosticReport: String {
        let info = Bundle.main.infoDictionary
        let version = "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium

        var lines = [
            "Boodschappen – iCloud-diagnose",
            "App: \(version), \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Bundle-ID: \(Bundle.main.bundleIdentifier ?? "?")",
            "Container: \(containerIdentifier ?? "geen (gebouwd zonder iCloud)")",
            "Account: \(accountDescription)",
            "Status: \(statusDescription)",
        ]
        if let storeError { lines.append("Opslagfout: \(storeError)") }
        if let lastSuccess { lines.append("Laatst gelukt: \(formatter.string(from: lastSuccess))") }
        if let lastError {
            lines.append("Laatste fout: \(lastError) [\(lastErrorCode ?? "?")]")
        }
        if !log.isEmpty {
            lines.append("Gebeurtenissen:")
            lines += log.map { "  \(formatter.string(from: $0.date)) \($0.succeeded ? "✓" : "✗") \($0.text)" }
        }
        return lines.joined(separator: "\n")
    }

    var statusDescription: String {
        switch status {
        case .off: "iCloud staat niet aan in deze versie van de app"
        case .connecting: "Verbinden met iCloud…"
        case .syncing: "Bezig met synchroniseren…"
        case .upToDate: "Gesynchroniseerd"
        case .problem: "Synchronisatie werkt niet"
        }
    }

    var accountDescription: String {
        switch account {
        case .unknown: "nog niet bekend"
        case .available: "ingelogd"
        case .noAccount: "niet ingelogd"
        case .restricted: "beperkt"
        case .temporarilyUnavailable: "tijdelijk niet beschikbaar"
        case .couldNotDetermine: "onbekend"
        }
    }
}
