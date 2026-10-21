import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Op iPhone: de lijst met een knop om producten te kiezen.
/// Op iPad en Mac: categorieën, producten en de lijst naast elkaar.
struct RootView: View {
    #if DEBUG
    @Environment(\.modelContext) private var context
    @Environment(CatalogStore.self) private var catalog
    #endif
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        layout
            #if DEBUG
            .task(id: catalog.isLoaded) {
                DemoMode.seedIfNeeded(catalog: catalog, context: context)
            }
            #endif
    }

    @ViewBuilder
    private var layout: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            PhoneRootView()
        } else {
            SplitRootView()
        }
        #else
        SplitRootView()
        #endif
    }
}

struct PhoneRootView: View {
    #if DEBUG
    @State private var showingProducts = DemoMode.startScreen == "producten"
    #else
    @State private var showingProducts = false
    #endif

    var body: some View {
        NavigationStack {
            ShoppingListView(onAddProducts: { showingProducts = true })
        }
        .sheet(isPresented: $showingProducts) {
            ProductPickerSheet()
        }
    }
}

struct ProductPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ProductBrowserView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Klaar") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
        }
    }
}

struct SplitRootView: View {
    @Environment(CatalogStore.self) private var catalog
    @Query private var allFavorites: [FavoriteProduct]
    #if DEBUG
    @State private var scope: BrowseScope? = DemoMode.startCategory.map { BrowseScope.category($0) } ?? .all
    #else
    @State private var scope: BrowseScope? = .all
    #endif

    var body: some View {
        NavigationSplitView {
            List(selection: $scope) {
                Section {
                    Label("Alle producten", systemImage: "square.grid.2x2")
                        .tag(BrowseScope.all)
                    Label("Favorieten", systemImage: "heart")
                        .badge(allFavorites.filter { $0.shop == catalog.store }.count)
                        .tag(BrowseScope.favorites)
                    let newCount = catalog.newProducts.count
                    if newCount > 0 {
                        Label("Nieuw bij \(catalog.store.name)", systemImage: "sparkles")
                            .badge(newCount)
                            .tag(BrowseScope.new)
                    }
                }
                Section("Categorieën") {
                    ForEach(catalog.categories) { category in
                        Label {
                            Text(category.name)
                        } icon: {
                            Text(category.emoji)
                        }
                        .badge(category.products.count)
                        .tag(BrowseScope.category(category.name))
                    }
                }
            }
            .navigationTitle(catalog.store.name)
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 320)
        } content: {
            Group {
                if let scope {
                    ScopedProductsView(scope: scope)
                        .id(scope)
                } else {
                    ContentUnavailableView("Kies een categorie", systemImage: "square.grid.2x2")
                }
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 380, max: 540)
        } detail: {
            NavigationStack {
                ShoppingListView()
            }
        }
    }
}

extension Color {
    static var groupedBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemGroupedBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// Lichtblauw, in donkere modus donkerblauw; voor knoppen naast een felle hoofdknop.
    static var softBlue: Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.19, blue: 0.34, alpha: 1)
                : UIColor(red: 0.87, green: 0.92, blue: 1.0, alpha: 1)
        })
        #else
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.11, green: 0.19, blue: 0.34, alpha: 1)
                : NSColor(red: 0.87, green: 0.92, blue: 1.0, alpha: 1)
        })
        #endif
    }

    static var cardBackground: Color {
        #if os(iOS)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
