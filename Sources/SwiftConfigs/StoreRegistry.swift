import Foundation

/// The main configuration store that manages multiple category stores
public final class StoreRegistry {
    
    /// Whether any store has completed a fetch operation
    public var hasFetched: Bool {
        lock.withReaderLock {
            _didFetch
        }
    }
    
    private let lock = ReadWriteLock()
    private let storesLock = ReadWriteLock()
    private var _didFetch = false
    /// The category-specific configuration stores
    internal(set) public var stores: [ConfigCategory: ConfigStore] {
        get { storesLock.withReaderLock { _stores } }
        set { storesLock.withWriterLockVoid { _stores = newValue } }
    }
    private var _stores: [ConfigCategory: ConfigStore]
    private var observers: [UUID: () -> Void] = [:]
    private var didStartListen = false
    private var didStartFetch = false
    private var cancellation: Cancellation?
    
    /// Initializes with a set of category stores
    public init(_ stores: [ConfigCategory: ConfigStore]) {
        _stores = stores
    }
    
    public static func `default`(with custom: [ConfigCategory: ConfigStore]) -> StoreRegistry {
        StoreRegistry(
            custom.merging(isPreview ? ConfigSystem.mockStores : ConfigSystem.defaultStores) { new, _ in new }
        )
    }
    
    /// Fetches configuration values from all stores
    public func fetch(completion: @escaping (Error?) -> Void) {
        lock.withWriterLock {
            didStartFetch = true
        }
        store(for: nil).fetch { [weak self] error in
            self?.lock.withWriterLock { () -> [() -> Void] in
                self?.didStartFetch = false
                if error == nil {
                    self?._didFetch = true
                    return (self?.observers.values).map { Array($0) } ?? []
                }
                return []
            }
            .forEach { $0() }
            completion(error)
        }
    }

    /// Registers a listener for configuration changes
    public func onChange(_ observer: @escaping () -> Void) -> Cancellation {
        let hasFetched = self.hasFetched
        if !hasFetched, !lock.withReaderLock({ didStartFetch }) {
            fetch { _ in }
        }
        defer {
            if hasFetched {
                observer()
            }
        }
        let id = UUID()
        lock.withWriterLockVoid {
            observers[id] = observer
            if !didStartListen {
                didStartListen = true
                cancellation = store(for: nil).onChange { [weak self] in
                    self?.lock.withReaderLock {
                        self?.observers ?? [:]
                    }
                    .values
                    .forEach { $0() }
                }
            }
        }
        return Cancellation { self.cancel(id: id) }
    }
    
    /// Gets the appropriate store for a category
    public func store(for category: ConfigCategory?) -> ConfigStore {
        MultiplexConfigStore(
            stores: category.map { category in stores.compactMap { category == $0.key ? $0.value : nil } } ?? Array(stores.values)
        )
    }
    
    private func cancel(id: UUID) {
        lock.withWriterLock { () -> Cancellation? in
            observers.removeValue(forKey: id)
            if observers.isEmpty {
                let result = cancellation
                cancellation = nil
                didStartListen = false
                return result
            }
            return nil
        }?.cancel()
    }
}
