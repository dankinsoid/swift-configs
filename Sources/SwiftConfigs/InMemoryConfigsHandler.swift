import Foundation

@available(*, deprecated, renamed: "InMemoryConfigsHandler")
public typealias MockRemoteConfigsHandler = InMemoryConfigsHandler

/// Configuration handler that stores values in memory for testing and caching
public final class InMemoryConfigsHandler: ConfigsHandler {

    /// All configuration values stored in memory
    public var values: [String: String] {
        get {
            lock.withReaderLock { _values }
        }
        set {
            lock.withWriterLockVoid {
                _values = newValue
                observers.values.forEach { $0() }
            }
        }
    }
	
	/// Shared in-memory configuration handler instance
	public static let shared = InMemoryConfigsHandler()

    private var observers: [UUID: () -> Void] = [:]
    private var _values: [String: String]
    private let lock = ReadWriteLock()

    /// Creates an in-memory configuration handler
    /// - Parameter values: Initial configuration values
    public init(_ values: [String: String] = [:]) {
        _values = values
    }

    /// Retrieves a value from memory
    public func value(for key: String) -> String? {
        values[key]
    }

    /// In-memory values are always available, no fetching required
    public func fetch(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    /// Returns all keys stored in memory
    public func allKeys() -> Set<String>? {
        Set(lock.withReaderLock { _values.keys })
    }
	
	/// In-memory handler supports writing operations
	public var supportWriting: Bool {
		true
	}

    /// Writes a value to memory
    public func writeValue(_ value: String?, for key: String) throws {
        lock.withWriterLock {
            _values[key] = value
            return observers.values
        }
        .forEach { $0() }
    }

    /// Clears all values from memory
    public func clear() throws {
        lock.withWriterLock {
            _values = [:]
            return observers.values
        }
        .forEach { $0() }
    }

    /// Registers a listener for in-memory value changes
    public func listen(_ observer: @escaping () -> Void) -> ConfigsCancellation? {
        let id = UUID()
        lock.withWriterLockVoid {
            observers[id] = observer
        }
        return ConfigsCancellation { [weak self] in
            self?.lock.withWriterLockVoid {
                self?.observers.removeValue(forKey: id)
            }
        }
    }
}

extension ConfigsHandler where Self == InMemoryConfigsHandler {

	/// Returns a shared in-memory configuration handler
	public static var inMemory: InMemoryConfigsHandler {
		InMemoryConfigsHandler.shared
	}

	/// Creates an in-memory configuration handler with initial values
	/// - Parameter values: Initial configuration values
	public static func inMemory(_ values: [String: String] = [:]) -> InMemoryConfigsHandler {
		InMemoryConfigsHandler(values)
	}
}
