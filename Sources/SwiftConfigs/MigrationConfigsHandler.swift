import Foundation

/// A config store that supports **read-through migration**:
/// - **Reads**: try `newStore` first; if missing, fall back to `legacyStore`.
/// - **Writes**: write **only** to `newStore`.
/// Use this while migrating data from a legacy backend to a new one.
public struct MigrationConfigStore: ConfigStore {

    /// Target store for all writes and the primary source for reads.
    public let newStore: ConfigStore
    /// Legacy source used only as a read-through fallback.
    public let legacyStore: ConfigStore

    /// Creates a migration store that reads from `newStore` first, then falls back to `legacyStore`,
    /// and writes **only** to `newStore`.
    /// - Parameters:
    ///   - newStore: The primary store for reads and the only destination for writes.
    ///   - legacyStore: The secondary store used as a fallback source for reads.
    public init(newStore: ConfigStore, legacyStore: ConfigStore) {
        self.newStore = newStore
        self.legacyStore = legacyStore
    }

    // MARK: - Read

    public func get(_ key: String) throws -> String? {
        if let value = try newStore.get(key) {
            return value
        }
        return try legacyStore.get(key)
    }

    public func exists(_ key: String) throws -> Bool {
        try newStore.exists(key) || legacyStore.exists(key)
    }

    public func keys() -> Set<String>? {
        if let k = newStore.keys() {
            return k.union(legacyStore.keys() ?? [])
        } else {
            return legacyStore.keys()
        }
    }

    // MARK: - Fetch/Change notifications

    /// Fetch from both stores. Completion is called when **both** finish.
    public func fetch(completion: @escaping (Error?) -> Void) {
        let mux = MultiplexCompletion(count: 2, completion: completion)
        newStore.fetch { mux.call(with: $0) }
        legacyStore.fetch { mux.call(with: $0) }
    }

    /// Listen to any changes from either store.
    public func onChange(_ listener: @escaping () -> Void) -> Cancellation {
        let a = newStore.onChange(listener)
        let b = legacyStore.onChange(listener)
        let c = [a, b].compactMap { $0 }
        return Cancellation { c.forEach { $0.cancel() } }
    }

    /// Listen to changes of a particular key from either store.
    public func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation {
        let a = newStore.onChangeOfKey(key, listener)
        let b = legacyStore.onChangeOfKey(key, listener)
        let c = [a, b].compactMap { $0 }
        return Cancellation { c.forEach { $0.cancel() } }
    }

    // MARK: - Write

    /// Store capability is writable if **newStore** is writable.
    public var isWritable: Bool { newStore.isWritable }

    /// Write goes **only** to `newStore`.
    public func set(_ value: String?, for key: String) throws {
        try newStore.set(value, for: key)
    }

    /// Remove all keys from `newStore` only.
    public func removeAll() throws {
        try newStore.removeAll()
    }
}

// MARK: - Convenience factory

public extension ConfigStore where Self == MigrationConfigStore {

    /// Build a migration store that reads `new` first then falls back to `legacy`,
    /// writing only to `new`.
    static func migration(from legacy: ConfigStore, to new: ConfigStore) -> MigrationConfigStore {
        MigrationConfigStore(newStore: new, legacyStore: legacy)
    }
}
