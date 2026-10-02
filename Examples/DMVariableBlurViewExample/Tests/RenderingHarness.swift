import SwiftUI
import UIKit
import XCTest

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
    case notReady(reference: Double, drew: Bool)

    var description: String {
        switch self {
        case .noForegroundScene:
            "the host app has no foreground window scene"
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
///   The harness captures until the reference strip is sharp and two captures in a row
///   agree, and throws when that does not happen within its attempts.
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
    private static let pause: TimeInterval = 0.05
    private static let agreement = 0.02

    static func render(_ overlay: some View) throws -> RenderedScene {
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
        window.isHidden = false
        defer { window.isHidden = true }

        var previous: [Double]?
        var lastReference = 0.0
        var lastDrew = false
        for _ in 0..<attempts {
            RunLoop.main.run(until: Date().addingTimeInterval(pause))
            let (image, drew) = capture(window)
            let rows = rowContrast(of: image)
            let reference = mean(of: rows, from: 415, to: 435)
            lastReference = reference
            lastDrew = drew
            guard drew, reference >= minimumReference else {
                previous = nil
                continue
            }
            let bandHeight = Int(overlayHeight) / bandCount
            let bands = (0..<bandCount).map { band in
                mean(of: rows, from: band * bandHeight, to: (band + 1) * bandHeight) / reference
            }
            if let previous, zip(previous, bands).allSatisfy({ abs($0 - $1) <= agreement }) {
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

    /// The contrast of every pixel row of the image, top row first.
    private static func rowContrast(of image: UIImage) -> [Double] {
        guard let cgImage = image.cgImage else { return [] }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn, width > 1 else { return [] }
        return (0..<height).map { row in
            var total = 0
            for column in 0..<(width - 1) {
                let left = Int(pixels[(row * width + column) * 4])
                let right = Int(pixels[(row * width + column + 1) * 4])
                total += abs(left - right)
            }
            return Double(total) / Double(width - 1)
        }
    }

    private static func mean(of rows: [Double], from start: Int, to end: Int) -> Double {
        let slice = rows[min(start, rows.count)..<min(end, rows.count)]
        return slice.isEmpty ? 0 : slice.reduce(0, +) / Double(slice.count)
    }
}
