@testable import SwiftConfigs
import XCTest

final class SwiftConfigsTests: XCTestCase {

    static var allTests = [
        ("testReadDefaultValue", testReadDefaultValue),
        ("testReadValue", testReadValue),
        ("testRewriteValue", testRewriteValue),
        ("testListen", testListen),
        ("testDidFetch", testDidFetch),
        ("testFetchIfNeeded", testFetchIfNeeded),
        ("testEnvironmentVariableHandler", testEnvironmentVariableHandler),
    ]

    var handler = InMemoryConfigsHandler()

    override func setUp() {
        super.setUp()
		ConfigsSystem.bootstrapInternal([.default: handler])
    }

    func testReadDefaultValue() {
        // Act
        let value = Configs().testKey

        // Assert
        XCTAssertEqual(value, Configs.Keys().testKey.defaultValue())
    }

    func testReadValue() {
        // Arrange
        handler.set("value", for: \.testKey)

        // Act
        let value = Configs().testKey

        // Assert
        XCTAssertEqual(value, "value")
    }

    func testRewriteValue() {
        // Act
        let value = Configs().with(\.testKey, "value").testKey

        // Assert
        XCTAssertEqual(value, "value")
    }

    func testListen() {
        // Arrange
        var fetched = false
        Configs().listen { _ in
            fetched = true
        }

        // Act
        handler.values = ["key": "value"]

        // Assert
        XCTAssertTrue(fetched)
    }

    func testDidFetch() async throws {
        // Arrange
        let configs = Configs()

        // Act
        let didFetch = configs.didFetch

        // Assert
        XCTAssertFalse(didFetch)

        // Act
        handler.values = ["key": "value"]
        try await configs.fetchIfNeeded()
        // Assert
        XCTAssertTrue(configs.didFetch)
    }

    func testFetchIfNeeded() async throws {
        // Arrange
        let configs = Configs()

        // Act
        handler.values = ["key": "value"]
        let value = try await configs.fetchIfNeeded(\.testKey)

        // Assert
        XCTAssertEqual(value, "value")
    }
    
    func testEnvironmentVariableHandler() {
        // Arrange
        let mockProcessInfo = MockProcessInfo()
        mockProcessInfo.environment = ["TEST_ENV_VAR": "test_value"]
        let envHandler = EnvironmentVariableConfigsHandler(processInfo: mockProcessInfo)
        
        // Act
        let value = envHandler.value(for: "TEST_ENV_VAR")
        let nonExistentValue = envHandler.value(for: "NON_EXISTENT")
        let allKeys = envHandler.allKeys()
        
        // Assert
        XCTAssertEqual(value, "test_value")
        XCTAssertNil(nonExistentValue)
        XCTAssertTrue(allKeys?.contains("TEST_ENV_VAR") ?? false)
        
        // Test unsupported operations
        XCTAssertThrowsError(try envHandler.writeValue("value", for: "key"))
        XCTAssertThrowsError(try envHandler.clear())
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
    var testKey: Key<String> {
        Key("key", default: "defaultValue")
    }
}
