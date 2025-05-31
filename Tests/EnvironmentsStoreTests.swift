import XCTest
@testable import CantinarrModels

#if canImport(Combine) && canImport(SwiftUI)
final class EnvironmentsStoreTests: XCTestCase {
    func testLoadSaveAndValidateSelections() throws {
        // Use a unique temporary directory for isolation
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("env.json")

        // Initial store writes data to disk
        let store = EnvironmentsStore(fileURL: fileURL)
        var env = ServerEnvironment(name: "Demo")
        let svc = ServiceInstance(kind: .overseerrUsers, displayName: "Demo Service")
        env.services = [svc]
        store.environments = [env]
        store.selectedEnvironmentID = env.id
        store.selectedServiceID = svc.id
        try store.saveNow()

        // Loading a new instance should restore the environments
        let loaded = EnvironmentsStore(fileURL: fileURL)
        XCTAssertEqual(loaded.environments.count, 1)
        XCTAssertEqual(loaded.environments.first?.name, "Demo")

        // ValidateSelections adjusts service when removed
        loaded.selectedEnvironmentID = loaded.environments.first!.id
        loaded.selectedServiceID = loaded.environments.first!.services.first!.id
        loaded.environments[0].services.removeAll()
        loaded.validateSelections()
        XCTAssertNil(loaded.selectedServiceID)

        // Removing all environments clears selection
        loaded.environments.removeAll()
        loaded.validateSelections()
        XCTAssertNil(loaded.selectedServiceID)
    }
}
#endif
