#if canImport(Foundation) && (os(iOS) || os(macOS) || os(tvOS) || os(watchOS))
    import Foundation

    /// A ConfigStore implementation backed by NSUbiquitousKeyValueStore for iCloud key-value storage
    @available(iOS 5.0, macOS 10.7, tvOS 9.0, watchOS 2.0, *)
    public final class UbiquitousKeyValueStoreConfigStore: ConfigStore {
        private let ubiquitousStore: NSUbiquitousKeyValueStore
        private var observers: [UUID: () -> Void] = [:]
        private let lock = ReadWriteLock()
        private var notificationObserver: NSObjectProtocol?

        public static let `default` = UbiquitousKeyValueStoreConfigStore()

        /// Creates an iCloud key-value store configs store
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

        // MARK: - ConfigStore Implementation

        public func fetch(completion: @escaping (Error?) -> Void) {
            // Synchronize with iCloud
            let success = ubiquitousStore.synchronize()
            completion(success ? nil : UbiquitousStoreError.synchronizationFailed)
        }

        public func onChange(_ listener: @escaping () -> Void) -> Cancellation? {
            let id = UUID()
            lock.withWriterLockVoid {
                observers[id] = listener
            }

            return Cancellation { [weak self] in
                self?.lock.withWriterLockVoid {
                    self?.observers.removeValue(forKey: id)
                }
            }
        }
		
		public var isWritable: Bool {
			true
		}

        public func get(_ key: String) -> String? {
            ubiquitousStore.string(forKey: key)
        }
        
        public func exists(_ key: String) throws -> Bool {
            ubiquitousStore.object(forKey: key) != nil
        }

        public func set(_ value: String?, for key: String) throws {
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

        public func removeAll() throws {
            let keys = keys() ?? Set()
            for key in keys {
                ubiquitousStore.removeObject(forKey: key)
            }

            let success = ubiquitousStore.synchronize()
            if !success {
                throw UbiquitousStoreError.synchronizationFailed
            }
        }

        public func keys() -> Set<String>? {
            Set(ubiquitousStore.dictionaryRepresentation.keys)
        }
    }

    public enum UbiquitousStoreError: Error {
        case synchronizationFailed
    }

    #if compiler(>=5.6)
        @available(iOS 5.0, macOS 10.7, tvOS 9.0, watchOS 2.0, *)
        extension UbiquitousKeyValueStoreConfigStore: @unchecked Sendable {}
    #endif

    @available(iOS 5.0, macOS 10.7, tvOS 9.0, watchOS 2.0, *)
    public extension ConfigStore where Self == UbiquitousKeyValueStoreConfigStore {
        /// Creates a default iCloud key-value store configs store
        static var ubiquitous: UbiquitousKeyValueStoreConfigStore {
            .default
        }

        /// Creates an iCloud key-value store configs store with a specific NSUbiquitousKeyValueStore instance
        static func ubiquitous(store ubiquitousStore: NSUbiquitousKeyValueStore) -> UbiquitousKeyValueStoreConfigStore {
            UbiquitousKeyValueStoreConfigStore(ubiquitousStore: ubiquitousStore)
        }
    }
#endif
