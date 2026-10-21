import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Toont het keuzescherm zolang er geen winkel gekozen is, en daarna de app voor die winkel.
struct StoreGate: View {
    @Environment(StoreSelection.self) private var selection
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SyncMonitor.self) private var syncMonitor

    var body: some View {
        content
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active {
                    ListActions.mergeDuplicates(in: context)
                }
                syncMonitor.setAppActive(phase != .background)
            }
            .task {
                // Pushberichten van iCloud, voor updates als de app op de achtergrond staat.
                guard syncMonitor.containerIdentifier != nil else { return }
                #if os(iOS)
                UIApplication.shared.registerForRemoteNotifications()
                #else
                NSApplication.shared.registerForRemoteNotifications()
                #endif
            }
    }

    @ViewBuilder
    private var content: some View {
        if let store = selection.current {
            let catalog = selection.catalog(for: store)
            RootView()
                .environment(catalog)
                .task { await catalog.load() }
                // Alles opnieuw opbouwen bij een andere winkel, zodat niets van de vorige blijft hangen.
                .id(store)
        } else {
            StorePickerView()
        }
    }
}

struct StorePickerView: View {
    @Environment(StoreSelection.self) private var selection
    @Query private var items: [ShoppingItem]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                    Text("Waar ga je boodschappen doen?")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.bottom, 10)

                ForEach(Store.allCases) { store in
                    Button {
                        withAnimation(.snappy) { selection.current = store }
                    } label: {
                        StoreCard(
                            store: store,
                            openCount: items.filter { $0.shop == store && !$0.isChecked }.count,
                            isLast: store == selection.lastStore
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(Color.groupedBackground)
    }
}

private struct StoreCard: View {
    let store: Store
    let openCount: Int
    let isLast: Bool

    var body: some View {
        HStack(spacing: 16) {
            StoreBadge(store: store, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(store.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.primary)
                Text(store.tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if openCount > 0 {
                    Label(openCount == 1 ? "1 product op je lijst" : "\(openCount) producten op je lijst",
                          systemImage: "list.bullet")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(store.color)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.headline)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isLast ? store.color.opacity(0.5) : .clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opent je \(store.name)-lijst")
    }
}

/// Het logo van de winkel.
struct StoreBadge: View {
    let store: Store
    var size: CGFloat = 28

    var body: some View {
        Image(store.logoName)
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Knop in de werkbalk om naar het keuzescherm terug te gaan.
struct SwitchStoreButton: View {
    @Environment(StoreSelection.self) private var selection
    @Environment(CatalogStore.self) private var catalog

    var body: some View {
        Button {
            withAnimation(.snappy) { selection.current = nil }
        } label: {
            // Een vaste maat, anders rekt de werkbalk het logo uit.
            StoreBadge(store: catalog.store, size: 28)
                .fixedSize()
        }
        .help("Kies een andere winkel")
        .accessibilityLabel("Andere winkel kiezen, nu \(catalog.store.name)")
    }
}
