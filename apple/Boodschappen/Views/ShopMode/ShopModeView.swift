#if os(iOS)
import SwiftUI
import SwiftData
import UIKit

/// Fullscreen winkelmodus: volgorde kiezen, hulp vragen, producten laten pakken en afrekenen.
struct ShopModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(CatalogStore.self) private var catalog
    @Query private var allItems: [ShoppingItem]

    /// `nil`: de volgorde wordt nog bepaald.
    @State private var step: ShopStep?
    @State private var route: [ShoppingItem] = []
    @State private var itemIndex = 0
    @State private var spokenText: String?
    @State private var speaker = Speaker()
    @State private var messageStore = ShopMessageStore.shared
    @State private var editingMessages = false
    @State private var confirmingStop = false
    @State private var confirmingFinish = false

    /// Producten die intussen (bijvoorbeeld via een ander apparaat) zijn verwijderd vallen weg.
    private var liveRoute: [ShoppingItem] {
        route.filter { $0.modelContext != nil && !$0.isDeleted }
    }

    var body: some View {
        Group {
            if let step {
                stepScreen(step)
            } else {
                ShopOrderView(route: $route, onStart: { go(to: .help) }, onClose: { dismiss() })
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        // Zolang de volgorde nog bepaald wordt, meegaan met wijzigingen (bijv. via iCloud).
        .task(id: RouteTrigger(count: allItems.count, openCount: allItems.filter { !$0.isChecked }.count, catalogLoaded: catalog.isLoaded)) {
            guard step == nil else { return }
            route = ListActions.shopRoute(catalog: catalog, in: context)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            speaker.stop()
        }
        .sheet(isPresented: $editingMessages) {
            NavigationStack {
                ShopMessagesEditor(initialStep: step ?? .help, isSheet: true)
            }
        }
    }

    private func stepScreen(_ current: ShopStep) -> some View {
        VStack(spacing: 0) {
            header(current)
            if let spokenText {
                SpokenBanner(
                    text: spokenText,
                    onRepeat: { speaker.speak(spokenText) },
                    onClose: { withAnimation { self.spokenText = nil } }
                )
                .padding(.horizontal)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            content(for: current)
                .frame(maxHeight: .infinity)
        }
        .background(Color.groupedBackground)
        // Bij een ander product moet het aantal weer volledig in beeld staan.
        .onChange(of: itemIndex) {
            withAnimation(.snappy) { spokenText = nil }
        }
        .confirmationDialog("Winkelmodus stoppen?", isPresented: $confirmingStop, titleVisibility: .visible) {
            Button("Stoppen", role: .destructive) { dismiss() }
        }
        .confirmationDialog("Afgevinkte producten van de lijst halen?", isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button("Ja, van de lijst halen") {
                ListActions.removeChecked(in: context)
                dismiss()
            }
            Button("Nee, laten staan") { dismiss() }
        }
    }

    private func header(_ current: ShopStep) -> some View {
        HStack(spacing: 10) {
            Button {
                confirmingStop = true
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Stop winkelmodus")

            StepBar(current: current) { go(to: $0) }

            Button {
                editingMessages = true
            } label: {
                Image(systemName: "pencil")
                    .font(.title3.weight(.bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Berichten aanpassen")
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func content(for current: ShopStep) -> some View {
        switch current {
        case .help:
            ShopHelpStep(
                messages: messageStore.usableMessages(for: .help),
                onSay: say,
                onNext: { go(to: .shopping) }
            )
        case .shopping:
            ShopItemStep(
                route: liveRoute,
                index: $itemIndex,
                messages: messageStore.usableMessages(for: .shopping),
                onSay: say,
                onCheckout: { go(to: .checkout) }
            )
        case .checkout:
            ShopCheckoutStep(
                messages: messageStore.usableMessages(for: .checkout),
                onSay: say,
                onFinish: { confirmingFinish = true }
            )
        }
    }

    private struct RouteTrigger: Equatable {
        let count: Int
        let openCount: Int
        let catalogLoaded: Bool
    }

    private func say(_ text: String) {
        withAnimation(.snappy) { spokenText = text }
        speaker.speak(text)
    }

    private func go(to newStep: ShopStep) {
        speaker.stop()
        withAnimation(.snappy) {
            spokenText = nil
            step = newStep
        }
    }
}

/// Hulp · Winkelen · Afrekenen, met de huidige stap gemarkeerd.
struct StepBar: View {
    let current: ShopStep
    let onSelect: (ShopStep) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ShopStep.allCases) { step in
                let isCurrent = step == current
                Button {
                    onSelect(step)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: step.systemImage)
                            .font(.headline)
                        Text(step.title)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(isCurrent ? Color.white : Color.secondary)
                    .background(isCurrent ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stap: \(step.title)")
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// De laatst uitgesproken zin, groot in beeld voor de medewerker.
struct SpokenBanner: View {
    let text: String
    let onRepeat: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Button(action: onRepeat) {
                    Label("Nog een keer", systemImage: "speaker.wave.2.fill")
                }
                Spacer()
                Button(action: onClose) {
                    Label("Weg", systemImage: "xmark")
                }
            }
            .font(.headline)
            .buttonStyle(.bordered)
            .tint(.black)
        }
        .foregroundStyle(Color.black)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.97, blue: 0.86), Color(red: 1.0, green: 0.91, blue: 0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}

/// Grote berichtknoppen onder elkaar.
struct MessageList: View {
    let messages: [ShopMessage]
    let onSay: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(messages) { message in
                Button {
                    onSay(message.text)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(.tint)
                        Text(message.text)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Berichtknoppen naast elkaar, om opzij te vegen.
struct MessageChips: View {
    let messages: [ShopMessage]
    let onSay: (String) -> Void

    var body: some View {
        if !messages.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(messages) { message in
                        Button {
                            onSay(message.text)
                        } label: {
                            Label(message.text, systemImage: "speaker.wave.2.fill")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: 260, minHeight: 44, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 6)
        }
    }
}

struct ShopPrimaryButton: View {
    let title: String
    let systemImage: String
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(tint)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct ShopHelpStep: View {
    let messages: [ShopMessage]
    let onSay: (String) -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Tik op een zin: hij komt groot in beeld en wordt voorgelezen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    MessageList(messages: messages, onSay: onSay)
                }
                .padding()
            }
            ShopPrimaryButton(title: "Volgende: winkelen", systemImage: "cart.fill", action: onNext)
        }
    }
}
#endif
