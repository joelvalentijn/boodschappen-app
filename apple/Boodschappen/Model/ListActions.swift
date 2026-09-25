import Foundation
import SwiftData

/// Alle wijzigingen aan de lijst, favorieten en varianten op één plek.
@MainActor
enum ListActions {
    // MARK: - Boodschappenlijst

    @discardableResult
    static func add(_ product: Product, variant: String?, quantity: Int = 1, in context: ModelContext) -> ShoppingItem {
        let key = ItemKey.make(url: product.url, name: product.name, variant: variant)
        if let existing = items(in: context).first(where: { $0.key == key }) {
            existing.quantity = min(99, existing.quantity + quantity)
            if existing.isChecked {
                existing.isChecked = false
                existing.checkedAt = nil
            }
            save(context)
            return existing
        }
        let item = ShoppingItem(
            productURL: product.url,
            name: product.name,
            brand: product.brand,
            variant: variant,
            category: product.category,
            imageURL: product.imageURL,
            quantity: min(99, max(1, quantity))
        )
        context.insert(item)
        save(context)
        return item
    }

    /// Een eigen product toevoegen dat niet in de catalogus staat.
    static func addCustom(named name: String, in context: ModelContext) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let product = Product(
            url: "",
            name: trimmed.prefix(1).uppercased() + trimmed.dropFirst(),
            brand: nil,
            imageURL: nil,
            category: CatalogCategory.customName,
            firstSeen: nil
        )
        add(product, variant: nil, in: context)
    }

    static func toggleChecked(_ item: ShoppingItem, in context: ModelContext) {
        item.isChecked.toggle()
        item.checkedAt = item.isChecked ? Date() : nil
        save(context)
    }

    static func delete(_ item: ShoppingItem, in context: ModelContext) {
        context.delete(item)
        save(context)
    }

    static func removeChecked(in context: ModelContext) {
        for item in items(in: context) where item.isChecked {
            context.delete(item)
        }
        save(context)
    }

    static func clearList(in context: ModelContext) {
        for item in items(in: context) {
            context.delete(item)
        }
        save(context)
    }

    // MARK: - Favorieten

    static func toggleFavorite(_ product: Product, variant: String?, in context: ModelContext) {
        let key = ItemKey.make(url: product.url, name: product.name, variant: variant)
        let existing = favorites(in: context).filter { $0.key == key }
        if existing.isEmpty {
            context.insert(FavoriteProduct(product: product, variant: variant))
        } else {
            existing.forEach { context.delete($0) }
        }
        save(context)
    }

    // MARK: - Varianten

    static func addVariant(_ name: String, to product: Product, in context: ModelContext) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let alreadyExists = variants(in: context).contains {
            $0.productURL == product.url && $0.name.lowercased() == trimmed.lowercased()
        }
        guard !alreadyExists else { return }
        context.insert(CustomVariant(productURL: product.url, name: trimmed))
        save(context)
    }

    static func delete(_ variant: CustomVariant, in context: ModelContext) {
        context.delete(variant)
        save(context)
    }

    // MARK: - Opruimen na synchronisatie

    /// Als hetzelfde product op twee apparaten tegelijk is toegevoegd, kan het na
    /// synchronisatie dubbel voorkomen. Deze functie voegt dubbele regels samen.
    static func mergeDuplicates(in context: ModelContext) {
        var changed = false

        var itemsByKey: [String: ShoppingItem] = [:]
        for item in items(in: context).sorted(by: { $0.addedAt < $1.addedAt }) {
            if let keep = itemsByKey[item.key] {
                keep.quantity = max(keep.quantity, item.quantity)
                keep.isChecked = keep.isChecked && item.isChecked
                context.delete(item)
                changed = true
            } else {
                itemsByKey[item.key] = item
            }
        }

        var favoriteKeys = Set<String>()
        for favorite in favorites(in: context).sorted(by: { $0.addedAt < $1.addedAt }) {
            if !favoriteKeys.insert(favorite.key).inserted {
                context.delete(favorite)
                changed = true
            }
        }

        var variantKeys = Set<String>()
        for variant in variants(in: context).sorted(by: { $0.addedAt < $1.addedAt }) {
            if !variantKeys.insert(variant.productURL + "__" + variant.name.lowercased()).inserted {
                context.delete(variant)
                changed = true
            }
        }

        if changed { save(context) }
    }

    // MARK: - Hulpfuncties

    static func items(in context: ModelContext) -> [ShoppingItem] {
        (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []
    }

    static func favorites(in context: ModelContext) -> [FavoriteProduct] {
        (try? context.fetch(FetchDescriptor<FavoriteProduct>())) ?? []
    }

    static func variants(in context: ModelContext) -> [CustomVariant] {
        (try? context.fetch(FetchDescriptor<CustomVariant>())) ?? []
    }

    static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            print("Opslaan mislukt: \(error)")
        }
    }
}
