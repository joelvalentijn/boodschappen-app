import SwiftUI
import SwiftData

@main
struct BoodschappenApp: App {
    @State private var catalog = CatalogStore()
    @State private var syncMonitor: SyncMonitor
    private let modelContainer: ModelContainer

    init() {
        let storage = Self.makeModelContainer()
        modelContainer = storage.container
        _syncMonitor = State(initialValue: SyncMonitor(
            containerIdentifier: storage.cloudKitContainer,
            storeError: storage.error
        ))
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

    /// De lijst, favorieten en varianten worden via iCloud (CloudKit) gesynchroniseerd
    /// tussen iPhone, iPad en Mac. SwiftData gebruikt daarvoor automatisch de eerste
    /// iCloud-container uit de entitlements. Lukt dat niet, dan werkt de app lokaal
    /// en toont hij in Instellingen waarom.
    private static func makeModelContainer() -> (container: ModelContainer, cloudKitContainer: String?, error: String?) {
        let schema = Schema([ShoppingItem.self, FavoriteProduct.self, CustomVariant.self])
        do {
            let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            return (container, configuration.cloudKitContainerIdentifier, nil)
        } catch {
            print("iCloud-opslag niet beschikbaar, lokaal opslaan: \(error)")
            let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            do {
                let container = try ModelContainer(for: schema, configurations: [configuration])
                return (container, nil, SyncMonitor.describe(error).message)
            } catch {
                fatalError("Kon de opslag niet openen: \(error)")
            }
        }
    }
}
