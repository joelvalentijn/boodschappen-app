import SwiftUI
import SwiftData

@main
struct BoodschappenApp: App {
    @State private var catalog = CatalogStore()
    @State private var syncMonitor: SyncMonitor
    @State private var cloudSync: CloudSync?
    private let modelContainer: ModelContainer

    init() {
        let storage = Self.makeModelContainer()
        modelContainer = storage.container

        let containerIdentifier = CloudKitSetup.containerIdentifier()
        let monitor = SyncMonitor(containerIdentifier: containerIdentifier, storeError: storage.error)
        _syncMonitor = State(initialValue: monitor)
        if let containerIdentifier {
            let sync = CloudSync(containerIdentifier: containerIdentifier, context: storage.container.mainContext, monitor: monitor)
            monitor.engine = sync
            _cloudSync = State(initialValue: sync)
        } else {
            _cloudSync = State(initialValue: nil)
        }

        // Productfoto's op schijf bewaren, zodat de lijst ook in de winkel snel laadt.
        URLCache.shared = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(catalog)
                .environment(syncMonitor)
                .task { await catalog.load() }
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1180, height: 760)

        #if os(macOS)
        Settings {
            SettingsView()
                .frame(width: 460)
                .environment(catalog)
                .environment(syncMonitor)
                .modelContainer(modelContainer)
        }
        #endif
    }

    /// De gegevens staan lokaal in SwiftData. `CloudSync` synchroniseert ze zelf via iCloud,
    /// zodat wijzigingen binnen een paar seconden op je andere apparaten staan.
    private static func makeModelContainer() -> (container: ModelContainer, error: String?) {
        let schema = Schema([ShoppingItem.self, FavoriteProduct.self, CustomVariant.self])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return (try ModelContainer(for: schema, configurations: [configuration]), nil)
        } catch {
            // Kan de bestaande opslag niet worden geopend, begin dan liever leeg dan te crashen.
            print("Opslag kon niet worden geopend: \(error)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return (try ModelContainer(for: schema, configurations: [fallback]), error.localizedDescription)
            } catch {
                fatalError("Kon de opslag niet openen: \(error)")
            }
        }
    }
}
