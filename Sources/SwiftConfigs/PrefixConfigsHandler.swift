import Foundation

/// A ConfigsHandler that wraps another handler and adds a prefix to all keys
public struct PrefixConfigsHandler: ConfigsHandler {
    private let underlyingHandler: ConfigsHandler
    private let prefix: String
    
    /// Creates a prefix handler that adds a prefix to all keys
    /// - Parameters:
    ///   - prefix: The prefix to add to all keys
    ///   - handler: The underlying handler to wrap
    public init(prefix: String, handler: ConfigsHandler) {
        self.prefix = prefix
        self.underlyingHandler = handler
    }
    
    private func prefixedKey(_ key: String) -> String {
        return prefix + key
    }
    
    private func unprefixedKey(_ prefixedKey: String) -> String? {
        guard prefixedKey.hasPrefix(prefix) else { return nil }
        return String(prefixedKey.dropFirst(prefix.count))
    }
    
    public func value(for key: String) -> String? {
        return underlyingHandler.value(for: prefixedKey(key))
    }
    
    public func fetch(completion: @escaping (Error?) -> Void) {
        underlyingHandler.fetch(completion: completion)
    }
    
    public func listen(_ listener: @escaping () -> Void) -> ConfigsCancellation? {
        return underlyingHandler.listen(listener)
    }
    
    public func writeValue(_ value: String?, for key: String) throws {
        try underlyingHandler.writeValue(value, for: prefixedKey(key))
    }
    
    public func clear() throws {
        // Only clear keys with our prefix
        guard let allKeys = underlyingHandler.allKeys() else {
            throw Unsupported()
        }
        
        for key in allKeys where key.hasPrefix(prefix) {
            try underlyingHandler.writeValue(nil, for: key)
        }
    }
    
    public func allKeys() -> Set<String>? {
        guard let allKeys = underlyingHandler.allKeys() else { return nil }
        
        return Set(allKeys.compactMap { prefixedKey in
            unprefixedKey(prefixedKey)
        })
    }
    
    public var supportWriting: Bool {
        return underlyingHandler.supportWriting
    }
}

public extension ConfigsHandler where Self == PrefixConfigsHandler {

    /// Creates a prefix configs handler that adds a prefix to all keys
    /// - Parameters:
    ///   - prefix: The prefix to add to all keys
    ///   - handler: The underlying handler to wrap
    static func prefix(_ prefix: String, handler: ConfigsHandler) -> PrefixConfigsHandler {
        PrefixConfigsHandler(prefix: prefix, handler: handler)
    }
}
