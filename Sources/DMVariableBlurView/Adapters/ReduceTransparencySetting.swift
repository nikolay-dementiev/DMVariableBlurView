import UIKit

/// The Reduce Transparency setting of the device.
@MainActor
package protocol ReduceTransparencySetting {
    /// Whether the user turned Reduce Transparency on.
    var isEnabled: Bool { get }

    /// Calls `handler` after each change of the setting, for as long as this object lives.
    func onChange(_ handler: @escaping @MainActor () -> Void)
}

/// The setting as UIKit reports it.
package final class SystemReduceTransparencySetting: NSObject, ReduceTransparencySetting {
    private var handlers: [@MainActor () -> Void] = []

    nonisolated override package init() {
        super.init()
        // The system removes an observer that uses a selector when the observer goes away.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusDidChange),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
    }

    package var isEnabled: Bool {
        UIAccessibility.isReduceTransparencyEnabled
    }

    package func onChange(_ handler: @escaping @MainActor () -> Void) {
        handlers.append(handler)
    }

    @objc
    private func statusDidChange() {
        handlers.forEach { $0() }
    }
}
