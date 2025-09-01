@testable import SwiftConfigs
import XCTest

final class SwiftConfigsTests: XCTestCase {

    static var allTests = [
        ("testReadDefaultValue", testReadDefaultValue),
        ("testReadValue", testReadValue),
        ("testDidFetch", testDidFetch),
        ("testFetchIfNeeded", testFetchIfNeeded),
        ("testEnvironmentVariableStore", testEnvironmentVariableStore),
        ("testMigrationConfigStore", testMigrationConfigStore),
        ("testPrefixConfigStore", testPrefixConfigStore),
        ("testNamespaceWithKeyPrefix", testNamespaceWithKeyPrefix),
        ("testNestedNamespaceKeyPrefix", testNestedNamespaceKeyPrefix),
        ("testNamespaceKeyPrefixConcatenation", testNamespaceKeyPrefixConcatenation),
        ("testNamespaceWithOverrides", testNamespaceWithOverrides),
    ]

    var store = InMemoryConfigStore()

    override func setUp() {
        super.setUp()
        ConfigSystem.bootstrap([.default: store]) { _ in }
    }

    func testReadDefaultValue() {
        // Act
        let value = Configs().testKey

        // Assert
        XCTAssertEqual(value, "defaultValue")
    }

    func testReadValue() throws {
        // Arrange
        try store.set("value", for: "key")

        // Act
        let value = Configs().testKey

        // Assert
        XCTAssertEqual(value, "value")
    }

    func testReset() {
        // Act
        let value = Configs().with(\.testKey, "value").testKey

        // Assert
        XCTAssertEqual(value, "value")
    }

    func testDidFetch() async throws {
        // Arrange
        let configs = Configs()

        // Act
        let hasFetched = configs.hasFetched

        // Assert
        XCTAssertFalse(hasFetched)

        // Act
        store.values = ["key": "value"]
        try await configs.fetchIfNeeded()
        // Assert
        XCTAssertTrue(configs.hasFetched)
    }

    func testFetchIfNeeded() async throws {
        // Arrange
        let configs = Configs()

        // Act
        store.values = ["key": "value"]
        let value = try await configs.fetchIfNeeded(Configs.Keys().testKey)

        // Assert
        XCTAssertEqual(value, "value")
    }

    func testEnvironmentVariableStore() {
        // Arrange
        let mockProcessInfo = MockProcessInfo()
        mockProcessInfo.environment = ["TEST_ENV_VAR": "test_value"]
        let envStore = EnvironmentVariableConfigStore(processInfo: mockProcessInfo)

        // Act
        let value = envStore.get("TEST_ENV_VAR")
        let nonExistentValue = envStore.get("NON_EXISTENT")
        let keys = envStore.keys()

        // Assert
        XCTAssertEqual(value, "test_value")
        XCTAssertNil(nonExistentValue)
        XCTAssertTrue(keys?.contains("TEST_ENV_VAR") ?? false)

        // Test unsupported operations
        XCTAssertThrowsError(try envStore.set("value", for: "key"))
        XCTAssertThrowsError(try envStore.removeAll())
    }

    func testMigrationConfigStore() throws {
        // Arrange: legacy has "remote_key", new has "local_key"
        let legacyStore = InMemoryConfigStore(["remote_key": "remote_value"])
        let newStore = InMemoryConfigStore(["local_key": "local_value"])
        let migrationStore = MigrationConfigStore(newStore: newStore, legacyStore: legacyStore)

        // Reads: prefer newStore, otherwise fall back to legacyStore
        XCTAssertEqual(try migrationStore.get("remote_key"), "remote_value") // from legacy
        XCTAssertEqual(try migrationStore.get("local_key"), "local_value")   // from new

        // Non-existent
        XCTAssertNil(try migrationStore.get("non_existent"))

        // Writes: only to newStore
        try migrationStore.set("new_value", for: "test_key")
        XCTAssertEqual(newStore.get("test_key"), "new_value")
        XCTAssertNil(legacyStore.get("test_key"))

        // Keys: union of both stores (plus newly written key in newStore)
        let keys = migrationStore.keys() ?? []
        XCTAssertTrue(keys.contains("remote_key"))
        XCTAssertTrue(keys.contains("local_key"))
        XCTAssertTrue(keys.contains("test_key"))

        // removeAll() should clear only newStore (by design), legacy remains intact
        try migrationStore.removeAll()
        XCTAssertNil(newStore.get("local_key"))
        XCTAssertNil(newStore.get("test_key"))
        XCTAssertEqual(legacyStore.get("remote_key"), "remote_value")
    }

    func testPrefixConfigStore() throws {
        // Arrange
        let underlyingStore = InMemoryConfigStore(["app_user_name": "john", "app_user_age": "25", "other_key": "value"])
        let prefixStore = PrefixConfigStore(prefix: "app_", store: underlyingStore)

        // Test reading values with prefix
        try XCTAssertEqual(prefixStore.get("user_name"), "john")
        try XCTAssertEqual(prefixStore.get("user_age"), "25")
        try XCTAssertNil(prefixStore.get("other_key"))
        try XCTAssertNil(prefixStore.get("non_existent"))

        // Test keys returns only unprefixed keys for matching prefix
        let keys = prefixStore.keys()
        XCTAssertEqual(keys?.count, 2)
        XCTAssertTrue(keys?.contains("user_name") ?? false)
        XCTAssertTrue(keys?.contains("user_age") ?? false)
        XCTAssertFalse(keys?.contains("other_key") ?? true)

        // Test writing adds prefix
        try prefixStore.set("doe", for: "user_surname")
        XCTAssertEqual(underlyingStore.get("app_user_surname"), "doe")
        try XCTAssertEqual(prefixStore.get("user_surname"), "doe")

        // Test clear only clears prefixed keys
        try prefixStore.removeAll()
        XCTAssertNil(underlyingStore.get("app_user_name"))
        XCTAssertNil(underlyingStore.get("app_user_age"))
        XCTAssertNil(underlyingStore.get("app_user_surname"))
        XCTAssertEqual(underlyingStore.get("other_key"), "value")

        // Test isWritable delegates to underlying store
        XCTAssertEqual(prefixStore.isWritable, underlyingStore.isWritable)
    }

    func testNamespaceWithKeyPrefix() throws {
        // Arrange: Set up store with prefixed keys
        try store.set("secret-token", for: "security.api-token")
        try store.set("true", for: "security.encryption-enabled")
        try store.set("normal-value", for: "app-setting")
        
        let configs = Configs()
        
        // Act: Access through namespace with prefix
        let apiToken = configs.security.apiToken
        let encryptionEnabled = configs.security.encryptionEnabled
        let normalSetting = configs.appSetting
        
        // Assert: Prefixed keys should be found, non-prefixed key should be found too
        XCTAssertEqual(apiToken, "secret-token")
        XCTAssertEqual(encryptionEnabled, true)
        XCTAssertEqual(normalSetting, "normal-value")
        
        // Test that keyPrefix is correctly applied when reading values
        let securityNamespace = configs.keys.security
        XCTAssertEqual(securityNamespace.keyPrefix, "security.")
        
        // Test direct key access (this will use the prefixed key to read from store)
        let directApiToken = configs.security.apiToken
        XCTAssertEqual(directApiToken, "secret-token")
    }

    func testNestedNamespaceKeyPrefix() throws {
        // Arrange: Set up store with nested prefixed keys
        try store.set("nested-value", for: "security.auth.jwt-secret")
        try store.set("42", for: "security.auth.timeout")
        
        let configs = Configs()
        
        // Act: Access through nested namespace with prefixes
        let jwtSecret = configs.security.auth.jwtSecret
        let timeout = configs.security.auth.timeout
        
        // Assert: Nested prefixes should work correctly
        XCTAssertEqual(jwtSecret, "nested-value")
        XCTAssertEqual(timeout, 42)
    }

    func testNamespaceKeyPrefixConcatenation() {
        // Arrange
        let configs = Configs()
        
        // Act: Get key prefixes at different levels
        let rootPrefix = configs.keys.keyPrefix
        let securityPrefix = configs.keys.security.keyPrefix
        let authPrefix = configs.keys.security.auth.keyPrefix
        
        // Assert: Prefixes should concatenate correctly
        XCTAssertEqual(rootPrefix, "")
        XCTAssertEqual(securityPrefix, "security.")
        XCTAssertEqual(authPrefix, "security.auth.")
    }

    func testNamespaceWithOverrides() throws {
        // Arrange: Set up store with a prefixed key
        try store.set("store-value", for: "security.api-token")
        
        let configs = Configs()
        
        // Act & Assert: Normal access should read from store
        XCTAssertEqual(configs.security.apiToken, "store-value")
        
        // Method 1: Create override on namespace itself - this applies the prefix correctly
        let securityNamespace = configs.security
        let updatedNamespace = securityNamespace.with(\.apiToken, "namespace-override")
        XCTAssertEqual(updatedNamespace.apiToken, "namespace-override")
        
        // Method 2: Create override using root configs with the actual prefixed key
        let securityKey = configs.keys.security.apiToken
        let updatedConfigs = configs.with(securityKey, "root-override")
        XCTAssertEqual(updatedConfigs.security.apiToken, "root-override")
        
        // Original configs should still read from store
        XCTAssertEqual(configs.security.apiToken, "store-value")
    }
}

private final class MockProcessInfo: ProcessInfo, @unchecked Sendable {
    override var environment: [String: String] {
        get { _environment }
        set { _environment = newValue }
    }

    private var _environment: [String: String] = [:]
}

private extension Configs.Keys {
    
    var testKey: ROConfigKey<String> {
        ConfigKey("key", in: .default, default: "defaultValue")
    }
    
    var appSetting: ROConfigKey<String> {
        ConfigKey("app-setting", in: .default, default: "default-value")
    }
    
    var security: SecurityNamespace { SecurityNamespace() }
    
    struct SecurityNamespace: ConfigNamespaceKeys {
        
        var keyPrefix: String { "security." }
        
        var apiToken: RWConfigKey<String> {
            ConfigKey(qualify("api-token"), in: .default, default: "default-token")
        }
        
        var encryptionEnabled: ROConfigKey<Bool> {
            ConfigKey(qualify("encryption-enabled"), in: .default, default: false)
        }
        
        var auth: AuthNamespace { AuthNamespace(prefix: keyPrefix) }
    }
    
    struct AuthNamespace: ConfigNamespaceKeys {
        
        var prefix: String
        var keyPrefix: String { prefix + "auth." }
        
        var jwtSecret: ROConfigKey<String> {
            ConfigKey(qualify("jwt-secret"), in: .default, default: "default-secret")
        }
        
        var timeout: ROConfigKey<Int> {
            ConfigKey(qualify("timeout"), in: .default, default: 30)
        }
    }
}
