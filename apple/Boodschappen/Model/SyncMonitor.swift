import Foundation
import CloudKit
import Observation

/// Houdt bij of de iCloud-synchronisatie werkt, en zo niet: waarom niet.
/// Wordt gevoed door `CloudSync`.
@MainActor
@Observable
final class SyncMonitor {
    enum Status {
        /// Deze installatie heeft geen iCloud-rechten.
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

    /// De CloudKit-container van deze installatie, of nil als de app geen iCloud-rechten heeft.
    let containerIdentifier: String?
    /// Foutmelding als de lokale opslag niet goed geopend kon worden.
    let storeError: String?

    private(set) var account: Account = .unknown
    private(set) var lastSuccess: Date?
    private(set) var lastError: String?
    private(set) var lastErrorCode: String?
    private(set) var lastErrorDate: Date?
    private(set) var log: [LogEntry] = []
    private(set) var isSending = false

    @ObservationIgnored weak var engine: CloudSync?
    @ObservationIgnored private var accountObserver: NSObjectProtocol?

    init(containerIdentifier: String?, storeError: String?) {
        self.containerIdentifier = containerIdentifier
        self.storeError = storeError
        guard containerIdentifier != nil else { return }
        accountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.refreshAccount() }
            }
        }
    }

    // MARK: - Aansturing

    /// Door de app aangeroepen als hij actief wordt of naar de achtergrond gaat.
    func setAppActive(_ active: Bool) {
        engine?.setActive(active)
    }

    func syncNow() async {
        await engine?.syncNow()
    }

    // MARK: - Meldingen van CloudSync

    func setSending(_ sending: Bool) {
        isSending = sending
    }

    func didSync() {
        // Er wordt elke paar seconden opgehaald; de weergave hoeft niet elke keer te verversen.
        let hadError = (lastErrorDate ?? .distantPast) >= (lastSuccess ?? .distantPast)
        if let lastSuccess, !hadError, Date().timeIntervalSince(lastSuccess) < 20 { return }
        lastSuccess = Date()
    }

    func didReceive(_ count: Int) {
        lastSuccess = Date()
        append(LogEntry(date: Date(), text: count == 1 ? "1 wijziging ontvangen" : "\(count) wijzigingen ontvangen", succeeded: true))
    }

    func didFail(_ error: Error, step: String) {
        let description = Self.describe(error)
        lastError = description.message
        lastErrorCode = description.code
        lastErrorDate = Date()
        append(LogEntry(date: Date(), text: "\(step) mislukt: \(description.message) [\(description.code)]", succeeded: false))
    }

    private func append(_ entry: LogEntry) {
        // Dezelfde fout elke paar seconden hoeft er maar één keer in.
        if let first = log.first, first.text == entry.text, !entry.succeeded { return }
        log.insert(entry, at: 0)
        if log.count > 12 { log.removeLast(log.count - 12) }
    }

    func refreshAccount() async {
        guard let containerIdentifier else { return }
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

    // MARK: - Status

    var status: Status {
        if storeError != nil { return .problem }
        if containerIdentifier == nil { return .off }
        switch account {
        case .noAccount, .restricted, .temporarilyUnavailable:
            return .problem
        default:
            break
        }
        if let lastErrorDate, lastErrorDate >= (lastSuccess ?? .distantPast) { return .problem }
        if isSending { return .syncing }
        return lastSuccess == nil ? .connecting : .upToDate
    }

    /// Korte uitleg van het probleem, in gewone taal.
    var problemMessage: String? {
        if let storeError {
            return "De opslag kon niet goed worden geopend. (\(storeError))"
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

    var statusDescription: String {
        switch status {
        case .off: "iCloud staat niet aan in deze installatie"
        case .connecting: "Verbinden met iCloud…"
        case .syncing: "Bezig met versturen…"
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

    // MARK: - Foutmeldingen vertalen

    nonisolated static func describe(_ error: Error) -> (message: String, code: String) {
        let nsError = error as NSError
        guard let cloudKitError = findCloudKitError(nsError) else {
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
            "Container: \(containerIdentifier ?? "geen (geen iCloud-rechten in deze installatie)")",
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
}
