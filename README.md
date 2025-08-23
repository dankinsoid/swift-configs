# SwiftConfigs

SwiftConfigs provides a unified, type-safe API for small key-value storage systems where keys can be manually enumerated. The library abstracts storage implementation details behind a clean interface, making it easy to switch between different backends without changing application code.

## Features

- **Unified API for Small Key-Value Stores**: Works with UserDefaults, Keychain, environment variables, in-memory storage, and other enumerable key-value systems
- **Configuration Categories**: High-level abstraction that allows changing storage backends without modifying code that uses the values
- **Type Safety**: Full support for any `Codable` values out of the box with compile-time type checking
- **Flexible Key Configuration**: Individual keys can use specific handlers instead of abstract categories, allowing usage before system bootstrap
- **Easy Storage Migration**: Seamlessly migrate between different storage backends or individual key migrations
- **Test and Preview Support**: Automatically uses in-memory storage for SwiftUI previews and can be easily configured for testing
- **Per-Key Customization**: Each configuration key can have its own handler, transformer, or migration logic
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

    var apiToken: Key<String?, ReadWrite> {
        Key("api-token", in: .secure, default: nil)
    }

    var userID: Key<UUID, ReadOnly> { 
        Key("USER_ID", in: .syncedSecure, default: UUID(), cacheDefaultValue: true)
    }

    var serverURL: Key<String, ReadOnly> { 
        Key("SERVER_URL", in: .environments, default: "https://api.example.com")
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

// Write values (for ReadWrite Key only)
configs.apiToken = "new-token"
```

## Configuration Categories

SwiftConfigs organizes configuration data using categories, allowing you to store different types of settings in appropriate backends:

```swift
ConfigsSystem.bootstrap([
    .default: .userDefaults,           // General app settings
    .secure: .keychain,                // Sensitive data (tokens, passwords)
    .critical: .secureEnclave(),       // Maximum security with biometrics
    .syncedSecure: .keychain(iCloudSync: true), // Synced secure data
    .environments: .environments,       // Environment variables
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
- **`.environments`** - Environment variables
- **`.memory`** - In-memory storage
- **`.remote`** - Remote configuration cache

## Available Storage Handlers

### UserDefaults
```swift
.userDefaults                     // Standard UserDefaults
.userDefaults(suiteName: "group") // App group UserDefaults
```

### Keychain (iOS/macOS)
```swift
.keychain                        // Basic keychain storage
.keychain(iCloudSync: true)      // iCloud Keychain sync
.secureEnclave()                 // Secure Enclave with user presence
.biometricSecureEnclave()        // Secure Enclave with biometrics
.passcodeSecureEnclave()         // Secure Enclave with device passcode
```

### Other Handlers
```swift
.environments                  // Environment variables (read-only)
.inMemory                      // In-memory storage
.inMemory(["key": "value"])    // In-memory with initial values
.noop                          // No-operation handler
.multiple(handler1, handler2)  // Multiplex multiple handlers
.fallback(for: handler1, with: handler2) // Fallback to next handler if value not found, useful for migrations or debugging read only storages
```

## Property Wrapper API

Use property wrappers for inline configuration management:

```swift
struct AppSettings {

    @ReadOnlyConfig(\.userID) var userID
    
    @ReadWriteConfig("api-token", in: .secure) 
    var apiToken: String?
    
    @ReadWriteConfig("user-preferences", in: .default)
    var preferences: UserPreferences = UserPreferences()
}

let settings = AppSettings()
print(settings.userID)           // Read value
settings.apiToken = "new-token"  // Write value
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

```swift
let configs = Configs()

// Listen to all configuration changes
let cancellation = configs.listen { configs in
    print("Configurations updated")
}

// Listen to specific key changes  
let keyCancellation = configs.listen(\.apiToken) { newToken in
    print("API token changed: \(newToken)")
}

// Cancel when done
cancellation.cancel()
keyCancellation.cancel()
```

## Value Transformers

SwiftConfigs automatically handles common types:

```swift
public extension Configs.Keys {

    // String-convertible types
    var count: Key<Int, ReadOnly> { 
        Key("count", in: .default, default: 0)
    }

    var rate: Key<Double, ReadOnly> {
        Key("rate", in: .default, default: 1.0)
    }
    
    // Enum types
    var theme: Key<Theme, ReadOnly> { 
        Key("theme", in: .default, default: .light)
    }
    
    // Codable types (stored as JSON)
    var settings: Key<AppSettings, ReadOnly> {
        Key("settings", in: .default, default: AppSettings())
    }
    
    // Optional types
    var optionalValue: Key<String?, ReadOnly> {
        Key("optional", in: .default, default: nil)
    }
}
```

## Configuration Migration

Handle configuration schema changes gracefully:

```swift
public extension Configs.Keys {

    // Migrate from old boolean to new enum
    var notificationStyle: Key<NotificationStyle, ReadOnly> {
        .migraion(
            from: oldNotificationsEnabled,
            to: Key("notification-style", in: .default, default: .none)
        ) { oldValue in
            oldValue ? .all : .none
        }
    }
    
    private var oldNotificationsEnabled: Key<Bool, ReadOnly> {
        Key("notifications-enabled", in: .default, default: false)
    }
}
```

## Custom Configuration Handlers

You can create custom storage backends by implementing the `ConfigsHandler` protocol. See the protocol documentation for detailed implementation examples.

## Available Implementations

There is a ready-to-use ConfigsHandler implementation:

### Firebase Remote Config
- **Repository**: [swift-firebase-tools](https://github.com/dankinsoid/swift-firebase-tools)
- **Features**: Remote configuration management, A/B testing, real-time updates
- **Use case**: Server-controlled feature flags and configuration values

```swift
// Add to Package.swift
.package(url: "https://github.com/dankinsoid/swift-firebase-tools.git", from: "0.3.0")

// Usage
import FirebaseConfigs

ConfigsSystem.bootstrap([
    .default: .userDefaults,
    .remote: .firebaseRemoteConfig
])
```

### Community Contributions

Want to add your own ConfigsHandler implementation? Consider contributing to the ecosystem by:

1. Creating a separate package with your handler
2. Following the `ConfigsHandler` protocol
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

1. **Define keys in extensions** for organization and discoverability
2. **Use appropriate categories** for different security and persistence needs
3. **Provide sensible defaults** for all configuration keys
4. **Use read-only keys (`Key<Value, ReadOnly>`)** when values shouldn't be modified at runtime
5. **Bootstrap the system early** in your app lifecycle
6. **Handle migration** when changing configuration schemas
7. **Use property wrappers** for clean SwiftUI integration

## Security Considerations

- Use **`.secure`** category for sensitive data (API tokens, passwords)
- Use **`.critical`** for maximum security on supported devices
- **Never log** configuration values that might contain sensitive data
- Use **`.syncedSecure`** carefully - only for data that should be shared across devices
- **Environment variables** are read-only and visible to the process

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

SwiftConfigs is available under the MIT license. See the LICENSE file for more info.

## Author

**Daniil Voidilov**
- Email: voidilov@gmail.com
- GitHub: [@dankinsoid](https://github.com/dankinsoid)
