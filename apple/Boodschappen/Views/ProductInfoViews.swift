import SwiftUI
#if os(iOS)
import SafariServices
#endif

/// Prijs, beschrijving en EAN-code van lidl.nl, voor in een Form.
struct ProductInfoSection: View {
    let productURL: String

    private enum Phase: Equatable {
        case loading
        case loaded(ProductInfo)
        case unavailable
    }

    @State private var phase = Phase.loading
    @State private var expanded = false

    var body: some View {
        Section {
            switch phase {
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Informatie ophalen van lidl.nl…")
                        .foregroundStyle(.secondary)
                }
            case .loaded(let info):
                if let price = info.price {
                    LabeledContent("Prijs op lidl.nl") {
                        Text(price)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.primary)
                    }
                }
                if let description = info.description {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(description)
                            .font(.callout)
                            .lineLimit(expanded ? nil : 6)
                            .textSelection(.enabled)
                        if description.count > 280 {
                            Button(expanded ? "Minder" : "Lees meer") {
                                withAnimation { expanded.toggle() }
                            }
                            .font(.callout.weight(.semibold))
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 2)
                }
                if let ean = info.ean {
                    LabeledContent("EAN-code", value: ean)
                }
            case .unavailable:
                Text("Geen extra informatie gevonden. Open de productpagina voor alle details.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Productinformatie")
        } footer: {
            if case .loaded(let info) = phase, info.price != nil {
                Text("Prijzen kunnen in de winkel afwijken, bijvoorbeeld bij aanbiedingen.")
            }
        }
        .task(id: productURL) {
            phase = .loading
            if let info = await ProductInfoLoader.shared.info(for: productURL) {
                phase = .loaded(info)
            } else {
                phase = .unavailable
            }
        }
    }
}

/// Opent de productpagina: op iPhone en iPad binnen de app, op de Mac in de browser.
struct LidlPageButton: View {
    let url: URL

    @Environment(\.openURL) private var openURL
    @State private var showingPage = false

    var body: some View {
        Button {
            #if os(iOS)
            showingPage = true
            #else
            openURL(url)
            #endif
        } label: {
            Label("Bekijk op lidl.nl", systemImage: "safari")
        }
        #if os(iOS)
        .sheet(isPresented: $showingPage) {
            SafariView(url: url)
                .ignoresSafeArea()
        }
        #endif
    }
}

#if os(iOS)
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
#endif
