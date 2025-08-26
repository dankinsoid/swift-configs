#if canImport(UIKit) || canImport(AppKit)
    import Foundation

    #if canImport(UIKit)
        import UIKit
    #elseif canImport(AppKit)
        import AppKit
    #endif

    /// A ConfigStore implementation backed by NSUbiquitousKeyValueStore for iCloud key-value storage
    @available(iOS 5.0, macOS 10.7, tvOS 9.0, watchOS 2.0, *)
    public final class UbiquitousKeyValueStoreConfigStore: ConfigStore {

        private let ubiquitousStore: NSUbiquitousKeyValueStore
        private let listenHelper = ConfigStoreListeningHelper()
        private var notificationObserver: NSObjectProtocol?
        private var lifecycleObservers: [NSObjectProtocol] = []

        public static let `default` = UbiquitousKeyValueStoreConfigStore()

        /// Creates an iCloud key-value store configs store
        /// - Parameter ubiquitousStore: The NSUbiquitousKeyValueStore instance to use
        public init(ubiquitousStore: NSUbiquitousKeyValueStore = .default) {
            self.ubiquitousStore = ubiquitousStore
    
            setupNotificationObserver()
            setupLifecycleObservers()
        }

        deinit {
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            lifecycleObservers.forEach {
                NotificationCenter.default.removeObserver($0)
            }
        }

        private func setupNotificationObserver() {
            notificationObserver = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: ubiquitousStore,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.listenHelper.notifyChange { self.ubiquitousStore.string(forKey: $0) }
            }
        }

        private func setupLifecycleObservers() {
            let notifications: [Notification.Name]
            #if canImport(UIKit)
                notifications = [
                    UIApplication.didFinishLaunchingNotification,
                    UIApplication.willEnterForegroundNotification,
                ]
            #elseif canImport(AppKit)
                notifications = [
                    NSApplication.didFinishLaunchingNotification,
                    NSApplication.willBecomeActiveNotification,
                ]
            #endif
            for notification in notifications {
                let observer = NotificationCenter.default.addObserver(
                    forName: notification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.ubiquitousStore.synchronize()
                }
                lifecycleObservers.append(observer)
            }
        }

        // MARK: - ConfigStore Implementation

        public func fetch(completion: @escaping (Error?) -> Void) {
            // Synchronize with iCloud
            let success = ubiquitousStore.synchronize()
            completion(success ? nil : UbiquitousStoreError.synchronizationFailed)
        }

        public func onChange(_ listener: @escaping () -> Void) -> Cancellation? {
            listenHelper.onChange(listener)
        }

        public func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation? {
            listenHelper.onChangeOfKey(key, value: ubiquitousStore.string(forKey: key), listener)
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

            // Notify listeners about the change
            listenHelper.notifyChange(for: key, newValue: value)
        }

        public func removeAll() throws {
            let keys = keys() ?? Set()
            for key in keys {
                ubiquitousStore.removeObject(forKey: key)
            }

            // Notify listeners about the change
            listenHelper.notifyChange { _ in nil }
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
