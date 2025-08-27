import Foundation
#if canImport(Security)
    import Security
#endif

/// The `ConfigSystem` is a global facility where the default configs backend implementation (`ConfigStore`) can be
/// configured. `ConfigSystem` is set up just once in a given program to set up the desired configs backend
/// implementation.
public enum ConfigSystem {

	/// The default configuration stores for each category
	public static let defaultStores: [ConfigCategory: ConfigStore] = [
		.default: .userDefaults,
		.environment: .environment,
		.inMemory: .inMemory,
	]
		.withPlatformSpecific

	/// Mock configuration stores for testing and previews
	public static let mockStores: [ConfigCategory: ConfigStore] = [
		.default: .inMemory(),
		.environment: .inMemory(),
		.inMemory: .inMemory(),
		.secure: .inMemory(),
		.critical: .inMemory(),
		.syncedSecure: .inMemory(),
		.remote: .inMemory()
	]

    static let registry = StoreRegistry(isPreview ? mockStores : defaultStores)
#if DEBUG
    @Locked private static var isBootstrapped = false
#endif

	/// Bootstraps the configuration system with a single store
	/// 
	/// This function can only be called once per program execution.
	/// Multiple calls will lead to undefined behavior.
	///
	/// - Parameter store: The configuration store to use
	public static func bootstrap(_ store: ConfigStore, file: StaticString = #fileID, line: UInt = #line) {
        bootstrap([.default: store], file: file, line: line)
	}

	/// Bootstraps the configuration system with category-specific stores
	/// 
	/// This function can only be called once per program execution.
	/// Multiple calls will lead to undefined behavior.
	///
	/// - Parameter stores: A dictionary mapping categories to their stores
    public static func bootstrap(_ stores: [ConfigCategory: ConfigStore], file: StaticString = #fileID, line: UInt = #line) {
        registry.stores = stores
#if DEBUG
        assert(!isBootstrapped, "ConfigSystem.bootstrap() can only be called once per program execution.", file: file, line: line)
        isBootstrapped = true
        assert(!registry.didAccessStores, "ConfigSystem.bootstrap() must be called before accessing any configs.", file: file, line: line)
#endif
	}

	/// Bootstraps with default stores, overriding with provided stores
	/// 
	/// This function merges the provided stores with the default ones,
	/// with provided stores taking precedence.
	/// Can only be called once per program execution.
	///
	/// - Parameter stores: Custom stores to override defaults
	public static func defaultBootstrap(_ stores: [ConfigCategory: ConfigStore], file: StaticString = #fileID, line: UInt = #line) {
        bootstrap(stores.merging(isPreview ? mockStores : defaultStores) { new, _ in new }, file: file, line: line)
	}
}

// MARK: - Sendable support helpers

#if compiler(>=5.6)
    extension ConfigSystem: Sendable {}
#endif

private extension [ConfigCategory: ConfigStore] {
    
    var withPlatformSpecific: [ConfigCategory: ConfigStore] {
        var stores = self
#if canImport(Security)
        stores[.secure] = .keychain
        stores[.critical] = .keychain(useSecureEnclave: true, secureEnclaveAccessControl: .userPresence)
        stores[.syncedSecure] = .keychain(iCloudSync: true)
#if canImport(UIKit) || canImport(AppKit)
        if #available(iOS 5.0, macOS 10.7, tvOS 9.0, watchOS 2.0, *), hasKVStoreEntitlement() {
            stores[.synced] = .ubiquitous
        }
#endif
#endif
        return stores
    }
}

#if DEBUG
    let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" || ProcessInfo.processInfo.processName == "XCPreviewAgent"
#else
    let isPreview = false
#endif

private func hasKVStoreEntitlement() -> Bool {
#if canImport(Security)
    guard let task = SecTaskCreateFromSelf(nil) else { return false }
    if SecTaskCopyValueForEntitlement(task, "com.apple.developer.ubiquity-kvstore-identifier" as CFString, nil) != nil {
        return true // entitlement exists (value is CFTypeRef, often a string)
    }
#endif
    return false
}
