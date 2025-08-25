@testable import SwiftConfigs
import XCTest

final class SwiftConfigsTests: XCTestCase {

    static var allTests = [
        ("testReadDefaultValue", testReadDefaultValue),
        ("testReadValue", testReadValue),
        ("testListen", testListen),
        ("testDidFetch", testDidFetch),
        ("testFetchIfNeeded", testFetchIfNeeded),
        ("testEnvironmentVariableStore", testEnvironmentVariableStore),
        ("testFallbackConfigStore", testFallbackConfigStore),
        ("testPrefixConfigStore", testPrefixConfigStore),
    ]

    var store = InMemoryConfigStore()

    override func setUp() {
        super.setUp()
        ConfigSystem.bootstrap([.default: store])
    }

    func testReadDefaultValue() {
        // Act
        let value = Configs().testKey

        // Assert
        XCTAssertEqual(value, "defaultValue")
    }

    func testReadValue() {
        // Arrange
        try? store.set("value", for: "key")

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

    func testListen() {
        // Arrange
        var fetched = false
        Configs().onChange { _ in
            fetched = true
        }

        // Act
        store.values = ["key": "value"]

        // Assert
        XCTAssertTrue(fetched)
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

    func testFallbackConfigStore() throws {
        // Arrange
        let readStore = InMemoryConfigStore(["remote_key": "remote_value"])
        let writeStore = InMemoryConfigStore(["local_key": "local_value"])
        let fallbackStore = MigrationConfigStore(mainStore: writeStore, fallbackStore: readStore)

        // Test reading from read store first
        try XCTAssertEqual(fallbackStore.get("remote_key"), "remote_value")

        // Test migration to write store
        try XCTAssertEqual(fallbackStore.get("local_key"), "local_value")

        // Test non-existent key
        try XCTAssertNil(fallbackStore.get("non_existent"))

        // Test writing (should only write to write store)
        try? fallbackStore.set("new_value", for: "test_key")
        XCTAssertEqual(writeStore.get("test_key"), "new_value")
        XCTAssertNil(readStore.get("test_key"))

        // Test keys combines both stores
        let keys = fallbackStore.keys()
        XCTAssertFalse(keys?.contains("remote_key") ?? false)
        XCTAssertTrue(keys?.contains("local_key") ?? false)

        // Test clear only affects write store
        try? fallbackStore.removeAll()
        XCTAssertNil(writeStore.get("local_key"))
        XCTAssertEqual(readStore.get("remote_key"), "remote_value")
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
}

private final class MockProcessInfo: ProcessInfo, @unchecked Sendable {
    override var environment: [String: String] {
        get { _environment }
        set { _environment = newValue }
    }

    private var _environment: [String: String] = [:]
}

private extension Configs.Keys {

    var testKey: Key<String, ReadWrite> {
        Key("key", in: .default, default: "defaultValue")
    }
}
