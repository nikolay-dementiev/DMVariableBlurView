import DMVariableBlurView
import UIKit
import XCTest

/// The Reduce Transparency option through the public API, and the adapter that reads the
/// setting of the device. The simulators of this suite run with the setting off.
final class ReduceTransparencyTests: XCTestCase {
    @MainActor
    func test_blurView_optionOnAndSettingOff_showsTheVariableBlur() throws {
        try XCTSkipIf(UIAccessibility.isReduceTransparencyEnabled, "the device has Reduce Transparency on")
        let sut = try HostedBlurView(
            DMVariableBlurView(maxBlurRadius: 7, direction: .blurredTopClearBottom).respectsReduceTransparency()
        )
        defer { sut.hide() }

        XCTAssertEqual(sut.filterTypes, ["variableBlur"], "the variable blur is shown")
        XCTAssertNil(sut.blurView.failure, "nothing failed")
    }

    /// The SwiftUI method sets the option of the UIKit view, when it is made and when it is
    /// updated.
    @MainActor
    func test_blurView_respectsReduceTransparency_setsTheOptionOfTheUIKitView() throws {
        let sut = try HostedBlurView(DMVariableBlurView().respectsReduceTransparency())
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
}
