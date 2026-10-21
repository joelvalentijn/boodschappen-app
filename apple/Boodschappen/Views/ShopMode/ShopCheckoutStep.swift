#if os(iOS)
import SwiftUI

/// Afrekenen: kaart kiezen en na Face ID de pincode 10 seconden tonen.
struct ShopCheckoutStep: View {
    let messages: [ShopMessage]
    let onSay: (String) -> Void
    let onFinish: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var cardStore = PaymentCardStore.shared
    @State private var selectedCardID: UUID?
    @State private var revealedCard: PaymentCard?
    @State private var managingCards = false
    @State private var authenticationFailed = false

    private var selectedCard: PaymentCard? {
        cardStore.cards.first { $0.id == selectedCardID }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Betalen met")
                        .font(.title2.bold())

                    if cardStore.cards.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Je hebt nog geen betaalkaarten toegevoegd.")
                                .foregroundStyle(.secondary)
                            Button {
                                managingCards = true
                            } label: {
                                Label("Betaalkaart toevoegen", systemImage: "plus.circle.fill")
                                    .font(.headline)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    ForEach(cardStore.cards) { card in
                        cardButton(card)
                    }

                    if let card = selectedCard {
                        Button {
                            Task { await reveal(card) }
                        } label: {
                            Label("Pincode \(card.name) tonen", systemImage: "faceid")
                                .font(.title3.weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .tint(Color.indigo)
                        .padding(.top, 4)
                    }

                    if authenticationFailed {
                        Label("Face ID lukte niet. Probeer het nog een keer.", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.red)
                    }
                }
                .padding()
            }
            MessageChips(messages: messages, onSay: onSay)
            ShopPrimaryButton(title: "Klaar met winkelen", systemImage: "checkmark.circle.fill", tint: .green, action: onFinish)
        }
        .overlay {
            if let revealedCard {
                PinRevealView(card: revealedCard) {
                    withAnimation { self.revealedCard = nil }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            cardStore.loadIfNeeded()
            if selectedCardID == nil, cardStore.cards.count == 1 {
                selectedCardID = cardStore.cards.first?.id
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { revealedCard = nil }
        }
        .sheet(isPresented: $managingCards) {
            NavigationStack {
                PaymentCardsView(isSheet: true)
            }
        }
    }

    private func cardButton(_ card: PaymentCard) -> some View {
        let isSelected = card.id == selectedCardID
        return Button {
            selectedCardID = card.id
            authenticationFailed = false
            onSay(card.spokenSentence)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "creditcard.fill")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.title3.weight(.bold))
                    if !card.sentence.isEmpty {
                        Text(card.sentence)
                            .font(.subheadline)
                            .opacity(0.85)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                }
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(isSelected ? Color.accentColor : Color.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func reveal(_ card: PaymentCard) async {
        authenticationFailed = false
        guard await OwnerAuthentication.confirm(reason: "Om de pincode van \(card.name) te tonen") else {
            authenticationFailed = true
            return
        }
        // Alleen dit wordt hardop gezegd; de pincode zelf nooit.
        onSay("Kijk even op mijn telefoon.")
        withAnimation { revealedCard = card }
    }
}

/// De pincode heel groot, met een teller; verdwijnt na 10 seconden vanzelf.
struct PinRevealView: View {
    static let duration = 10

    let card: PaymentCard
    let onHide: () -> Void

    @State private var remaining = PinRevealView.duration

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Pincode \(card.name)")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
                Text(card.pin.map(String.init).joined(separator: " "))
                    .font(.system(size: 76, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .accessibilityLabel("De pincode staat in beeld")
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat(remaining) / CGFloat(Self.duration))
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: remaining)
                    Text("\(remaining)")
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(Color.white)
                        .contentTransition(.numericText())
                }
                .frame(width: 84, height: 84)
                .accessibilityLabel("Nog \(remaining) seconden")
                Button(action: onHide) {
                    Label("Verberg", systemImage: "eye.slash")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(Color.white)
            }
            .padding(24)
        }
        .task {
            while remaining > 0 {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                withAnimation { remaining -= 1 }
            }
            onHide()
        }
    }
}
#endif
