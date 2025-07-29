
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
    var showAd: Key<UUID> { Key("show-ad", default: false) }
}
```

3. we need to create a Configs
```swift
let configs = Configs()
```

4. we're now ready to use it
```swift
let id = configs.userID
```

## The core concepts

### Configs
`Configs` are used to read configs and therefore the most important type in SwiftConfigs, so their use should be as simple as possible.

## On the implementation of a configs backend (a ConfigsHandler)
Note: If you don't want to implement a custom configs backend, everything in this section is probably not very relevant, so please feel free to skip.

To become a compatible configs backend that all SwiftConfigs consumers can use, you need to do two things: 
1. Implement a type (usually a struct) that implements ConfigsHandler, a protocol provided by SwiftConfigs
2. Instruct SwiftConfigs to use your configs backend implementation.

Instructing SwiftConfigs to use your configs backend as the one the whole application (including all libraries) should use is very simple:

```swift
ConfigsSystem.bootstrap(Myconfigs())
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
