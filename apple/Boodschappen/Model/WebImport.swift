import Foundation
import SwiftData

/// Neemt de lijst, favorieten en varianten over uit de web-app
/// (knop "Overzetten naar app" op de website kopieert deze gegevens).
@MainActor
enum WebImport {
    struct Result {
        var items = 0
        var favorites = 0
        var variants = 0

        var summary: String {
            if items + favorites + variants == 0 {
                return "Alles stond al in de app."
            }
            return "Overgenomen: \(items) producten, \(favorites) favorieten en \(variants) varianten."
        }
    }

    enum ImportError: LocalizedError {
        case invalidData

        var errorDescription: String? {
            "Dit lijkt geen export uit de web-app. Tik op de website op ‘Overzetten naar app’ en probeer het opnieuw."
        }
    }

    private struct Export: Decodable {
        let items: [WebItem]?
        let favorites: [String: WebFavorite]?
        let variants: [String: [String]]?
    }

    private struct WebItem: Decodable {
        let productName: String
        let variant: String?
        let brand: String?
        let category: String?
        let image: String?
        let url: String?
        let quantity: Int?
        let checked: Bool?
    }

    private struct WebFavorite: Decodable {
        let name: String
        let brand: String?
        let image: String?
        let url: String
        let variant: String?
    }

    static func importData(_ text: String, catalog: CatalogStore, into context: ModelContext) throws -> Result {
        guard let data = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let export = try? JSONDecoder().decode(Export.self, from: data),
              export.items != nil || export.favorites != nil || export.variants != nil
        else {
            throw ImportError.invalidData
        }

        var result = Result()

        let existingItemKeys = Set(ListActions.items(in: context).map(\.key))
        for item in export.items ?? [] {
            let product = resolve(url: item.url ?? "", name: item.productName, brand: item.brand,
                                  image: item.image, category: item.category, catalog: catalog)
            let key = ItemKey.make(url: product.url, name: product.name, variant: item.variant)
            guard !existingItemKeys.contains(key) else { continue }
            let added = ListActions.add(product, variant: item.variant, quantity: item.quantity ?? 1, in: context)
            if item.checked == true {
                added.isChecked = true
                added.checkedAt = Date()
            }
            result.items += 1
        }

        let existingFavoriteKeys = Set(ListActions.favorites(in: context).map(\.key))
        for favorite in (export.favorites ?? [:]).values {
            let product = resolve(url: favorite.url, name: favorite.name, brand: favorite.brand,
                                  image: favorite.image, category: nil, catalog: catalog)
            let key = ItemKey.make(url: product.url, name: product.name, variant: favorite.variant)
            guard !existingFavoriteKeys.contains(key) else { continue }
            context.insert(FavoriteProduct(product: product, variant: favorite.variant))
            result.favorites += 1
        }

        let before = ListActions.variants(in: context).count
        for (url, names) in export.variants ?? [:] {
            let product = resolve(url: url, name: "", brand: nil, image: nil, category: nil, catalog: catalog)
            for name in names {
                ListActions.addVariant(name, to: product, in: context)
            }
        }
        result.variants = ListActions.variants(in: context).count - before

        ListActions.save(context)
        return result
    }

    private static func resolve(url: String, name: String, brand: String?, image: String?,
                                category: String?, catalog: CatalogStore) -> Product {
        if let product = catalog.product(url: url) { return product }
        return Product(
            url: url,
            name: name,
            brand: brand,
            imageURL: image?.hasPrefix("data:") == true ? nil : image,
            category: category ?? CatalogCategory.customName,
            firstSeen: nil
        )
    }
}
