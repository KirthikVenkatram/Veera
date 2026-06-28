import SwiftData
import SwiftUI
import UserNotifications

@main
struct veeraApp: App {
    // SwiftData model container — declares which @Model types get persisted.
    // SwiftData auto-creates the SQLite file in the app sandbox.
    let modelContainer: ModelContainer

    init() {
        do {
            // Routes through SharedPersistence so the widget extension reads the
            // same SwiftData file once the App Group entitlement is wired up.
            // Falls back to the default location until that capability lands.
            modelContainer = try SharedPersistence.makeContainer()
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }

        // Foreground notification delivery handler. Delegate is a weak ref on the
        // notification center, so we anchor it via the static `.shared` singleton.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .task {
                    await PersistenceController.bootstrapPlayerIfNeeded(
                        in: modelContainer.mainContext
                    )
                    await HealthKitImporter.runEnabled(in: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}
