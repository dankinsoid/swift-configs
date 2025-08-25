import Foundation

/// Configuration store that multiplexes operations across multiple stores
public struct MultiplexConfigStore: ConfigStore {
    private let stores: [ConfigStore]

    /// Creates a multiplex store with an array of stores
    public init(stores: [ConfigStore]) {
        self.stores = stores
    }

    /// Creates a multiplex store with variadic stores
    public init(_ stores: ConfigStore...) {
        self.init(stores: stores)
    }

    /// Retrieves value from the first store that has it
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

    /// Fetches from all stores and completes when all are done
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
    
    /// Registers listeners on all stores
    public func onChange(_ listener: @escaping () -> Void) -> Cancellation? {
        let cancellables = stores.compactMap { $0.onChange(listener) }
        return cancellables.isEmpty ? nil : Cancellation {
            cancellables.forEach { $0.cancel() }
        }
    }

    /// Returns union of keys from all stores
    public func keys() -> Set<String>? {
        stores.reduce(into: Set<String>?.none) { result, store in
            if let keys = store.keys() {
                if result == nil {
                    result = []
                }
                result?.formUnion(keys)
            }
        }
    }
	
	/// Supports writing if any store supports it
	public var isWritable: Bool {
		stores.contains(where: \.isWritable)
	}

    /// Writes to all stores, collecting any errors
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

    /// Clears all stores, collecting any errors
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

    /// Error type that wraps multiple errors from stores
    public struct Errors: Error {
        /// The collection of errors from different stores
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
    /// Creates a multiplex configuration store with an array of stores
    static func multiple(_ stores: [ConfigStore]) -> MultiplexConfigStore {
        MultiplexConfigStore(stores: stores)
    }

    /// Creates a multiplex configuration store with variadic stores
    static func multiple(_ stores: ConfigStore...) -> MultiplexConfigStore {
        MultiplexConfigStore(stores: stores)
    }
}
