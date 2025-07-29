import Foundation

@available(*, deprecated, renamed: "InMemoryConfigsHandler")
public typealias MockRemoteConfigsHandler = InMemoryConfigsHandler

/// In-memory ConfigsHandler for testing and caching
public final class InMemoryConfigsHandler: ConfigsHandler {
    /// The configuration values stored in memory
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

    private var observers: [UUID: () -> Void] = [:]
    private var _values: [String: String]
    private let lock = ReadWriteLock()

    /// Creates an in-memory configs handler
    /// - Parameter values: Initial configuration values
    public init(_ values: [String: String] = [:]) {
        _values = values
    }

    public func value(for key: String) -> String? {
        values[key]
    }

    /// Sets a value using a key path
    public func set<Value>(_ value: Value, for keyPath: KeyPath<Configs.Keys, Configs.Keys.Key<Value>>) where Value: CustomStringConvertible {
        values[Configs.Keys()[keyPath: keyPath].name] = value.description
    }

    public func fetch(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    public func allKeys() -> Set<String>? {
        Set(lock.withReaderLock { _values.keys })
    }

    public func writeValue(_ value: String?, for key: String) throws {
        lock.withWriterLock {
            _values[key] = value
            return observers.values
        }
        .forEach { $0() }
    }

    public func clear() throws {
        lock.withWriterLock {
            _values = [:]
            return observers.values
        }
        .forEach { $0() }
    }

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
