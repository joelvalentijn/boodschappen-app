import SwiftUI

/// Productfoto met een nette placeholder. Foto's hebben een witte achtergrond,
/// dus ook in de donkere modus tonen we ze op een wit tegeltje.
struct ProductImage: View {
    let url: String?
    var size: CGFloat = 52

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
        AsyncImage(url: url.flatMap { URL(string: $0) }, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.06)
            case .failure:
                placeholder
            case .empty:
                if url == nil {
                    placeholder
                } else {
                    Color.clear
                }
            @unknown default:
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(Color.white, in: shape)
        .overlay {
            shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .clipShape(shape)
    }

    private var placeholder: some View {
        Image(systemName: "cart")
            .font(.system(size: size * 0.38, weight: .medium))
            .foregroundStyle(Color.gray.opacity(0.6))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Label voor een variant, zoals "Halfvol".
struct VariantBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(Color.purple)
            .background(Color.purple.opacity(0.12), in: Capsule())
    }
}

/// Compacte −/+ knoppen voor het aantal.
struct QuantityStepper: View {
    @Binding var quantity: Int

    var body: some View {
        HStack(spacing: 2) {
            Button {
                quantity = max(1, quantity - 1)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .disabled(quantity <= 1)
            .accessibilityLabel("Minder")

            Text("\(quantity)")
                .font(.body.weight(.bold))
                .monospacedDigit()
                .frame(minWidth: 22)
                .contentTransition(.numericText())

            Button {
                quantity = min(99, quantity + 1)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .disabled(quantity >= 99)
            .accessibilityLabel("Meer")
        }
        .font(.subheadline.weight(.bold))
        .buttonStyle(.borderless)
        .padding(.horizontal, 3)
        .background(Color.secondary.opacity(0.12), in: Capsule())
        .animation(.snappy(duration: 0.2), value: quantity)
    }
}

/// Voortgang bovenaan de lijst.
struct ProgressHeader: View {
    let total: Int
    let checked: Int

    private var remaining: Int { total - checked }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(remaining)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(remaining == 1 ? "product nog te halen" : "producten nog te halen")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if remaining == 0 {
                    Label("Klaar!", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.green)
                } else {
                    Text("\(checked)/\(total)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: Double(checked), total: Double(max(total, 1)))
                .tint(Color.green)
        }
        .padding(.vertical, 4)
        .animation(.snappy, value: checked)
    }
}

/// Korte melding onderin, bijvoorbeeld "Toegevoegd: Halfvolle melk".
struct ToastView: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
