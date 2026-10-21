#if os(iOS)
import SwiftUI
import SwiftData

/// Vóór het winkelen: de volgorde van de producten bepalen.
struct ShopOrderView: View {
    @Binding var route: [ShoppingItem]
    let onStart: () -> Void
    let onClose: () -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(route.enumerated()), id: \.element.id) { index, item in
                        row(item, at: index)
                    }
                } footer: {
                    Text("Zet de producten in de volgorde waarin je door de winkel gaat. In de winkel ziet de medewerker ze één voor één, groot in beeld.")
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if route.isEmpty {
                    ContentUnavailableView(
                        "Alles is al gepakt",
                        systemImage: "checkmark.seal",
                        description: Text("Er staan geen open producten op je lijst.")
                    )
                }
            }
            .navigationTitle("Volgorde")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluit", action: onClose)
                }
            }
            .safeAreaInset(edge: .bottom) {
                ShopPrimaryButton(title: "Start winkelen", systemImage: "play.fill", tint: .green, action: onStart)
                    .disabled(route.isEmpty)
            }
        }
    }

    private func row(_ item: ShoppingItem, at index: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 24)
            ProductImage(url: item.imageURL, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text("\(item.quantity)×")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    if let variant = item.variant {
                        VariantBadge(text: variant)
                    }
                }
            }
            Spacer(minLength: 0)
            moveButton("arrow.up", label: "\(item.name) omhoog", disabled: index == 0) {
                move(from: index, by: -1)
            }
            moveButton("arrow.down", label: "\(item.name) omlaag", disabled: index == route.count - 1) {
                move(from: index, by: 1)
            }
        }
    }

    private func moveButton(_ systemImage: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    private func move(from index: Int, by offset: Int) {
        let target = index + offset
        guard route.indices.contains(index), route.indices.contains(target) else { return }
        withAnimation(.snappy) { route.swapAt(index, target) }
        ListActions.saveShopOrder(route, in: context)
    }
}
#endif
