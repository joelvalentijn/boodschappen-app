import Foundation

/// Een product uit de Lidl-catalogus (products.json).
struct Product: Identifiable, Hashable, Sendable {
    let url: String
    let name: String
    let brand: String?
    let imageURL: String?
    let category: String
    let firstSeen: Date?
    let searchKey: String
    let nameKey: String

    var id: String { url }

    init(url: String, name: String, brand: String?, imageURL: String?, category: String, firstSeen: Date?) {
        self.url = url
        self.name = name
        self.brand = brand
        self.imageURL = imageURL
        self.category = category
        self.firstSeen = firstSeen
        self.nameKey = name.searchNormalized
        self.searchKey = [brand, name, category]
            .compactMap { $0 }
            .joined(separator: " ")
            .searchNormalized
    }
}

struct CatalogCategory: Identifiable, Hashable, Sendable {
    let name: String
    let emoji: String
    let products: [Product]

    var id: String { name }

    /// Categorie voor zelf ingetypte producten die niet in de catalogus staan.
    static let customName = "Eigen producten"

    static func defaultEmoji(for name: String) -> String {
        switch name {
        case "Groente & fruit": "🥦"
        case "Brood & bakkerij": "🍞"
        case "Vers vlees, vis & vega": "🥩"
        case "Vleeswaren & beleg": "🥪"
        case "Kaas": "🧀"
        case "Zuivel, plantaardig & eieren": "🥛"
        case "Verse maaltijden & pizza": "🍕"
        case "Pasta, rijst & wereldkeuken": "🍝"
        case "Sauzen, kruiden & olie": "🫒"
        case "Conserven & soepen": "🥫"
        case "Ontbijt & cereals": "🥣"
        case "Koffie & thee": "☕"
        case "Snoep & chocolade": "🍫"
        case "Snacks, koeken & noten": "🍪"
        case "Frisdrank, sap & water": "🥤"
        case "Bier & wijn": "🍷"
        case "Diepvries": "🧊"
        case "Huishouden & schoonmaak": "🧹"
        case "Verzorging": "🧴"
        case "Huisdieren": "🐾"
        case "Bloemen & planten": "💐"
        case customName: "✏️"
        default: "📦"
        }
    }
}

/// Een ingelezen versie van products.json.
struct CatalogSnapshot: Sendable {
    let categories: [CatalogCategory]
    let generatedAt: Date?

    var allProducts: [Product] { categories.flatMap(\.products) }

    private struct RawCatalog: Decodable {
        let generatedAt: String?
        let categories: [RawCategory]
    }

    private struct RawCategory: Decodable {
        let name: String
        let emoji: String?
        let products: [RawProduct]
    }

    private struct RawProduct: Decodable {
        let name: String
        let brand: String?
        let image: String?
        let url: String
        let firstSeen: String?
    }

    static func decode(_ data: Data) throws -> CatalogSnapshot {
        let raw = try JSONDecoder().decode(RawCatalog.self, from: data)

        let dayFormatter = ISO8601DateFormatter()
        dayFormatter.formatOptions = [.withFullDate]

        var seenURLs = Set<String>()
        let categories = raw.categories.compactMap { rawCategory -> CatalogCategory? in
            let products = rawCategory.products.compactMap { rawProduct -> Product? in
                guard !rawProduct.url.isEmpty, seenURLs.insert(rawProduct.url).inserted else { return nil }
                return Product(
                    url: rawProduct.url,
                    name: rawProduct.name,
                    brand: rawProduct.brand,
                    imageURL: rawProduct.image,
                    category: rawCategory.name,
                    firstSeen: rawProduct.firstSeen.flatMap { dayFormatter.date(from: $0) }
                )
            }
            guard !products.isEmpty else { return nil }
            return CatalogCategory(
                name: rawCategory.name,
                emoji: rawCategory.emoji ?? CatalogCategory.defaultEmoji(for: rawCategory.name),
                products: products
            )
        }
        return CatalogSnapshot(categories: categories, generatedAt: raw.generatedAt.flatMap(parseTimestamp))
    }

    private static func parseTimestamp(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text)
    }
}

extension String {
    /// Kleine letters, zonder accenten: "Crème Fraîche" → "creme fraiche".
    var searchNormalized: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_NL"))
    }
}
