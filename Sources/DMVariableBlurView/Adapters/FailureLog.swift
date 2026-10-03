import os

/// Writes down why a blur view shows the plain blur of the system.
package protocol FailureLog {
    /// - Parameters:
    ///   - error: The reason, as a host would receive it.
    ///   - detail: What the library knows beyond the reason, for example what the system
    ///     answered. For a developer, never shown to a user.
    func record(_ error: DMVariableBlurError, detail: String?)
}

/// The unified log of the system, one line at error level per failure, under the
/// subsystem `DMVariableBlurView`.
package struct SystemFailureLog: FailureLog {
    private let logger = Logger(subsystem: "DMVariableBlurView", category: "failure")

    package init() {}

    package func record(_ error: DMVariableBlurError, detail: String?) {
        // Every text is the library's own: the description and the detail name values and
        // states, never data of the host. Interpolated strings are private in the unified log
        // unless they are marked public.
        let description = error.errorDescription ?? String(describing: error)
        let consequence = "The view shows the plain blur of the system, or no blur while the host has removed its effect."
        if let detail {
            logger.error(
                "\(description, privacy: .public). \(consequence, privacy: .public) Detail: \(detail, privacy: .public)"
            )
        } else {
            logger.error("\(description, privacy: .public). \(consequence, privacy: .public)")
        }
    }
}
