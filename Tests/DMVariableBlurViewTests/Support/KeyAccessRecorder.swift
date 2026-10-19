import Foundation

/// A harmless stand-in for a filter that a host, or a later system, could leave alone on the
/// backdrop of a blur view.
///
/// It records the keys that are asked of it and the keys that are set on it. For a key it does
/// not define, `NSObject` raises `NSUndefinedKeyException`: the documentation of
/// `value(forUndefinedKey:)` and of `setValue(_:forUndefinedKey:)` says that the default
/// implementation does, and that a subclass may override the method. The exception cannot be
/// caught from Swift, and in a test it would end the whole run, so the recorder answers `nil`
/// and the test reads what was asked.
final class KeyAccessRecorder: NSObject {
    private(set) var readKeys: [String] = []
    private(set) var writtenKeys: [String] = []

    override func value(forUndefinedKey key: String) -> Any? {
        readKeys.append(key)
        return nil
    }

    override func setValue(_ value: Any?, forUndefinedKey key: String) {
        writtenKeys.append(key)
    }
}
