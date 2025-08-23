# SwiftConfigs

SwiftConfigs is a Swift package that provides a unified API for configuration management across different storage backends. It supports various storage options including UserDefaults, Keychain, environment variables, in-memory storage, and more, with a clean, type-safe interface.

## Features

- **Type-safe configuration keys** with compile-time validation
- **Multiple storage backends** (UserDefaults, Keychain, Environment Variables, etc.)
- **Configuration categories** for organizing different types of settings
- **Secure Enclave support** for maximum security on supported devices
- **Async/await support** for modern Swift concurrency
- **Property wrapper APIs** for SwiftUI-style usage
- **Migration utilities** for evolving configuration schemas
- **Listening for changes** with cancellable subscriptions

## Getting Started

### 1. Import SwiftConfigs

```swift
import SwiftConfigs
```

### 2. Define Configuration Keys

```swift
public extension Configs.Keys {
    var showAds: Key<Bool, ReadOnly> { Key("show-ads", in: .default, default: false) }
    var apiToken: Key<String, ReadWrite> { Key("api-token", in: .secure, default: "") }
    var serverURL: Key<String, ReadOnly> { Key("SERVER_URL", in: .environments, default: "https://api.example.com") }
}
```

> **Note**: The full `Key<Value, Permission>` syntax is now used instead of the previous `ROKey` and `RWKey` type aliases for better clarity and explicitness.

### 3. Create a Configs Instance

```swift
let configs = Configs()
```

### 4. Use Your Configuration

```swift
// Read values
let shouldShowAds = configs.showAds
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
    .secureEnclave: .secureEnclave(),  // Maximum security with biometrics
    .syncedSecure: .keychain(iCloudSync: true), // Synced secure data
    .environments: .environments,       // Environment variables
    .memory: .inMemory,                // Temporary/testing data
    .remote: .userDefaults             // Remote configuration cache
])
```

### Built-in Categories

- **`.default`** - General application settings (UserDefaults)
- **`.secure`** - Sensitive data requiring encryption (Keychain)
- **`.secureEnclave`** - Maximum security with hardware protection
- **`.syncedSecure`** - Secure data synced across devices (iCloud Keychain)
- **`.environments`** - Environment variables (read-only)
- **`.memory`** - In-memory storage for testing
- **`.remote`** - Remote configuration cache

## Available Storage Handlers

### UserDefaults
```swift
.userDefaults                    // Standard UserDefaults
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
.environments                    // Environment variables (read-only)
.inMemory                        // In-memory storage
.inMemory(["key": "value"])      // In-memory with initial values
.noop                           // No-operation handler
.multiple([handler1, handler2])  // Multiplex multiple handlers
```

## Property Wrapper API

Use property wrappers for SwiftUI-style configuration management:

```swift
struct AppSettings {
    @ROConfig("show-ads", in: .default)
    var showAds: Bool = false
    
    @RWConfig("api-token", in: .secure) 
    var apiToken: String = ""
    
    @RWConfig("user-preferences", in: .default)
    var preferences: UserPreferences = UserPreferences()
}

let settings = AppSettings()
print(settings.showAds)          // Read value
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
let cancellation = configs.listen { updatedConfigs in
    print("Configurations updated")
}

// Listen to specific key changes  
let keyCancellation = configs.listen(configs.apiToken) { newToken in
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
    var count: Key<Int, ReadOnly> { Key("count", in: .default, default: 0) }
    var rate: Key<Double, ReadOnly> { Key("rate", in: .default, default: 1.0) }
    
    // Enum types
    var theme: Key<Theme, ReadOnly> { Key("theme", in: .default, default: .light) }
    
    // Codable types (stored as JSON)
    var settings: Key<AppSettings, ReadOnly> { Key("settings", in: .default, default: AppSettings()) }
    
    // Optional types
    var optionalValue: Key<String?, ReadOnly> { Key("optional", in: .default, default: nil) }
}
```

## Configuration Migration

Handle configuration schema changes gracefully:

```swift
public extension Configs.Keys {
    // Migrate from old boolean to new enum
    var notificationStyle: Key<NotificationStyle, ReadOnly> {
        Key.migraion(
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

Implement `ConfigsHandler` protocol for custom storage backends:

```swift
public struct RedisConfigsHandler: ConfigsHandler {
    public var supportWriting: Bool { true }
    
    public func fetch(completion: @escaping (Error?) -> Void) {
        // Implement Redis fetch logic
    }
    
    public func value(for key: String) -> String? {
        // Implement Redis get logic
    }
    
    public func writeValue(_ value: String?, for key: String) throws {
        // Implement Redis set logic
    }
    
    public func listen(_ listener: @escaping () -> Void) -> ConfigsCancellation? {
        // Implement Redis pub/sub logic
    }
    
    public func clear() throws {
        // Implement Redis clear logic
    }
    
    public func allKeys() -> Set<String>? {
        // Implement Redis keys logic
    }
}

// Bootstrap with custom handler
ConfigsSystem.bootstrap([
    .default: .userDefaults,
    .remote: RedisConfigsHandler()
])
```

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
- Use **`.secureEnclave`** for maximum security on supported devices
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
