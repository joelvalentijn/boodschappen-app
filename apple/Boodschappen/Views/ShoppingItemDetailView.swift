import SwiftUI
import SwiftData

/// Meer informatie over een product op je lijst: foto, aantal, productinformatie van lidl.nl.
struct ShoppingItemDetailView: View {
    let item: ShoppingItem

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CatalogStore.self) private var catalog
    @Query private var favorites: [FavoriteProduct]
    @State private var deleteWhenClosed = false

    private var product: Product? {
        item.isCustom ? nil : catalog.product(url: item.productURL)
    }

    private var favoriteKey: String {
        ItemKey.make(url: item.productURL, name: item.name, variant: item.variant)
    }

    private var isFavorite: Bool {
        favorites.contains { $0.key == favoriteKey }
    }

    private var isNew: Bool {
        guard let firstSeen = product?.firstSeen else { return false }
        return firstSeen >= Date().addingTimeInterval(-21 * 24 * 60 * 60)
    }

    var body: some View {
        NavigationStack {
            Form {
                header

                Section("Op je lijst") {
                    LabeledContent("Aantal") {
                        QuantityStepper(quantity: Binding(
                            get: { item.quantity },
                            set: { ListActions.setQuantity($0, for: item, in: context) }
                        ))
                    }
                    Toggle(isOn: Binding(
                        get: { item.isChecked },
                        set: { _ in ListActions.toggleChecked(item, in: context) }
                    )) {
                        Label("In je mandje", systemImage: "checkmark.circle")
                    }
                    LabeledContent("Toegevoegd") {
                        Text(item.addedAt, format: .relative(presentation: .named))
                    }
                }

                if !item.isCustom {
                    ProductInfoSection(productURL: item.productURL)
                }

                Section {
                    if !item.isCustom, let url = URL(string: item.productURL) {
                        LidlPageButton(url: url)
                        ShareLink(item: url) {
                            Label("Deel product", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            ListActions.toggleFavorite(favoriteProduct, variant: item.variant, in: context)
                        } label: {
                            Label(
                                isFavorite ? "Verwijder uit favorieten" : "Maak favoriet",
                                systemImage: isFavorite ? "heart.slash" : "heart"
                            )
                        }
                    }
                    Button(role: .destructive) {
                        // Pas verwijderen als het scherm dicht is, zodat het niet een
                        // verwijderd product probeert te tonen.
                        deleteWhenClosed = true
                        dismiss()
                    } label: {
                        Label("Verwijder van lijst", systemImage: "trash")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(item.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
        .onDisappear {
            if deleteWhenClosed {
                ListActions.delete(item, in: context)
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #else
        .frame(minWidth: 460, minHeight: 620)
        #endif
    }

    private var header: some View {
        Section {
            VStack(spacing: 10) {
                ProductImage(url: item.imageURL, size: 200)
                Text(item.name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    if let brand = item.brand {
                        Text(brand)
                            .fontWeight(.semibold)
                            .foregroundStyle(.tint)
                    }
                    if let variant = item.variant {
                        VariantBadge(text: variant)
                    }
                }
                .font(.subheadline)
                HStack(spacing: 8) {
                    Text("\(catalog.emoji(for: item.category)) \(item.category)")
                        .foregroundStyle(.secondary)
                    if isNew {
                        Label("Nieuw bij Lidl", systemImage: "sparkles")
                            .foregroundStyle(Color.orange)
                    }
                }
                .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    /// Het product uit de catalogus, of een reconstructie als het er niet meer in staat.
    private var favoriteProduct: Product {
        product ?? Product(
            url: item.productURL,
            name: item.name,
            brand: item.brand,
            imageURL: item.imageURL,
            category: item.category,
            firstSeen: nil
        )
    }
}
