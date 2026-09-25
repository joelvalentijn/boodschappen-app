import SwiftUI
import SwiftData

enum BrowseScope: Hashable {
    case all
    case favorites
    case new
    case category(String)
}

struct ProductEntry: Identifiable, Hashable {
    let product: Product
    var variant: String?

    var id: String { product.url + "|" + product.name + "|" + (variant ?? "") }
}

/// Startscherm van de productkiezer op iPhone: zoeken of een categorie kiezen.
struct ProductBrowserView: View {
    @Environment(CatalogStore.self) private var catalog
    #if DEBUG
    @State private var searchText = DemoMode.initialSearch
    #else
    @State private var searchText = ""
    #endif

    private var query: String { searchText.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        Group {
            if query.isEmpty {
                CategoryGridView()
            } else {
                ProductListView(
                    entries: catalog.search(query).map { ProductEntry(product: $0) },
                    customName: query
                )
            }
        }
        .navigationTitle("Producten")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Zoek in \(catalog.allProducts.count) producten"
        )
        #else
        .searchable(text: $searchText, prompt: "Zoek een product")
        #endif
        .autocorrectionDisabled()
        .navigationDestination(for: BrowseScope.self) { scope in
            ScopedProductsView(scope: scope)
        }
    }
}

struct CategoryGridView: View {
    @Environment(CatalogStore.self) private var catalog
    @Query private var favorites: [FavoriteProduct]

    private let columns = [GridItem(.adaptive(minimum: 155), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                if !favorites.isEmpty {
                    NavigationLink(value: BrowseScope.favorites) {
                        CategoryTile(emoji: "❤️", title: "Favorieten", count: favorites.count, tint: .red)
                    }
                }
                let newCount = catalog.newProducts.count
                if newCount > 0 {
                    NavigationLink(value: BrowseScope.new) {
                        CategoryTile(emoji: "✨", title: "Nieuw bij Lidl", count: newCount, tint: .orange)
                    }
                }
                ForEach(catalog.categories) { category in
                    NavigationLink(value: BrowseScope.category(category.name)) {
                        CategoryTile(
                            emoji: category.emoji,
                            title: category.name,
                            count: category.products.count,
                            tint: .accentColor
                        )
                    }
                }
            }
            .buttonStyle(.plain)
            .padding()
        }
        .background(Color.groupedBackground)
        .overlay {
            if !catalog.isLoaded {
                ProgressView()
            }
        }
    }
}

struct CategoryTile: View {
    let emoji: String
    let title: String
    let count: Int
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Producten binnen een categorie, de favorieten, het nieuwe assortiment of alles.
struct ScopedProductsView: View {
    let scope: BrowseScope

    @Environment(CatalogStore.self) private var catalog
    @Query(sort: \FavoriteProduct.addedAt, order: .reverse) private var favorites: [FavoriteProduct]
    @State private var searchText = ""

    private var query: String { searchText.trimmingCharacters(in: .whitespaces) }

    private var title: String {
        switch scope {
        case .all: "Alle producten"
        case .favorites: "Favorieten"
        case .new: "Nieuw bij Lidl"
        case .category(let name): name
        }
    }

    private var entries: [ProductEntry] {
        switch scope {
        case .all:
            return (query.isEmpty ? catalog.allProducts : catalog.search(query))
                .map { ProductEntry(product: $0) }
        case .new:
            let products = catalog.newProducts
            return (query.isEmpty ? products : catalog.search(query, in: products))
                .map { ProductEntry(product: $0) }
        case .category(let name):
            let products = catalog.products(in: name)
            return (query.isEmpty ? products : catalog.search(query, in: products))
                .map { ProductEntry(product: $0) }
        case .favorites:
            let all = favorites.map { ProductEntry(product: $0.product(in: catalog), variant: $0.variant) }
            guard !query.isEmpty else { return all }
            let terms = query.searchNormalized.split(separator: " ").map(String.init)
            return all.filter { entry in
                let text = entry.product.searchKey + " " + (entry.variant ?? "").searchNormalized
                return terms.allSatisfy { text.contains($0) }
            }
        }
    }

    private var emptyMessage: String {
        switch scope {
        case .favorites: "Nog geen favorieten. Tik op het hartje bij een product."
        case .new: "Er zijn de laatste weken geen nieuwe producten bijgekomen."
        default: "Geen producten gevonden"
        }
    }

    var body: some View {
        ProductListView(
            entries: entries,
            customName: scope == .all ? query : nil,
            emptyMessage: emptyMessage
        )
        .navigationTitle(title)
        .searchable(text: $searchText, prompt: "Zoek in \(title.lowercased())")
        .autocorrectionDisabled()
    }
}
