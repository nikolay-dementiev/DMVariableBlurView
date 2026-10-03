import DMVariableBlurView
import SnapshotTesting
import XCTest

/// Pictures of the blur over the striped scene of `RenderingHarness`, compared with
/// references recorded on iOS 17.5, 18.6 and 26.5.
///
/// The band tests decide on every OS whether a mode works. These tests catch a change of
/// the picture on the runtimes that have references: the course of the transition, the
/// tint, the strength of the blur, and the system blur shown in place of the variable one,
/// which no band can tell from the full mode.
///
/// - **Names.** `<name>_ios<major>_<minor>`, in `Examples/DMVariableBlurViewExample/Snapshots`.
///   Every runtime has its own references: iOS 26.5 draws four of the five scenes with 4
///   to 6 % of the pixels over Delta E 2 against 17.5 and 18.6, which agree within 1.1.
/// - **Recording.** Locally a missing reference is recorded and its test fails once. When
///   the variable `CI` is set (xcodebuild hands `TEST_RUNNER_CI` to the test process as
///   `CI`) nothing is recorded. A folder without any reference fails: it moved, or the
///   tests run away from the checkout. A runtime without references skips every test with
///   a message that says so, unless `SNAPSHOT_REFERENCES_REQUIRED` is `true`: the CI cell
///   that compares the snapshots sets it, and there a missing reference fails.
/// - **Tolerance.** A pixel matches when its colour is within a Delta E of 2 of the
///   reference, and 99 % of the pixels must match. The device that recorded a reference
///   renders it again byte for byte; another device of the same OS stayed within Delta E 2
///   in every pixel. On iOS 17.5 and 26.5 each of these faults puts at least 5 % of the
///   pixels over Delta E 2 and fails: the system blur in place of the variable blur, its
///   tint left visible, the top mode drawn as the bottom mode, a clear area 40 points
///   longer, a center band wider than asked, half the radius (except in the full mode,
///   where any radius flattens the stripes), edges not normalized, a blur 20 points
///   shorter, no blur. A mask one step of 255 lower stays under 1 % and passes.
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

    // MARK: - Helpers

    private static var snapshotDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots", isDirectory: true)
    }

    private static var runtimeSuffix: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "_ios\(version.majorVersion)_\(version.minorVersion)"
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
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        if Self.isCI {
            try checkReferencesForThisRuntime()
        }
        let scene = try RenderingHarness.render(overlay)
        let failure = verifySnapshot(
            of: scene.image,
            as: .image(precision: Self.precision, perceptualPrecision: Self.perceptualPrecision, scale: 1),
            record: Self.isCI ? .never : .missing,
            snapshotDirectory: Self.snapshotDirectory.path,
            file: file,
            testName: base + Self.runtimeSuffix,
            line: line
        )
        if let failure {
            XCTFail(failure, file: file, line: line)
        }
    }

    /// A runtime with references compares all of them, so a deleted reference fails. A
    /// runtime without any is skipped, because CI never records one, unless the cell
    /// requires references. A folder without any reference fails.
    private func checkReferencesForThisRuntime() throws {
        let directory = Self.snapshotDirectory.path
        var references: [String] = []
        if FileManager.default.fileExists(atPath: directory) {
            references = try FileManager.default.contentsOfDirectory(atPath: directory)
                .filter { $0.hasSuffix(".png") }
        }
        guard !references.isEmpty else {
            throw ReferenceError(
                "No snapshot reference at all in \(directory): the folder moved, or the tests "
                    + "run away from the checkout."
            )
        }
        guard references.contains(where: { $0.contains("\(Self.runtimeSuffix).") }) else {
            let missing = "No snapshot references for this runtime (\(Self.runtimeSuffix)) in \(directory)."
            if Self.referencesRequired {
                throw ReferenceError(missing + " This run requires them: record them on this runtime.")
            }
            throw XCTSkip(missing + " CI does not record them; the band tests cover this runtime.")
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
