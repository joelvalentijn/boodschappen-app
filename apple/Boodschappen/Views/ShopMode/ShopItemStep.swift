#if os(iOS)
import SwiftUI
import SwiftData

/// Eén product per scherm, met naam, variant en aantal groot in beeld.
struct ShopItemStep: View {
    let route: [ShoppingItem]
    @Binding var index: Int
    let messages: [ShopMessage]
    let onSay: (String) -> Void
    let onCheckout: () -> Void

    @Environment(\.modelContext) private var context
    @State private var pickedCount = 0

    var body: some View {
        VStack(spacing: 0) {
            if route.isEmpty {
                ContentUnavailableView("Geen producten", systemImage: "cart")
                    .frame(maxHeight: .infinity)
                ShopPrimaryButton(title: "Naar afrekenen", systemImage: "creditcard.fill", action: onCheckout)
            } else if index >= route.count {
                summary
            } else {
                itemScreen(route[index])
            }
        }
        .sensoryFeedback(.success, trigger: pickedCount)
    }

    private var checkedCount: Int {
        route.filter(\.isChecked).count
    }

    private func itemScreen(_ item: ShoppingItem) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                HStack {
                    Text("Product \(index + 1) van \(route.count)")
                        .font(.headline)
                    Spacer()
                    Text("\(checkedCount) gepakt")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.green)
                }
                ProgressView(value: Double(checkedCount), total: Double(route.count))
                    .tint(Color.green)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            ScrollView {
                ShopItemCard(item: item) { onSay(spokenDescription(of: item)) }
                    .padding()
                    .id(item.id)
            }

            MessageChips(messages: messages, onSay: onSay)

            HStack(spacing: 10) {
                navigationButton("chevron.left", label: "Vorige", disabled: index == 0) {
                    index -= 1
                }
                if item.isChecked {
                    Button {
                        ListActions.toggleChecked(item, in: context)
                    } label: {
                        Label("Toch niet", systemImage: "arrow.uturn.backward")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                } else {
                    Button {
                        pick(item)
                    } label: {
                        Label("Gepakt", systemImage: "checkmark")
                            .font(.title2.weight(.heavy))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .tint(Color.green)
                }
                navigationButton("chevron.right", label: "Volgende", disabled: false) {
                    index += 1
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func navigationButton(_ systemImage: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    private func pick(_ item: ShoppingItem) {
        ListActions.toggleChecked(item, in: context)
        pickedCount += 1
        withAnimation(.snappy) { index += 1 }
    }

    private var summary: some View {
        let missing = route.filter { !$0.isChecked }
        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    Image(systemName: missing.isEmpty ? "checkmark.seal.fill" : "list.bullet.clipboard.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(missing.isEmpty ? Color.green : Color.orange)
                    Text(missing.isEmpty ? "Alles gepakt!" : "Bijna klaar")
                        .font(.largeTitle.bold())
                    Text("Gepakt: \(route.count - missing.count) · Niet afgevinkt: \(missing.count)")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    ForEach(missing) { item in
                        Button {
                            if let position = route.firstIndex(where: { $0.id == item.id }) {
                                withAnimation(.snappy) { index = position }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ProductImage(url: item.imageURL, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.body.weight(.semibold))
                                    if let variant = item.variant {
                                        VariantBadge(text: variant)
                                    }
                                }
                                Spacer(minLength: 0)
                                Text("\(item.quantity)×")
                                    .font(.headline)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            ShopPrimaryButton(title: "Naar afrekenen", systemImage: "creditcard.fill", action: onCheckout)
        }
    }

    private func spokenDescription(of item: ShoppingItem) -> String {
        var text = "\(item.quantity) keer"
        if let brand = item.brand { text += " \(brand)" }
        text += " \(item.name)"
        if let variant = item.variant, !variant.isEmpty { text += ", \(variant)" }
        return text
    }
}

struct ShopItemCard: View {
    let item: ShoppingItem
    let onSpeak: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ProductImage(url: item.imageURL, size: 170)

            VStack(spacing: 8) {
                if let brand = item.brand {
                    Text(brand)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.tint)
                }
                Text(item.name)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                if let variant = item.variant, !variant.isEmpty {
                    Text(variant)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(Color.purple)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.14), in: Capsule())
                        .accessibilityLabel("Variant: \(variant)")
                }
            }

            HStack(spacing: 16) {
                Text("\(item.quantity)×")
                    .font(.system(size: 88, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aantal")
                        .font(.headline)
                        .opacity(0.85)
                    Text("Pak er \(item.quantity)")
                        .font(.title2.weight(.bold))
                }
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Aantal: \(item.quantity)")

            if item.isChecked {
                Label("Gepakt", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.green)
            }

            Button(action: onSpeak) {
                Label("Voorlezen", systemImage: "speaker.wave.2.fill")
                    .font(.headline)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
#endif
