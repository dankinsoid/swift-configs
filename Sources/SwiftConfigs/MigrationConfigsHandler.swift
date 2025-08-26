import Foundation

/// A ConfigStore that reads from a specified store first, then falls back to the write store, but only writes to the write store
public struct MigrationConfigStore: ConfigStore {

    public let fallbackStore: ConfigStore
    public let mainStore: ConfigStore

    /// Creates a migration store that reads from readStore first, then writeStore, but only writes to writeStore
    /// - Parameters:
    ///   - mainStore: The primary store to read from
    ///   - fallbackStore: The store to write to and use as migration for reads
    public init(mainStore: ConfigStore, fallbackStore: ConfigStore) {
        self.mainStore = mainStore
        self.fallbackStore = fallbackStore
    }

    public func get(_ key: String) throws -> String? {
        // Try the read store first, then fall back to the write store
        if let value = try mainStore.get(key) {
            return value
        }
        return try fallbackStore.get(key)
    }
    
    public func exists(_ key: String) throws -> Bool {
        try mainStore.exists(key) || fallbackStore.exists(key)
    }

    public func fetch(completion: @escaping (Error?) -> Void) {
        // Fetch from both stores
        let multiplexCompletion = MultiplexCompletion(count: 2, completion: completion)

		mainStore.fetch { error in
            multiplexCompletion.call(with: error)
        }

		fallbackStore.fetch { error in
            multiplexCompletion.call(with: error)
        }
    }

    public func onChange(_ listener: @escaping () -> Void) -> Cancellation? {
        // Listen to both stores
        let mainCancellation = mainStore.onChange(listener)
        let fallbackCancellation = fallbackStore.onChange(listener)

        let cancellables = [mainCancellation, fallbackCancellation].compactMap { $0 }

        return cancellables.isEmpty ? nil : Cancellation {
            cancellables.forEach { $0.cancel() }
        }
    }

    public func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation? {
        // Listen to both stores
        let mainCancellation = mainStore.onChangeOfKey(key, listener)
        let fallbackCancellation = fallbackStore.onChangeOfKey(key, listener)

        let cancellables = [mainCancellation, fallbackCancellation].compactMap { $0 }

        return cancellables.isEmpty ? nil : Cancellation {
            cancellables.forEach { $0.cancel() }
        }
    }

    public func keys() -> Set<String>? {
		if let keys = mainStore.keys() {
			return keys.union(fallbackStore.keys() ?? [])
		} else {
			return fallbackStore.keys()
		}
    }
	
	public var isWritable: Bool {
		mainStore.isWritable || fallbackStore.isWritable
	}

    public func set(_ value: String?, for key: String) throws {
		if mainStore.isWritable {
			try mainStore.set(value, for: key)
		}
    }

    public func removeAll() throws {
		do {
			try mainStore.removeAll()
		} catch {
			try fallbackStore.removeAll()
			throw error
		}
		try fallbackStore.removeAll()
    }
}

public extension ConfigStore where Self == MigrationConfigStore {

    /// Creates a migration configs store that reads from readStore first, then writeStore, but only writes to writeStore
    /// - Parameters:
    ///   - mainStore: The primary store to read from
    ///   - fallbackStore: The store to write to and use as migration for reads
    static func migration(from mainStore: ConfigStore, to fallbackStore: ConfigStore) -> MigrationConfigStore {
        MigrationConfigStore(mainStore: mainStore, fallbackStore: fallbackStore)
    }
}
