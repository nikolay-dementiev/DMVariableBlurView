import DMVariableBlurView
import UIKit
import XCTest

/// The Reduce Transparency option through the public API, and the adapter that reads the
/// setting of the device. The simulators of this suite run with the setting off.
final class ReduceTransparencyTests: XCTestCase {
    @MainActor
    func test_blurView_optionOnAndSettingOff_showsTheVariableBlur() throws {
        try XCTSkipIf(UIAccessibility.isReduceTransparencyEnabled, "the device has Reduce Transparency on")
        let sut = try makeSUT(
            DMVariableBlurView(maxBlurRadius: 7, direction: .blurredTopClearBottom).respectsReduceTransparency()
        )
        defer { sut.hide() }

        XCTAssertEqual(sut.filterTypes, ["variableBlur"], "the variable blur is shown")
        XCTAssertNil(sut.blurView.failure, "nothing failed")
    }

    /// What a view that follows the setting draws, with the installer of the library: the
    /// standard effect of the system while the setting is on, which is no failure, and the
    /// variable blur again when the setting is turned off.
    @MainActor
    func test_blurUIView_optionOnAndSettingOn_showsTheStandardEffectAndReportsNothing() throws {
        // The spy stands in for the setting; the system still draws the effect by the real one.
        try XCTSkipIf(UIAccessibility.isReduceTransparencyEnabled, "the device has Reduce Transparency on")
        let setting = ReduceTransparencySettingSpy(isEnabled: false)
        let view = DMVariableBlurUIView(
            maskRenderer: CoreGraphicsMaskImageRenderer(),
            installer: SystemVariableBlurInstaller(),
            failureLog: FailureLogSpy(),
            reduceTransparency: setting
        )
        view.respectsReduceTransparency = true
        view.apply(VariableBlurConfiguration(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0))
        let sut = HostedBlurView(placing: view)
        defer { sut.hide() }
        let filtersWithTheSettingOff = sut.filterTypes

        setting.simulateChange(to: true)
        sut.window.layoutIfNeeded()

        XCTAssertEqual(filtersWithTheSettingOff, ["variableBlur"], "precondition: the variable blur is shown")
        XCTAssertFalse(sut.filterTypes.contains("variableBlur"), "the setting on: no variable blur")
        XCTAssertFalse(sut.filterTypes.isEmpty, "the backdrop carries the standard filters of the effect")
        XCTAssertEqual(sut.tintAlphas, [1], "the tint of the standard effect is visible")
        XCTAssertNil(view.failure, "following the setting is no failure")

        setting.simulateChange(to: false)
        sut.window.layoutIfNeeded()

        XCTAssertEqual(sut.filterTypes, ["variableBlur"], "the setting off: the variable blur is back")
        XCTAssertEqual(sut.radius, 7, "with its radius")
        XCTAssertEqual(sut.tintAlphas, [0], "and the tint hidden")
        assertMaskProfile(of: sut, matches: MaskProfileFixtures.topZeroOffset)
        XCTAssertEqual(
            sut.backdropScale,
            view.traitCollection.displayScale,
            "the backdrop keeps the display scale through the standard effect and back"
        )
        XCTAssertNil(view.failure, "nothing failed")
    }

    /// The SwiftUI method sets the option of the UIKit view, when it is made and when it is
    /// updated.
    @MainActor
    func test_blurView_respectsReduceTransparency_setsTheOptionOfTheUIKitView() throws {
        let sut = try makeSUT(DMVariableBlurView().respectsReduceTransparency())
        defer { sut.hide() }
        let afterMake = sut.blurView.respectsReduceTransparency

        let updated = try sut.update(DMVariableBlurView().respectsReduceTransparency(false))

        XCTAssertTrue(afterMake, "the option is on after the view is made")
        XCTAssertFalse(updated.respectsReduceTransparency, "an update turns it off")
    }

    @MainActor
    func test_blurUIView_option_isOffByDefaultAndCanBeSet() {
        let sut = DMVariableBlurUIView()
        let byDefault = sut.respectsReduceTransparency

        sut.respectsReduceTransparency = true

        XCTAssertFalse(byDefault, "the view ignores the setting by default, as release 1.0.0 does")
        XCTAssertTrue(sut.respectsReduceTransparency, "a host can turn the option on")
    }

    @MainActor
    func test_systemSetting_isEnabled_isTheValueOfUIAccessibility() {
        XCTAssertEqual(SystemReduceTransparencySetting().isEnabled, UIAccessibility.isReduceTransparencyEnabled)
    }

    @MainActor
    func test_systemSetting_statusDidChangeNotification_callsTheHandlerOnce() {
        let sut = SystemReduceTransparencySetting()
        var calls = 0
        sut.onChange { calls += 1 }

        NotificationCenter.default.post(name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)

        XCTAssertEqual(calls, 1)
    }

    /// UIKit posts the notification on the main thread; another poster may not. The handler
    /// still runs on the main actor, and the process keeps running.
    @MainActor
    func test_systemSetting_notificationPostedOffTheMainThread_callsTheHandlerOnTheMainActor() async throws {
        let sut = SystemReduceTransparencySetting()
        var threads: [Bool] = []
        sut.onChange { threads.append(Thread.isMainThread) }

        await Task.detached {
            NotificationCenter.default.post(name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
        }.value
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(threads, [true], "one call, on the main thread")
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT(_ view: DMVariableBlurView) throws -> HostedBlurView {
        try HostedBlurView(view)
    }
}
