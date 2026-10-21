import Foundation
import Observation

/// De drie stappen van de winkelmodus.
enum ShopStep: String, CaseIterable, Identifiable {
    case help, shopping, checkout

    var id: String { rawValue }

    var title: String {
        switch self {
        case .help: "Hulp"
        case .shopping: "Winkelen"
        case .checkout: "Afrekenen"
        }
    }

    var systemImage: String {
        switch self {
        case .help: "hand.wave.fill"
        case .shopping: "cart.fill"
        case .checkout: "creditcard.fill"
        }
    }

    var defaultMessages: [String] {
        switch self {
        case .help:
            [
                "Kun je mij helpen mijn boodschappen te pakken en af te rekenen?",
                "Ik heb een lijstje gemaakt in de app.",
                "Wil je op mijn telefoon kijken?",
            ]
        case .shopping:
            [
                "Wil je op mijn telefoon kijken?",
                "Een ander merk is ook goed.",
                "Dank je wel!",
            ]
        case .checkout:
            [
                "Ik wil graag zegeltjes alstublieft",
                "Mag ik de bon?",
                "Bedankt voor je hulp en fijne dag nog!",
            ]
        }
    }
}

/// Hoe de winkelmodus geopend wordt: met de lijst, of alleen voor zinnen en betalen.
enum ShopModeEntry: String, Identifiable {
    case shopping, talk

    var id: String { rawValue }

    /// `nil`: eerst de volgorde van de producten bepalen.
    var startStep: ShopStep? {
        switch self {
        case .shopping: nil
        case .talk: .help
        }
    }
}

struct ShopMessage: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
}

/// De zinnen per stap; aanpasbaar in Instellingen en alleen op dit apparaat bewaard.
@MainActor
@Observable
final class ShopMessageStore {
    static let shared = ShopMessageStore()

    private static let storageKey = "winkelBerichten"
    private var messagesByStep: [String: [ShopMessage]]

    private init() {
        var saved: [String: [ShopMessage]] = [:]
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: [ShopMessage]].self, from: data) {
            saved = decoded
        }
        for step in ShopStep.allCases where saved[step.rawValue] == nil {
            saved[step.rawValue] = step.defaultMessages.map { ShopMessage(text: $0) }
        }
        messagesByStep = saved
    }

    func messages(for step: ShopStep) -> [ShopMessage] {
        messagesByStep[step.rawValue] ?? []
    }

    /// Alleen berichten met tekst, voor in de winkelmodus.
    func usableMessages(for step: ShopStep) -> [ShopMessage] {
        messages(for: step).filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func update(_ step: ShopStep, _ change: (inout [ShopMessage]) -> Void) {
        var messages = messages(for: step)
        change(&messages)
        messagesByStep[step.rawValue] = messages
        persist()
    }

    func resetToDefaults(for step: ShopStep) {
        update(step) { $0 = step.defaultMessages.map { ShopMessage(text: $0) } }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(messagesByStep) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
