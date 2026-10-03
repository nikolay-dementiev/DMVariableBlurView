import DMVariableBlurView
import UIKit
import XCTest

/// The variable blur stays on when UIKit rebuilds the effect view: after a change of
/// appearance and after a host assigns `effect`.
final class BlurViewReapplicationTests: XCTestCase {
    @MainActor
    func test_blurView_appearanceChangesToDarkAndBack_keepsTheVariableBlur() throws {
        let sut = try makeSUT()
        defer { sut.hide() }

        for style in [UIUserInterfaceStyle.dark, .light] {
            sut.window.overrideUserInterfaceStyle = style
            sut.window.layoutIfNeeded()

            expectTheVariableBlur(on: sut, after: style == .dark ? "the change to dark" : "the change back to light")
        }
    }

    @MainActor
    func test_blurView_effectAssignedByTheHost_keepsTheVariableBlur() throws {
        let sut = try makeSUT()
        defer { sut.hide() }

        sut.blurView.effect = UIBlurEffect(style: .dark)
        sut.blurView.layoutIfNeeded()

        expectTheVariableBlur(on: sut, after: "a new effect")
    }

    /// Setting `effect` to `nil` is the usual way to fade an effect view out. The view has
    /// no backdrop then, which is not a failure, and the blur comes back with the effect.
    @MainActor
    func test_blurView_effectRemovedAndRestoredByTheHost_recordsNoFailureAndShowsTheBlurAgain() throws {
        let sut = try makeSUT()
        defer { sut.hide() }

        sut.blurView.effect = nil
        sut.blurView.layoutIfNeeded()
        let failureWithoutEffect = sut.blurView.failure
        sut.blurView.effect = UIBlurEffect(style: .dark)
        sut.blurView.layoutIfNeeded()

        XCTAssertNil(failureWithoutEffect, "no effect is not a failure")
        expectTheVariableBlur(on: sut, after: "the effect came back")
        XCTAssertNil(sut.blurView.failure, "nothing failed")
    }

    /// A host that faded the view out may give it new values before it shows it again. The
    /// new values wait for the effect: the view leaves the effect to the host, and nothing
    /// failed.
    @MainActor
    func test_blurView_updatedWhileTheHostRemovedTheEffect_showsTheNewValuesWhenTheEffectReturns() throws {
        let sut = try makeSUT()
        defer { sut.hide() }

        sut.blurView.effect = nil
        sut.blurView.layoutIfNeeded()
        sut.blurView.update(maxBlurRadius: 9, direction: .blurredBottomClearTop, startOffset: 0)
        let failureWithoutEffect = sut.blurView.failure
        let effectAfterTheUpdate = sut.blurView.effect
        sut.blurView.effect = UIBlurEffect(style: .dark)
        sut.blurView.layoutIfNeeded()

        XCTAssertNil(failureWithoutEffect, "new values without an effect are not a failure")
        XCTAssertNil(effectAfterTheUpdate, "the view leaves the effect to the host")
        XCTAssertEqual(sut.filterTypes, ["variableBlur"], "the effect came back with the variable blur")
        XCTAssertEqual(sut.radius, 9, "the blur has the new radius")
        XCTAssertEqual(sut.tintAlphas, [0], "the tint is hidden")
        assertMaskProfile(of: sut, matches: MaskProfileFixtures.bottomZeroOffset)
        XCTAssertNil(sut.blurView.failure, "nothing failed")
    }

    /// A rejected value while the host faded the view out is reported at once, and the view
    /// still leaves the effect to the host: the plain blur appears when the effect returns.
    @MainActor
    func test_blurView_rejectedValueWhileTheHostRemovedTheEffect_reportsItAndLeavesTheEffectToTheHost() throws {
        let sut = try makeSUT()
        defer { sut.hide() }

        sut.blurView.effect = nil
        sut.blurView.layoutIfNeeded()
        sut.blurView.update(maxBlurRadius: -1, direction: .blurredBottomClearTop, startOffset: 0)
        let effectAfterTheUpdate = sut.blurView.effect
        sut.blurView.effect = UIBlurEffect(style: .dark)
        sut.blurView.layoutIfNeeded()

        XCTAssertEqual(sut.blurView.failure, .invalidMaxBlurRadius(-1), "the rejected value is reported")
        XCTAssertNil(effectAfterTheUpdate, "the view leaves the effect to the host")
        XCTAssertFalse(sut.filterTypes.contains("variableBlur"), "the effect came back as the plain blur")
    }

    /// The same without SwiftUI: the view in a plain UIKit hierarchy, with the collaborators
    /// the library uses.
    @MainActor
    func test_blurUIView_inAUIKitHierarchy_appearanceChangesToDark_keepsTheVariableBlur() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 400))
        let controller = UIViewController()
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        let sut = DMVariableBlurUIView(
            maskRenderer: CoreGraphicsMaskImageRenderer(),
            installer: SystemVariableBlurInstaller(),
            failureLog: SystemFailureLog(),
            reduceTransparency: SystemReduceTransparencySetting()
        )
        sut.frame = controller.view.bounds
        controller.view.addSubview(sut)
        sut.apply(VariableBlurConfiguration(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0))
        window.layoutIfNeeded()

        window.overrideUserInterfaceStyle = .dark
        window.layoutIfNeeded()

        let filterTypes = (sut.subviews.first?.layer.filters ?? []).map {
            (($0 as? NSObject)?.value(forKey: "type") as? String) ?? "unknown"
        }
        XCTAssertEqual(filterTypes, ["variableBlur"], "the backdrop carries the variable blur and nothing else")
        XCTAssertEqual(sut.subviews.dropFirst().map(\.alpha), [0], "the tint stays hidden")
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) throws -> HostedBlurView {
        try HostedBlurView(DMVariableBlurView(maxBlurRadius: 7, direction: .blurredTopClearBottom), file: file, line: line)
    }

    @MainActor
    private func expectTheVariableBlur(
        on sut: HostedBlurView,
        after event: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            sut.filterTypes,
            ["variableBlur"],
            "after \(event) the backdrop carries the variable blur and nothing else",
            file: file,
            line: line
        )
        XCTAssertEqual(sut.radius, 7, "after \(event) the radius is kept", file: file, line: line)
        XCTAssertEqual(sut.tintAlphas, [0], "after \(event) the tint stays hidden", file: file, line: line)
        XCTAssertEqual(
            sut.backdropScale,
            sut.window.screen.scale,
            "after \(event) the backdrop keeps the scale of the screen",
            file: file,
            line: line
        )
        assertMaskProfile(of: sut, matches: MaskProfileFixtures.topZeroOffset, file: file, line: line)
    }
}
