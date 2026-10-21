import SwiftUI
import Observation

/// Een winkel met een eigen catalogus en een eigen boodschappenlijst.
enum Store: String, CaseIterable, Identifiable, Sendable {
    case lidl
    case hema

    var id: String { rawValue }

    var name: String {
        switch self {
        case .lidl: "Lidl"
        case .hema: "HEMA"
        }
    }

    /// Webadres van de winkel, voor knoppen als "Bekijk op lidl.nl".
    var host: String {
        switch self {
        case .lidl: "lidl.nl"
        case .hema: "hema.nl"
        }
    }

    var tagline: String {
        switch self {
        case .lidl: "Boodschappen, vers en houdbaar"
        case .hema: "Snoep, verzorging, huishouden en meer"
        }
    }

    var color: Color {
        switch self {
        case .lidl: Color(red: 0.0, green: 0.31, blue: 0.67)
        case .hema: Color(red: 0.89, green: 0.02, blue: 0.07)
        }
    }

    /// Naam van de catalogus in de app en op GitHub (zonder `.json`).
    var catalogName: String {
        switch self {
        case .lidl: "products"
        case .hema: "products-hema"
        }
    }

    var remoteCatalogURL: URL {
        URL(string: "https://raw.githubusercontent.com/joelvalentijn/boodschappen-app/main/\(catalogName).json")!
    }

    /// De winkel waar een productlink bij hoort; `nil` voor eigen producten zonder link.
    init?(productURL: String) {
        guard let host = URL(string: productURL)?.host else { return nil }
        guard let store = Store.allCases.first(where: { host.hasSuffix($0.host) }) else { return nil }
        self = store
    }

    /// Opgeslagen waarde van een lijstregel of favoriet. Leeg = van vóór de HEMA, dus Lidl.
    init(storedValue: String) {
        self = Store(rawValue: storedValue) ?? .lidl
    }

    /// De winkel die nu open staat; nieuwe producten en eigen producten komen in deze lijst.
    @MainActor static var current: Store = .lidl
}

/// Welke winkel er gekozen is, met per winkel een eigen catalogus.
@MainActor
@Observable
final class StoreSelection {
    /// `nil`: de app is net geopend en er is nog geen winkel gekozen.
    var current: Store? {
        didSet {
            guard let current else { return }
            Store.current = current
            UserDefaults.standard.set(current.rawValue, forKey: Self.lastStoreKey)
        }
    }

    @ObservationIgnored private let catalogs: [Store: CatalogStore] =
        Dictionary(uniqueKeysWithValues: Store.allCases.map { ($0, CatalogStore(store: $0)) })

    init() {
        #if DEBUG
        // Screenshots: meteen de lijst tonen (kies de winkel met `-demoWinkel hema`).
        if DemoMode.isEnabled {
            current = UserDefaults.standard.string(forKey: "demoWinkel").flatMap(Store.init(rawValue:)) ?? .lidl
            Store.current = current ?? .lidl
        }
        #endif
    }

    /// De winkel van de vorige keer, om in het keuzescherm te markeren.
    var lastStore: Store? {
        UserDefaults.standard.string(forKey: Self.lastStoreKey).flatMap(Store.init(rawValue:))
    }

    func catalog(for store: Store) -> CatalogStore {
        catalogs[store]!
    }

    private static let lastStoreKey = "laatsteWinkel"
}

extension ShoppingItem {
    var shop: Store { Store(storedValue: storeID) }
}

extension FavoriteProduct {
    var shop: Store { Store(storedValue: storeID) }
}
