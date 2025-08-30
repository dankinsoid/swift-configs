import Foundation

extension ConfigKey {

    /// Creates a migration key that handles transitioning from an old key to a new one
    /// - Parameters:
    ///   - oldKey: The old configuration key to migrate from
    ///   - newKey: The new configuration key to migrate to
    ///   - firstReadPolicy: Policy for what to do on first read of old value
    ///   - migrate: Function to transform the old value to the new value type
    public static func migration<OldValue, OldP: KeyAccess>(
        from oldKey: ConfigKey<OldValue, OldP>,
        to newKey: Self,
        firstReadPolicy: MigrationFirstReadPolicy = .default,
        migrate: @escaping (OldValue) -> Value
    ) -> Self {
        Self.init(newKey.name) { registry in
            if newKey.exists(registry: registry) || !oldKey.exists(registry: registry) {
                return newKey.get(registry: registry)
            } else {
                let value = migrate(oldKey.get(registry: registry))
                if firstReadPolicy.contains(.writeToNew), Access.isWritable {
                    newKey.set(registry: registry, value)
                }
                if firstReadPolicy.contains(.removeOld), OldP.isWritable {
                    oldKey.remove(registry: registry)
                }
                return value
            }
        } set: { registry, newValue in
            newKey.set(registry: registry, newValue)
        } remove: { registry in
            oldKey.remove(registry: registry)
            newKey.remove(registry: registry)
        } exists: { registry in
            oldKey.exists(registry: registry) || newKey.exists(registry: registry)
        } onChange: { registry, observer in
            newKey.onChange(registry: registry, observer)
        }
    }

    /// Creates a migration key using key paths
    public static func migration<OldValue, OldP: KeyAccess>(
        from oldKey: KeyPath<Configs.Keys, ConfigKey<OldValue, OldP>>,
        to newKey: KeyPath<Configs.Keys, Self>,
        firstReadPolicy: MigrationFirstReadPolicy = .default,
        migrate: @escaping (OldValue) -> Value
    ) -> Self {
        migration(from: Configs.Keys()[keyPath: oldKey], to: Configs.Keys()[keyPath: newKey], firstReadPolicy: firstReadPolicy, migrate: migrate)
    }
    
    /// Creates a migration key for same-type values (no transformation needed)
    public static func migration<OldP: KeyAccess>(
        from oldKey: ConfigKey<Value, OldP>,
        to newKey: Self,
        firstReadPolicy: MigrationFirstReadPolicy = .default
    ) -> Self {
        migration(from: oldKey, to: newKey, firstReadPolicy: firstReadPolicy, migrate: { $0 })
    }
    
    /// Creates a migration key using key paths for same-type values
    public static func migration<OldP: KeyAccess>(
        from oldKey: KeyPath<Configs.Keys, ConfigKey<Value, OldP>>,
        to newKey: KeyPath<Configs.Keys, Self>,
        firstReadPolicy: MigrationFirstReadPolicy = .default
    ) -> Self {
        migration(from: oldKey, to: newKey, firstReadPolicy: firstReadPolicy, migrate: { $0 })
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

    /// Default policy: write to new key and delete old key
    public static let `default`: MigrationFirstReadPolicy = [.writeToNew, .removeOld]
}
