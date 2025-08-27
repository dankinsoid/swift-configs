#if canImport(UIKit) || canImport(AppKit)
    import Foundation

    #if canImport(UIKit)
        import UIKit
    #elseif canImport(AppKit)
        import AppKit
    #endif

    /// Configuration store backed by iCloud key-value storage
    ///
    /// This store provides seamless synchronization of configuration values across all of a user's
    /// devices through iCloud. It's ideal for user preferences and settings that should persist
    /// and sync across devices.
    ///
    /// ## Features
    ///
    /// - **Cross-Device Sync**: Automatic synchronization via iCloud
    /// - **Offline Support**: Works when iCloud is unavailable, syncs when connectivity returns
    /// - **Change Notifications**: Real-time notifications when values change remotely
    /// - **Automatic Sync**: Syncs on app foreground and other system events
    /// - **Storage Limits**: 1MB total storage limit imposed by Apple
    ///
    /// ## Requirements
    ///
    /// - iCloud capability must be enabled in your app's entitlements
    /// - User must be signed in to iCloud
    /// - Key-value store must be enabled in iCloud settings
    ///
    /// ## Performance Notes
    ///
    /// - **Network Dependent**: Initial sync may take time on slow connections
    /// - **Eventual Consistency**: Changes may not appear immediately on other devices
    /// - **Size Limits**: Individual values limited to ~1MB, total store limited to 1MB
    /// - **Rate Limiting**: Excessive writes may be throttled by iCloud
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Use for user preferences that should sync across devices
    /// extension Configs.Keys {
    ///     static let preferredTheme = RWKey("theme", in: .icloud, default: "system")
    ///     static let notificationsEnabled = RWKey("notifications", in: .icloud, default: true)
    /// }
    /// ```
    @available(iOS 5.0, macOS 10.7, tvOS 9.0, watchOS 2.0, *)
    public final class UbiquitousKeyValueStoreConfigStore: ConfigStore {

        private let ubiquitousStore: NSUbiquitousKeyValueStore
        private let listenHelper = ConfigStoreObserver()
        private var observers: [NSObjectProtocol] = []

        /// Shared iCloud key-value store configuration store
        public static let `default` = UbiquitousKeyValueStoreConfigStore()

        /// Creates an iCloud key-value store configuration store
        ///
        /// - Parameter ubiquitousStore: The NSUbiquitousKeyValueStore instance to use
        /// - Note: Automatically sets up sync triggers and change notifications
        public init(ubiquitousStore: NSUbiquitousKeyValueStore = .default) {
            self.ubiquitousStore = ubiquitousStore

            setupObservers()
        }

        deinit {
            observers.forEach {
                NotificationCenter.default.removeObserver($0)
            }
        }

        private func setupObservers() {
            let notifications: [Notification.Name]
#if canImport(UIKit)
            notifications = [
                UIApplication.willEnterForegroundNotification,
            ]
#elseif canImport(AppKit)
            notifications = [
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
                observers.append(observer)
            }
            observers.append(
                NotificationCenter.default.addObserver(
                    forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                    object: ubiquitousStore,
                    queue: .main
                ) { [weak self] _ in
                    guard let self else { return }
                    listenHelper.notifyChange(values: { self.ubiquitousStore.string(forKey: $0) })
                }
            )
        }

        // MARK: - ConfigStore Implementation

        /// Forces synchronization with iCloud
        ///
        /// - Parameter completion: Called when sync attempt completes (always succeeds locally)
        /// - Note: Sync success doesn't guarantee iCloud connectivity; changes sync when available
        public func fetch(completion: @escaping (Error?) -> Void) {
            ubiquitousStore.synchronize()
            completion(nil)
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

        /// Removes all values from iCloud key-value storage
        ///
        /// - Warning: This affects all devices signed in to the same iCloud account
        /// - Note: Removal will sync to other devices when iCloud is available
        public func removeAll() throws {
            let keys = keys() ?? Set()
            for key in keys {
                ubiquitousStore.removeObject(forKey: key)
            }

            // Notify listeners about the change
            listenHelper.notifyChange(values: { _ in nil })
        }

        public func keys() -> Set<String>? {
            Set(ubiquitousStore.dictionaryRepresentation.keys)
        }
    }

    #if compiler(>=5.6)
        @available(iOS 5.0, macOS 10.7, tvOS 9.0, watchOS 2.0, *)
        extension UbiquitousKeyValueStoreConfigStore: @unchecked Sendable {}
    #endif

    @available(iOS 5.0, macOS 10.7, tvOS 9.0, watchOS 2.0, *)
    public extension ConfigStore where Self == UbiquitousKeyValueStoreConfigStore {
        /// Default iCloud key-value store configuration store
        static var ubiquitous: UbiquitousKeyValueStoreConfigStore {
            .default
        }

        /// Creates an iCloud key-value store configuration store with a specific instance
        ///
        /// - Parameter ubiquitousStore: The NSUbiquitousKeyValueStore instance to use
        /// - Returns: A configuration store backed by the specified iCloud store
        static func ubiquitous(store ubiquitousStore: NSUbiquitousKeyValueStore) -> UbiquitousKeyValueStoreConfigStore {
            UbiquitousKeyValueStoreConfigStore(ubiquitousStore: ubiquitousStore)
        }
    }
#endif
