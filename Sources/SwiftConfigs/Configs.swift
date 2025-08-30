import Foundation

/// Primary interface for configuration management
///
/// This structure provides the main API for reading, writing, and observing configuration
/// values across multiple storage backends. It supports dynamic member lookup, async operations,
/// and change observation for reactive configuration management.
///
/// ## Key Features
///
/// - **Multi-Store Support**: Coordinates access across different configuration stores
/// - **Type Safety**: Compile-time enforcement of read-only vs read-write access
/// - **Dynamic Lookup**: Access configuration values using dot notation
/// - **Async Support**: Modern async/await API for configuration fetching
/// - **Change Observation**: Real-time notifications when configuration values change
/// - **Value Overrides**: Temporary in-memory overrides for testing and debugging
///
/// ## Usage Examples
///
/// ```swift
/// // Initialize with default system
/// let configs = Configs()
///
/// // Access values using dynamic member lookup
/// let apiUrl: String = configs.apiBaseURL
/// configs.debugMode = true
///
/// // Observe configuration changes
/// let cancellation = configs.onChange { updatedConfigs in
///     print("Configuration changed")
/// }
///
/// // Fetch latest values from remote sources
/// try await configs.fetch()
/// ```
@dynamicMemberLookup
public struct Configs: ConfigsType {

    /// The store registry coordinating access across multiple configuration stores
    public let registry: StoreRegistry
    
    /// In-memory value overrides for testing and temporary modifications
    var values: [String: Any]
    
    public var configs: Configs {
        get { self }
        set { self = newValue }
    }

    /// Creates a configuration instance with a custom store registry
    ///
    /// - Parameter registry: The store registry to use for configuration operations
    /// - Note: Most applications should use the default initializer instead
    public init(registry: StoreRegistry) {
        self.registry = registry
        self.values = [:]
    }
    
    init(registry: StoreRegistry, values: [String: Any]) {
        self.registry = registry
        self.values = values
    }
    
    /// Creates a configuration instance using the system default registry
    ///
    /// This is the standard way to create a Configs instance. The system registry
    /// is configured through `ConfigSystem.bootstrap()`.
    public init() {
        self.init(registry: ConfigSystem.registry)
    }
}

public extension Configs {

    /// Indicates whether at least one fetch operation has been completed
    ///
    /// This can be used to determine if remote configuration values have been loaded
    /// at least once since the application started.
    var hasFetched: Bool { registry.hasFetched }

    /// Fetches the latest configuration values from all stores
    ///
    /// This method coordinates fetching across all configured stores concurrently.
    /// For local stores (UserDefaults, Keychain), this typically completes immediately.
    /// For remote stores, this triggers network requests to update cached values.
    ///
    /// - Throws: Aggregated errors from any stores that fail to fetch
    /// - Note: Individual store failures don't prevent other stores from succeeding
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetch() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            registry.fetch { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// Registers a listener for configuration changes across all stores
    ///
    /// The listener is called whenever any configuration value changes in any store.
    /// This provides a centralized way to react to configuration updates from remote
    /// sources, user preferences changes, or programmatic updates.
    ///
    /// - Parameter listener: Called with an updated Configs instance when changes occur
    /// - Returns: Cancellation token to stop listening for changes
    /// - Note: The listener is called on the main thread
    func onChange(_ listener: @escaping (Configs) -> Void) -> Cancellation {
        registry.onChange {
            listener(self)
        }
    }

    /// Fetches configuration values only if not already fetched
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func fetchIfNeeded() async throws {
        guard !hasFetched else { return }
        try await fetch()
    }

    /// Returns an async sequence for configuration changes
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func changes() -> ConfigChangesSequence<Configs> {
        ConfigChangesSequence { observer in
            self.onChange { configs in
                observer(configs)
            }
        }
    }
}

#if compiler(>=5.6)
    extension Configs: @unchecked Sendable {}
#endif
