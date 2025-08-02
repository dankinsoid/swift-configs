#if canImport(Foundation) && (os(iOS) || os(macOS) || os(tvOS) || os(watchOS))
    import Foundation

    /// A ConfigsHandler implementation backed by NSUbiquitousKeyValueStore for iCloud key-value storage
    @available(iOS 5.0, macOS 10.7, tvOS 9.0, watchOS 2.0, *)
    public final class UbiquitousKeyValueStoreConfigsHandler: ConfigsHandler {
        private let ubiquitousStore: NSUbiquitousKeyValueStore
        private var observers: [UUID: () -> Void] = [:]
        private let lock = ReadWriteLock()
        private var notificationObserver: NSObjectProtocol?

        public static let `default` = UbiquitousKeyValueStoreConfigsHandler()

        /// Creates an iCloud key-value store configs handler
        /// - Parameter ubiquitousStore: The NSUbiquitousKeyValueStore instance to use
        public init(ubiquitousStore: NSUbiquitousKeyValueStore = .default) {
            self.ubiquitousStore = ubiquitousStore
            setupNotificationObserver()
        }

        deinit {
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        private func setupNotificationObserver() {
            notificationObserver = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: ubiquitousStore,
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
            // Synchronize with iCloud
            let success = ubiquitousStore.synchronize()
            completion(success ? nil : UbiquitousStoreError.synchronizationFailed)
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
            ubiquitousStore.string(forKey: key)
        }

        public func writeValue(_ value: String?, for key: String) throws {
            if let value = value {
                ubiquitousStore.set(value, forKey: key)
            } else {
                ubiquitousStore.removeObject(forKey: key)
            }

            // Attempt to synchronize immediately
            let success = ubiquitousStore.synchronize()
            if !success {
                throw UbiquitousStoreError.synchronizationFailed
            }
        }

        public func clear() throws {
            let keys = allKeys() ?? Set()
            for key in keys {
                ubiquitousStore.removeObject(forKey: key)
            }

            let success = ubiquitousStore.synchronize()
            if !success {
                throw UbiquitousStoreError.synchronizationFailed
            }
        }

        public func allKeys() -> Set<String>? {
            Set(ubiquitousStore.dictionaryRepresentation.keys)
        }
    }

    public enum UbiquitousStoreError: Error {
        case synchronizationFailed
    }

    #if compiler(>=5.6)
        @available(iOS 5.0, macOS 10.7, tvOS 9.0, watchOS 2.0, *)
        extension UbiquitousKeyValueStoreConfigsHandler: @unchecked Sendable {}
    #endif

    @available(iOS 5.0, macOS 10.7, tvOS 9.0, watchOS 2.0, *)
    public extension ConfigsHandler where Self == UbiquitousKeyValueStoreConfigsHandler {
        /// Creates a default iCloud key-value store configs handler
        static var ubiquitous: UbiquitousKeyValueStoreConfigsHandler {
            .default
        }

        /// Creates an iCloud key-value store configs handler with a specific NSUbiquitousKeyValueStore instance
        static func ubiquitous(store ubiquitousStore: NSUbiquitousKeyValueStore) -> UbiquitousKeyValueStoreConfigsHandler {
            UbiquitousKeyValueStoreConfigsHandler(ubiquitousStore: ubiquitousStore)
        }
    }
#endif
