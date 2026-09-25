import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(CatalogStore.self) private var catalog
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lijstGroeperen") private var groupByCategory = true
    @Environment(SyncMonitor.self) private var syncMonitor
    @State private var importMessage: String?

    var body: some View {
        Form {
            Section {
                SyncStatusRow()
                if let lastSuccess = syncMonitor.lastSuccess {
                    LabeledContent("Laatst gesynchroniseerd") {
                        Text(lastSuccess, format: .relative(presentation: .named))
                    }
                }
                DisclosureGroup("Technische details") {
                    LabeledContent("Container", value: syncMonitor.containerIdentifier ?? "geen")
                    LabeledContent("iCloud-account", value: syncMonitor.accountDescription)
                    ForEach(syncMonitor.log) { entry in
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.text)
                                    .font(.footnote)
                                Text(entry.date, format: .dateTime.hour().minute().second())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: entry.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .foregroundStyle(entry.succeeded ? Color.green : Color.red)
                        }
                    }
                    ShareLink(item: syncMonitor.diagnosticReport) {
                        Label("Deel diagnose", systemImage: "square.and.arrow.up")
                    }
                }
            } header: {
                Text("iCloud")
            } footer: {
                Text(syncFooter)
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
        .task { await syncMonitor.refreshAccount() }
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Klaar") { dismiss() }
            }
        }
        #endif
    }

    private var syncFooter: String {
        switch syncMonitor.status {
        case .off:
            "Deze versie is gebouwd zonder iCloud-rechten, dus je lijst blijft op dit apparaat. Zie ‘iCloud-synchronisatie’ in apple/README.md."
        case .problem:
            "Zolang dit niet werkt, blijft alles wat je doet op dit apparaat bewaard en wordt het later alsnog gesynchroniseerd."
        default:
            "Je lijst, favorieten en varianten zijn hetzelfde op al je apparaten met hetzelfde Apple-account. Wijzigingen verschijnen meestal binnen een paar seconden; open de app op het andere apparaat als het langer duurt."
        }
    }
}

/// Eén regel met de iCloud-status: icoon, titel en uitleg.
struct SyncStatusRow: View {
    @Environment(SyncMonitor.self) private var syncMonitor

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(syncMonitor.statusDescription)
                    .fontWeight(.semibold)
                if let message = syncMonitor.problemMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            if syncMonitor.status == .syncing || syncMonitor.status == .connecting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
            }
        }
    }

    private var iconName: String {
        switch syncMonitor.status {
        case .off: "icloud.slash"
        case .problem: "exclamationmark.icloud.fill"
        default: "checkmark.icloud.fill"
        }
    }

    private var iconColor: Color {
        switch syncMonitor.status {
        case .off: Color.secondary
        case .problem: Color.orange
        default: Color.green
        }
    }
}
