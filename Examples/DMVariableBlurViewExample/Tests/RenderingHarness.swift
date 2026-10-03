import SwiftUI
import UIKit

/// What the harness measured in one rendered scene.
struct RenderedScene {
    /// Contrast of twenty equal bands of the overlay area, top to bottom, relative to the
    /// reference strip: 1 is as sharp as the bare stripes, 0 is flat.
    let bands: [Double]
    /// Raw contrast of the reference strip. Bare two-point stripes measure about 125.
    let reference: Double
    let image: UIImage

    var summary: String {
        let values = bands.map { String(format: "%.2f", $0) }.joined(separator: " ")
        return "bands top to bottom: \(values) | reference \(String(format: "%.1f", reference))"
    }
}

enum RenderingHarnessError: Error, CustomStringConvertible {
    case noForegroundScene
    case noPixels
    case notReady(reference: Double, drew: Bool)

    var description: String {
        switch self {
        case .noForegroundScene:
            "the host app has no foreground window scene"
        case .noPixels:
            "the capture of the window has no pixels"
        case let .notReady(reference, drew):
            "the scene never became stable: drawHierarchy=\(drew), reference contrast \(reference)"
        }
    }
}

/// Renders a SwiftUI overlay above a striped background in a window of the host app and
/// measures how sharp each part of the result is.
///
/// The contract of the harness:
/// - **Scene.** 200 x 440 points. The overlay under test covers the top 400 points. The
///   bottom 40 points are a reference strip that nothing covers.
/// - **Capture.** `drawHierarchy(in:afterScreenUpdates:)` into an 8-bit sRGB image at
///   scale 1. It needs a window in a foreground scene of a host app: in a package test
///   process it returns `false`, and `CALayer.render(in:)` never includes a backdrop filter.
/// - **Contrast.** For a row of pixels: the mean absolute difference of the red channel
///   between horizontal neighbours. For a band: the mean over its rows, divided by the
///   same measure of the reference strip.
/// - **Readiness.** The render server draws the backdrop after the window is on screen.
///   The harness captures until the reference strip is sharp and three captures in a row
///   agree, which takes at least 0.3 seconds, and throws when that does not happen within
///   its attempts. A backdrop that appears later than that makes a blur test fail with the
///   captured image attached. It cannot make one pass.
/// - **A change.** `render(_:then:)` can change the window after the first stable scene,
///   for example its appearance, and measures the scene that follows the change. The
///   window starts in the light appearance whatever the simulator is set to, so a switch
///   to dark is a change there too.
/// - **Failure.** `RenderedScene` carries the image and the band values, and the tests
///   attach both when an assertion fails.
@MainActor
enum RenderingHarness {
    static let sceneSize = CGSize(width: 200, height: 440)
    static let overlayHeight: CGFloat = 400
    static let bandCount = 20

    /// A capture is trusted only when the reference strip shows bare stripes. They measure
    /// about 125; a blank capture measures 0.
    static let minimumReference = 100.0

    private static let attempts = 60
    private static let pause: TimeInterval = 0.1
    private static let agreement = 0.02
    /// Captures in a row that must agree before the scene counts as rendered.
    private static let agreeingCaptures = 3

    /// The measured rows of the reference strip. They keep clear of the overlay above the
    /// strip and of the edge of the window below it.
    private static var referenceRows: Range<Int> {
        (Int(overlayHeight) + 15)..<(Int(sceneSize.height) - 5)
    }

    static func render(_ overlay: some View, then change: ((UIWindow) -> Void)? = nil) throws -> RenderedScene {
        let window = UIWindow(windowScene: try foregroundScene())
        window.frame = CGRect(origin: .zero, size: sceneSize)
        let content = ZStack(alignment: .top) {
            StripedBackground()
            overlay.frame(height: overlayHeight)
        }
        .frame(width: sceneSize.width, height: sceneSize.height)
        let controller = UIHostingController(rootView: content)
        controller.safeAreaRegions = []
        window.rootViewController = controller
        window.overrideUserInterfaceStyle = .light
        window.isHidden = false
        defer { window.isHidden = true }

        let scene = try stableScene(in: window)
        guard let change else { return scene }
        change(window)
        return try stableScene(in: window)
    }

    private static func stableScene(in window: UIWindow) throws -> RenderedScene {
        var previous: [Double]?
        var agreed = 0
        var lastReference = 0.0
        var lastDrew = false
        for _ in 0..<attempts {
            RunLoop.main.run(until: Date().addingTimeInterval(pause))
            let (image, drew) = capture(window)
            guard let pixels = image.cgImage else {
                throw RenderingHarnessError.noPixels
            }
            let rows = try BandAnalysis.rowContrast(of: pixels)
            let reference = BandAnalysis.mean(of: rows, from: referenceRows.lowerBound, to: referenceRows.upperBound)
            lastReference = reference
            lastDrew = drew
            guard drew, reference >= minimumReference else {
                previous = nil
                continue
            }
            let bands = BandAnalysis.bands(
                of: rows,
                from: 0,
                to: Int(overlayHeight),
                count: bandCount,
                reference: reference
            )
            if let previous, zip(previous, bands).allSatisfy({ abs($0 - $1) <= agreement }) {
                agreed += 1
            } else {
                agreed = 1
            }
            if agreed >= agreeingCaptures {
                return RenderedScene(bands: bands, reference: reference, image: image)
            }
            previous = bands
        }
        throw RenderingHarnessError.notReady(reference: lastReference, drew: lastDrew)
    }

    private static func foregroundScene() throws -> UIWindowScene {
        for _ in 0..<attempts {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let scene = scenes.first(where: { $0.activationState == .foregroundActive }) {
                return scene
            }
            RunLoop.main.run(until: Date().addingTimeInterval(pause))
        }
        throw RenderingHarnessError.noForegroundScene
    }

    private static func capture(_ window: UIWindow) -> (UIImage, Bool) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        var drew = false
        let image = UIGraphicsImageRenderer(size: sceneSize, format: format).image { _ in
            drew = window.drawHierarchy(in: CGRect(origin: .zero, size: sceneSize), afterScreenUpdates: true)
        }
        return (image, drew)
    }
}
