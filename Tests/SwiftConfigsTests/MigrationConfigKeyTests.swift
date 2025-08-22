@testable import SwiftConfigs
import XCTest

final class MigrationConfigKeyTests: XCTestCase {
    
    var handler: InMemoryConfigsHandler!
    
    override func setUp() {
        super.setUp()
        handler = InMemoryConfigsHandler()
        ConfigsSystem.bootstrap([.default: handler])
    }
    
    override func tearDown() {
        super.tearDown()
        handler = nil
    }
    
    // MARK: - Basic Migration Tests
    
    func testMigrationFromOldToNewKey_WhenOnlyOldExists() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        handler.set("old_value", for: oldKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { oldValue in
            "migrated_\(oldValue)"
        }
        
        // Act
        let result = migrationKey.get(handler: ConfigsSystem.handler)
        
        // Assert
        XCTAssertEqual(result, "migrated_old_value")
        // Check that value was written to new key
        XCTAssertEqual(newKey.get(handler: ConfigsSystem.handler), "migrated_old_value")
        // Check that old key was removed
        XCTAssertFalse(oldKey.exists(handler: ConfigsSystem.handler))
    }
    
    func testMigrationReturnsNewValue_WhenBothKeysExist() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        handler.set("old_value", for: oldKey)
        handler.set("new_value", for: newKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { oldValue in
            "migrated_\(oldValue)"
        }
        
        // Act
        let result = migrationKey.get(handler: ConfigsSystem.handler)
        
        // Assert
        XCTAssertEqual(result, "new_value")
        // Old key should still exist (migration didn't happen)
        XCTAssertTrue(oldKey.exists(handler: ConfigsSystem.handler))
        XCTAssertEqual(oldKey.get(handler: ConfigsSystem.handler), "old_value")
    }
    
    func testMigrationReturnsDefaultValue_WhenNeitherKeyExists() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { oldValue in
            "migrated_\(oldValue)"
        }
        
        // Act
        let result = migrationKey.get(handler: ConfigsSystem.handler)
        
        // Assert
        XCTAssertEqual(result, "new_default")
    }
    
    // MARK: - Migration Policy Tests
    
    func testMigrationPolicy_WriteToNewOnly() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        handler.set("old_value", for: oldKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .writeToNew
        ) { $0.uppercased() }
        
        // Act
        let result = migrationKey.get(handler: ConfigsSystem.handler)
        
        // Assert
        XCTAssertEqual(result, "OLD_VALUE")
        XCTAssertEqual(newKey.get(handler: ConfigsSystem.handler), "OLD_VALUE")
        // Old key should still exist
        XCTAssertTrue(oldKey.exists(handler: ConfigsSystem.handler))
        XCTAssertEqual(oldKey.get(handler: ConfigsSystem.handler), "old_value")
    }
    
    func testMigrationPolicy_RemoveOldOnly() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        handler.set("old_value", for: oldKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .removeOld
        ) { $0.uppercased() }
        
        // Act
        let result = migrationKey.get(handler: ConfigsSystem.handler)
        
        // Assert
        XCTAssertEqual(result, "OLD_VALUE")
        // New key should not be written to
        XCTAssertEqual(newKey.get(handler: ConfigsSystem.handler), "new_default")
        // Old key should be removed
        XCTAssertFalse(oldKey.exists(handler: ConfigsSystem.handler))
    }
    
    func testMigrationPolicy_NoAction() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        handler.set("old_value", for: oldKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: oldKey,
            to: newKey,
            firstReadPolicy: []
        ) { $0.uppercased() }
        
        // Act
        let result = migrationKey.get(handler: ConfigsSystem.handler)
        
        // Assert
        XCTAssertEqual(result, "OLD_VALUE")
        // New key should not be written to
        XCTAssertEqual(newKey.get(handler: ConfigsSystem.handler), "new_default")
        // Old key should still exist
        XCTAssertTrue(oldKey.exists(handler: ConfigsSystem.handler))
        XCTAssertEqual(oldKey.get(handler: ConfigsSystem.handler), "old_value")
    }
    
    // MARK: - Type Migration Tests
    
    func testMigrationWithTypeTransformation() {
        // Arrange
        let oldBoolKey = TestKeys().oldBoolKey
        let newStringKey = TestKeys().newStringKey
        handler.set(true, for: oldBoolKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: oldBoolKey,
            to: newStringKey,
            firstReadPolicy: .default
        ) { boolValue in
            boolValue ? "enabled" : "disabled"
        }
        
        // Act
        let result = migrationKey.get(handler: ConfigsSystem.handler)
        
        // Assert
        XCTAssertEqual(result, "enabled")
        XCTAssertEqual(newStringKey.get(handler: ConfigsSystem.handler), "enabled")
        XCTAssertFalse(oldBoolKey.exists(handler: ConfigsSystem.handler))
    }
    
    func testMigrationWithSameType() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().anotherStringKey
        handler.set("old_value", for: oldKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        )
        
        // Act
        let result = migrationKey.get(handler: ConfigsSystem.handler)
        
        // Assert
        XCTAssertEqual(result, "old_value")
        XCTAssertEqual(newKey.get(handler: ConfigsSystem.handler), "old_value")
        XCTAssertFalse(oldKey.exists(handler: ConfigsSystem.handler))
    }
    
    // MARK: - KeyPath Migration Tests
    
    func testMigrationWithKeyPaths() {
        // Arrange
        let testKeys = TestKeys()
        handler.set("old_value", for: testKeys.oldStringKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: testKeys.oldStringKey,
            to: testKeys.newStringKey,
            firstReadPolicy: .default
        ) { $0.uppercased() }
        
        // Act
        let result = migrationKey.get(handler: ConfigsSystem.handler)
        
        // Assert
        XCTAssertEqual(result, "OLD_VALUE")
    }
    
    func testSameTypeMigrationWithKeyPaths() {
        // Arrange
        let testKeys = TestKeys()
        handler.set("old_value", for: testKeys.oldStringKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: testKeys.oldStringKey,
            to: testKeys.anotherStringKey,
            firstReadPolicy: .default
        )
        
        // Act
        let result = migrationKey.get(handler: ConfigsSystem.handler)
        
        // Assert
        XCTAssertEqual(result, "old_value")
    }
    
    // MARK: - Migration Key Operations Tests
    
    func testMigrationKeySet() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        handler.set("old_value", for: oldKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { $0.uppercased() }
        
        // Act
        migrationKey.set(handler: ConfigsSystem.handler, "set_value")
        
        // Assert
        XCTAssertEqual(newKey.get(handler: ConfigsSystem.handler), "set_value")
        XCTAssertEqual(migrationKey.get(handler: ConfigsSystem.handler), "set_value")
    }
    
    func testMigrationKeyExists() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { $0.uppercased() }
        
        // Test when neither exists
        XCTAssertFalse(migrationKey.exists(handler: ConfigsSystem.handler))
        
        // Test when only old exists
        handler.set("old_value", for: oldKey)
        XCTAssertTrue(migrationKey.exists(handler: ConfigsSystem.handler))
        
        // Test when only new exists
        try? handler.clear()
        handler.set("new_value", for: newKey)
        XCTAssertTrue(migrationKey.exists(handler: ConfigsSystem.handler))
        
        // Test when both exist
        handler.set("old_value", for: oldKey)
        XCTAssertTrue(migrationKey.exists(handler: ConfigsSystem.handler))
    }
    
    func testMigrationKeyRemove() {
        // Arrange
        let oldKey = TestKeys().oldStringKey
        let newKey = TestKeys().newStringKey
        handler.set("old_value", for: oldKey)
        handler.set("new_value", for: newKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { $0.uppercased() }
        
        // Act
        try? migrationKey.remove(handler: ConfigsSystem.handler)
        
        // Assert
        XCTAssertFalse(oldKey.exists(handler: ConfigsSystem.handler))
        XCTAssertFalse(newKey.exists(handler: ConfigsSystem.handler))
    }
    
    func testMigrationKeyRemoveWhenOldKeyRemovalFails() {
        // Arrange - Create a mock handler that throws on remove for specific key
        let throwingHandler = ThrowingRemoveHandler()
        let oldKey = Configs.Keys.RWKey<String>("throwing_key", in: .default, default: "default")
        let newKey = TestKeys().newStringKey
        
        ConfigsSystem.bootstrap([.default: throwingHandler])
        defer { ConfigsSystem.bootstrap([.default: handler]) }
        
        try? throwingHandler.writeValue("new_value", for: newKey.name)
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { $0.uppercased() }
        
        // Act & Assert
        XCTAssertThrowsError(try migrationKey.remove(handler: ConfigsSystem.handler))
        // Due to the implementation, new key gets removed even when old key removal fails
        // This is because the implementation calls newKey.remove in the catch block
        // and the ThrowingRemoveHandler throws on any writeValue(nil, ...)
        // So the assertion should check if new key still exists (it shouldn't be removed)
        XCTAssertTrue(newKey.exists(handler: ConfigsSystem.handler))
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
        handler.set("old_value", for: testKeys.oldStringKey)
        
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
        handler.set("old_value", for: oldKey)
        
        let migrationKey = Configs.Keys.RWKey<String>.migraion(
            from: oldKey,
            to: newKey,
            firstReadPolicy: .default
        ) { $0.uppercased() }
        
        var observedValues: [String] = []
        let cancellation = migrationKey.listen(handler: ConfigsSystem.handler) { value in
            observedValues.append(value)
        }
        
        // Act
        newKey.set(handler: ConfigsSystem.handler, "new_value")
        
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
        Configs.Keys.RWKey<String>.migraion(
            from: oldStringKey,
            to: newStringKey,
            firstReadPolicy: .default
        ) { "MIGRATED_\($0.uppercased())" }
    }
}

private extension InMemoryConfigsHandler {
    func set<T>(_ value: T, for key: any ConfigKey<T>) {
        try? writeValue(String(describing: value), for: key.name)
    }
    
    func clearValues() {
        values = [:]
    }
}

private class ThrowingRemoveHandler: ConfigsHandler {
    private var storage: [String: String] = [:]
    
    var supportWriting: Bool { true }
    
    func fetch(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
    
    func listen(_ listener: @escaping () -> Void) -> ConfigsCancellation? {
        nil
    }
    
    func value(for key: String) -> String? {
        storage[key]
    }
    
    func writeValue(_ value: String?, for key: String) throws {
        if let value = value {
            storage[key] = value
        } else {
            // This will throw for any remove operation
            throw TestError.removalFailed
        }
    }
    
    func clear() throws {
        storage.removeAll()
    }
    
    func allKeys() -> Set<String>? {
        Set(storage.keys)
    }
    
    private enum TestError: Error {
        case removalFailed
    }
}