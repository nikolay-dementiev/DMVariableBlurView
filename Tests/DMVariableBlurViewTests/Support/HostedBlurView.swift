import DMVariableBlurView
import SwiftUI
import UIKit
import XCTest

/// A blur view hosted in a window, with access to what the library installed on it.
///
/// The accessors read the private structure the library itself depends on: the backdrop
/// layer of the effect view and the keys of its filter. That is deliberate. When a system
/// update changes that structure the library stops working, and these tests are the first
/// to say so.
@MainActor
struct HostedBlurView {
    let blurView: DMVariableBlurUIView
    let window: UIWindow
    private let controller: UIHostingController<AnyView>

    init(_ view: some View, file: StaticString = #filePath, line: UInt = #line) throws {
        // The root view is type-erased so that update(_:) can replace it. Views of the same
        // type keep their identity inside AnyView, so SwiftUI updates the existing view.
        let controller = UIHostingController(rootView: AnyView(view))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        do {
            blurView = try XCTUnwrap(
                Self.firstBlurView(in: controller.view),
                "the SwiftUI view created no DMVariableBlurUIView",
                file: file,
                line: line
            )
        } catch {
            // No caller holds the window yet, so nobody else can take it off the screen.
            window.isHidden = true
            throw error
        }
        self.window = window
        self.controller = controller
    }

    /// Hands SwiftUI a new value of the hosted view, as a state change in a host would, and
    /// lays the window out.
    ///
    /// - Returns: The blur view in the hierarchy after the update.
    func update(_ view: some View, file: StaticString = #filePath, line: UInt = #line) throws -> DMVariableBlurUIView {
        controller.rootView = AnyView(view)
        window.layoutIfNeeded()
        return try XCTUnwrap(
            Self.firstBlurView(in: controller.view),
            "the SwiftUI view has no DMVariableBlurUIView after the update",
            file: file,
            line: line
        )
    }

    /// The types of the filters on the backdrop layer, in order.
    var filterTypes: [String] {
        filters.map { ($0.value(forKey: "type") as? String) ?? "unknown" }
    }

    /// The maximum radius the variable blur filter carries.
    var radius: CGFloat? {
        (variableBlurFilter?.value(forKey: "inputRadius") as? NSNumber).map { CGFloat($0.doubleValue) }
    }

    /// The alpha of every other subview of the effect view: its tint and dimming.
    var tintAlphas: [CGFloat] {
        blurView.subviews.dropFirst().map(\.alpha)
    }

    var backdropScale: CGFloat? {
        (blurView.subviews.first?.layer.value(forKey: "scale") as? NSNumber).map { CGFloat($0.doubleValue) }
    }

    /// The alpha of every row of the mask image, top row first.
    var maskAlphaProfile: [UInt8]? {
        guard let value = variableBlurFilter?.value(forKey: "inputMaskImage") else { return nil }
        let object = value as AnyObject
        // A conditional cast to a Core Foundation type always succeeds, so the type
        // identifier is what proves that the value is an image.
        guard CFGetTypeID(object) == CGImage.typeID else { return nil }
        let image = unsafeDowncast(object, to: CGImage.self)
        let width = image.width
        let height = image.height
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
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        let column = width / 2
        return (0..<height).map { pixels[($0 * width + column) * 4 + 3] }
    }

    func hide() {
        window.isHidden = true
    }

    /// Takes the hosted views out of the window at once. SwiftUI would remove a view from
    /// its hierarchy only in a later turn of the main run loop.
    func removeFromWindow() {
        window.rootViewController = nil
    }

    private var filters: [NSObject] {
        (blurView.subviews.first?.layer.filters ?? []).compactMap { $0 as? NSObject }
    }

    private var variableBlurFilter: NSObject? {
        filters.first { ($0.value(forKey: "type") as? String) == "variableBlur" }
    }

    private static func firstBlurView(in view: UIView) -> DMVariableBlurUIView? {
        if let match = view as? DMVariableBlurUIView {
            return match
        }
        for subview in view.subviews {
            if let found = firstBlurView(in: subview) {
                return found
            }
        }
        return nil
    }
}

extension XCTestCase {
    /// Compares the mask of a hosted blur view with a recorded profile, row by row.
    ///
    /// The tolerance of one step of 255 covers rounding in the renderer. The recorded
    /// profiles came out identical on three iOS versions.
    @MainActor
    func assertMaskProfile(
        of sut: HostedBlurView,
        matches recorded: [UInt8],
        tolerance: Int = 1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let profile = sut.maskAlphaProfile else {
            return XCTFail("the backdrop layer has no variable blur filter with a mask", file: file, line: line)
        }
        guard profile.count == recorded.count else {
            return XCTFail(
                "the mask has \(profile.count) rows, the recorded profile has \(recorded.count)",
                file: file,
                line: line
            )
        }
        let differences = zip(profile, recorded).map { abs(Int($0) - Int($1)) }
        let largest = differences.max() ?? 0
        guard largest > tolerance else { return }
        let row = differences.firstIndex(of: largest) ?? 0
        XCTFail(
            "the mask differs from the recorded profile by up to \(largest), allowed \(tolerance): "
                + "row \(row) is \(profile[row]), recorded \(recorded[row])",
            file: file,
            line: line
        )
    }
}
