import Foundation
import CloudKit
import SwiftData

extension Notification.Name {
    /// Wordt verstuurd nadat de gebruiker iets aan de lijst, favorieten of varianten heeft gewijzigd.
    static let boodschappenLocalChange = Notification.Name("BoodschappenLocalChange")
}

/// Synchroniseert de lijst, favorieten en varianten binnen een paar seconden via iCloud.
///
/// Gebruikt `CKSyncEngine`: wijzigingen worden direct verstuurd, en zolang de app open is
/// wordt elke paar seconden gekeken of een ander apparaat iets heeft veranderd. Pushberichten
/// van iCloud zorgen daarnaast voor updates als de app op de achtergrond staat.
///
/// Welke records gewijzigd zijn, bepalen we door de huidige gegevens te vergelijken met wat
/// iCloud als laatste bevestigde (`known`). Zo maakt het niet uit waar in de app iets verandert.
@MainActor
final class CloudSync: CKSyncEngineDelegate {
    static let zoneID = CKRecordZone.ID(zoneName: "Boodschappen", ownerName: CKCurrentUserDefaultName)
    /// Hoe vaak we kijken of er iets nieuws is zolang de app open is.
    static let pollInterval: Duration = .seconds(3)

    let containerIdentifier: String
    private let container: CKContainer
    private let context: ModelContext
    private weak var monitor: SyncMonitor?
    private var engine: CKSyncEngine?
    private var stored: StoredState
    private var pollTask: Task<Void, Never>?
    private var localCheckTask: Task<Void, Never>?
    private var observer: NSObjectProtocol?
    private var pauseUntil = Date.distantPast

    init(containerIdentifier: String, context: ModelContext, monitor: SyncMonitor) {
        self.containerIdentifier = containerIdentifier
        self.container = CKContainer(identifier: containerIdentifier)
        self.context = context
        self.monitor = monitor
        self.stored = StoredState.load()

        let configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: stored.engineState,
            delegate: self
        )
        engine = CKSyncEngine(configuration)
        if !stored.zoneReady {
            engine?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
        }

        observer = NotificationCenter.default.addObserver(
            forName: .boodschappenLocalChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleLocalCheck()
            }
        }

        ListActions.ensureSyncIDs(in: context)
        queueLocalChanges()
    }

    // MARK: - Aansturing vanuit de app

    /// Zolang de app actief is, halen we elke paar seconden de wijzigingen op.
    func setActive(_ active: Bool) {
        pollTask?.cancel()
        pollTask = nil
        guard active else { return }
        pollTask = Task { [weak self] in
            // Bij openen meteen versturen wat nog klaarstaat en ophalen wat nieuw is.
            await self?.syncNow()
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard !Task.isCancelled else { return }
                await self?.fetch()
            }
        }
    }

    /// Meteen versturen en ophalen, bijvoorbeeld bij omlaag trekken van de lijst.
    func syncNow() async {
        pauseUntil = .distantPast
        queueLocalChanges()
        await send()
        await fetch()
    }

    private func fetch() async {
        guard let engine, Date() >= pauseUntil else { return }
        do {
            try await engine.fetchChanges()
            monitor?.didSync()
        } catch {
            handle(error, step: "Ophalen van iCloud")
        }
    }

    private func send() async {
        guard let engine, Date() >= pauseUntil,
              !engine.state.pendingRecordZoneChanges.isEmpty || !engine.state.pendingDatabaseChanges.isEmpty
        else { return }
        monitor?.setSending(true)
        defer { monitor?.setSending(false) }
        do {
            try await engine.sendChanges()
            monitor?.didSync()
        } catch {
            handle(error, step: "Versturen naar iCloud")
        }
    }

    private func handle(_ error: Error, step: String) {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .requestRateLimited, .zoneBusy, .serviceUnavailable:
                // iCloud vraagt om even te wachten.
                pauseUntil = Date().addingTimeInterval(ckError.retryAfterSeconds ?? 10)
            case .networkFailure, .networkUnavailable:
                pauseUntil = Date().addingTimeInterval(5)
            case .notAuthenticated, .accountTemporarilyUnavailable:
                // Zonder account heeft elke paar seconden proberen geen zin.
                pauseUntil = Date().addingTimeInterval(30)
            case .operationCancelled:
                return
            default:
                break
            }
        }
        monitor?.didFail(error, step: step)
    }

    // MARK: - Lokale wijzigingen

    private func scheduleLocalCheck() {
        localCheckTask?.cancel()
        localCheckTask = Task { [weak self] in
            // Snel achter elkaar tikken (bijv. + + +) als één wijziging versturen.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }
            if self.queueLocalChanges() {
                await self.send()
            }
        }
    }

    /// Vergelijkt de lokale gegevens met wat iCloud kent en zet de verschillen klaar.
    @discardableResult
    private func queueLocalChanges() -> Bool {
        guard let engine else { return false }
        let objects = localObjects()

        var alreadyPending = Set<String>()
        for change in engine.state.pendingRecordZoneChanges {
            switch change {
            case .saveRecord(let id): alreadyPending.insert("save:" + id.recordName)
            case .deleteRecord(let id): alreadyPending.insert("delete:" + id.recordName)
            @unknown default: break
            }
        }

        var changes: [CKSyncEngine.PendingRecordZoneChange] = []
        for (name, object) in objects
        where stored.known[name]?.fingerprint != Self.fingerprint(of: object) && !alreadyPending.contains("save:" + name) {
            changes.append(.saveRecord(Self.recordID(name)))
        }
        for name in stored.known.keys where objects[name] == nil && !alreadyPending.contains("delete:" + name) {
            changes.append(.deleteRecord(Self.recordID(name)))
        }
        guard !changes.isEmpty else { return false }
        engine.state.add(pendingRecordZoneChanges: changes)
        return true
    }

    private func localObjects() -> [String: any SyncedModel] {
        var result: [String: any SyncedModel] = [:]
        for item in ListActions.items(in: context) where !item.syncID.isEmpty { result[item.syncID] = item }
        for favorite in ListActions.favorites(in: context) where !favorite.syncID.isEmpty { result[favorite.syncID] = favorite }
        for variant in ListActions.variants(in: context) where !variant.syncID.isEmpty { result[variant.syncID] = variant }
        return result
    }

    // MARK: - CKSyncEngineDelegate

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            stored.engineState = update.stateSerialization
            stored.save()

        case .accountChange(let change):
            switch change.changeType {
            case .signIn, .switchAccounts:
                uploadEverythingAgain()
            case .signOut:
                stored.known = [:]
                stored.zoneReady = false
                stored.save()
            @unknown default:
                break
            }
            await monitor?.refreshAccount()

        case .fetchedDatabaseChanges(let changes):
            if changes.deletions.contains(where: { $0.zoneID == Self.zoneID }) {
                // De iCloud-gegevens zijn gewist (bijv. via iCloud-opslag beheren): opnieuw opbouwen.
                uploadEverythingAgain()
            }

        case .fetchedRecordZoneChanges(let changes):
            apply(changes)

        case .sentDatabaseChanges(let sent):
            if sent.savedZones.contains(where: { $0.zoneID == Self.zoneID }) {
                stored.zoneReady = true
                stored.save()
            }
            for failure in sent.failedZoneSaves {
                monitor?.didFail(failure.error, step: "iCloud voorbereiden")
            }

        case .sentRecordZoneChanges(let sent):
            handleSent(sent, syncEngine: syncEngine)

        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ sendContext: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = sendContext.options.scope
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        guard !changes.isEmpty else { return nil }

        let objects = localObjects()
        var records: [CKRecord.ID: CKRecord] = [:]
        var stale: [CKSyncEngine.PendingRecordZoneChange] = []
        for change in changes {
            guard case .saveRecord(let id) = change else { continue }
            if let object = objects[id.recordName] {
                records[id] = makeRecord(for: object, id: id)
            } else {
                // Inmiddels weer verwijderd; de verwijdering staat al klaar.
                stale.append(change)
            }
        }
        if !stale.isEmpty {
            syncEngine.state.remove(pendingRecordZoneChanges: stale)
        }
        let toSend = changes.filter { change in
            if case .saveRecord(let id) = change { return records[id] != nil }
            return true
        }
        guard !toSend.isEmpty else { return nil }

        let recordsToSend = records
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: toSend) { id in
            recordsToSend[id]
        }
    }

    // MARK: - Wijzigingen van iCloud verwerken

    private func apply(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        var objects = localObjects()
        var changedLocally = false
        var inserted = false

        for modification in changes.modifications {
            let record = modification.record
            guard record.recordID.zoneID == Self.zoneID else { continue }
            let name = record.recordID.recordName
            let serverPrint = Self.fingerprint(of: record)

            if let object = objects[name] {
                let localPrint = Self.fingerprint(of: object)
                let hasUnsentChange = localPrint != stored.known[name]?.fingerprint
                let serverModified = record.object(forKey: "modifiedAt") as? Date ?? .distantPast
                if hasUnsentChange && object.modifiedAt > serverModified {
                    // Onze wijziging is nieuwer; die wordt zo verstuurd.
                } else if localPrint != serverPrint {
                    object.read(from: record)
                    changedLocally = true
                }
            } else if let object = Self.makeObject(from: record) {
                context.insert(object)
                objects[name] = object
                changedLocally = true
                inserted = true
            }
            stored.known[name] = KnownRecord(fingerprint: serverPrint, systemFields: Self.systemFields(of: record))
        }

        for deletion in changes.deletions where deletion.recordID.zoneID == Self.zoneID {
            let name = deletion.recordID.recordName
            if let object = objects[name] {
                context.delete(object)
                objects[name] = nil
                changedLocally = true
            }
            stored.known[name] = nil
        }

        if changedLocally {
            // Direct opslaan, zonder `ListActions.save`: dit is geen wijziging van de gebruiker.
            try? context.save()
            monitor?.didReceive(changes.modifications.count + changes.deletions.count)
        }
        stored.save()
        if inserted {
            // Hetzelfde product tegelijk op twee apparaten toegevoegd: samenvoegen.
            ListActions.mergeDuplicates(in: context)
        }
        scheduleLocalCheck()
    }

    private func handleSent(_ sent: CKSyncEngine.Event.SentRecordZoneChanges, syncEngine: CKSyncEngine) {
        var retry: [CKSyncEngine.PendingRecordZoneChange] = []
        var databaseChanges: [CKSyncEngine.PendingDatabaseChange] = []

        for record in sent.savedRecords {
            stored.known[record.recordID.recordName] = KnownRecord(
                fingerprint: Self.fingerprint(of: record),
                systemFields: Self.systemFields(of: record)
            )
        }
        for id in sent.deletedRecordIDs {
            stored.known[id.recordName] = nil
        }

        for failure in sent.failedRecordSaves {
            let id = failure.record.recordID
            let name = id.recordName
            switch failure.error.code {
            case .serverRecordChanged:
                // Een ander apparaat was net eerder: de nieuwste wijziging wint.
                guard let serverRecord = failure.error.serverRecord else { continue }
                stored.known[name] = KnownRecord(
                    fingerprint: Self.fingerprint(of: serverRecord),
                    systemFields: Self.systemFields(of: serverRecord)
                )
                let serverModified = serverRecord.object(forKey: "modifiedAt") as? Date ?? .distantPast
                if let object = localObjects()[name] {
                    if object.modifiedAt > serverModified {
                        retry.append(.saveRecord(id))
                    } else {
                        object.read(from: serverRecord)
                        try? context.save()
                    }
                }
            case .zoneNotFound:
                stored.zoneReady = false
                databaseChanges.append(.saveZone(CKRecordZone(zoneID: Self.zoneID)))
                stored.known[name]?.systemFields = nil
                retry.append(.saveRecord(id))
            case .unknownItem:
                stored.known[name]?.systemFields = nil
                retry.append(.saveRecord(id))
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                 .notAuthenticated, .operationCancelled, .requestRateLimited:
                // CKSyncEngine probeert dit zelf opnieuw.
                break
            default:
                monitor?.didFail(failure.error, step: "Versturen naar iCloud")
            }
        }

        for (id, error) in sent.failedRecordDeletes {
            if error.code == .unknownItem {
                stored.known[id.recordName] = nil
            } else if error.code != .networkFailure && error.code != .networkUnavailable {
                monitor?.didFail(error, step: "Verwijderen uit iCloud")
            }
        }

        if !databaseChanges.isEmpty { syncEngine.state.add(pendingDatabaseChanges: databaseChanges) }
        if !retry.isEmpty { syncEngine.state.add(pendingRecordZoneChanges: retry) }
        stored.save()
        if !sent.savedRecords.isEmpty || !sent.deletedRecordIDs.isEmpty {
            monitor?.didSync()
        }
        // Wat tijdens het versturen alweer veranderd is, gaat meteen hierna mee.
        scheduleLocalCheck()
    }

    private func uploadEverythingAgain() {
        stored.known = [:]
        stored.zoneReady = false
        stored.save()
        engine?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
        scheduleLocalCheck()
    }

    // MARK: - Records

    private func makeRecord(for object: any SyncedModel, id: CKRecord.ID) -> CKRecord {
        let recordType = type(of: object).recordType
        var record = CKRecord(recordType: recordType, recordID: id)
        if let data = stored.known[id.recordName]?.systemFields,
           let known = Self.record(fromSystemFields: data),
           known.recordType == recordType {
            record = known
        }
        object.write(to: record)
        return record
    }

    private static func makeObject(from record: CKRecord) -> (any SyncedModel)? {
        let object: any SyncedModel
        switch record.recordType {
        case ShoppingItem.recordType:
            object = ShoppingItem(productURL: "", name: "", brand: nil, variant: nil, category: "", imageURL: nil)
        case FavoriteProduct.recordType:
            object = FavoriteProduct(
                product: Product(url: "", name: "", brand: nil, imageURL: nil, category: "", firstSeen: nil),
                variant: nil
            )
        case CustomVariant.recordType:
            object = CustomVariant(productURL: "", name: "")
        default:
            return nil
        }
        object.syncID = record.recordID.recordName
        object.read(from: record)
        return object
    }

    private static func recordID(_ name: String) -> CKRecord.ID {
        CKRecord.ID(recordName: name, zoneID: zoneID)
    }

    /// Korte samenvatting van de inhoud van een record, om wijzigingen te herkennen.
    private static func fingerprint(of record: CKRecord) -> String {
        let keys: [String]
        switch record.recordType {
        case ShoppingItem.recordType: keys = ShoppingItem.contentKeys
        case FavoriteProduct.recordType: keys = FavoriteProduct.contentKeys
        case CustomVariant.recordType: keys = CustomVariant.contentKeys
        default: keys = record.allKeys().sorted()
        }
        let values = keys.map { key -> String in
            guard let value = record.object(forKey: key) else { return "-" }
            if let date = value as? Date { return String(Int(date.timeIntervalSince1970.rounded())) }
            if let number = value as? NSNumber { return number.stringValue }
            if let string = value as? String { return string }
            return String(describing: value)
        }
        return record.recordType + "|" + values.joined(separator: "|")
    }

    private static func fingerprint(of object: any SyncedModel) -> String {
        let record = CKRecord(recordType: type(of: object).recordType, recordID: recordID(object.syncID))
        object.write(to: record)
        return fingerprint(of: record)
    }

    private static func systemFields(of record: CKRecord) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    private static func record(fromSystemFields data: Data) -> CKRecord? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        defer { unarchiver.finishDecoding() }
        return CKRecord(coder: unarchiver)
    }
}

// MARK: - Opgeslagen synchronisatiestatus

struct KnownRecord: Codable {
    var fingerprint: String
    var systemFields: Data?
}

private struct StoredState: Codable {
    var engineState: CKSyncEngine.State.Serialization?
    /// Per record: wat iCloud als laatste van ons heeft bevestigd.
    var known: [String: KnownRecord] = [:]
    var zoneReady = false

    private static var url: URL {
        let directory = URL.applicationSupportDirectory.appending(path: "Synchronisatie", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "status.json")
    }

    static func load() -> StoredState {
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(StoredState.self, from: data)
        else { return StoredState() }
        return state
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.url, options: .atomic)
    }
}

// MARK: - Van model naar iCloud-record en terug

protocol SyncedModel: PersistentModel {
    static var recordType: String { get }
    /// Velden die meetellen om een wijziging te herkennen (zonder `modifiedAt`).
    static var contentKeys: [String] { get }
    var syncID: String { get set }
    var modifiedAt: Date { get set }
    func write(to record: CKRecord)
    func read(from record: CKRecord)
}

private extension CKRecord {
    func set(_ key: String, _ value: String?) { setObject(value.map { $0 as NSString }, forKey: key) }
    func set(_ key: String, _ value: Date?) { setObject(value.map { $0 as NSDate }, forKey: key) }
    func set(_ key: String, _ value: Int) { setObject(NSNumber(value: value), forKey: key) }
    func set(_ key: String, _ value: Bool) { setObject(NSNumber(value: value), forKey: key) }
    func string(_ key: String) -> String? { object(forKey: key) as? String }
    func date(_ key: String) -> Date? { object(forKey: key) as? Date }
    func number(_ key: String) -> NSNumber? { object(forKey: key) as? NSNumber }
}

extension ShoppingItem: SyncedModel {
    static var recordType: String { "Item" }
    static var contentKeys: [String] {
        ["productURL", "name", "brand", "variant", "category", "imageURL", "quantity", "isChecked", "addedAt", "checkedAt"]
    }

    func write(to record: CKRecord) {
        record.set("productURL", productURL)
        record.set("name", name)
        record.set("brand", brand)
        record.set("variant", variant)
        record.set("category", category)
        record.set("imageURL", imageURL)
        record.set("quantity", quantity)
        record.set("isChecked", isChecked)
        record.set("addedAt", addedAt)
        record.set("checkedAt", checkedAt)
        record.set("modifiedAt", modifiedAt)
    }

    func read(from record: CKRecord) {
        productURL = record.string("productURL") ?? ""
        name = record.string("name") ?? ""
        brand = record.string("brand")
        variant = record.string("variant")
        category = record.string("category") ?? ""
        imageURL = record.string("imageURL")
        quantity = record.number("quantity")?.intValue ?? 1
        isChecked = record.number("isChecked")?.boolValue ?? false
        addedAt = record.date("addedAt") ?? Date()
        checkedAt = record.date("checkedAt")
        modifiedAt = record.date("modifiedAt") ?? Date()
    }
}

extension FavoriteProduct: SyncedModel {
    static var recordType: String { "Favorite" }
    static var contentKeys: [String] {
        ["productURL", "name", "brand", "variant", "category", "imageURL", "addedAt"]
    }

    func write(to record: CKRecord) {
        record.set("productURL", productURL)
        record.set("name", name)
        record.set("brand", brand)
        record.set("variant", variant)
        record.set("category", category)
        record.set("imageURL", imageURL)
        record.set("addedAt", addedAt)
        record.set("modifiedAt", modifiedAt)
    }

    func read(from record: CKRecord) {
        productURL = record.string("productURL") ?? ""
        name = record.string("name") ?? ""
        brand = record.string("brand")
        variant = record.string("variant")
        category = record.string("category") ?? ""
        imageURL = record.string("imageURL")
        addedAt = record.date("addedAt") ?? Date()
        modifiedAt = record.date("modifiedAt") ?? Date()
    }
}

extension CustomVariant: SyncedModel {
    static var recordType: String { "Variant" }
    static var contentKeys: [String] { ["productURL", "name", "addedAt"] }

    func write(to record: CKRecord) {
        record.set("productURL", productURL)
        record.set("name", name)
        record.set("addedAt", addedAt)
        record.set("modifiedAt", modifiedAt)
    }

    func read(from record: CKRecord) {
        productURL = record.string("productURL") ?? ""
        name = record.string("name") ?? ""
        addedAt = record.date("addedAt") ?? Date()
        modifiedAt = record.date("modifiedAt") ?? Date()
    }
}

// MARK: - Heeft deze installatie iCloud-rechten?

enum CloudKitSetup {
    /// De iCloud-container die deze installatie mag gebruiken, of nil.
    ///
    /// Zonder iCloud-rechten laat CloudKit de app crashen, dus we kijken eerst in het
    /// provisioning-profiel dat Xcode bij een ondertekende build meelevert.
    static func containerIdentifier() -> String? {
        guard let entitlements = provisioningProfileEntitlements() else { return nil }

        let services = entitlements["com.apple.developer.icloud-services"]
        let hasCloudKit: Bool
        if let list = services as? [String] {
            hasCloudKit = list.contains("CloudKit") || list.contains("*")
        } else if let value = services as? String {
            hasCloudKit = value == "CloudKit" || value == "*"
        } else {
            hasCloudKit = false
        }
        guard hasCloudKit,
              let containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String],
              !containers.isEmpty
        else { return nil }

        let preferred = Bundle.main.object(forInfoDictionaryKey: "CloudKitContainerIdentifier") as? String
        if let preferred, containers.contains(preferred) { return preferred }
        return containers.first
    }

    private static func provisioningProfileEntitlements() -> [String: Any]? {
        #if os(macOS)
        let url = Bundle.main.bundleURL.appending(path: "Contents/embedded.provisionprofile")
        #else
        let url = Bundle.main.bundleURL.appending(path: "embedded.mobileprovision")
        #endif
        guard let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)
        return (plist as? [String: Any])?["Entitlements"] as? [String: Any]
    }
}
