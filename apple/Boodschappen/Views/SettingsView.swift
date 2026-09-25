import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(CatalogStore.self) private var catalog
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lijstGroeperen") private var groupByCategory = true
    @State private var importMessage: String?
    @State private var iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil

    var body: some View {
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(iCloudAvailable ? "iCloud-synchronisatie staat aan" : "Niet ingelogd bij iCloud")
                        Text(iCloudAvailable
                             ? "Je lijst, favorieten en varianten zijn hetzelfde op al je apparaten met dit Apple-account."
                             : "Log in bij iCloud om je lijst te delen tussen iPhone, iPad en Mac. Tot die tijd blijft alles op dit apparaat.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: iCloudAvailable ? "checkmark.icloud.fill" : "icloud.slash")
                        .foregroundStyle(iCloudAvailable ? Color.accentColor : Color.secondary)
                }
            } header: {
                Text("iCloud")
            }

            Section("Lijst") {
                Toggle("Groeperen per categorie (winkelvolgorde)", isOn: $groupByCategory)
            }

            Section {
                LabeledContent("Producten", value: catalog.allProducts.count.formatted())
                if let date = catalog.generatedAt {
                    LabeledContent("Bijgewerkt op", value: date.formatted(date: .long, time: .omitted))
                }
                Button {
                    Task { await catalog.refresh(force: true) }
                } label: {
                    HStack {
                        Label("Zoek naar nieuwe producten", systemImage: "arrow.clockwise")
                        Spacer()
                        if catalog.isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(catalog.isRefreshing)
                if let message = catalog.statusMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Productcatalogus")
            } footer: {
                Text("Nieuwe Lidl-producten worden elke week verzameld en automatisch in de app gezet.")
            }

            Section {
                PasteButton(payloadType: String.self) { strings in
                    guard let text = strings.first else { return }
                    Task { @MainActor in
                        do {
                            importMessage = try WebImport.importData(text, catalog: catalog, into: context).summary
                        } catch {
                            importMessage = error.localizedDescription
                        }
                    }
                }
                if let importMessage {
                    Text(importMessage)
                        .font(.footnote)
                }
            } header: {
                Text("Overzetten vanuit de web-app")
            } footer: {
                Text("Open de web-app in Safari, tik onderaan op ‘Overzetten naar app’ en tik daarna hier op Plak. Je lijst, favorieten en varianten komen dan in de app.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Instellingen")
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Klaar") { dismiss() }
            }
        }
        #endif
    }
}
