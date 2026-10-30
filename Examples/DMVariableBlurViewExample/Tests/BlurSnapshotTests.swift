import DMVariableBlurView
import SnapshotTesting
import UIKit
import XCTest

/// Pictures of the blur over the striped scene of `RenderingHarness`, compared with
/// references recorded on an iPhone 14 with iOS 17.5, an iPhone 16 with iOS 18.6 and an
/// iPhone 17 with iOS 26.5. CI compares the set of the iPhone 17 only.
///
/// The band tests decide on every OS whether a mode works. These tests catch a change of
/// the picture on the devices and OS versions that have references: the course of the transition, the
/// tint, the strength of the blur, and the system blur shown in place of the variable one,
/// which no band can tell from the full mode.
///
/// - **Names.** `<name>_<device>_ios<major>_<minor>` (`SnapshotReference`), in
///   `Examples/DMVariableBlurViewExample/Snapshots`. Every device and every OS has its own
///   references: iOS 26.5 draws four of the five scenes with 4 to 6 % of the pixels over
///   Delta E 2 against 17.5 and 18.6, which agree within 1.1.
/// - **Recording.** Locally a new device or OS records its references and fails once, and so
///   does a missing reference of a device and OS that has the others. CI never records: when
///   the variable `CI` is set (xcodebuild hands `TEST_RUNNER_CI` to the test process as `CI`),
///   a folder without any reference fails, because it moved or the tests run away from the
///   checkout, and a device and OS without references skip every test with a message that says
///   so, unless `SNAPSHOT_REFERENCES_REQUIRED` is `true`: the CI cell that compares the
///   snapshots sets it, and there a missing reference fails.
/// - **Tolerance.** A pixel matches when its colour is within a Delta E of 2 of the
///   reference, and 99 % of the pixels must match. The device that recorded a reference
///   renders it again byte for byte; another device of the same OS stayed within Delta E 2
///   in every pixel. On iOS 17.5 and 26.5 each of these faults puts at least 5 % of the
///   pixels over Delta E 2 and fails: the system blur in place of the variable blur, its
///   tint left visible, the top mode drawn as the bottom mode, a clear area 40 points
///   longer, a center band wider than asked, half the radius (except in the full mode,
///   where any radius flattens the stripes), edges not normalized, a blur 20 points
///   shorter, no blur. A mask one step of 255 lower stays under 1 % of the whole picture and
///   passes there; the focused picture of the end of the top ramp, rows 340 to 400, puts about
///   3 % of its pixels over Delta E 2 and fails.
/// - **Scale.** The capture has a scale of 1, so it does not show the scale the backdrop
///   renders at; the package tests pin that value.
final class BlurSnapshotTests: XCTestCase {
    private static let precision: Float = 0.99
    private static let perceptualPrecision: Float = 0.98

    @MainActor
    func test_snapshot_blurredTopClearBottom_matchesTheReference() throws {
        try assertMatchesReference(makeSUT(direction: .blurredTopClearBottom), named: "blurredTopClearBottom")
    }

    @MainActor
    func test_snapshot_blurredBottomClearTop_matchesTheReference() throws {
        try assertMatchesReference(makeSUT(direction: .blurredBottomClearTop), named: "blurredBottomClearTop")
    }

    @MainActor
    func test_snapshot_centerBandOfThirtyPercent_matchesTheReference() throws {
        let direction = DMVariableBlurDirection.blurredCenterClearTopBottom(centerBandProportion: 0.3)
        try assertMatchesReference(makeSUT(direction: direction), named: "centerBandOfThirtyPercent")
    }

    @MainActor
    func test_snapshot_blurredFully_matchesTheReference() throws {
        try assertMatchesReference(makeSUT(direction: .blurredFully), named: "blurredFully")
    }

    /// The configuration the DMUnLoader package shows behind its HUD.
    @MainActor
    func test_snapshot_configurationOfDMUnLoader_matchesTheReference() throws {
        let direction = DMVariableBlurDirection.blurredCenterClearTopBottom(centerBandProportion: 0.4)
        try assertMatchesReference(makeSUT(maxBlurRadius: 4, direction: direction), named: "configurationOfDMUnLoader")
    }

    /// The end of the ramp of the top mode, rows 340 to 400, where the blur fades out and the stripes
    /// come back. A fault that the whole picture lets through shows here: a mask one step of 255
    /// lower moves about 3 % of these pixels over Delta E 2, and about 0.5 % of the whole picture.
    @MainActor
    func test_snapshot_endOfTheTopModeRamp_matchesTheReference() throws {
        try assertMatchesReference(
            makeSUT(direction: .blurredTopClearBottom),
            named: "endOfTheTopModeRamp",
            rows: 340..<400
        )
    }

    // MARK: - Helpers

    private static var snapshotDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots", isDirectory: true)
    }

    private static var isCI: Bool {
        ProcessInfo.processInfo.environment["CI"] != nil
    }

    private static var referencesRequired: Bool {
        ProcessInfo.processInfo.environment["SNAPSHOT_REFERENCES_REQUIRED"] == "true"
    }

    @MainActor
    private func makeSUT(maxBlurRadius: CGFloat = 6, direction: DMVariableBlurDirection) -> DMVariableBlurView {
        DMVariableBlurView(maxBlurRadius: maxBlurRadius, direction: direction)
    }

    @MainActor
    private func assertMatchesReference(
        _ overlay: DMVariableBlurView,
        named base: String,
        rows: Range<Int>? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let reference = try SnapshotReference.current()
        if Self.isCI {
            try checkReferences(of: reference)
        }
        let scene = try RenderingHarness.render(overlay)
        let picture = try rows.map { try Self.crop(scene.image, to: $0) } ?? scene.image
        let failure = verifySnapshot(
            of: picture,
            as: .image(precision: Self.precision, perceptualPrecision: Self.perceptualPrecision, scale: 1),
            record: Self.isCI ? .never : .missing,
            snapshotDirectory: Self.snapshotDirectory.path,
            file: file,
            testName: reference.name(for: base),
            line: line
        )
        if let failure {
            XCTFail(failure, file: file, line: line)
        }
    }

    /// The rows of a picture, over its whole width.
    private static func crop(_ image: UIImage, to rows: Range<Int>) throws -> UIImage {
        let area = CGRect(x: 0, y: rows.lowerBound, width: Int(image.size.width), height: rows.count)
        guard let cropped = image.cgImage?.cropping(to: area) else {
            throw ReferenceError("The picture has no rows \(rows).")
        }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }

    /// A device and an OS with references compare all of them, so a deleted reference fails. A
    /// run without any is skipped, because CI never records one, unless the cell requires
    /// references. A folder without any reference fails.
    private func checkReferences(of reference: SnapshotReference) throws {
        let directory = Self.snapshotDirectory.path
        var files: [String] = []
        if FileManager.default.fileExists(atPath: directory) {
            files = try FileManager.default.contentsOfDirectory(atPath: directory)
        }
        switch reference.availability(among: files, in: directory, required: Self.referencesRequired) {
        case .compare:
            return
        case .skip(let message):
            throw XCTSkip(message)
        case .fail(let message):
            throw ReferenceError(message)
        }
    }
}

/// The references a run in CI needs are not there.
private struct ReferenceError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
