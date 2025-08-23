import Foundation

extension Configs.Keys.Key {

    /// Creates a migration key that handles transitioning from an old key to a new one
    /// - Parameters:
    ///   - oldKey: The old configuration key to migrate from
    ///   - newKey: The new configuration key to migrate to
    ///   - firstReadPolicy: Policy for what to do on first read of old value
    ///   - migrate: Function to transform the old value to the new value type
    public static func migraion<OldValue, OldP: ConfigKeyPermission>(
        from oldKey: Configs.Keys.Key<OldValue, OldP>,
        to newKey: Self,
        firstReadPolicy: MigrationFirstReadPolicy = .default,
        migrate: @escaping (OldValue) -> Value
    ) -> Self {
        Self.init(newKey.name) { handler in
            if newKey.exists(handler: handler) || !oldKey.exists(handler: handler) {
                return newKey.get(handler: handler)
            } else {
                let value = migrate(oldKey.get(handler: handler))
                if firstReadPolicy.contains(.writeToNew), Permission.supportWriting {
                    newKey.set(handler: handler, value)
                }
                if firstReadPolicy.contains(.removeOld), OldP.supportWriting {
                    try? oldKey.remove(handler: handler)
                }
                return value
            }
        } set: { handler, newValue in
            newKey.set(handler: handler, newValue)
        } remove: { hanlder in
            do {
                try oldKey.remove(handler: hanlder)
            } catch {
                try newKey.remove(handler: hanlder)
                throw error
            }
            try newKey.remove(handler: hanlder)
        } exists: { handler in
            oldKey.exists(handler: handler) || newKey.exists(handler: handler)
        } listen: { handler, observer in
            newKey.listen(handler: handler, observer)
        }
    }

    /// Creates a migration key using key paths
    public static func migraion<OldValue, OldP: ConfigKeyPermission>(
        from oldKey: KeyPath<Configs.Keys, Configs.Keys.Key<OldValue, OldP>>,
        to newKey: KeyPath<Configs.Keys, Self>,
        firstReadPolicy: MigrationFirstReadPolicy = .default,
        migrate: @escaping (OldValue) -> Value
    ) -> Self {
        migraion(from: Configs.Keys()[keyPath: oldKey], to: Configs.Keys()[keyPath: newKey], firstReadPolicy: firstReadPolicy, migrate: migrate)
    }
    
    /// Creates a migration key for same-type values (no transformation needed)
    public static func migraion<OldP: ConfigKeyPermission>(
        from oldKey: Configs.Keys.Key<Value, OldP>,
        to newKey: Self,
        firstReadPolicy: MigrationFirstReadPolicy = .default
    ) -> Self {
        migraion(from: oldKey, to: newKey, firstReadPolicy: firstReadPolicy, migrate: { $0 })
    }
    
    /// Creates a migration key using key paths for same-type values
    public static func migraion<OldP: ConfigKeyPermission>(
        from oldKey: KeyPath<Configs.Keys, Configs.Keys.Key<Value, OldP>>,
        to newKey: KeyPath<Configs.Keys, Self>,
        firstReadPolicy: MigrationFirstReadPolicy = .default
    ) -> Self {
        migraion(from: oldKey, to: newKey, firstReadPolicy: firstReadPolicy, migrate: { $0 })
    }
}

/// Policy options for handling the first read during migration
public struct MigrationFirstReadPolicy: OptionSet, Hashable, CaseIterable {

    public var rawValue: UInt8

    /// Creates a migration policy with the specified raw value
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// All possible migration policy combinations
    public static var allCases: [MigrationFirstReadPolicy] {
        [.writeToNew, .removeOld, [], [.removeOld, .writeToNew]]
    }

    /// Write the migrated value to the new key location
    public static let writeToNew = MigrationFirstReadPolicy(rawValue: 1 << 0)
    /// Remove the old key after successful migration
    public static let removeOld = MigrationFirstReadPolicy(rawValue: 1 << 1)

    /// Default policy: write to new key and remove old key
    public static let `default`: MigrationFirstReadPolicy = [.writeToNew, .removeOld]
}
