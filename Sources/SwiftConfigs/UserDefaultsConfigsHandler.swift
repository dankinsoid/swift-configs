import Foundation

/// Configuration store backed by UserDefaults for persistent storage
///
/// This store provides persistent configuration storage using the system's UserDefaults.
/// Values are automatically synchronized across app launches and can be shared between
/// app extensions using suite names.
///
/// ## Features
///
/// - **Persistent Storage**: Values survive app restarts and system reboots
/// - **Change Notifications**: Automatic notification when UserDefaults change
/// - **App Extension Support**: Share configuration between main app and extensions
/// - **Synchronization**: Automatic sync with system preferences and iCloud (when enabled)
/// - **Thread Safe**: All operations are safe to call from any thread
///
/// ## Performance Notes
///
/// - **Caching**: UserDefaults caches values in memory for fast access
/// - **Synchronization**: `fetch()` calls `synchronize()` to ensure latest values
/// - **Bulk Operations**: `removeAll()` operations may be slow with many keys
///
/// ## Example
///
/// ```swift
/// // Using standard UserDefaults
/// ConfigSystem.bootstrap([.default: .userDefaults])
///
/// // Using app group for sharing with extensions
/// if let groupStore = UserDefaultsConfigStore(suiteName: "group.com.example.myapp") {
///     ConfigSystem.bootstrap([.default: groupStore])
/// }
/// ```
public final class UserDefaultsConfigStore: ConfigStore {

    private let userDefaults: UserDefaults
    private var listenHelper = ConfigStoreObserver()
    private var notificationObserver: NSObjectProtocol?
	
	/// Shared UserDefaults configuration store using standard UserDefaults
	public static let standard = UserDefaultsConfigStore()

    /// Creates a UserDefaults configuration store
    ///
    /// - Parameter userDefaults: The UserDefaults instance to use for storage
    /// - Note: Automatically sets up change notifications for the specified UserDefaults instance
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        setupNotificationObserver()
    }

    /// Creates a UserDefaults configuration store with a specific suite name
    ///
    /// App groups allow sharing UserDefaults between the main app and extensions.
    /// The suite name typically follows the format "group.com.example.myapp".
    ///
    /// - Parameter suiteName: The suite name for shared UserDefaults
    /// - Returns: A new store instance, or `nil` if the suite name is invalid
    /// - Note: Requires proper App Group entitlements to be configured
    public convenience init?(suiteName: String) {
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return nil
        }
        self.init(userDefaults: userDefaults)
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: userDefaults,
            queue: .main
        ) { [weak self] _ in
            self?.notifyObservers()
        }
    }

    private func notifyObservers() {
        listenHelper.notifyChange(values: userDefaults.string)
    }

    // MARK: - ConfigStore Implementation

    /// Synchronizes UserDefaults to ensure latest values from disk
    ///
    /// - Parameter completion: Called when synchronization completes (always succeeds)
    /// - Note: UserDefaults automatically synchronizes, but this forces an immediate sync
    public func fetch(completion: @escaping (Error?) -> Void) {
        userDefaults.synchronize()
        completion(nil)
    }

    public func onChange(_ listener: @escaping () -> Void) -> Cancellation? {
        listenHelper.onChange(listener)
    }

    public func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation? {
        listenHelper.onChangeOfKey(key, value: userDefaults.string(forKey: key), listener)
    }

    public func get(_ key: String) -> String? {
        userDefaults.string(forKey: key)
    }
    
    public func exists(_ key: String) throws -> Bool {
        userDefaults.object(forKey: key) != nil
    }
	
	public var isWritable: Bool {
		true
	}

    public func set(_ value: String?, for key: String) throws {
        if let value = value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    /// Removes all configuration values from UserDefaults
    ///
    /// - Warning: This operation cannot be undone and may affect other parts of your app
    /// - Note: Only removes keys that are present in the current dictionary representation
    public func removeAll() throws {
        let keys = keys() ?? Set()
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
    }

    public func keys() -> Set<String>? {
        Set(userDefaults.dictionaryRepresentation().keys)
    }
}

#if compiler(>=5.6)
    extension UserDefaultsConfigStore: @unchecked Sendable {}
#endif

extension ConfigStore where Self == UserDefaultsConfigStore {

	/// Standard UserDefaults configuration store
	public static var userDefaults: UserDefaultsConfigStore {
		.standard
	}

	/// Creates a UserDefaults configuration store with a specific suite name
	///
	/// - Parameter suiteName: The suite name for shared UserDefaults (e.g., "group.com.example.myapp")
	/// - Returns: A new store instance, or `nil` if the suite name is invalid
	public static func userDefaults(suiteName: String) -> UserDefaultsConfigStore? {
		UserDefaultsConfigStore(suiteName: suiteName)
	}
}
