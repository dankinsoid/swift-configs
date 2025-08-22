import Foundation

extension ConfigKey {
    
    /// Creates a migration key that handles transitioning from an old key to a new one
    /// - Parameters:
    ///   - oldKey: The old configuration key to migrate from
    ///   - newKey: The new configuration key to migrate to
    ///   - firstReadPolicy: Policy for what to do on first read of old value
    ///   - migrate: Function to transform the old value to the new value type
    public static func migraion<Old: ConfigKey, New: ConfigKey<Value>>(
        from oldKey: Old,
        to newKey: New,
        firstReadPolicy: MigrationFirstReadPolicy = .default,
        migrate: @escaping (Old.Value) -> New.Value
    ) -> Self {
        Self.init(newKey.name) { handler in
            if newKey.exists(handler: handler) || !oldKey.exists(handler: handler) {
                return newKey.get(handler: handler)
            } else {
                let value = migrate(oldKey.get(handler: handler))
                if firstReadPolicy.contains(.writeToNew) {
                    newKey.set(handler: handler, value)
                }
                if firstReadPolicy.contains(.removeOld) {
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
    public static func migraion<Old: ConfigKey, New: ConfigKey<Value>>(
        from oldKey: KeyPath<Configs.Keys, Old>,
        to newKey: KeyPath<Configs.Keys, New>,
        firstReadPolicy: MigrationFirstReadPolicy = .default,
        migrate: @escaping (Old.Value) -> New.Value
    ) -> Self {
        migraion(from: Configs.Keys()[keyPath: oldKey], to: Configs.Keys()[keyPath: newKey], firstReadPolicy: firstReadPolicy, migrate: migrate)
    }
    
    /// Creates a migration key for same-type values (no transformation needed)
    public static func migraion<Old: ConfigKey<Value>, New: ConfigKey<Value>>(
        from oldKey: Old,
        to newKey: New,
        firstReadPolicy: MigrationFirstReadPolicy = .default
    ) -> Self {
        migraion(from: oldKey, to: newKey, firstReadPolicy: firstReadPolicy, migrate: { $0 })
    }
    
    /// Creates a migration key using key paths for same-type values
    public static func migraion<Old: ConfigKey<Value>, New: ConfigKey<Value>>(
        from oldKey: KeyPath<Configs.Keys, Old>,
        to newKey: KeyPath<Configs.Keys, New>,
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
