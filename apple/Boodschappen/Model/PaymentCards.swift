#if os(iOS)
import Foundation
import LocalAuthentication
import Observation
import Security

/// Een betaalpas met de zin die de app voorleest en de pincode.
struct PaymentCard: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sentence: String
    var pin: String

    var spokenSentence: String {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ik betaal met \(name)." : trimmed
    }

    static func isValidPIN(_ pin: String) -> Bool {
        (4...12).contains(pin.count) && pin.allSatisfy { $0.isASCII && $0.isNumber }
    }
}

/// Betaalkaarten staan alleen op dit apparaat, in de sleutelhanger, en gaan niet mee met iCloud.
@MainActor
@Observable
final class PaymentCardStore {
    static let shared = PaymentCardStore()

    private(set) var cards: [PaymentCard] = []
    // Pas opslaan na een geslaagde lees-actie, anders kan een vergrendelde sleutelhanger
    // (bijvoorbeeld bij starten op de achtergrond) de bestaande kaarten overschrijven.
    private var isLoaded = false

    private init() {}

    func loadIfNeeded() {
        guard !isLoaded, let saved = PaymentCardKeychain.load() else { return }
        cards = saved
        isLoaded = true
    }

    /// `false` als de sleutelhanger de kaart niet kon bewaren.
    @discardableResult
    func save(_ card: PaymentCard) -> Bool {
        loadIfNeeded()
        guard isLoaded else { return false }
        var updated = cards
        if let index = updated.firstIndex(where: { $0.id == card.id }) {
            updated[index] = card
        } else {
            updated.append(card)
        }
        guard PaymentCardKeychain.save(updated) else { return false }
        cards = updated
        return true
    }

    func delete(_ card: PaymentCard) {
        guard isLoaded else { return }
        cards.removeAll { $0.id == card.id }
        persist()
    }

    func delete(atOffsets offsets: IndexSet) {
        guard isLoaded else { return }
        cards.remove(atOffsets: offsets)
        persist()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard isLoaded else { return }
        cards.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() {
        PaymentCardKeychain.save(cards)
    }
}

private enum PaymentCardKeychain {
    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "nl.joelvalentijn.Boodschappen.betaalkaarten",
            kSecAttrAccount as String: "kaarten",
        ]
    }

    /// `nil` als de sleutelhanger nu niet leesbaar is.
    static func load() -> [PaymentCard]? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return [] }
            return (try? JSONDecoder().decode([PaymentCard].self, from: data)) ?? []
        case errSecItemNotFound:
            return []
        default:
            return nil
        }
    }

    @discardableResult
    static func save(_ cards: [PaymentCard]) -> Bool {
        guard let data = try? JSONEncoder().encode(cards) else { return false }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        var status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let item = baseQuery.merging(attributes) { $1 }
            status = SecItemAdd(item as CFDictionary, nil)
        }
        return status == errSecSuccess
    }
}

enum OwnerAuthentication {
    /// Face ID, met de toegangscode als terugval.
    static func confirm(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Zonder toegangscode op het toestel valt er niets te controleren.
            return error?.code == LAError.Code.passcodeNotSet.rawValue
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
#endif
