import Foundation

/// A ConfigsHandler implementation backed by UserDefaults
public final class UserDefaultsConfigsHandler: ConfigsHandler {
    private let userDefaults: UserDefaults
    private var observers: [UUID: () -> Void] = [:]
    private let lock = ReadWriteLock()
    private var notificationObserver: NSObjectProtocol?

    /// Creates a UserDefaults configs handler
    /// - Parameter userDefaults: The UserDefaults instance to use
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        setupNotificationObserver()
    }

    /// Creates a UserDefaults configs handler with a specific suite
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
        let currentObservers = lock.withReaderLock { observers.values }
        currentObservers.forEach { $0() }
    }

    // MARK: - ConfigsHandler Implementation

    public func fetch(completion: @escaping (Error?) -> Void) {
        // UserDefaults is synchronous and always available
        completion(nil)
    }

    public func listen(_ listener: @escaping () -> Void) -> ConfigsCancellation? {
        let id = UUID()
        lock.withWriterLockVoid {
            observers[id] = listener
        }

        return ConfigsCancellation { [weak self] in
            self?.lock.withWriterLockVoid {
                self?.observers.removeValue(forKey: id)
            }
        }
    }

    public func value(for key: String) -> String? {
        userDefaults.string(forKey: key)
    }

    public func writeValue(_ value: String?, for key: String) throws {
        if let value = value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    public func clear() throws {
        let keys = allKeys() ?? Set()
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
    }

    public func allKeys() -> Set<String>? {
        Set(userDefaults.dictionaryRepresentation().keys)
    }
}

#if compiler(>=5.6)
    extension UserDefaultsConfigsHandler: @unchecked Sendable {}
#endif
