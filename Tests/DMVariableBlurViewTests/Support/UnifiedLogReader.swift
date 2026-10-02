import OSLog

/// Reads the lines this test process wrote to the unified log.
///
/// `OSLogStore(scope: .currentProcessIdentifier)` gives a process its own entries
/// (iOS 15 and later, https://developer.apple.com/documentation/oslog/oslogstore).
struct UnifiedLogReader {
    /// The subsystem under which the library writes.
    static let librarySubsystem = "DMVariableBlurView"

    private let start: Date

    /// Starts reading from now on: lines written before this call are not returned.
    init() {
        start = Date()
    }

    /// The lines of the library written since the reader was created.
    func libraryLines() throws -> [OSLogEntryLog] {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        return try store.getEntries(at: store.position(date: start))
            .compactMap { $0 as? OSLogEntryLog }
            .filter { $0.subsystem == Self.librarySubsystem }
    }
}
