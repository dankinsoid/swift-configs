import Foundation

/// Helper for managing configuration change listeners in ConfigStore implementations
public final class ConfigStoreObserver {
    /// Thread-safe observer management
    ///
    /// This class handles the complexity of:
    /// - Thread-safe registration/deregistration of observers
    /// - Automatic main thread dispatch for observer callbacks
    /// - Memory-safe weak references to avoid retain cycles
    /// - Efficient per-key and global change notifications

    private var observers: [UUID: () -> Void] = [:]
    private var perKeyObservers: [String: [UUID: (_ specific: Bool, String?) -> Void]] = [:]
    private let lock = ReadWriteLock()

    /// Notify observers of a specific key change
    /// - Parameters:
    ///   - key: The configuration key that changed
    ///   - newValue: The new value for the key (nil if removed)
    public func notifyChange(for key: String, newValue: String?) {
        lock.withWriterLock {
            observers.values + perKeyObservers[key, default: [:]].values.map { o in
                { o(true, newValue) }
            }
        }
        .forEach(callOnMainThread)
    }

    /// Notify all observers of potential changes
    /// - Parameter values: Function to get current value for any key
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

    /// Register a global change observer
    /// - Parameter observer: Callback invoked on any configuration change
    /// - Returns: Cancellation token to stop observing
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

    /// Register an observer for a specific configuration key
    /// - Parameters:
    ///   - key: The configuration key to observe
    ///   - value: Current value of the key (for deduplication)
    ///   - observer: Callback invoked when the key's value changes
    /// - Returns: Cancellation token to stop observing
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
