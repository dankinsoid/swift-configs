import Foundation

extension ConfigKey {

    /// Creates a configuration key that always returns a constant value and does not support writing or listening
    /// - Parameters:
    ///   - name: The name of the configuration key
    ///   - value: The constant value to return
    /// - Returns: A configuration key that always returns the specified constant value
    public static func constant(
        _ name: String,
        _ value: Value
    ) -> Self {
        Self.init(name) { _ in
            value
        } set: { _, _ in
        } remove: { _ in
        } exists: { _ in
            false
        } onChange: { _, _ in
            Cancellation {}
        }
    }
}
