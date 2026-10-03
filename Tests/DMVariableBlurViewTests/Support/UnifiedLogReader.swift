import Foundation
import OSLog

/// Reads the lines this test process wrote to the unified log.
///
/// `OSLogStore(scope: .currentProcessIdentifier)` gives a process its own entries
/// (iOS 15 and later). The reader writes a marker line when it is created and another one
/// when it reads, and returns the lines of the library between the two. It compares no
/// dates: the time stamp of an entry may lie a little before the wall clock of the moment
/// it was written, so a filter by date could drop a line written right after the start.
/// Entries reach the store with a delay, so the reader waits for its end marker.
struct UnifiedLogReader {
    enum ReaderError: Error {
        case markerNotFound(String)
    }

    /// The subsystem under which the library writes.
    static let librarySubsystem = "DMVariableBlurView"

    private static let markerCategory = "test-marker"
    private static let timeout: TimeInterval = 10

    private let beginMarker = UUID().uuidString
    /// Only a lower bound for the position the store starts reading at.
    private let searchStart = Date().addingTimeInterval(-60)

    /// Starts reading from now on: lines written before this call are not returned.
    init() {
        Self.writeMarker(beginMarker)
    }

    /// The lines of the library written since the reader was created.
    func libraryLines() throws -> [OSLogEntryLog] {
        let endMarker = UUID().uuidString
        Self.writeMarker(endMarker)
        let deadline = Date().addingTimeInterval(Self.timeout)
        repeat {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let lines = try store.getEntries(at: store.position(date: searchStart))
                .compactMap { $0 as? OSLogEntryLog }
                .filter { $0.subsystem == Self.librarySubsystem }
            if let begin = lines.firstIndex(where: { Self.isMarker($0, beginMarker) }),
               let end = lines.firstIndex(where: { Self.isMarker($0, endMarker) }),
               begin < end {
                return lines[lines.index(after: begin)..<end].filter { $0.category != Self.markerCategory }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        throw ReaderError.markerNotFound(endMarker)
    }

    private static func writeMarker(_ marker: String) {
        Logger(subsystem: librarySubsystem, category: markerCategory).notice("\(marker, privacy: .public)")
    }

    private static func isMarker(_ line: OSLogEntryLog, _ marker: String) -> Bool {
        line.category == markerCategory && line.composedMessage == marker
    }
}
