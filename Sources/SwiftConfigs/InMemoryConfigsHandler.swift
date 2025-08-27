import Foundation

/// Configuration store that stores values in memory
///
/// This store keeps all configuration values in RAM, making it ideal for testing,
/// temporary storage, and scenarios where persistence is not required.
///
/// ## Use Cases
///
/// - **Unit Testing**: Easily controlled configuration state
/// - **Temporary Overrides**: Runtime configuration changes that don't persist
/// - **Caching Layer**: Fast access to frequently used configuration values
/// - **Default Fallbacks**: Providing fallback values when other stores fail
///
/// ## Thread Safety
///
/// All operations are thread-safe using internal read-write locks.
///
/// ## Performance
///
/// - **Fast**: All operations are in-memory with minimal overhead
/// - **Change Notifications**: Supports efficient change observation
/// - **Memory Efficient**: Values are only stored when set
///
/// ## Example
///
/// ```swift
/// // Create store with initial values
/// let store = InMemoryConfigStore([
///     "feature_enabled": "true",
///     "api_timeout": "30"
/// ])
///
/// // Use in configuration system
/// ConfigSystem.bootstrap([.default: store])
/// ```
/// - Tip: Use `.inMemory()` shorthand to create an in-memory store
public final class InMemoryConfigStore: ConfigStore {
    /// All configuration values stored in memory
    ///
    /// - Warning: Direct modification triggers change notifications for all observers
    public var values: [String: String] {
        get {
            lock.withReaderLock { _values }
        }
        set {
            let newValues = lock.withWriterLock {
                _values = newValue
                return _values
            }
            listenHelper.notifyChange(values: { newValues[$0] })
        }
    }

    /// Shared in-memory configuration store instance
    ///
    /// - Note: Use with caution in multi-module applications to avoid unexpected state sharing
    public static let shared = InMemoryConfigStore()

    private var _values: [String: String]
    private let lock = ReadWriteLock()
    private let listenHelper = ConfigStoreObserver()

    /// Creates an in-memory configuration store
    ///
    /// - Parameter values: Initial configuration values to populate the store
    /// - Note: Changes to the passed dictionary after initialization don't affect the store
    public init(_ values: [String: String] = [:]) {
        _values = values
    }

    public func get(_ key: String) -> String? {
        values[key]
    }

    public func fetch(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    public func keys() -> Set<String>? {
        Set(lock.withReaderLock { _values.keys })
    }

    public func exists(_ key: String) -> Bool {
        lock.withReaderLock { _values[key] != nil }
    }

    public var isWritable: Bool {
        true
    }

    public func set(_ value: String?, for key: String) throws {
        lock.withWriterLock {
            _values[key] = value
        }
        listenHelper.notifyChange(for: key, newValue: value)
    }

    /// Removes all stored values
    ///
    /// - Warning: This operation cannot be undone and will notify all observers
    public func removeAll() throws {
        lock.withWriterLock {
            _values = [:]
        }
        listenHelper.notifyChange(values: { _ in nil })
    }

    public func onChange(_ observer: @escaping () -> Void) -> Cancellation {
        listenHelper.onChange(observer)
    }

    public func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation {
        listenHelper.onChangeOfKey(key, value: values[key], listener)
    }
}

public extension ConfigStore where Self == InMemoryConfigStore {
    /// Shared in-memory configuration store
    static var inMemory: InMemoryConfigStore {
        InMemoryConfigStore.shared
    }

    /// Creates a new in-memory configuration store with initial values
    ///
    /// - Parameter values: Initial configuration values to populate the store
    /// - Returns: A new store instance independent from the shared store
    static func inMemory(_ values: [String: String] = [:]) -> InMemoryConfigStore {
        InMemoryConfigStore(values)
    }
}
