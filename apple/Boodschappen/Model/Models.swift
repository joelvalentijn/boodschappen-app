import Foundation
import SwiftData

// Let op: voor iCloud-synchronisatie moeten alle velden een standaardwaarde
// hebben of optioneel zijn, en mogen er geen unieke velden zijn.

/// Een product op de boodschappenlijst.
@Model
final class ShoppingItem {
    var productURL: String = ""
    var name: String = ""
    var brand: String?
    var variant: String?
    var category: String = ""
    var imageURL: String?
    var quantity: Int = 1
    var isChecked: Bool = false
    var addedAt: Date = Date()
    var checkedAt: Date?

    init(
        productURL: String,
        name: String,
        brand: String?,
        variant: String?,
        category: String,
        imageURL: String?,
        quantity: Int = 1
    ) {
        self.productURL = productURL
        self.name = name
        self.brand = brand
        self.variant = variant
        self.category = category
        self.imageURL = imageURL
        self.quantity = quantity
        self.addedAt = Date()
    }

    var key: String { ItemKey.make(url: productURL, name: name, variant: variant) }
    var isCustom: Bool { productURL.isEmpty }
}

/// Een favoriet product, eventueel in een specifieke variant.
@Model
final class FavoriteProduct {
    var productURL: String = ""
    var name: String = ""
    var brand: String?
    var variant: String?
    var category: String = ""
    var imageURL: String?
    var addedAt: Date = Date()

    init(product: Product, variant: String?) {
        self.productURL = product.url
        self.name = product.name
        self.brand = product.brand
        self.variant = variant
        self.category = product.category
        self.imageURL = product.imageURL
        self.addedAt = Date()
    }

    var key: String { ItemKey.make(url: productURL, name: name, variant: variant) }

    /// Het product uit de catalogus, of een reconstructie als het niet meer bestaat.
    @MainActor
    func product(in catalog: CatalogStore) -> Product {
        catalog.product(url: productURL) ?? Product(
            url: productURL,
            name: name,
            brand: brand,
            imageURL: imageURL,
            category: category,
            firstSeen: nil
        )
    }
}

/// Een eigen variant van een product, zoals "Halfvol" of "Aardbei".
@Model
final class CustomVariant {
    var productURL: String = ""
    var name: String = ""
    var addedAt: Date = Date()

    init(productURL: String, name: String) {
        self.productURL = productURL
        self.name = name
        self.addedAt = Date()
    }
}

enum ItemKey {
    static func make(url: String, name: String, variant: String?) -> String {
        let base = url.isEmpty ? "eigen:" + name.lowercased() : url
        guard let variant, !variant.isEmpty else { return base }
        return base + "__" + variant.lowercased()
    }
}
