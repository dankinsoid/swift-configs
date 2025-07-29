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
    ]

    var handler = InMemoryConfigsHandler()

    override func setUp() {
        super.setUp()
        ConfigsSystem.bootstrapInternal(handler)
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
        let remoteConfigs = Configs()

        // Act
        let didFetch = remoteConfigs.didFetch

        // Assert
        XCTAssertFalse(didFetch)

        // Act
        handler.values = ["key": "value"]
        try await remoteConfigs.fetchIfNeeded()
        // Assert
        XCTAssertTrue(remoteConfigs.didFetch)
    }

    func testFetchIfNeeded() async throws {
        // Arrange
        let remoteConfigs = Configs()

        // Act
        handler.values = ["key": "value"]
        let value = try await remoteConfigs.fetchIfNeeded(\.testKey)

        // Assert
        XCTAssertEqual(value, "value")
    }
}

private extension Configs.Keys {
    var testKey: Key<String> {
        Key("key", default: "defaultValue")
    }
}
