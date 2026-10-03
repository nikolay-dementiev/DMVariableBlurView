import DMVariableBlurView
import XCTest

/// The view cannot be made from an archive or a storyboard, and asking for it must not
/// stop the host.
final class BlurUIViewDecodingTests: XCTestCase {
    /// The initializer is unavailable to a direct call, so the test reaches it the way
    /// UIKit does: through `NSCoding`.
    @MainActor
    func test_blurUIView_decodedFromAnArchive_returnsNil() throws {
        let decoder = try makeSUT()
        let type: any NSCoding.Type = DMVariableBlurUIView.self

        XCTAssertNil(type.init(coder: decoder))
    }

    // MARK: - Helpers

    private func makeSUT() throws -> NSKeyedUnarchiver {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.finishEncoding()
        return try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
    }
}
