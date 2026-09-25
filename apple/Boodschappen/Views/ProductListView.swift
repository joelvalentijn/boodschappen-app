import SwiftUI
import SwiftData

/// Lijst met producten waaruit je kunt kiezen, met hartjes en een +-knop.
struct ProductListView: View {
    let entries: [ProductEntry]
    var customName: String?
    var emptyMessage: String = "Geen producten gevonden"

    @Environment(\.modelContext) private var context
    @Query private var items: [ShoppingItem]
    @Query private var favorites: [FavoriteProduct]
    @Query(sort: \CustomVariant.addedAt) private var variants: [CustomVariant]
    @State private var detailProduct: Product?
    @State private var toast: String?
    @State private var addCount = 0

    var body: some View {
        let quantities = Dictionary(items.map { ($0.key, $0.quantity) }, uniquingKeysWith: +)
        let favoriteKeys = Set(favorites.map(\.key))
        let variantsByURL = Dictionary(grouping: variants, by: \.productURL)
        let customText = customName?.trimmingCharacters(in: .whitespaces) ?? ""

        List {
            if !customText.isEmpty {
                Section {
                    Button {
                        ListActions.addCustom(named: customText, in: context)
                        showToast("Toegevoegd: \(customText)")
                    } label: {
                        Label("‘\(customText)’ als eigen product toevoegen", systemImage: "square.and.pencil")
                    }
                } footer: {
                    if entries.isEmpty {
                        Text("Niet gevonden in de Lidl-catalogus.")
                    }
                }
            }

            if !entries.isEmpty {
                Section {
                    ForEach(entries) { entry in
                        let key = ItemKey.make(url: entry.product.url, name: entry.product.name, variant: entry.variant)
                        ProductRow(
                            entry: entry,
                            quantityInList: quantities[key] ?? 0,
                            isFavorite: favoriteKeys.contains(key),
                            variants: variantsByURL[entry.product.url]?.map(\.name) ?? [],
                            onAdd: { variant in add(entry.product, variant: variant) },
                            onToggleFavorite: {
                                ListActions.toggleFavorite(entry.product, variant: entry.variant, in: context)
                            },
                            onShowDetails: { detailProduct = entry.product }
                        )
                    }
                } footer: {
                    if entries.count >= 250 {
                        Text("Typ meer letters om verder te zoeken.")
                    }
                }
            }
        }
        .overlay {
            if entries.isEmpty && customText.isEmpty {
                ContentUnavailableView(emptyMessage, systemImage: "magnifyingglass")
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                ToastView(text: toast)
                    .id(toast)
            }
        }
        .animation(.snappy, value: toast)
        .sensoryFeedback(.success, trigger: addCount)
        .task(id: addCount) {
            guard toast != nil else { return }
            do {
                try await Task.sleep(for: .seconds(1.8))
                toast = nil
            } catch {
                // Er is intussen iets anders toegevoegd; die melding blijft staan.
            }
        }
        .sheet(item: $detailProduct) { product in
            ProductDetailView(product: product)
        }
    }

    private func add(_ product: Product, variant: String?) {
        ListActions.add(product, variant: variant, in: context)
        showToast("Toegevoegd: \(product.name)" + (variant.map { " (\($0))" } ?? ""))
    }

    private func showToast(_ text: String) {
        toast = text
        addCount += 1
    }
}

struct ProductRow: View {
    let entry: ProductEntry
    let quantityInList: Int
    let isFavorite: Bool
    let variants: [String]
    let onAdd: (String?) -> Void
    let onToggleFavorite: () -> Void
    let onShowDetails: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 12) {
                ProductImage(url: entry.product.imageURL, size: 50)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.product.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        if let brand = entry.product.brand {
                            Text(brand)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                        if let variant = entry.variant {
                            VariantBadge(text: variant)
                        } else if !variants.isEmpty {
                            Text(variants.count == 1 ? "1 variant" : "\(variants.count) varianten")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if quantityInList > 0 {
                        Label("\(quantityInList)× op je lijst", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.green)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onShowDetails)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(isFavorite ? Color.red : Color.secondary)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isFavorite ? "Verwijder uit favorieten" : "Maak favoriet")

            addControl
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var addControl: some View {
        if entry.variant == nil && !variants.isEmpty {
            Menu {
                Button("Zonder variant") { onAdd(nil) }
                Section("Varianten") {
                    ForEach(variants, id: \.self) { variant in
                        Button(variant) { onAdd(variant) }
                    }
                }
            } label: {
                addIcon
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.borderless)
            .fixedSize()
            .accessibilityLabel("Toevoegen")
        } else {
            Button {
                onAdd(entry.variant)
            } label: {
                addIcon
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Toevoegen")
        }
    }

    private var addIcon: some View {
        Image(systemName: "plus.circle.fill")
            .font(.system(size: 28))
            .foregroundStyle(.tint)
            .contentShape(Circle())
    }
}

/// Details van een product: varianten beheren, favoriet maken en toevoegen.
struct ProductDetailView: View {
    let product: Product

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [ShoppingItem]
    @Query private var favorites: [FavoriteProduct]
    @Query(sort: \CustomVariant.addedAt) private var allVariants: [CustomVariant]
    @State private var newVariant = ""
    @State private var addCount = 0

    private var variants: [CustomVariant] {
        allVariants.filter { $0.productURL == product.url }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        ProductImage(url: product.imageURL, size: 170)
                        Text(product.name)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        HStack(spacing: 8) {
                            if let brand = product.brand {
                                Text(brand)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.tint)
                            }
                            Text(product.category)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section {
                    addRow(title: "Zonder variant", variant: nil)
                    ForEach(variants) { variant in
                        addRow(title: variant.name, variant: variant.name)
                            .swipeActions {
                                Button(role: .destructive) {
                                    ListActions.delete(variant, in: context)
                                } label: {
                                    Label("Verwijder", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    ListActions.delete(variant, in: context)
                                } label: {
                                    Label("Verwijder variant", systemImage: "trash")
                                }
                            }
                    }
                    HStack {
                        TextField("Nieuwe variant, bijv. Halfvol", text: $newVariant)
                            .onSubmit(saveVariant)
                        Button("Bewaar", action: saveVariant)
                            .disabled(newVariant.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Op je lijst zetten")
                } footer: {
                    Text("Maak varianten voor smaken of soorten, zoals Aardbei of Halfvol. Ze worden via iCloud gedeeld met je andere apparaten.")
                }

                if !product.url.isEmpty, let url = URL(string: product.url) {
                    Section {
                        Link(destination: url) {
                            Label("Bekijk op lidl.nl", systemImage: "safari")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(product.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: addCount)
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #else
        .frame(minWidth: 440, minHeight: 580)
        #endif
    }

    private func addRow(title: String, variant: String?) -> some View {
        let key = ItemKey.make(url: product.url, name: product.name, variant: variant)
        let quantity = items.filter { $0.key == key }.reduce(0) { $0 + $1.quantity }
        let isFavorite = favorites.contains { $0.key == key }

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if variant == nil {
                    Text(title)
                } else {
                    VariantBadge(text: title)
                }
                if quantity > 0 {
                    Text("\(quantity)× op je lijst")
                        .font(.caption)
                        .foregroundStyle(Color.green)
                }
            }
            Spacer()
            Button {
                ListActions.toggleFavorite(product, variant: variant, in: context)
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? Color.red : Color.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isFavorite ? "Verwijder uit favorieten" : "Maak favoriet")

            Button {
                ListActions.add(product, variant: variant, in: context)
                addCount += 1
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Toevoegen")
        }
    }

    private func saveVariant() {
        ListActions.addVariant(newVariant, to: product, in: context)
        newVariant = ""
    }
}
