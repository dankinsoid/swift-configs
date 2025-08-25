import Foundation

@available(*, deprecated, renamed: "InMemoryConfigStore")
public typealias MockRemoteConfigStore = InMemoryConfigStore

/// Configuration store that stores values in memory for testing and caching
public final class InMemoryConfigStore: ConfigStore {

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
	
	/// Shared in-memory configuration store instance
	public static let shared = InMemoryConfigStore()

    private var observers: [UUID: () -> Void] = [:]
    private var _values: [String: String]
    private let lock = ReadWriteLock()

    /// Creates an in-memory configuration store
    /// - Parameter values: Initial configuration values
    public init(_ values: [String: String] = [:]) {
        _values = values
    }

    /// Retrieves a value from memory
    public func get(_ key: String) -> String? {
        values[key]
    }

    /// In-memory values are always available, no fetching required
    public func fetch(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    /// Returns all keys stored in memory
    public func keys() -> Set<String>? {
        Set(lock.withReaderLock { _values.keys })
    }
    
    public func exists(_ key: String) -> Bool {
        lock.withReaderLock { _values[key] != nil }
    }
	
	/// In-memory store supports writing operations
	public var isWritable: Bool {
		true
	}

    /// Writes a value to memory
    public func set(_ value: String?, for key: String) throws {
        lock.withWriterLock {
            _values[key] = value
            return observers.values
        }
        .forEach { $0() }
    }

    /// Clears all values from memory
    public func removeAll() throws {
        lock.withWriterLock {
            _values = [:]
            return observers.values
        }
        .forEach { $0() }
    }

    /// Registers a listener for in-memory value changes
    public func onChange(_ observer: @escaping () -> Void) -> Cancellation? {
        let id = UUID()
        lock.withWriterLockVoid {
            observers[id] = observer
        }
        return Cancellation { [weak self] in
            self?.lock.withWriterLockVoid {
                self?.observers.removeValue(forKey: id)
            }
        }
    }
}

extension ConfigStore where Self == InMemoryConfigStore {

	/// Returns a shared in-memory configuration store
	public static var inMemory: InMemoryConfigStore {
		InMemoryConfigStore.shared
	}

	/// Creates an in-memory configuration store with initial values
	/// - Parameter values: Initial configuration values
	public static func inMemory(_ values: [String: String] = [:]) -> InMemoryConfigStore {
		InMemoryConfigStore(values)
	}
}
