import Foundation

extension ConfigKey {

    /// Returns a new configuration key with the specified prefix applied to the key name
    ///
    /// This method enables manual key prefixing when namespace-based prefixing isn't suitable.
    /// The prefix is prepended directly to the key name, and all operations (get, set, exists, etc.)
    /// are performed using the prefixed key.
    ///
    /// ```swift
    /// let userKey = RWConfigKey<String>("username", in: .default, default: "")
    /// let prefixedKey = userKey.prefix("feature/")
    /// // prefixedKey operates on "feature/username"
    /// 
    /// let value = configs.get(prefixedKey)  // Reads from "feature/username"
    /// ```
    ///
    /// - Parameter prefix: The string to prepend to the key name
    /// - Returns: A new configuration key that operates with the prefixed name
    /// - Note: This creates a completely independent key; changes to the prefixed key
    ///   don't affect the original key and vice versa
    public func prefix(_ prefix: String) -> ConfigKey {
        ConfigKey(prefix + name) { registry in
            get(registry: PrefixedRegistry(prefix, base: registry))
        } set: { registry, value in
            set(registry: PrefixedRegistry(prefix, base: registry), value)
        } remove: { registry in
            remove(registry: PrefixedRegistry(prefix, base: registry))
        } exists: { registry in
            exists(registry: PrefixedRegistry(prefix, base: registry))
        } onChange: { registry, observer in
            onChange(registry: PrefixedRegistry(prefix, base: registry), observer)
        }
    }
}

private struct PrefixedRegistry: StoreRegistryType {

    let prefix: String
    let base: StoreRegistryType
    var stores: [ConfigCategory: ConfigStore] {
        base.stores.mapValues { PrefixConfigStore(prefix: prefix, store: $0) }
    }

    init(_ prefix: String, base: StoreRegistryType) {
        self.prefix = prefix
        self.base = base
    }
    
    func store(for category: ConfigCategory?) -> any ConfigStore {
        .prefix(prefix, store: base.store(for: category))
    }
    
    
    func fetch(completion: @escaping ((any Error)?) -> Void) {
        base.fetch(completion: completion)
    }
    
    func onChange(_ observer: @escaping () -> Void) -> Cancellation {
        base.onChange(observer)
    }
}
