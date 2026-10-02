import DMVariableBlurView
import UIKit
import XCTest

/// The installer against the real system, and against classes that behave like a system
/// on which the private filter changed.
///
/// The filter class is private, so no documentation describes its states. The two fake
/// classes below model changes the guards of the installer are written for: a factory
/// that returns nothing, and a filter that does not keep its values. The other guards are
/// reached with names the real system does not know.
final class SystemVariableBlurInstallerTests: XCTestCase {
    @MainActor
    func test_install_onAnEffectView_leavesOnlyTheVariableBlurWithItsRadiusAndMask() throws {
        let effectView = makeEffectView()
        let mask = try makeMaskImage()

        let outcome = SystemVariableBlurInstaller().install(maxBlurRadius: 7.3, mask: mask, on: effectView)

        let filters = filters(of: effectView.subviews.first)
        XCTAssertEqual(outcome, .installed, "the system takes the filter")
        XCTAssertEqual(filters.map(type(of:)), ["variableBlur"], "the backdrop carries the variable blur and nothing else")
        XCTAssertEqual(
            (filters.first?.value(forKey: "inputRadius") as? NSNumber)?.doubleValue,
            7.3,
            "the filter carries the radius, also one that is not a whole number"
        )
        XCTAssertTrue(
            filters.first?.value(forKey: "inputMaskImage") as AnyObject === mask,
            "the filter carries the mask it was given"
        )
        XCTAssertEqual(effectView.subviews.dropFirst().map(\.alpha), [0], "the tint of the effect view is hidden")
    }

    /// The system has always put the backdrop first. The installer does not rely on it.
    @MainActor
    func test_install_backdropIsNotTheFirstSubview_putsTheFilterOnTheBackdropAndHidesTheOtherSubview() throws {
        let effectView = makeEffectView()
        let backdrop = try XCTUnwrap(effectView.subviews.first)
        effectView.bringSubviewToFront(backdrop)
        let tint = try XCTUnwrap(effectView.subviews.first)
        XCTAssertFalse(tint === backdrop, "precondition: the backdrop is no longer the first subview")

        let outcome = SystemVariableBlurInstaller().install(maxBlurRadius: 7, mask: try makeMaskImage(), on: effectView)

        XCTAssertEqual(outcome, .installed, "the system takes the filter")
        XCTAssertEqual(filters(of: backdrop).map(type(of:)), ["variableBlur"], "the backdrop carries the variable blur")
        XCTAssertEqual(filters(of: tint).count, 0, "the other subview gets no filter")
        XCTAssertEqual([backdrop.alpha, tint.alpha], [1, 0], "the other subview is hidden and the backdrop is not")
    }

    @MainActor
    func test_install_filterClassTheSystemDoesNotHave_reportsTheMissingClass() throws {
        let sut = SystemVariableBlurInstaller(filterClassName: "DMFilterClassTheSystemDoesNotHave")

        try expect(sut, toReport: .filterClassMissing)
    }

    @MainActor
    func test_install_classThatDoesNotAnswerTheFilterCalls_reportsTheMissingFactory() throws {
        let sut = SystemVariableBlurInstaller(filterClassName: "NSObject")

        try expect(sut, toReport: .filterFactoryMissing)
    }

    @MainActor
    func test_install_filterTypeTheSystemDoesNotList_reportsTheMissingType() throws {
        let sut = SystemVariableBlurInstaller(filterType: "dmBlurTheSystemDoesNotList")

        try expect(sut, toReport: .filterTypeMissing)
    }

    @MainActor
    func test_install_factoryThatReturnsNothing_reportsTheFailedCreation() throws {
        let sut = SystemVariableBlurInstaller(filterClassName: "DMFilterClassThatCreatesNothing")

        try expect(sut, toReport: .filterCreationFailed)
    }

    @MainActor
    func test_install_filterThatDoesNotKeepItsValues_reportsThatItWasNotAppliedAndRestoresTheStandardFilters() throws {
        let sut = SystemVariableBlurInstaller(filterClassName: "DMFilterClassWithForgetfulFilters")

        try expect(sut, toReport: .notApplied)
    }

    @MainActor
    func test_install_effectViewWithoutAnEffect_reportsTheMissingBackdrop() throws {
        let effectView = UIVisualEffectView(effect: nil)

        let outcome = SystemVariableBlurInstaller().install(maxBlurRadius: 7, mask: try makeMaskImage(), on: effectView)

        XCTAssertEqual(outcome, .unavailable(.backdropMissing))
    }

    @MainActor
    func test_setBackdropScale_setsTheScaleOfTheBackdropLayer() {
        let effectView = makeEffectView()

        SystemVariableBlurInstaller().setBackdropScale(3, on: effectView)

        XCTAssertEqual(effectView.subviews.first?.layer.value(forKey: "scale") as? NSNumber, 3)
    }

    // MARK: - Helpers

    @MainActor
    private func makeEffectView() -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    }

    /// Installs on a fresh effect view and expects the installer to give the reason and to
    /// leave the effect view with the filters and the tint it had.
    @MainActor
    private func expect(
        _ sut: SystemVariableBlurInstaller,
        toReport reason: VariableBlurInstallation.Reason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let effectView = makeEffectView()
        let standardFilters = filters(of: effectView.subviews.first).map(type(of:))
        let standardAlphas = effectView.subviews.map(\.alpha)

        let outcome = sut.install(maxBlurRadius: 7, mask: try makeMaskImage(), on: effectView)

        XCTAssertEqual(outcome, .unavailable(reason), "the outcome names the reason", file: file, line: line)
        XCTAssertEqual(
            filters(of: effectView.subviews.first).map(type(of:)),
            standardFilters,
            "the backdrop keeps its standard filters",
            file: file,
            line: line
        )
        XCTAssertEqual(
            effectView.subviews.map(\.alpha),
            standardAlphas,
            "the tint of the effect view stays visible",
            file: file,
            line: line
        )
    }

    @MainActor
    private func filters(of view: UIView?) -> [NSObject] {
        (view?.layer.filters ?? []).compactMap { $0 as? NSObject }
    }

    private func type(of filter: NSObject) -> String {
        (filter.value(forKey: "type") as? String) ?? "unknown"
    }
}

/// A filter class that lists the variable blur and then returns no filter.
@objc(DMFilterClassThatCreatesNothing)
private final class FilterClassThatCreatesNothing: NSObject {
    @objc
    static func filterTypes() -> [String] {
        ["variableBlur"]
    }

    @objc(filterWithType:)
    static func filter(withType type: String) -> NSObject? {
        nil
    }
}

/// A filter class whose filters accept every value and keep none.
@objc(DMFilterClassWithForgetfulFilters)
private final class FilterClassWithForgetfulFilters: NSObject {
    @objc
    static func filterTypes() -> [String] {
        ["variableBlur"]
    }

    @objc(filterWithType:)
    static func filter(withType type: String) -> NSObject? {
        ForgetfulFilter()
    }
}

private final class ForgetfulFilter: NSObject {
    override func setValue(_ value: Any?, forUndefinedKey key: String) {}

    override func value(forUndefinedKey key: String) -> Any? {
        nil
    }
}
