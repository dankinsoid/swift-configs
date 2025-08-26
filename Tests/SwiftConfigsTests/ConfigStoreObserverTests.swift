@testable import SwiftConfigs
import XCTest

final class ConfigStoreObserverTests: XCTestCase {
    
    private var observer: ConfigStoreObserver!
    private var store: InMemoryConfigStore!
    
    override func setUp() {
        super.setUp()
        observer = ConfigStoreObserver()
        store = InMemoryConfigStore()
    }
    
    override func tearDown() {
        observer = nil
        store = nil
        super.tearDown()
    }
    
    // MARK: - Global Observer Tests
    
    func testOnChangeGlobalObserver() {
        // Arrange
        let expectation = expectation(description: "global observer called")
        var callCount = 0
        
        let cancellation = observer.onChange {
            callCount += 1
            expectation.fulfill()
        }
        
        // Act
        observer.notifyChange(for: "test_key", newValue: "test_value")
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(callCount, 1)
        
        // Cleanup
        cancellation.cancel()
    }
    
    func testOnChangeGlobalObserverWithValuesFunction() {
        // Arrange
        let expectation = expectation(description: "global observer called")
        var callCount = 0
        
        let cancellation = observer.onChange {
            callCount += 1
            expectation.fulfill()
        }
        
        // Act
        observer.notifyChange(values: { _ in "any_value" })
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(callCount, 1)
        
        // Cleanup
        cancellation.cancel()
    }
    
    func testMultipleGlobalObservers() {
        // Arrange
        let expectation1 = expectation(description: "observer 1 called")
        let expectation2 = expectation(description: "observer 2 called")
        var callCount1 = 0
        var callCount2 = 0
        
        let cancellation1 = observer.onChange {
            callCount1 += 1
            expectation1.fulfill()
        }
        
        let cancellation2 = observer.onChange {
            callCount2 += 1
            expectation2.fulfill()
        }
        
        // Act
        observer.notifyChange(for: "test_key", newValue: "test_value")
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(callCount1, 1)
        XCTAssertEqual(callCount2, 1)
        
        // Cleanup
        cancellation1.cancel()
        cancellation2.cancel()
    }
    
    func testGlobalObserverCancellation() {
        // Arrange
        let expectation = expectation(description: "observer should not be called")
        expectation.isInverted = true
        var callCount = 0
        
        let cancellation = observer.onChange {
            callCount += 1
            expectation.fulfill()
        }
        
        // Act
        cancellation.cancel()
        observer.notifyChange(for: "test_key", newValue: "test_value")
        
        // Assert
        waitForExpectations(timeout: 0.1)
        XCTAssertEqual(callCount, 0)
    }
    
    // MARK: - Per-Key Observer Tests
    
    func testOnChangeOfKeyObserver() {
        // Arrange
        let expectation = expectation(description: "key observer called")
        var receivedValue: String?
        
        let cancellation = observer.onChangeOfKey("test_key", value: nil) { value in
            receivedValue = value
            expectation.fulfill()
        }
        
        // Act
        observer.notifyChange(for: "test_key", newValue: "new_value")
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedValue, "new_value")
        
        // Cleanup
        cancellation.cancel()
    }
    
    func testOnChangeOfKeyObserverWithInitialValue() {
        // Arrange
        let expectation = expectation(description: "key observer should not be called immediately")
        expectation.isInverted = true
        var receivedValue: String?
        
        // Act
        let cancellation = observer.onChangeOfKey("existing_key", value: "initial_value") { value in
            receivedValue = value
            expectation.fulfill()
        }
        
        // Assert - Should not be called immediately for existing value
        waitForExpectations(timeout: 0.1)
        XCTAssertNil(receivedValue) // Initial value should not trigger callback
        
        // Cleanup
        cancellation.cancel()
    }
    
    func testOnChangeOfKeyDeduplication() {
        // Arrange
        let expectation = expectation(description: "key observer called for changes")
        expectation.expectedFulfillmentCount = 2 // Should be called twice for different values
        var callCount = 0
        var receivedValues: [String?] = []
        
        let cancellation = observer.onChangeOfKey("test_key", value: "initial") { value in
            callCount += 1
            receivedValues.append(value)
            expectation.fulfill()
        }
        
        // Act - Notify with same value multiple times, then different value
        observer.notifyChange(values: { key in
            key == "test_key" ? "same_value" : nil
        })
        observer.notifyChange(values: { key in
            key == "test_key" ? "same_value" : nil
        })
        observer.notifyChange(values: { key in
            key == "test_key" ? "different_value" : nil
        })
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(callCount, 2) // Should be called twice: once for "same_value", once for "different_value"
        XCTAssertEqual(receivedValues, ["same_value", "different_value"])
        
        // Cleanup
        cancellation.cancel()
    }
    
    func testOnChangeOfKeySpecificChange() {
        // Arrange
        let expectation = expectation(description: "key observer called")
        var receivedValue: String?
        
        let cancellation = observer.onChangeOfKey("specific_key", value: nil) { value in
            receivedValue = value
            expectation.fulfill()
        }
        
        // Act - Notify specific key change
        observer.notifyChange(for: "specific_key", newValue: "specific_value")
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedValue, "specific_value")
        
        // Cleanup
        cancellation.cancel()
    }
    
    func testOnChangeOfKeyDoesNotTriggerForOtherKeys() {
        // Arrange
        let expectation = expectation(description: "observer should not be called")
        expectation.isInverted = true
        var callCount = 0
        
        let cancellation = observer.onChangeOfKey("target_key", value: nil) { _ in
            callCount += 1
            expectation.fulfill()
        }
        
        // Act - Notify different key
        observer.notifyChange(for: "other_key", newValue: "some_value")
        
        // Assert
        waitForExpectations(timeout: 0.1)
        XCTAssertEqual(callCount, 0)
        
        // Cleanup
        cancellation.cancel()
    }
    
    func testOnChangeOfKeyCancellation() {
        // Arrange
        let expectation = expectation(description: "observer should not be called")
        expectation.isInverted = true
        var callCount = 0
        
        let cancellation = observer.onChangeOfKey("test_key", value: nil) { _ in
            callCount += 1
            expectation.fulfill()
        }
        
        // Act
        cancellation.cancel()
        observer.notifyChange(for: "test_key", newValue: "value")
        
        // Assert
        waitForExpectations(timeout: 0.1)
        XCTAssertEqual(callCount, 0)
    }
    
    // MARK: - Integration with InMemoryConfigStore Tests
    
    func testIntegrationWithInMemoryStore() {
        // Arrange
        let expectation = expectation(description: "store change observer called")
        var receivedValue: String?
        
        let cancellation = store.onChangeOfKey("integration_key") { value in
            receivedValue = value
            expectation.fulfill()
        }
        
        // Act
        try? store.set("integration_value", for: "integration_key")
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedValue, "integration_value")
        
        // Cleanup
        cancellation?.cancel()
    }
    
    func testIntegrationWithInMemoryStoreGlobalChange() {
        // Arrange
        let expectation = expectation(description: "global store change observer called")
        var callCount = 0
        
        let cancellation = store.onChange {
            callCount += 1
            expectation.fulfill()
        }
        
        // Act
        try? store.set("any_value", for: "any_key")
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(callCount, 1)
        
        // Cleanup
        cancellation?.cancel()
    }
    
    func testIntegrationWithInMemoryStoreRemoveAll() {
        // Arrange
        store.values = ["key1": "value1", "key2": "value2"]
        
        let expectation1 = expectation(description: "key1 observer called")
        let expectation2 = expectation(description: "key2 observer called")
        var receivedValue1: String?
        var receivedValue2: String?
        
        let cancellation1 = store.onChangeOfKey("key1") { value in
            receivedValue1 = value
            expectation1.fulfill()
        }
        
        let cancellation2 = store.onChangeOfKey("key2") { value in
            receivedValue2 = value
            expectation2.fulfill()
        }
        
        // Act
        try? store.removeAll()
        
        // Assert
        waitForExpectations(timeout: 1.0)
        XCTAssertNil(receivedValue1)
        XCTAssertNil(receivedValue2)
        
        // Cleanup
        cancellation1?.cancel()
        cancellation2?.cancel()
    }
    
    // MARK: - Thread Safety Tests
    
    func testThreadSafety() {
        // Arrange
        let registrationExpectation = expectation(description: "registrations complete")
        let notificationExpectation = expectation(description: "notifications complete")
        registrationExpectation.expectedFulfillmentCount = 5
        notificationExpectation.expectedFulfillmentCount = 5
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        @Locked var cancellations: [Cancellation] = []
        
        // Act - Perform concurrent registrations
        for _ in 0..<5 {
            queue.async {
                let cancellation = self.observer.onChange {
                    // Observer callback
                }
                cancellations.append(cancellation)
                registrationExpectation.fulfill()
            }
        }
        
        // Wait for registrations to complete
        wait(for: [registrationExpectation], timeout: 1.0)
        
        // Now perform notifications
        for i in 0..<5 {
            queue.async {
                self.observer.notifyChange(for: "concurrent_key_\(i)", newValue: "value_\(i)")
                notificationExpectation.fulfill()
            }
        }
        
        // Assert
        wait(for: [notificationExpectation], timeout: 1.0)
        
        // Cleanup
        cancellations.forEach { $0.cancel() }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() {
        // Arrange
        weak var weakObserver: ConfigStoreObserver?
        var cancellations: [Cancellation] = []
        
        autoreleasepool {
            let localObserver = ConfigStoreObserver()
            weakObserver = localObserver
            
            // Add observers
            for i in 0..<5 {
                let cancellation = localObserver.onChange {
                    // Observer callback
                }
                cancellations.append(cancellation)
                
                let keyCancellation = localObserver.onChangeOfKey("key_\(i)", value: nil) { _ in
                    // Key observer callback
                }
                cancellations.append(keyCancellation)
            }
        }
        
        // Act - Cancel all observers
        cancellations.forEach { $0.cancel() }
        
        // Assert - Observer should be deallocated
        XCTAssertNil(weakObserver, "ConfigStoreObserver should be deallocated when no strong references remain")
    }
}
