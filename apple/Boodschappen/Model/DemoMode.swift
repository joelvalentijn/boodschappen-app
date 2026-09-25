#if DEBUG
import Foundation
import SwiftData

/// Alleen in debug-builds: start de app met voorbeeldgegevens, voor screenshots.
///
///     -demo YES                lijst vullen met voorbeeldproducten
///     -demoScherm producten    meteen de productkiezer openen
///     -demoScherm zegeltjes    meteen het zegeltjes-scherm openen
///     -demoZoek melk           met deze zoekterm starten
///     -demoCategorie Kaas      (iPad/Mac) deze categorie tonen
enum DemoMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo")
    }

    static var startScreen: String? {
        isEnabled ? UserDefaults.standard.string(forKey: "demoScherm") : nil
    }

    static var startCategory: String? {
        isEnabled ? UserDefaults.standard.string(forKey: "demoCategorie") : nil
    }

    static var initialSearch: String {
        isEnabled ? UserDefaults.standard.string(forKey: "demoZoek") ?? "" : ""
    }

    @MainActor
    static func seedIfNeeded(catalog: CatalogStore, context: ModelContext) {
        guard isEnabled, catalog.isLoaded, ListActions.items(in: context).isEmpty else { return }

        let wishes: [(query: String, variant: String?, quantity: Int, checked: Bool)] = [
            ("bananen", nil, 1, false),
            ("komkommer", nil, 2, false),
            ("volkoren desembrood", nil, 1, false),
            ("halfvolle melk", "Halfvol", 2, false),
            ("griekse yoghurt", nil, 1, true),
            ("goudse kaas belegen plakken", nil, 1, false),
            ("kipfilet", nil, 1, false),
            ("koffiepads", nil, 1, true),
            ("chips paprika", nil, 3, false),
        ]
        for wish in wishes {
            guard let product = catalog.search(wish.query, limit: 1).first else { continue }
            if let variant = wish.variant {
                ListActions.addVariant(variant, to: product, in: context)
            }
            let item = ListActions.add(product, variant: wish.variant, quantity: wish.quantity, in: context)
            if wish.checked {
                ListActions.toggleChecked(item, in: context)
            }
            if wish.query == "kipfilet" || wish.query == "chips paprika" {
                ListActions.toggleFavorite(product, variant: nil, in: context)
            }
        }
        ListActions.addCustom(named: "Verjaardagskaart", in: context)
    }
}
#endif
