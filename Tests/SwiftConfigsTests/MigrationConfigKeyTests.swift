@testable import SwiftConfigs
import XCTest

final class MigrationConfigKeyTests: XCTestCase {
    
    var store: InMemoryConfigStore!
    
    override func setUp() {
        super.setUp()
        store = InMemoryConfigStore()
        ConfigSystem.bootstrap([.default: store])
    }
    
    override func tearDown() {
        super.tearDown()
        store = nil
    }
    
    // MARK: - Basic Migration Tests
    
    func testMigrationFromOldToNewKey_WhenOnlyOldExists() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        store.set("old_value", for: oldKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { oldValue in
            "migrated_\(oldValue)"
        }
        
        // Act
        let result = migrationKey.get(store: ConfigSystem.store)
        
        // Assert
        XCTAssertEqual(result, "migrated_old_value")
        // Check that value was written to new key
        XCTAssertEqual(newKey.get(store: ConfigSystem.store), "migrated_old_value")
        // Check that old key was removed
        XCTAssertFalse(oldKey.exists(store: ConfigSystem.store))
    }
    
    func testMigrationReturnsNewValue_WhenBothKeysExist() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        store.set("old_value", for: oldKey)
        store.set("new_value", for: newKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { oldValue in
            "migrated_\(oldValue)"
        }
        
        // Act
        let result = migrationKey.get(store: ConfigSystem.store)
        
        // Assert
        XCTAssertEqual(result, "new_value")
        // Old key should still exist (migration didn't happen)
        XCTAssertTrue(oldKey.exists(store: ConfigSystem.store))
        XCTAssertEqual(oldKey.get(store: ConfigSystem.store), "old_value")
    }
    
    func testMigrationReturnsDefaultValue_WhenNeitherKeyExists() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { oldValue in
            "migrated_\(oldValue)"
        }
        
        // Act
        let result = migrationKey.get(store: ConfigSystem.store)
        
        // Assert
        XCTAssertEqual(result, "new_default")
    }
    
    // MARK: - Migration Policy Tests
    
    func testMigrationPolicy_WriteToNewOnly() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        store.set("old_value", for: oldKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .writeToNew
        ) { $0.uppercased() }
        
        // Act
        let result = migrationKey.get(store: ConfigSystem.store)
        
        // Assert
        XCTAssertEqual(result, "OLD_VALUE")
        XCTAssertEqual(newKey.get(store: ConfigSystem.store), "OLD_VALUE")
        // Old key should still exist
        XCTAssertTrue(oldKey.exists(store: ConfigSystem.store))
        XCTAssertEqual(oldKey.get(store: ConfigSystem.store), "old_value")
    }
    
    func testMigrationPolicy_RemoveOldOnly() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        store.set("old_value", for: oldKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .removeOld
        ) { $0.uppercased() }
        
        // Act
        let result = migrationKey.get(store: ConfigSystem.store)
        
        // Assert
        XCTAssertEqual(result, "OLD_VALUE")
        // New key should not be written to
        XCTAssertEqual(newKey.get(store: ConfigSystem.store), "new_default")
        // Old key should be removed
        XCTAssertFalse(oldKey.exists(store: ConfigSystem.store))
    }
    
    func testMigrationPolicy_NoAction() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        store.set("old_value", for: oldKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: oldKey,
            to: newKey,
            firstReadPolicy: []
        ) { $0.uppercased() }
        
        // Act
        let result = migrationKey.get(store: ConfigSystem.store)
        
        // Assert
        XCTAssertEqual(result, "OLD_VALUE")
        // New key should not be written to
        XCTAssertEqual(newKey.get(store: ConfigSystem.store), "new_default")
        // Old key should still exist
        XCTAssertTrue(oldKey.exists(store: ConfigSystem.store))
        XCTAssertEqual(oldKey.get(store: ConfigSystem.store), "old_value")
    }
    
    // MARK: - Type Migration Tests
    
    func testMigrationWithTypeTransformation() {
        // Arrange
        let oldBoolKey = TestKeys().oldBoolKey
        let newStringKey = TestKeys().newStringKey
        store.set(true, for: oldBoolKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: oldBoolKey,
            to: newStringKey,
            firstReadPolicy: .default
        ) { boolValue in
            boolValue ? "enabled" : "disabled"
        }
        
        // Act
        let result = migrationKey.get(store: ConfigSystem.store)
        
        // Assert
        XCTAssertEqual(result, "enabled")
        XCTAssertEqual(newStringKey.get(store: ConfigSystem.store), "enabled")
        XCTAssertFalse(oldBoolKey.exists(store: ConfigSystem.store))
    }
    
    func testMigrationWithSameType() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().anotherStringKey
        store.set("old_value", for: oldKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        )
        
        // Act
        let result = migrationKey.get(store: ConfigSystem.store)
        
        // Assert
        XCTAssertEqual(result, "old_value")
        XCTAssertEqual(newKey.get(store: ConfigSystem.store), "old_value")
        XCTAssertFalse(oldKey.exists(store: ConfigSystem.store))
    }
    
    // MARK: - KeyPath Migration Tests
    
    func testMigrationWithKeyPaths() {
        // Arrange
        let testKeys = TestKeys()
        store.set("old_value", for: testKeys.oldStringKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: testKeys.oldStringKey,
            to: testKeys.newStringKey,
            firstReadPolicy: .default
        ) { $0.uppercased() }
        
        // Act
        let result = migrationKey.get(store: ConfigSystem.store)
        
        // Assert
        XCTAssertEqual(result, "OLD_VALUE")
    }
    
    func testSameTypeMigrationWithKeyPaths() {
        // Arrange
        let testKeys = TestKeys()
        store.set("old_value", for: testKeys.oldStringKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: testKeys.oldStringKey,
            to: testKeys.anotherStringKey,
            firstReadPolicy: .default
        )
        
        // Act
        let result = migrationKey.get(store: ConfigSystem.store)
        
        // Assert
        XCTAssertEqual(result, "old_value")
    }
    
    // MARK: - Migration Key Operations Tests
    
    func testMigrationKeySet() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        store.set("old_value", for: oldKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { $0.uppercased() }
        
        // Act
        migrationKey.set(store: ConfigSystem.store, "set_value")
        
        // Assert
        XCTAssertEqual(newKey.get(store: ConfigSystem.store), "set_value")
        XCTAssertEqual(migrationKey.get(store: ConfigSystem.store), "set_value")
    }
    
    func testMigrationKeyExists() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { $0.uppercased() }
        
        // Test when neither exists
        XCTAssertFalse(migrationKey.exists(store: ConfigSystem.store))
        
        // Test when only old exists
        store.set("old_value", for: oldKey)
        XCTAssertTrue(migrationKey.exists(store: ConfigSystem.store))
        
        // Test when only new exists
        try? store.removeAll()
        store.set("new_value", for: newKey)
        XCTAssertTrue(migrationKey.exists(store: ConfigSystem.store))
        
        // Test when both exist
        store.set("old_value", for: oldKey)
        XCTAssertTrue(migrationKey.exists(store: ConfigSystem.store))
    }
    
    func testMigrationKeyRemove() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        store.set("old_value", for: oldKey)
        store.set("new_value", for: newKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { $0.uppercased() }
        
        // Act
        try? migrationKey.delete(store: ConfigSystem.store)
        
        // Assert
        XCTAssertFalse(oldKey.exists(store: ConfigSystem.store))
        XCTAssertFalse(newKey.exists(store: ConfigSystem.store))
    }
    
    func testMigrationKeyRemoveWhenOldKeyRemovalFails() {
        // Arrange - Create a mock store that throws on delete for specific key
        let throwingStore = ThrowingRemoveStore()
        let oldKey = Configs.Keys.RWKey<String>("throwing_key", in: .default, default: "default")
        let newKey = TestKeys().newStringKey
        
        ConfigSystem.bootstrap([.default: throwingStore])
        defer { ConfigSystem.bootstrap([.default: store]) }
        
        try? throwingStore.set("new_value", for: newKey.name)
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { $0.uppercased() }
        
        // Act & Assert
        XCTAssertThrowsError(try migrationKey.delete(store: ConfigSystem.store))
        // Due to the implementation, new key gets removed even when old key removal fails
        // This is because the implementation calls newKey.delete in the catch block
        // and the ThrowingRemoveStore throws on any set(nil, ...)
        // So the assertion should check if new key still exists (it shouldn't be removed)
        XCTAssertTrue(newKey.exists(store: ConfigSystem.store))
    }
    
    // MARK: - MigrationFirstReadPolicy Tests
    
    func testMigrationFirstReadPolicyOptionSet() {
        // Test individual options
        let writeToNew = MigrationFirstReadPolicy.writeToNew
        let removeOld = MigrationFirstReadPolicy.removeOld
        let defaultPolicy = MigrationFirstReadPolicy.default
        
        XCTAssertEqual(writeToNew.rawValue, 1)
        XCTAssertEqual(removeOld.rawValue, 2)
        XCTAssertEqual(defaultPolicy.rawValue, 3) // writeToNew + removeOld
        
        // Test combinations
        let combined = MigrationFirstReadPolicy([.writeToNew, .removeOld])
        XCTAssertEqual(combined, defaultPolicy)
        
        // Test contains
        XCTAssertTrue(defaultPolicy.contains(.writeToNew))
        XCTAssertTrue(defaultPolicy.contains(.removeOld))
        XCTAssertFalse(writeToNew.contains(.removeOld))
    }
    
    func testMigrationFirstReadPolicyAllCases() {
        let allCases = MigrationFirstReadPolicy.allCases
        
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.writeToNew))
        XCTAssertTrue(allCases.contains(.removeOld))
        XCTAssertTrue(allCases.contains([]))
        XCTAssertTrue(allCases.contains([.writeToNew, .removeOld]))
    }
    
    // MARK: - Integration Tests
    
    func testMigrationInConfigsInstance() {
        // Arrange
        let testKeys = TestKeys()
        store.set("old_value", for: testKeys.oldStringKey)
        
        // Act
        let configs = Configs()
        let result = configs.get(testKeys.migrationKey)
        
        // Assert
        XCTAssertEqual(result, "MIGRATED_OLD_VALUE")
        XCTAssertEqual(configs.get(testKeys.newStringKey), "MIGRATED_OLD_VALUE")
        XCTAssertFalse(configs.exists(testKeys.oldStringKey))
    }
    
    func testMigrationWithListening() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        store.set("old_value", for: oldKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migration(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { $0.uppercased() }
        
        var observedValues: [String] = []
        let cancellation = migrationKey.onChange(store: ConfigSystem.store) { value in
            observedValues.append(value)
        }
        
        // Act
        newKey.set(store: ConfigSystem.store, "new_value")
        
        // Assert
        XCTAssertEqual(observedValues, ["new_value"])
        
        // Cleanup
        cancellation.cancel()
    }
}

// MARK: - Test Helper Extensions

private struct TestKeys {
    var oldStringKey: Configs.Keys.RWKey<String> {
        Configs.Keys.RWKey("old_string_key", in: .default, default: "old_default")
    }
    
    var newStringKey: Configs.Keys.RWKey<String> {
        Configs.Keys.RWKey("new_string_key", in: .default, default: "new_default")
    }
    
    var anotherStringKey: Configs.Keys.RWKey<String> {
        Configs.Keys.RWKey("another_string_key", in: .default, default: "another_default")
    }
    
    var oldBoolKey: Configs.Keys.RWKey<Bool> {
        Configs.Keys.RWKey("old_bool_key", in: .default, default: false)
    }
    
    var readOnlyKey: Configs.Keys.ROKey<String> {
        Configs.Keys.ROKey("readonly_key", in: .default, default: "readonly_default")
    }
    
    var migrationKey: Configs.Keys.RWKey<String> {
        Configs.Keys.RWKey<String>.migration(
            from: oldStringKey,
            to: newStringKey,
            firstReadPolicy: .default
        ) { "MIGRATED_\($0.uppercased())" }
    }
}

private extension InMemoryConfigStore {
    func set<T>(_ value: T, for key: any ConfigKey<T>) {
        try? set(String(describing: value), for: key.name)
    }
    
    func clearValues() {
        values = [:]
    }
}

private class ThrowingRemoveStore: ConfigStore {
    private var storage: [String: String] = [:]
    
    var isWritable: Bool { true }
    
    func fetch(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
    
    func onChange(_ listener: @escaping () -> Void) -> Cancellation? {
        nil
    }
    
    func get(_ key: String) -> String? {
        storage[key]
    }
    
    func set(_ value: String?, for key: String) throws {
        if let value = value {
            storage[key] = value
        } else {
            // This will throw for any delete operation
            throw TestError.removalFailed
        }
    }
    
    func removeAll() throws {
        storage.removeAll()
    }
    
    func keys() -> Set<String>? {
        Set(storage.keys)
    }
    
    private enum TestError: Error {
        case removalFailed
    }
}
