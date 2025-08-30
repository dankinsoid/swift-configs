# SwiftConfigs

SwiftConfigs provides a unified, type-safe API for small key-value storage systems where keys can be manually enumerated. The library abstracts storage implementation details behind a clean interface, making it easy to switch between different backends without changing application code.

## Features

- **Unified API for Small Key-Value Stores**: Works with UserDefaults, Keychain, environment variables, in-memory storage, and other enumerable key-value systems
- **Configuration Categories**: High-level abstraction that allows changing storage backends without modifying code that uses the values
- **Type Safety**: Full support for any `Codable` values out of the box with compile-time type checking
- **Flexible Key Configuration**: Individual keys can use specific stores instead of abstract categories, allowing usage before system bootstrap
- **Easy Storage Migration**: Seamlessly migrate between different storage backends or individual key migrations
- **Test and Preview Support**: Automatically uses in-memory storage for SwiftUI previews and can be easily configured for testing
- **Per-Key Customization**: Each configuration key can have its own store, transformer, or migration logic
- **Property Wrapper APIs** for simpler usage
- **Real-time Updates** with cancellable change subscriptions
- **Secure Storage Options** including Keychain and Secure Enclave support

## Getting Started

### 1. Import SwiftConfigs

```swift
import SwiftConfigs
```

### 2. Define Configuration Keys

```swift
public extension Configs.Keys {
    
    var apiToken: RWConfigKey<String?> {
        RWConfigKey("api-token", in: .secure, default: nil)
    }
    
    var userID: ROConfigKey<UUID> { 
        ROConfigKey("USER_ID", in: .syncedSecure, default: UUID(), cacheDefaultValue: true)
    }
    
    var serverURL: ROConfigKey<String> { 
        ROConfigKey("SERVER_URL", in: .environment, default: "https://api.example.com")
    }
}
```

### 3. Create a Configs Instance

```swift
let configs = Configs()
```

### 4. Use Your Configuration

```swift
// Read values
let userID = configs.userID
let token = configs.apiToken
let serverURL = configs.serverURL

// Write values (for RWConfigKey only)
configs.apiToken = "new-token"
```

## Configuration Categories

SwiftConfigs organizes configuration data using categories, allowing you to store different types of settings in appropriate backends:

```swift
ConfigSystem.bootstrap([
    .default: .userDefaults,           // General app settings
    .secure: .keychain,                // Sensitive data (tokens, passwords)
    .critical: .secureEnclave(),       // Maximum security with biometrics
    .syncedSecure: .keychain(iCloudSync: true), // Synced secure data
    .environment: .environment,       // Environment variables
    .memory: .inMemory,                // Temporary/testing data
    .remote: .userDefaults             // Remote configuration cache
])
```

### Built-in Categories

- **`.default`** - General application settings
- **`.synced`** - Data synced across devices
- **`.secure`** - Sensitive data requiring encryption
- **`.critical`** - Maximum security with hardware protection
- **`.syncedSecure`** - Secure data synced across devices
- **`.environment`** - Environment variables
- **`.memory`** - In-memory storage
- **`.remote`** - Remote configuration cache

## Available Stores

### UserDefaults
```swift
.userDefaults                     // Standard UserDefaults
.userDefaults(suiteName: "group") // App group UserDefaults
```

### Keychain (iOS/macOS)
```swift
.keychain                                 // Basic keychain storage
.keychain(iCloudSync: true)               // iCloud Keychain sync
.secureEnclave()                          // Secure Enclave with user presence
.biometricSecureEnclave()                 // Secure Enclave with biometrics
.passcodeSecureEnclave()                  // Secure Enclave with device passcode
```

### iCloud Key-Value Store
```swift
.ubiquitous                               // Default iCloud key-value store
.ubiquitous(store: customUbiquitousStore) // Custom iCloud store instance
```

### Other Stores
```swift
.environment                              // Environment variables (read-only)
.infoPlist                                // App bundle Info.plist (read-only)
.infoPlist(for: bundle)                   // Custom bundle Info.plist
.inMemory                                 // In-memory storage
.inMemory(["key": "value"])               // In-memory with initial values
.multiple(store1, store2)                 // Multiplex multiple stores (fallback chain)
```

## Property Wrapper API

Use property wrappers for inline configuration management:

```swift
struct AppSettings {
    
    // Using key path reference to predefined keys
    @ROConfig(\.userID) 
    var userID: UUID
    
    // Using category-based initialization (recommended)
    @RWConfig(wrappedValue: nil, "api-token", in: .secure) 
    var apiToken: String?
    
    @RWConfig(wrappedValue: UserPreferences(), "user-preferences", in: .default)
    var preferences: UserPreferences
    
    // Using store-based initialization (for specific store targeting)
    @RWConfig(wrappedValue: false, "debug-mode", store: .inMemory) 
    var debugMode: Bool
}

let settings = AppSettings()
print(settings.userID)           // Read value
settings.apiToken = "new-token"  // Write value
settings.preferences.theme = .dark
```

## SwiftUI Property Wrappers

For SwiftUI views, use `ROConfigState` and `RWConfigState` property wrappers that automatically trigger view updates when configuration changes:

```swift
struct SettingsView: View {
    
    // Read-only configuration with automatic view updates
    @ROConfigState(\.userID) 
    var userID: UUID
    
    // Read-write configuration with automatic view updates
    @RWConfigState("theme", in: .default) 
    var theme = Theme.light
    
    @RWConfigState("counter", in: .default) 
    var counter = 0
    
    var body: some View {
        VStack {
            Text("User: \(userID)")
            
            Picker("Theme", selection: $theme) {
                Text("Light").tag(Theme.light)
                Text("Dark").tag(Theme.dark)
            }
            
            Text("Count: \(counter)")
            
            Button("Increment") {
                counter += 1
            }
        }
    }
}
```

## Namespaces

SwiftConfigs supports namespace-based organization of configuration keys, providing compile-time structure and type safety for logically related keys.

### Basic Namespaces

Group related keys in namespace extensions of `Configs.Keys`:

```swift
extension Configs.Keys {
    var security: Security { Security() }
    
    struct Security: ConfigNamespaceKeys {
        var apiToken: RWConfigKey<String?> {
            RWConfigKey("api-token", in: .secure, default: nil)
        }
        
        var encryptionEnabled: ROConfigKey<Bool> {
            ROConfigKey("encryption-enabled", in: .secure, default: true)
        }
    }
}

// Usage - clean, organized access
let configs = Configs()
let apiToken = configs.security.apiToken
configs.security.encryptionEnabled = false

// Property wrapper usage
@RWConfig(\.security.apiToken) var token: String?
@ROConfigState(\.security.encryptionEnabled) var isEncryptionEnabled: Bool
```

### Nested Namespaces

Create deeper hierarchies by nesting namespace types:

```swift
extension Configs.Keys {
    struct Features: ConfigNamespaceKeys {
        var auth: Auth { Auth() }
        
        struct Auth: ConfigNamespaceKeys {
            var biometricEnabled: RWConfigKey<Bool> {
                RWConfigKey("biometric-enabled", in: .default, default: false)
            }
        }
    }
}

// Usage - deep namespace navigation
let biometricEnabled = configs.features.auth.biometricEnabled
configs.features.auth.biometricEnabled = true
```

### Key Prefixing (Optional)

Namespaces are primarily for code organization. But if needed, you can add a `keyPrefix` to automatically prefix all keys in that namespace:

```swift
extension Configs.Keys {

    struct Environment: ConfigNamespaceKeys {
        var keyPrefix: String { "env/" }  // Optional key prefixing
        
        var apiUrl: ROConfigKey<String> {
            ROConfigKey("api-url", in: .environment, default: "localhost")
            // Final key name: "env/api-url"
        }
    }
}
```

## Async/Await Support

```swift
let configs = Configs()

// Fetch latest values
try await configs.fetch()

// Fetch and get specific value
let token = try await configs.fetch(configs.apiToken)

// Fetch only if needed
let value = try await configs.fetchIfNeeded(configs.someKey)
```

## Listening for Changes

### Callback-based Listening

```swift
let configs = Configs()

// Listen to all configuration changes
let cancellation = configs.onChange { configs in
    print("Configurations updated")
}

// Listen to specific key changes  
let keyCancellation = configs.onChange(\.apiToken) { newToken in
    print("API token changed: \(newToken)")
}

// Cancel when done
cancellation.cancel()
keyCancellation.cancel()
```

### Async Sequence-based Listening

```swift
let configs = Configs()

// Listen to all configuration changes using async sequences
for await updatedConfigs in configs.changes() {
    print("Configurations updated")
}

// Listen to specific key changes using async sequences
for await newToken in configs.changes(for: \.apiToken) {
    print("API token changed: \(newToken)")
}

// Use in async context with cancellation
let task = Task {
    for await newToken in configs.changes(for: \.apiToken) {
        print("API token changed: \(newToken)")
        // Break on specific condition
        if newToken == "expected-token" {
            break
        }
    }
}

// Cancel the task when needed
task.cancel()
```

### Combine Publisher Support

When Combine is available, configuration changes can also be used as Publishers:

```swift
import Combine

let configs = Configs()
var cancellables = Set<AnyCancellable>()

// Listen to configuration changes using Combine
configs.changes()
    .sink { updatedConfigs in
        print("Configurations updated")
    }
    .store(in: &cancellables)

// Listen to specific key changes using Combine
configs.changes(for: \.apiToken)
    .sink { newToken in
        print("API token changed: \(newToken)")
    }
    .store(in: &cancellables)

// Chain with other Combine operators
configs.changes(for: \.apiToken)
    .compactMap { $0 }
    .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
    .sink { debouncedToken in
        print("Debounced API token: \(debouncedToken)")
    }
    .store(in: &cancellables)
```

## Value Transformers

SwiftConfigs automatically handles common types:

```swift
public extension Configs.Keys {
    
    // String-convertible types
    var count: ROConfigKey<Int> { 
        ROConfigKey("count", in: .default, default: 0)
    }
    
    var rate: ROConfigKey<Double> {
        ROConfigKey("rate", in: .default, default: 1.0)
    }
    
    // Enum types
    var theme: ROConfigKey<Theme> { 
        ROConfigKey("theme", in: .default, default: .light)
    }
    
    // Codable types (stored as JSON)
    var settings: ROConfigKey<AppSettings> {
        ROConfigKey("settings", in: .default, default: AppSettings())
    }
    
    // Optional types
    var optionalValue: ROConfigKey<String?> {
        ROConfigKey("optional", in: .default, default: nil)
    }
    
    // Using specific stores when needed
    var tempSetting: RWConfigKey<String> {
        RWConfigKey("temp", store: .inMemory, default: "temp-value")
    }
    
    var secureToken: RWConfigKey<String?> {
        RWConfigKey("secure-token", store: .keychain, default: nil)
    }
}
```

## Configuration Migration

Handle configuration schema changes gracefully:

```swift
public extension Configs.Keys {
    
    // Migrate from old boolean to new enum
    var notificationStyle: ROConfigKey<NotificationStyle> {
        ROConfigKey("notification-style", in: .default, default: .none)
    }
    
    private var oldNotificationsEnabled: ROConfigKey<Bool> {
        ROConfigKey("notifications-enabled", in: .default, default: false)
    }
    
    // Custom migration using multiplex stores can be done at bootstrap level:
    // ConfigSystem.bootstrap([
    //     .default: .multiple(.userDefaults, .inMemory) // Check multiple sources
    // ])
}
```

## Custom Configuration Stores

Create custom storage backends by implementing the `ConfigStore` protocol:

```swift
import Foundation

struct MyCustomStore: ConfigStore {
    var isWritable: Bool { true }
    
    func fetch(completion: @escaping (Error?) -> Void) {
        // Fetch latest values from your backend
        completion(nil)
    }
    
    func onChange(_ listener: @escaping () -> Void) -> Cancellation {
        // Set up change notifications
        return Cancellation { /* cleanup */ }
    }
    
    func onChangeOfKey(_ key: String, _ listener: @escaping (String?) -> Void) -> Cancellation {
        // Set up key-specific change notifications
        return Cancellation { /* cleanup */ }
    }
    
    func get(_ key: String) throws -> String? {
        // Retrieve value for key
        return myDatabase.getValue(key)
    }
    
    func set(_ value: String?, for key: String) throws {
        // Store value for key
        if let value = value {
            myDatabase.setValue(value, forKey: key)
        } else {
            myDatabase.removeValue(forKey: key)
        }
    }
    
    func exists(_ key: String) throws -> Bool {
        return myDatabase.hasValue(forKey: key)
    }
    
    func removeAll() throws {
        myDatabase.clearAll()
    }
    
    func keys() -> Set<String>? {
        return Set(myDatabase.allKeys())
    }
}

// Use your custom store
ConfigSystem.bootstrap([
    .default: MyCustomStore(),
    .secure: .keychain
])
```

## Available Implementations

There is a ready-to-use ConfigStore implementation:

### Firebase Remote Config
- **Repository**: [swift-firebase-tools](https://github.com/dankinsoid/swift-firebase-tools)
- **Features**: Remote configuration management, A/B testing, real-time updates
- **Use case**: Server-controlled feature flags and configuration values

```swift
// Add to Package.swift
.package(url: "https://github.com/dankinsoid/swift-firebase-tools.git", from: "0.3.0")

// Usage
import FirebaseConfigs

ConfigSystem.bootstrap([
    .default: .userDefaults,
    .remote: .firebaseRemoteConfig
])
```

### Community Contributions

Want to add your own ConfigStore implementation? Consider contributing to the ecosystem by:

1. Creating a separate package with your store
2. Following the `ConfigStore` protocol
3. Adding comprehensive tests and documentation
4. Submitting your package for inclusion in this list

## Installation

### Swift Package Manager

Add SwiftConfigs to your `Package.swift`:

```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "YourProject",
    dependencies: [
        .package(url: "https://github.com/dankinsoid/swift-configs.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "YourProject", dependencies: ["SwiftConfigs"])
    ]
)
```

Or add it through Xcode:
1. Go to File → Add Package Dependencies
2. Enter: `https://github.com/dankinsoid/swift-configs.git`
3. Choose the version and add to your target

## Best Practices

1. **Define keys as computed properties** in `Configs.Keys` extensions for organization and discoverability using `ROConfigKey`/`RWConfigKey` type aliases
2. **Use namespaces for organization** - group related keys into `ConfigNamespaceKeys` types for compile-time structure
3. **Use appropriate categories** for different security and persistence needs
4. **Provide sensible defaults** for all configuration keys
5. **Use read-only keys (`ROConfigKey`)** when values shouldn't be modified at runtime
6. **Bootstrap the system early** in your app lifecycle before accessing any configuration
7. **Prefer category-based initialization** (`init(_:in:default:)`) over store-based for most use cases
8. **Use store-based initialization** (`init(_:store:default:)`) only when you need specific store targeting or before system bootstrap
9. **Use prefixing sparingly** - only add `keyPrefix` when you need it; most namespaces work fine with the default empty prefix
10. **Handle migration** using multiplex stores or custom migration logic
11. **Use property wrappers** for clean SwiftUI and declarative code integration
12. **Leverage async/await** for remote configuration fetching
13. **Use change observation** for reactive configuration updates

## Security Considerations

- Use **`.secure`** category for sensitive data (API tokens, passwords) - uses Keychain encryption
- Use **`.critical`** for maximum security with hardware-backed Secure Enclave protection
- Use **`.syncedSecure`** carefully - only for data that should be shared across devices via iCloud Keychain
- **Never log** configuration values that might contain sensitive data
- **Environment variables** are read-only and visible to the entire process and system
- **Keychain accessibility levels** control when encrypted data can be accessed (device locked/unlocked)
- **Biometric authentication** adds an extra layer of security for critical configuration data
- **iCloud sync** (`.ubiquitous`) has a 1MB total storage limit and is eventually consistent

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

SwiftConfigs is available under the MIT license. See the LICENSE file for more info.

## Author

**Daniil Voidilov**
- Email: voidilov@gmail.com
- GitHub: [@dankinsoid](https://github.com/dankinsoid)
