import Foundation

/// Configuration store backed by UserDefaults for persistent storage
public final class UserDefaultsConfigStore: ConfigStore {

    private let userDefaults: UserDefaults
    private var listenHelper = ConfigStoreObserver()
    private var notificationObserver: NSObjectProtocol?
	
	/// Shared standard UserDefaults configuration store
	public static let standard = UserDefaultsConfigStore()

    /// Creates a UserDefaults configuration store
    /// - Parameter userDefaults: The UserDefaults instance to use
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        setupNotificationObserver()
    }

    /// Creates a UserDefaults configuration store with a specific suite
    /// - Parameter suiteName: The suite name for UserDefaults
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

    /// UserDefaults is always available, no fetching required
    public func fetch(completion: @escaping (Error?) -> Void) {
        userDefaults.synchronize()
        completion(nil)
    }

    /// Registers a listener for UserDefaults changes
    public func onChange(_ listener: @escaping () -> Void) -> Cancellation? {
        listenHelper.onChange(listener)
    }

    /// Registers a listener for changes to a specific key
    public func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation? {
        listenHelper.onChangeOfKey(key, value: userDefaults.string(forKey: key), listener)
    }

    /// Retrieves a string value from UserDefaults
    public func get(_ key: String) -> String? {
        userDefaults.string(forKey: key)
    }
    
    public func exists(_ key: String) throws -> Bool {
        userDefaults.object(forKey: key) != nil
    }
	
	/// UserDefaults store supports writing operations
	public var isWritable: Bool {
		true
	}

    /// Writes a value to UserDefaults
    public func set(_ value: String?, for key: String) throws {
        if let value = value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    /// Clears all UserDefaults values
    public func removeAll() throws {
        let keys = keys() ?? Set()
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
    }

    /// Returns all UserDefaults keys
    public func keys() -> Set<String>? {
        Set(userDefaults.dictionaryRepresentation().keys)
    }
}

#if compiler(>=5.6)
    extension UserDefaultsConfigStore: @unchecked Sendable {}
#endif

extension ConfigStore where Self == UserDefaultsConfigStore {

	/// Creates a standard UserDefaults configuration store
	public static var userDefaults: UserDefaultsConfigStore {
		.standard
	}

	/// Creates a UserDefaults configuration store with a specific suite
	public static func userDefaults(suiteName: String) -> UserDefaultsConfigStore? {
		UserDefaultsConfigStore(suiteName: suiteName)
	}
}
