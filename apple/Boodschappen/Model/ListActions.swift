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

    static func setQuantity(_ quantity: Int, for item: ShoppingItem, in context: ModelContext) {
        let newValue = min(99, max(1, quantity))
        guard newValue != item.quantity else { return }
        item.quantity = newValue
        save(context)
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
        for item in items(in: context).sorted(by: { ($0.addedAt, $0.syncID) < ($1.addedAt, $1.syncID) }) {
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
        for favorite in favorites(in: context).sorted(by: { ($0.addedAt, $0.syncID) < ($1.addedAt, $1.syncID) }) {
            if !favoriteKeys.insert(favorite.key).inserted {
                context.delete(favorite)
                changed = true
            }
        }

        var variantKeys = Set<String>()
        for variant in variants(in: context).sorted(by: { ($0.addedAt, $0.syncID) < ($1.addedAt, $1.syncID) }) {
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
        let now = Date()
        for model in context.insertedModelsArray + context.changedModelsArray {
            if let synced = model as? any SyncedModel {
                synced.modifiedAt = now
            }
        }
        do {
            try context.save()
            NotificationCenter.default.post(name: .boodschappenLocalChange, object: nil)
        } catch {
            print("Opslaan mislukt: \(error)")
        }
    }

    /// Geeft objecten zonder (of met een dubbele) syncID een eigen ID.
    /// Nodig voor gegevens van vóór de synchronisatie via CloudSync.
    static func ensureSyncIDs(in context: ModelContext) {
        var seen = Set<String>()
        var changed = false
        func fix(_ object: any SyncedModel) {
            if object.syncID.isEmpty || !seen.insert(object.syncID).inserted {
                object.syncID = UUID().uuidString
                seen.insert(object.syncID)
                changed = true
            }
        }
        for item in items(in: context) { fix(item) }
        for favorite in favorites(in: context) { fix(favorite) }
        for variant in variants(in: context) { fix(variant) }
        if changed { save(context) }
    }
}
