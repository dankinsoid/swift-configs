import Foundation

extension ConfigKey {
    
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

    public static func migraion<Old: ConfigKey, New: ConfigKey<Value>>(
        from oldKey: KeyPath<Configs.Keys, Old>,
        to newKey: KeyPath<Configs.Keys, New>,
        firstReadPolicy: MigrationFirstReadPolicy = .default,
        migrate: @escaping (Old.Value) -> New.Value
    ) -> Self {
        migraion(from: Configs.Keys()[keyPath: oldKey], to: Configs.Keys()[keyPath: newKey], firstReadPolicy: firstReadPolicy, migrate: migrate)
    }
    
    public static func migraion<Old: ConfigKey<Value>, New: ConfigKey<Value>>(
        from oldKey: Old,
        to newKey: New,
        firstReadPolicy: MigrationFirstReadPolicy = .default
    ) -> Self {
        migraion(from: oldKey, to: newKey, firstReadPolicy: firstReadPolicy, migrate: { $0 })
    }
    
    public static func migraion<Old: ConfigKey<Value>, New: ConfigKey<Value>>(
        from oldKey: KeyPath<Configs.Keys, Old>,
        to newKey: KeyPath<Configs.Keys, New>,
        firstReadPolicy: MigrationFirstReadPolicy = .default
    ) -> Self {
        migraion(from: oldKey, to: newKey, firstReadPolicy: firstReadPolicy, migrate: { $0 })
    }
}

public struct MigrationFirstReadPolicy: OptionSet, Hashable, CaseIterable {

    public var rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static var allCases: [MigrationFirstReadPolicy] {
        [.writeToNew, .removeOld, [], [.removeOld, .writeToNew]]
    }

    public static let writeToNew = MigrationFirstReadPolicy(rawValue: 1 << 0)
    public static let removeOld = MigrationFirstReadPolicy(rawValue: 1 << 1)

    public static let `default`: MigrationFirstReadPolicy = [.writeToNew, .removeOld]
}
