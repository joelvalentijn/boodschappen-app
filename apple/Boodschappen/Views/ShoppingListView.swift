import SwiftUI
import SwiftData

/// De boodschappenlijst, gegroepeerd in winkelvolgorde.
struct ShoppingListView: View {
    /// Alleen op iPhone: opent de productkiezer. Op iPad/Mac staan de producten ernaast.
    var onAddProducts: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(CatalogStore.self) private var catalog
    @Environment(SyncMonitor.self) private var syncMonitor
    @Query(sort: \ShoppingItem.addedAt) private var items: [ShoppingItem]
    @AppStorage("lijstGroeperen") private var groupByCategory = true
    #if DEBUG
    @State private var showingZegels = DemoMode.startScreen == "zegeltjes"
    #else
    @State private var showingZegels = false
    #endif
    @State private var showingSettings = false
    @State private var confirmingClear = false
    @State private var detailItem: ShoppingItem?

    private struct ListSection: Identifiable {
        let title: String
        let emoji: String
        let items: [ShoppingItem]
        var id: String { title }
    }

    private var openItems: [ShoppingItem] {
        items.filter { !$0.isChecked }
    }

    private var checkedItems: [ShoppingItem] {
        items
            .filter(\.isChecked)
            .sorted { ($0.checkedAt ?? .distantPast) > ($1.checkedAt ?? .distantPast) }
    }

    private var sections: [ListSection] {
        guard groupByCategory else {
            return openItems.isEmpty ? [] : [ListSection(title: "Op je lijst", emoji: "🛒", items: openItems)]
        }
        let grouped = Dictionary(grouping: openItems, by: \.category)
        return grouped.keys
            .sorted { lhs, rhs in
                let left = catalog.sortIndex(for: lhs)
                let right = catalog.sortIndex(for: rhs)
                return left == right ? lhs < rhs : left < right
            }
            .map { ListSection(title: $0, emoji: catalog.emoji(for: $0), items: grouped[$0] ?? []) }
    }

    var body: some View {
        List {
            if syncMonitor.status == .problem {
                Section {
                    syncWarning
                }
            }

            if !items.isEmpty {
                Section {
                    ProgressHeader(total: items.count, checked: checkedItems.count)
                }
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        ShoppingItemRow(item: item) { detailItem = item }
                    }
                } header: {
                    if groupByCategory {
                        Text("\(section.emoji)  \(section.title)")
                            .textCase(nil)
                    }
                }
            }

            if !checkedItems.isEmpty {
                Section {
                    ForEach(checkedItems) { item in
                        ShoppingItemRow(item: item) { detailItem = item }
                    }
                } header: {
                    HStack {
                        Text("✅  In je mandje")
                            .textCase(nil)
                        Spacer()
                        Button("Wis") {
                            withAnimation { ListActions.removeChecked(in: context) }
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .refreshable {
            await syncMonitor.syncNow()
        }
        .overlay {
            if items.isEmpty {
                emptyState
            }
        }
        .navigationTitle("Boodschappen")
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) {
            if let onAddProducts {
                addButton(action: onAddProducts)
            }
        }
        .sheet(item: $detailItem) { item in
            ShoppingItemDetailView(item: item)
        }
        .sheet(isPresented: $showingZegels) {
            ZegelView()
        }
        #if os(iOS)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        #endif
        .confirmationDialog("Hele lijst leegmaken?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Lijst leegmaken", role: .destructive) {
                withAnimation { ListActions.clearList(in: context) }
            }
        }
    }

    @ViewBuilder
    private var syncWarning: some View {
        #if os(iOS)
        Button {
            showingSettings = true
        } label: {
            SyncStatusRow()
        }
        .buttonStyle(.plain)
        #else
        SettingsLink {
            SyncStatusRow()
        }
        .buttonStyle(.plain)
        #endif
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Je lijst is leeg", systemImage: "cart")
        } description: {
            if onAddProducts == nil {
                Text("Kies een categorie en tik op + om producten toe te voegen.")
            } else {
                Text("Kies uit \(catalog.allProducts.count) Lidl-producten, of typ zelf iets in.")
            }
        } actions: {
            if let onAddProducts {
                Button("Product toevoegen", action: onAddProducts)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingZegels = true
            } label: {
                Label("Zegeltjes", systemImage: "star.circle")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Toggle(isOn: $groupByCategory) {
                    Label("Groepeer per categorie", systemImage: "square.grid.2x2")
                }
                ShareLink(item: shareText) {
                    Label("Deel lijst", systemImage: "square.and.arrow.up")
                }
                .disabled(openItems.isEmpty)
                Divider()
                Button {
                    withAnimation { ListActions.removeChecked(in: context) }
                } label: {
                    Label("Verwijder afgevinkte", systemImage: "checkmark.circle")
                }
                .disabled(checkedItems.isEmpty)
                Button(role: .destructive) {
                    confirmingClear = true
                } label: {
                    Label("Lijst leegmaken", systemImage: "trash")
                }
                .disabled(items.isEmpty)
                Divider()
                #if os(iOS)
                Button {
                    showingSettings = true
                } label: {
                    Label("Instellingen", systemImage: "gearshape")
                }
                #else
                SettingsLink {
                    Label("Instellingen", systemImage: "gearshape")
                }
                #endif
            } label: {
                Label("Meer", systemImage: "ellipsis.circle")
            }
        }
    }

    private func addButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("Product toevoegen", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .shadow(color: Color.accentColor.opacity(0.3), radius: 12, y: 6)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var shareText: String {
        let lines = openItems.map { item -> String in
            var line = "• "
            if item.quantity > 1 { line += "\(item.quantity)× " }
            if let brand = item.brand { line += brand + " " }
            line += item.name
            if let variant = item.variant { line += " (\(variant))" }
            return line
        }
        return (["🛒 Boodschappenlijst"] + lines).joined(separator: "\n")
    }
}

struct ShoppingItemRow: View {
    @Bindable var item: ShoppingItem
    /// Tik op de naam of foto: meer informatie tonen.
    var onShowDetails: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isChecked ? Color.green : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.isChecked ? "Terugzetten" : "Afvinken")

            HStack(spacing: 12) {
                ProductImage(url: item.imageURL, size: 50)
                    .opacity(item.isChecked ? 0.45 : 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.body.weight(.semibold))
                        .strikethrough(item.isChecked)
                        .foregroundStyle(item.isChecked ? Color.secondary : Color.primary)
                        .lineLimit(2)
                    if item.brand != nil || item.variant != nil {
                        HStack(spacing: 6) {
                            if let brand = item.brand {
                                Text(brand)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tint)
                            }
                            if let variant = item.variant {
                                VariantBadge(text: variant)
                            }
                        }
                        .opacity(item.isChecked ? 0.6 : 1)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onShowDetails)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Toont meer informatie")

            if !item.isChecked {
                QuantityStepper(quantity: Binding(
                    get: { item.quantity },
                    set: { ListActions.setQuantity($0, for: item, in: context) }
                ))
            } else if item.quantity > 1 {
                Text("\(item.quantity)×")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: toggle) {
                Label(item.isChecked ? "Terugzetten" : "Afvinken",
                      systemImage: item.isChecked ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: delete) {
                Label("Verwijder", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(action: onShowDetails) {
                Label("Meer informatie", systemImage: "info.circle")
            }
            Button(action: toggle) {
                Label(item.isChecked ? "Terugzetten" : "Afvinken",
                      systemImage: item.isChecked ? "arrow.uturn.backward" : "checkmark")
            }
            if !item.isCustom, let url = URL(string: item.productURL) {
                Button {
                    openURL(url)
                } label: {
                    Label("Bekijk op lidl.nl", systemImage: "safari")
                }
            }
            Button(role: .destructive, action: delete) {
                Label("Verwijder", systemImage: "trash")
            }
        }
    }

    private func toggle() {
        withAnimation(.snappy) {
            ListActions.toggleChecked(item, in: context)
        }
    }

    private func delete() {
        withAnimation {
            ListActions.delete(item, in: context)
        }
    }
}
