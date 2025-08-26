import Foundation

/// Configuration store that stores values in memory for testing and caching
public final class InMemoryConfigStore: ConfigStore {

    /// All configuration values stored in memory
    public var values: [String: String] {
        get {
            lock.withReaderLock { _values }
        }
        set {
            let newValues = lock.withWriterLock {
                _values = newValue
                return _values
            }
            listenHelper.notifyChange { newValues[$0] }
        }
    }
	
	/// Shared in-memory configuration store instance
	public static let shared = InMemoryConfigStore()

    private var _values: [String: String]
    private let lock = ReadWriteLock()
    private let listenHelper = ConfigStoreListeningHelper()

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
        }
        listenHelper.notifyChange(for: key, newValue: value)
    }

    /// Clears all values from memory
    public func removeAll() throws {
        lock.withWriterLock {
            _values = [:]
        }
        listenHelper.notifyChange { _ in nil }
    }

    /// Registers a listener for in-memory value changes
    public func onChange(_ observer: @escaping () -> Void) -> Cancellation? {
        listenHelper.onChange(observer)
    }

    /// Registers a listener for changes to a specific key
    public func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation? {
        listenHelper.onChangeOfKey(key, value: values[key], listener)
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
