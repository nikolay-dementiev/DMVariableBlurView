import Foundation
import XCTest

/// How the example names its snapshot references and decides whether a run has any. A reference
/// is the picture of one device on one OS, so the name says both.
final class SnapshotReferenceTests: XCTestCase {
    private let folder = "Snapshots"

    func test_name_sceneDeviceAndOS_carriesAllThree() {
        let sut = makeSUT(device: "iPhone 17", major: 26, minor: 5)

        XCTAssertEqual(sut.name(for: "blurredFully"), "blurredFully_iPhone17_ios26_5")
    }

    func test_name_anotherDeviceOrAnotherOS_isAnotherName() {
        let name = makeSUT(device: "iPhone 17", major: 26, minor: 5).name(for: "scene")
        let anotherDevice = makeSUT(device: "iPhone 16", major: 26, minor: 5).name(for: "scene")
        let anotherMinor = makeSUT(device: "iPhone 17", major: 26, minor: 4).name(for: "scene")
        let anotherMajor = makeSUT(device: "iPhone 17", major: 18, minor: 5).name(for: "scene")

        XCTAssertNotEqual(anotherDevice, name, "another device of the same OS")
        XCTAssertNotEqual(anotherMinor, name, "the same device on another minor version")
        XCTAssertNotEqual(anotherMajor, name, "the same device on another major version")
    }

    /// swift-snapshot-testing writes any other run of characters of a name as a hyphen, so the name
    /// of a reference keeps letters, digits and underscores only, or it is never found on disk.
    func test_name_deviceWithPunctuation_keepsLettersAndDigitsOnly() {
        let sut = makeSUT(device: "iPad Pro 11-inch (M4)", major: 26, minor: 5)

        XCTAssertEqual(sut.name(for: "scene"), "scene_iPadPro11inchM4_ios26_5")
    }

    func test_current_environmentAndVersion_namesTheDeviceWithoutSpacesAndTheVersion() throws {
        let sut = try SnapshotReference.current(
            environment: ["SIMULATOR_DEVICE_NAME": "iPhone 14 Pro Max"],
            version: OperatingSystemVersion(majorVersion: 17, minorVersion: 5, patchVersion: 1)
        )

        XCTAssertEqual(sut, makeSUT(device: "iPhone14ProMax", major: 17, minor: 5))
    }

    func test_current_deviceNameMissing_throwsAMessageThatNamesTheVariable() {
        XCTAssertThrowsError(
            try SnapshotReference.current(environment: [:], version: anyVersion),
            "no device name throws"
        ) { error in
            XCTAssertTrue("\(error)".contains("SIMULATOR_DEVICE_NAME"), "the message names the variable: \(error)")
        }
    }

    /// A name of spaces and punctuation leaves nothing of the device: the name of a reference
    /// would be `scene__ios26_5`.
    func test_current_deviceNameWithoutLettersOrDigits_throws() {
        XCTAssertThrowsError(
            try SnapshotReference.current(environment: ["SIMULATOR_DEVICE_NAME": " () "], version: anyVersion),
            "a device name with nothing to keep is no name"
        )
    }

    func test_current_deviceNameEmpty_throws() {
        XCTAssertThrowsError(
            try SnapshotReference.current(environment: ["SIMULATOR_DEVICE_NAME": ""], version: anyVersion),
            "an empty name is no name"
        )
    }

    func test_availability_referenceOfThisDeviceAndOS_compares() {
        let sut = makeSUT(device: "iPhone 17", major: 26, minor: 5)

        let availability = sut.availability(among: ["blurredFully_iPhone17_ios26_5.1.png"], in: folder, required: true)

        XCTAssertEqual(availability, .compare)
    }

    /// The tolerance of the comparison covers another device of the same OS, but a reference that
    /// another device recorded is not one this run can reproduce: a required reference is missing.
    func test_availability_onlyReferencesOfAnotherDeviceOfTheSameOS_failsWhenTheRunRequiresThem() {
        let sut = makeSUT(device: "iPhone 17", major: 26, minor: 5)

        let availability = sut.availability(among: ["blurredFully_iPhone16_ios26_5.1.png"], in: folder, required: true)

        guard case .fail(let message) = availability else {
            return XCTFail("a required reference of this device is missing, got \(availability)")
        }
        XCTAssertTrue(message.contains("requires them"), "the message says the run requires the references: \(message)")
    }

    func test_availability_onlyReferencesOfAnotherDeviceOfTheSameOS_skipsWhenTheRunDoesNotRequireThem() {
        let sut = makeSUT(device: "iPhone 17", major: 26, minor: 5)

        let availability = sut.availability(among: ["blurredFully_iPhone16_ios26_5.1.png"], in: folder, required: false)

        guard case .skip(let message) = availability else {
            return XCTFail("a run without references of its own is skipped, got \(availability)")
        }
        XCTAssertTrue(message.contains("CI does not record"), "the message says why nothing is recorded: \(message)")
    }

    func test_availability_onlyReferencesOfAnotherOS_skipsWhenTheRunDoesNotRequireThem() {
        let sut = makeSUT(device: "iPhone 17", major: 26, minor: 5)

        let availability = sut.availability(among: ["blurredFully_iPhone17_ios18_6.1.png"], in: folder, required: false)

        guard case .skip = availability else {
            return XCTFail("a run on a runtime without references is skipped, got \(availability)")
        }
    }

    /// The minor version ends at the dot of the file name: iOS 26.50 is not iOS 26.5.
    func test_availability_onlyReferencesOfALongerMinorVersion_skipsWhenTheRunDoesNotRequireThem() {
        let sut = makeSUT(device: "iPhone 17", major: 26, minor: 5)

        let availability = sut.availability(among: ["blurredFully_iPhone17_ios26_50.1.png"], in: folder, required: false)

        guard case .skip = availability else {
            return XCTFail("a reference of iOS 26.50 is not one of iOS 26.5, got \(availability)")
        }
    }

    /// A folder with no picture at all is a moved folder, not a runtime without references.
    func test_availability_folderWithoutAnyPicture_failsAlsoWhenTheRunDoesNotRequireReferences() {
        let sut = makeSUT(device: "iPhone 17", major: 26, minor: 5)

        let availability = sut.availability(among: [".DS_Store"], in: folder, required: false)

        guard case .fail(let message) = availability else {
            return XCTFail("an empty folder fails, got \(availability)")
        }
        XCTAssertTrue(message.contains("No snapshot reference at all"), "the message says the folder is empty: \(message)")
    }

    // MARK: - Helpers

    private var anyVersion: OperatingSystemVersion {
        ProcessInfo.processInfo.operatingSystemVersion
    }

    private func makeSUT(device: String, major: Int, minor: Int) -> SnapshotReference {
        SnapshotReference(deviceName: device, major: major, minor: minor)
    }
}
