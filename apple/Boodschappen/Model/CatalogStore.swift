import Foundation
import Observation

/// Laadt de productcatalogus en haalt periodiek de nieuwste versie op van GitHub,
/// zodat nieuwe Lidl-producten verschijnen zonder de app opnieuw te installeren.
@MainActor
@Observable
final class CatalogStore {
    private(set) var categories: [CatalogCategory] = []
    private(set) var allProducts: [Product] = []
    private(set) var generatedAt: Date?
    private(set) var isLoaded = false
    private(set) var isRefreshing = false
    private(set) var statusMessage: String?

    @ObservationIgnored private var productsByURL: [String: Product] = [:]
    @ObservationIgnored private var categoryOrder: [String: Int] = [:]
    @ObservationIgnored private var didStartLoading = false

    /// Producten die de afgelopen drie weken voor het eerst in het assortiment zijn gezien.
    var newProducts: [Product] {
        let cutoff = Date().addingTimeInterval(-21 * 24 * 60 * 60)
        return allProducts
            .filter { ($0.firstSeen ?? .distantPast) >= cutoff }
            .sorted { ($0.firstSeen ?? .distantPast) > ($1.firstSeen ?? .distantPast) }
    }

    func product(url: String) -> Product? {
        productsByURL[url]
    }

    func products(in category: String) -> [Product] {
        categories.first { $0.name == category }?.products ?? []
    }

    func emoji(for category: String) -> String {
        categories.first { $0.name == category }?.emoji ?? CatalogCategory.defaultEmoji(for: category)
    }

    /// Positie van een categorie in de winkel (voor het sorteren van de lijst).
    func sortIndex(for category: String) -> Int {
        categoryOrder[category] ?? Int.max
    }

    // MARK: - Zoeken

    func search(_ query: String, in products: [Product]? = nil, limit: Int = 250) -> [Product] {
        let terms = query.searchNormalized
            .split(whereSeparator: { $0 == " " || $0 == "-" })
            .map(String.init)
        guard !terms.isEmpty else { return products ?? [] }
        let phrase = terms.joined(separator: " ")

        let matches = (products ?? allProducts).filter { product in
            terms.allSatisfy { product.searchKey.contains($0) }
        }

        // In het Nederlands staat het hoofdwoord achteraan: "halfvolle melk" is melk,
        // "melk brioche" is brood. Namen die op de zoekterm eindigen gaan dus voor.
        func endsWithPhrase(_ name: String) -> Bool {
            name.hasSuffix(phrase) || name.hasSuffix(phrase + "s") || name.hasSuffix(phrase + "en")
        }

        // De afdeling waar de zoekterm het vaakst het hoofdwoord is ("melk" → zuivel)
        // krijgt voorrang boven producten die er alleen naar smaken ("hagelslag melk").
        var headCounts: [String: Int] = [:]
        for product in matches where endsWithPhrase(product.nameKey) {
            headCounts[product.category, default: 0] += 1
        }
        let mainCategory = headCounts.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key
        }?.key

        var scored: [(score: Int, product: Product)] = []
        for product in matches {
            let name = product.nameKey
            var score = 0
            if name == phrase { score += 20 }
            if (" " + name + " ").contains(" " + phrase + " ") { score += 6 }
            if endsWithPhrase(name) { score += 5 }
            if name.hasPrefix(phrase) { score += 3 }
            if name.contains(phrase) { score += 1 }
            if product.category == mainCategory { score += 4 }
            scored.append((score, product))
        }
        scored.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.product.name.count != rhs.product.name.count {
                return lhs.product.name.count < rhs.product.name.count
            }
            return lhs.product.name.localizedStandardCompare(rhs.product.name) == .orderedAscending
        }
        return scored.prefix(limit).map { $0.product }
    }

    // MARK: - Laden

    func load() async {
        guard !didStartLoading else { return }
        didStartLoading = true

        let bundledURL = Bundle.main.url(forResource: "products", withExtension: "json")
        let cacheURL = CatalogFiles.cacheURL
        let snapshot = await Task.detached(priority: .userInitiated) { () -> CatalogSnapshot? in
            let bundled = bundledURL
                .flatMap { try? Data(contentsOf: $0) }
                .flatMap { try? CatalogSnapshot.decode($0) }
            let cached = (try? Data(contentsOf: cacheURL))
                .flatMap { try? CatalogSnapshot.decode($0) }
            // Gebruik de nieuwste: de gedownloade versie of die in de app.
            if let bundled, let cached {
                return (cached.generatedAt ?? .distantPast) > (bundled.generatedAt ?? .distantPast) ? cached : bundled
            }
            return cached ?? bundled
        }.value

        if let snapshot { apply(snapshot) }
        isLoaded = true
        await refresh(force: false)
    }

    /// Controleert of er een nieuwere catalogus op GitHub staat.
    func refresh(force: Bool) async {
        let defaults = UserDefaults.standard
        if !force, let last = defaults.object(forKey: CatalogFiles.lastCheckKey) as? Date,
           Date().timeIntervalSince(last) < 6 * 60 * 60 {
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            var request = URLRequest(url: CatalogFiles.remoteURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let snapshot = try await Task.detached(priority: .utility) {
                try CatalogSnapshot.decode(data)
            }.value
            defaults.set(Date(), forKey: CatalogFiles.lastCheckKey)

            guard (snapshot.generatedAt ?? .distantPast) > (generatedAt ?? .distantPast) else {
                statusMessage = "Je hebt de nieuwste productlijst al."
                return
            }
            let knownURLs = Set(allProducts.map(\.url))
            let added = snapshot.allProducts.filter { !knownURLs.contains($0.url) }.count
            apply(snapshot)
            try? data.write(to: CatalogFiles.cacheURL, options: .atomic)
            statusMessage = added == 1 ? "1 nieuw product gevonden." : "\(added) nieuwe producten gevonden."
        } catch {
            if force { statusMessage = "Kon niet controleren op nieuwe producten. Ben je online?" }
        }
    }

    private func apply(_ snapshot: CatalogSnapshot) {
        categories = snapshot.categories
        allProducts = snapshot.allProducts
        generatedAt = snapshot.generatedAt
        productsByURL = Dictionary(allProducts.map { ($0.url, $0) }, uniquingKeysWith: { first, _ in first })
        categoryOrder = Dictionary(
            snapshot.categories.enumerated().map { ($0.element.name, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}

enum CatalogFiles {
    static let remoteURL = URL(string: "https://raw.githubusercontent.com/joelvalentijn/boodschappen-app/main/products.json")!
    static let lastCheckKey = "catalogusLaatstGecontroleerd"

    static var cacheURL: URL {
        let directory = URL.applicationSupportDirectory.appending(path: "Catalogus", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "products.json")
    }
}
