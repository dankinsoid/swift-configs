import Foundation

/// Configuration store that coordinates operations across multiple stores
///
/// This store implements a layered configuration system where values are read from the first
/// store that contains them, but writes are applied to all stores. This enables patterns like:
///
/// - **Fallback Chains**: Check remote configs first, then local defaults
/// - **Write-Through Caching**: Write to both cache and persistent storage
/// - **Multi-Source Configuration**: Combine environment variables, UserDefaults, and remote configs
///
/// ## Read Behavior
///
/// Values are read from stores in order until one returns a non-nil value.
/// If all stores return nil, the multiplex store returns nil.
///
/// ## Write Behavior  
///
/// Write operations are sent to all stores. If any store fails, the error is collected
/// and all errors are either returned individually or wrapped in a `Errors` object.
///
/// ## Example
///
/// ```swift
/// let multiplexStore = MultiplexConfigStore(
///     .environment,           // Check environment variables first
///     .userDefaults,         // Then UserDefaults
///     .inMemory(["key": "fallback"])  // Finally in-memory defaults
/// )
/// 
/// ConfigSystem.bootstrap([.default: multiplexStore])
/// ```
public struct MultiplexConfigStore: ConfigStore {
    private let stores: [ConfigStore]

    /// Creates a multiplex store with an array of stores
    ///
    /// - Parameter stores: The stores to multiplex, in priority order for reads
    /// - Note: Stores are queried in order for reads, but all receive writes
    public init(stores: [ConfigStore]) {
        self.stores = stores
    }

    /// Creates a multiplex store with variadic stores
    ///
    /// - Parameter stores: The stores to multiplex, in priority order for reads
    /// - Note: Stores are queried in order for reads, but all receive writes
    public init(_ stores: ConfigStore...) {
        self.init(stores: stores)
    }

    /// Retrieves value from the first store that contains the key
    public func get(_ key: String) throws -> String? {
        var errors: [Error] = []
        for store in stores {
            do {
                if let value = try store.get(key) {
                    return value
                }
            } catch {
                errors.append(error)
            }
        }
        if !errors.isEmpty {
            throw errors.count == 1 ? errors[0] : Errors(errors: errors)
        }
        return nil
    }

    /// Fetches from all stores concurrently and completes when all finish
    ///
    /// - Parameter completion: Called when all stores complete, with collected errors if any
    /// - Note: Fetches from all stores in parallel for best performance
    public func fetch(completion: @escaping (Error?) -> Void) {
        let multiplexCompletion = MultiplexCompletion(count: stores.count, completion: completion)
        for store in stores {
            store.fetch { error in
                multiplexCompletion.call(with: error)
            }
        }
    }

    public func exists(_ key: String) throws -> Bool {
        var errors: [Error] = []
        for store in stores {
            do {
                if try store.exists(key) {
                    return true
                }
            } catch {
                errors.append(error)
            }
        }
        if !errors.isEmpty {
            throw errors.count == 1 ? errors[0] : Errors(errors: errors)
        }
        return false
    }
    
    /// Registers change listeners on all stores that support them
    ///
    /// - Parameter listener: Called when any store reports a configuration change
    /// - Returns: Cancellation token that stops all listeners, or `nil` if no stores support listening
    /// - Note: The listener may be called multiple times for a single logical change
    public func onChange(_ listener: @escaping () -> Void) -> Cancellation {
        let cancellables = stores.map { $0.onChange(listener) }
        return Cancellation {
            cancellables.forEach { $0.cancel() }
        }
    }
    
    public func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation {
        let cancellables = stores.map { $0.onChangeOfKey(key, listener) }
        return Cancellation {
            cancellables.forEach { $0.cancel() }
        }
    }

    /// Returns the union of all keys from all stores
    ///
    /// - Returns: Combined set of all keys across stores, or `nil` if no store supports key enumeration
    /// - Warning: If any store returns `nil` for keys, the entire result is `nil`
    public func keys() -> Set<String>? {
        var allKeys: Set<String> = []
        for store in stores {
            if let keys = store.keys() {
                allKeys.formUnion(keys)
            } else {
                return nil
            }
        }
        return allKeys
    }

	public var isWritable: Bool {
		stores.contains(where: \.isWritable)
	}

    /// Writes to all stores, collecting and throwing any errors
    ///
    /// - Parameters:
    ///   - value: The value to store, or `nil` to remove
    ///   - key: The configuration key
    /// - Throws: Individual error if only one store fails, or `Errors` if multiple stores fail
    public func set(_ value: String?, for key: String) throws {
        var errors: [Error] = []
        for store in stores {
            do {
                try store.set(value, for: key)
            } catch {
                errors.append(error)
            }
        }
        if !errors.isEmpty {
            throw errors.count == 1 ? errors[0] : Errors(errors: errors)
        }
    }

    /// Removes all values from all stores
    ///
    /// - Throws: Individual error if only one store fails, or `Errors` if multiple stores fail
    /// - Warning: This operation cannot be undone and affects all underlying stores
    public func removeAll() throws {
        var errors: [Error] = []
        for store in stores {
            do {
                try store.removeAll()
            } catch {
                errors.append(error)
            }
        }
        if !errors.isEmpty {
            throw errors.count == 1 ? errors[0] : Errors(errors: errors)
        }
    }

    /// Error type that wraps multiple errors from different stores
    ///
    /// This error is thrown when operations affect multiple stores and more than one fails.
    /// Individual store errors are preserved in the `errors` array.
    public struct Errors: Error {
        /// The collection of errors from different stores
        ///
        /// Each error corresponds to a failure in one of the underlying stores.
        /// The order matches the order of stores in the multiplex configuration.
        public let errors: [Error?]
    }
}

final class MultiplexCompletion {
    let lock = ReadWriteLock()
    var count: Int
    var errors: [Error?] = []
    let completion: (Error?) -> Void

    init(count: Int, completion: @escaping (Error?) -> Void) {
        self.completion = completion
        self.count = count
    }

    func call(with error: Error?) {
        lock.withWriterLock {
            count -= 1
            if let error {
                self.errors.append(error)
            }
        }
        let (isLast, errors) = lock.withReaderLock { (count == 0, self.errors) }
        if isLast {
            let error: Error?
            switch errors.count {
            case 0: error = nil
            case 1: error = errors[0]
            default: error = MultiplexConfigStore.Errors(errors: errors)
            }
            completion(error)
        }
    }
}

public extension ConfigStore where Self == MultiplexConfigStore {
    /// Creates a multiplex configuration store from an array of stores
    ///
    /// - Parameter stores: The stores to multiplex, in priority order for reads
    /// - Returns: A multiplex store that coordinates operations across all stores
    static func multiple(_ stores: [ConfigStore]) -> MultiplexConfigStore {
        MultiplexConfigStore(stores: stores)
    }

    /// Creates a multiplex configuration store from variadic stores
    ///
    /// - Parameter stores: The stores to multiplex, in priority order for reads
    /// - Returns: A multiplex store that coordinates operations across all stores
    static func multiple(_ stores: ConfigStore...) -> MultiplexConfigStore {
        MultiplexConfigStore(stores: stores)
    }
}
