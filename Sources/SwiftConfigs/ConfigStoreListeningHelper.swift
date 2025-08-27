import Foundation

/// Thread-safe helper for managing configuration change listeners
///
/// Use this class in your `ConfigStore` implementations to handle observer registration,
/// thread safety, and efficient notification delivery. It automatically dispatches callbacks
/// to the main thread and manages memory safely to prevent retain cycles.
///
/// ## Usage Example
///
/// ```swift
/// final class MyConfigStore: ConfigStore {
///     private let observer = ConfigStoreObserver()
///     
///     func onChange(_ listener: @escaping () -> Void) -> Cancellation {
///         return observer.onChange(listener)
///     }
///     
///     func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation {
///         let currentValue = try? get(key)
///         return observer.onChangeOfKey(key, value: currentValue, listener)
///     }
///     
///     private func notifyObservers() {
///         observer.notifyChange { key in try? get(key) }
///     }
/// }
/// ```
public final class ConfigStoreObserver {

    private var observers: [UUID: () -> Void] = [:]
    private var perKeyObservers: [String: [UUID: (_ specific: Bool, String?) -> Void]] = [:]
    private let lock = ReadWriteLock()

    /// Notifies observers when a specific configuration key changes
    ///
    /// Call this method when you know exactly which key changed and its new value.
    /// This is more efficient than `notifyChange(values:)` for targeted updates.
    ///
    /// - Parameters:
    ///   - key: The configuration key that changed
    ///   - newValue: The new value for the key, or `nil` if removed
    /// - Note: All callbacks are automatically dispatched to the main thread
    public func notifyChange(for key: String, newValue: String?) {
        lock.withWriterLock {
            observers.values + perKeyObservers[key, default: [:]].values.map { o in
                { o(true, newValue) }
            }
        }
        .forEach(callOnMainThread)
    }

    /// Notifies all observers of potential configuration changes
    ///
    /// Use this method when you don't know which specific keys changed (e.g., after
    /// a bulk fetch operation). It queries all monitored keys and notifies observers
    /// only if values actually changed.
    ///
    /// - Parameter values: Function to get the current value for any key
    /// - Note: All callbacks are automatically dispatched to the main thread
    /// - Warning: This method is less efficient than `notifyChange(for:newValue:)` for single key changes
    public func notifyChange(values: (String) -> String?) {
        lock.withWriterLock {
            observers.values + perKeyObservers.flatMap { key, observers in
                let value = values(key)
                return observers.values.map { o in
                    { o(false, value) }
                }
            }
        }
        .forEach(callOnMainThread)
    }

    /// Registers a global observer for all configuration changes
    ///
    /// The observer will be called whenever any configuration value changes,
    /// regardless of which specific key was modified.
    ///
    /// - Parameter observer: Callback invoked on any configuration change
    /// - Returns: Cancellation token to stop observing changes
    /// - Note: The callback is automatically dispatched to the main thread
    public func onChange(_ observer: @escaping () -> Void) -> Cancellation {
        let id = UUID()
        lock.withWriterLockVoid {
            observers[id] = observer
        }
        return Cancellation { [weak self] in
            self?.lock.withWriterLockVoid {
                self?.observers.removeValue(forKey: id)
            }
        }
    }

    /// Registers an observer for changes to a specific configuration key
    ///
    /// The observer is only called when the specified key's value actually changes,
    /// providing automatic deduplication to avoid unnecessary callbacks.
    ///
    /// - Parameters:
    ///   - key: The configuration key to monitor
    ///   - value: Current value of the key (used for change detection)
    ///   - observer: Callback invoked with the new value when the key changes
    /// - Returns: Cancellation token to stop observing changes
    /// - Note: The callback is automatically dispatched to the main thread
    /// - Warning: Ensure the initial `value` parameter is accurate to prevent missed change notifications
    public func onChangeOfKey(_ key: String, value: String?, _ observer: @escaping (String?) -> Void) -> Cancellation {
        let id = UUID()
        var lastValue = value // should be always called on main thread
        lock.withWriterLockVoid {
            perKeyObservers[key, default: [:]][id] = { specific, newValue in
                if specific || lastValue != newValue {
                    lastValue = newValue
                    observer(newValue)
                }
            }
        }
        return Cancellation { [weak self] in
            self?.lock.withWriterLockVoid {
                self?.perKeyObservers[key, default: [:]].removeValue(forKey: id)
            }
        }
    }
}

private func callOnMainThread(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.async {
            block()
        }
    }
}
