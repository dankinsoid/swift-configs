import Foundation

final class ConfigStoreListeningHelper {

    private var observers: [UUID: () -> Void] = [:]
    private var perKeyObservers: [String: [UUID: (_ specific: Bool, String?) -> Void]] = [:]
    private let lock = ReadWriteLock()

    func notifyChange(for key: String, newValue: String?) {
        lock.withWriterLock {
            observers.values + perKeyObservers[key, default: [:]].values.map { o in
                { o(true, newValue) }
            }
        }
        .forEach(callOnMainThread)
    }

    func notifyChange(values: (String) -> String?) {
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

    func onChange(_ observer: @escaping () -> Void) -> Cancellation? {
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

    func onChangeOfKey(_ key: String, value: String?, _ observer: @escaping (String?) -> Void) -> Cancellation? {
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

private func withArg<T>(_ arg: T, _ block: @escaping (Bool, T) -> Void) -> (Bool) -> Void {
    { block($0, arg) }
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
