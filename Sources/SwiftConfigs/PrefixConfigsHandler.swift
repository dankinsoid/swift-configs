import Foundation

/// A ConfigStore that wraps another store and adds a prefix to all keys
public struct PrefixConfigStore: ConfigStore {
    private let underlyingStore: ConfigStore
    private let prefix: String
    
    /// Creates a prefix store that adds a prefix to all keys
    /// - Parameters:
    ///   - prefix: The prefix to add to all keys
    ///   - store: The underlying store to wrap
    public init(prefix: String, store: ConfigStore) {
        self.prefix = prefix
        self.underlyingStore = store
    }
    
    private func prefixedKey(_ key: String) -> String {
        return prefix + key
    }
    
    private func unprefixedKey(_ prefixedKey: String) -> String? {
        guard prefixedKey.hasPrefix(prefix) else { return nil }
        return String(prefixedKey.dropFirst(prefix.count))
    }
    
    public func get(_ key: String) throws -> String? {
        try underlyingStore.get(prefixedKey(key))
    }
    
    public func exists(_ key: String) throws -> Bool {
        try underlyingStore.exists(prefixedKey(key))
    }
    
    public func fetch(completion: @escaping (Error?) -> Void) {
        underlyingStore.fetch(completion: completion)
    }
    
    public func onChange(_ listener: @escaping () -> Void) -> Cancellation {
        underlyingStore.onChange(listener)
    }
    
    public func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation {
        underlyingStore.onChangeOfKey(prefixedKey(key), listener)
    }
    
    public func set(_ value: String?, for key: String) throws {
        try underlyingStore.set(value, for: prefixedKey(key))
    }
    
    public func removeAll() throws {
        // Only clear keys with our prefix
        guard let keys = underlyingStore.keys() else {
            throw Unsupported()
        }
        
        for key in keys where key.hasPrefix(prefix) {
            try underlyingStore.set(nil, for: key)
        }
    }
    
    public func keys() -> Set<String>? {
        guard let keys = underlyingStore.keys() else { return nil }
        
        return Set(keys.compactMap { prefixedKey in
            unprefixedKey(prefixedKey)
        })
    }
    
    public var isWritable: Bool {
        return underlyingStore.isWritable
    }
}

public extension ConfigStore where Self == PrefixConfigStore {

    /// Creates a prefix configs store that adds a prefix to all keys
    /// - Parameters:
    ///   - prefix: The prefix to add to all keys
    ///   - store: The underlying store to wrap
    static func prefix(_ prefix: String, store: ConfigStore) -> PrefixConfigStore {
        PrefixConfigStore(prefix: prefix, store: store)
    }
}
