import Foundation

/// A harmless stand-in for a filter that a host, or a later system, could leave alone on the
/// backdrop of a blur view.
///
/// It records the keys that are asked of it. A real object without the key raises
/// `NSUndefinedKeyException`, which a test cannot survive and the library cannot catch, so the
/// recorder answers `nil` instead and the test reads what was asked.
final class KeyReadRecorder: NSObject {
    private(set) var readKeys: [String] = []

    override func value(forUndefinedKey key: String) -> Any? {
        readKeys.append(key)
        return nil
    }
}
