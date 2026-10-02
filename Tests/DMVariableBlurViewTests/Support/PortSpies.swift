import DMVariableBlurView
import UIKit
import XCTest

/// Records what a blur view asks its installer to do and answers with a prepared outcome.
///
/// It stands in for the installer port of the library, not for a system interface, and
/// answers only with outcomes the real installer can give.
@MainActor
final class VariableBlurInstallerSpy: VariableBlurInstaller {
    struct Installation {
        let maxBlurRadius: CGFloat
        let mask: CGImage
        let effectView: ObjectIdentifier
    }

    struct ScaleUpdate: Equatable {
        let scale: CGFloat
        let effectView: ObjectIdentifier
    }

    private(set) var installations: [Installation] = []
    private(set) var scaleUpdates: [ScaleUpdate] = []
    var outcome: VariableBlurInstallation = .installed
    /// What the spy answers when the view asks whether its blur is still on.
    var blurIsStillInstalled = true

    func install(maxBlurRadius: CGFloat, mask: CGImage, on effectView: UIVisualEffectView) -> VariableBlurInstallation {
        installations.append(
            Installation(maxBlurRadius: maxBlurRadius, mask: mask, effectView: ObjectIdentifier(effectView))
        )
        return outcome
    }

    func isInstalled(maxBlurRadius: CGFloat, mask: CGImage, on effectView: UIVisualEffectView) -> Bool {
        blurIsStillInstalled
    }

    func setBackdropScale(_ scale: CGFloat, on effectView: UIVisualEffectView) {
        scaleUpdates.append(ScaleUpdate(scale: scale, effectView: ObjectIdentifier(effectView)))
    }
}

/// Records the profiles a blur view asks for and answers with a prepared image or error.
final class MaskImageRendererSpy: MaskImageRenderer {
    private(set) var profiles: [BlurMaskProfile] = []
    private let result: Result<CGImage, any Error>

    init(result: Result<CGImage, any Error>) {
        self.result = result
    }

    func makeMaskImage(for profile: BlurMaskProfile) throws -> CGImage {
        profiles.append(profile)
        return try result.get()
    }
}

/// Records the failures a blur view writes to its log.
final class FailureLogSpy: FailureLog {
    struct Entry: Equatable {
        let error: DMVariableBlurError
        let detail: String?
    }

    private(set) var entries: [Entry] = []

    func record(_ error: DMVariableBlurError, detail: String?) {
        entries.append(Entry(error: error, detail: detail))
    }
}

extension XCTestCase {
    /// A one-pixel image that stands for a rendered mask.
    func makeMaskImage(file: StaticString = #filePath, line: UInt = #line) throws -> CGImage {
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            file: file,
            line: line
        )
        return try XCTUnwrap(context.makeImage(), file: file, line: line)
    }
}
