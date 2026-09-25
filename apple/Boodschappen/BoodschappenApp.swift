import SwiftUI
import SwiftData

@main
struct BoodschappenApp: App {
    @State private var catalog = CatalogStore()
    private let modelContainer: ModelContainer

    init() {
        modelContainer = Self.makeModelContainer()
        // Productfoto's op schijf bewaren, zodat de lijst ook in de winkel snel laadt.
        URLCache.shared = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(catalog)
                .task { await catalog.load() }
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1180, height: 760)

        #if os(macOS)
        Settings {
            SettingsView()
                .frame(width: 460)
                .environment(catalog)
                .modelContainer(modelContainer)
        }
        #endif
    }

    /// De lijst, favorieten en varianten worden via iCloud (CloudKit) gesynchroniseerd
    /// tussen iPhone, iPad en Mac. Zonder iCloud-account of -rechten werkt de app lokaal.
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([ShoppingItem.self, FavoriteProduct.self, CustomVariant.self])
        do {
            let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("iCloud-opslag niet beschikbaar, lokaal opslaan: \(error)")
            let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Kon de opslag niet openen: \(error)")
            }
        }
    }
}
