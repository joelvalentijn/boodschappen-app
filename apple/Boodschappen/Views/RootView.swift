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
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        layout
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active {
                    ListActions.mergeDuplicates(in: context)
                }
            }
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
    @State private var showingProducts = false

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
    @Query private var favorites: [FavoriteProduct]
    @State private var scope: BrowseScope? = .all

    var body: some View {
        NavigationSplitView {
            List(selection: $scope) {
                Section {
                    Label("Alle producten", systemImage: "square.grid.2x2")
                        .tag(BrowseScope.all)
                    Label("Favorieten", systemImage: "heart")
                        .badge(favorites.count)
                        .tag(BrowseScope.favorites)
                    let newCount = catalog.newProducts.count
                    if newCount > 0 {
                        Label("Nieuw bij Lidl", systemImage: "sparkles")
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
            .navigationTitle("Producten")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } content: {
            Group {
                if let scope {
                    ScopedProductsView(scope: scope)
                        .id(scope)
                } else {
                    ContentUnavailableView("Kies een categorie", systemImage: "square.grid.2x2")
                }
            }
            .navigationSplitViewColumnWidth(min: 320, ideal: 430, max: 600)
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

    static var cardBackground: Color {
        #if os(iOS)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
