import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Ensure the Core Data model file (CantinarrModel.xcdatamodeld) is added to your project.
        container = NSPersistentContainer(name: "Cantinarr")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Error loading persistent stores: \(error)")
            }
        }
    }
}
