
# SwiftConfigs
SwiftConfigs is an API package which tries to establish a common API the ecosystem can use.
To make SwiftConfigs really work for real-world workloads, we need SwiftConfigs-compatible backends which load configs from the Ri

## Getting Started

### Let's read a config
1. let's import the SwiftConfigs API package
```swift
import SwiftConfigs
```

2. let's define a key
```swift
public extension Configs.Keys {
    var showAd: Key<Bool> { Key("show-ad", default: false) }
}
```

3. we need to create a Configs
```swift
let configs = Configs()
```

4. we're now ready to use it
```swift
let shouldShowAd = configs.showAd
```

## The core concepts

### Configs
`Configs` are used to read configs and therefore the most important type in SwiftConfigs, so their use should be as simple as possible.

### Categories
Categories allow you to save different keys in different storages without direct access to the handler. This enables you to organize your configuration data by security level, persistence requirements, or other criteria.

You can bootstrap SwiftConfigs with different handlers for different categories:

```swift
ConfigsSystem.bootstrap(
    [
        .secure: .keychain,
        .secureSynced: .keychain(iCloudSync: true),
        .environment: .environment,
        .default: .userDefaults,
        .synced: .ubiquitous,
    ]
)
```

### Available Handlers
SwiftConfigs provides several built-in configuration handlers:

- **`.userDefaults`** - Stores configurations in UserDefaults
- **`.keychain`** - Stores configurations in Keychain
- **`.keychain(iCloudSync: true)`** - Stores configurations in Keychain with iCloud sync
- **`.environment`** - Reads configurations from environment variables (read-only)
- **`.ubiquitous`** - Stores configurations in iCloud key-value store (Apple platforms only)
- **`.inMemory`** - Stores configurations in memory
- **`.noop`** - No-operation handler
- **`.multiple(...)`** - Combines multiple handlers for different categories
- **`.fallback(read:write:)`** - Reads from one handler with fallback to another, writes to one handler only

#### Defining Keys with Categories

You can define keys that automatically use specific categories by specifying the `from` parameter:

```swift
public extension Configs.Keys {
    // Uses .default category (UserDefaults)
    var showAds: Key<Bool> { Key("show-ads", default: false) }
    
    // Uses .secure category (Keychain)
    var apiToken: Key<String> { Key("api-token", from: .secure, default: "") }
    
    // Uses .environment category (Environment Variables)
    var serverURL: Key<String> { Key("SERVER_URL", from: .environment, default: "https://api.example.com") }
    
    // Uses .remote category (iCloud key-value store)
    var userPreferences: Key<UserPreferences> { Key("user-preferences", from: .remote, default: []) }
    
    // Writable key with different read/write categories
    var userSetting: WritableKey<[Setting]> { 
        WritableKey("user-setting", from: .remote, to: .remote, default: []) 
    }
}
```

When you access these keys, they automatically use the appropriate storage:

```swift
let configs = Configs()

// Reads from UserDefaults
let showAds = configs.showAds

// Reads from Keychain
let token = configs.apiToken

// Reads from environment variables
let serverURL = configs.serverURL

// Reads from iCloud key-value store
let preferences = configs.userPreferences

// Can read from remote, write to local
configs.userSetting = "new value"
```

## On the implementation of a configs backend (a ConfigsHandler)
Note: If you don't want to implement a custom configs backend, everything in this section is probably not very relevant, so please feel free to skip.

To become a compatible configs backend that all SwiftConfigs consumers can use, you need to do two things: 
1. Implement a type (usually a struct) that implements ConfigsHandler, a protocol provided by SwiftConfigs
2. Instruct SwiftConfigs to use your configs backend implementation.

Instructing SwiftConfigs to use your configs backend as the one the whole application (including all libraries) should use is very simple:

```swift
ConfigsSystem.bootstrap(MyConfigs())
```

Or with categories:

```swift
ConfigsSystem.bootstrap([
    .default: .userDefaults,
    .secure: MySecureConfigs()
])
```

## Installation

1. [Swift Package Manager](https://github.com/apple/swift-package-manager)

Create a `Package.swift` file.
```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
  name: "SomeProject",
  dependencies: [
    .package(url: "https://github.com/dankinsoid/swift-configs.git", from: "0.10.0")
  ],
  targets: [
    .target(name: "SomeProject", dependencies: ["SwiftConfigs"])
  ]
)
```
```ruby
$ swift build
```

## Implementations
There are a few implementations of ConfigsHandler that you can use in your application:

- [Firebase Remote Configs](https://github.com/dankinsoid/swift-firebase-tools)

## Author

dankinsoid, voidilov@gmail.com

## License

swift-configs is available under the MIT license. See the LICENSE file for more info.
