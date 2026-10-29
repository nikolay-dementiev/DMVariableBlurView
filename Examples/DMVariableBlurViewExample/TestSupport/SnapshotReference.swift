import Foundation

/// The device and the OS a run draws on, and the names of the snapshot references that belong
/// to them: `<scene>_<device>_ios<major>_<minor>`, for example `blurredFully_iPhone17_ios26_5`.
///
/// The tolerance of the comparison covers another device of the same OS, but the files must not
/// mix: a reference that is not named after its device cannot be recorded again by anyone.
struct SnapshotReference: Equatable {
    /// What a run does with the references it finds.
    enum Availability: Equatable {
        case compare
        case skip(String)
        case fail(String)
    }

    /// The run cannot name its device.
    struct MissingDevice: Error, CustomStringConvertible {
        let description = "SIMULATOR_DEVICE_NAME is not set: the references are named after the device, "
            + "and a run does not guess it."
    }

    let device: String
    let major: Int
    let minor: Int

    /// The device keeps its letters, digits and underscores only: swift-snapshot-testing turns any
    /// other run of characters in a file name into a hyphen, and the name of a reference has to
    /// be the name of its file.
    init(deviceName: String, major: Int, minor: Int) {
        device = deviceName.filter { $0.isLetter || $0.isNumber || $0 == "_" }
        self.major = major
        self.minor = minor
    }

    /// The device and the OS of this process. The simulator names its device in
    /// `SIMULATOR_DEVICE_NAME`; a run without it throws and does not guess.
    static func current(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        version: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    ) throws -> SnapshotReference {
        guard let name = environment["SIMULATOR_DEVICE_NAME"] else {
            throw MissingDevice()
        }
        let reference = SnapshotReference(deviceName: name, major: version.majorVersion, minor: version.minorVersion)
        guard !reference.device.isEmpty else {
            throw MissingDevice()
        }
        return reference
    }

    /// The part of a name that follows the scene.
    var suffix: String {
        "_\(device)_ios\(major)_\(minor)"
    }

    func name(for scene: String) -> String {
        scene + suffix
    }

    func availability(among fileNames: [String], in folder: String, required: Bool) -> Availability {
        let references = fileNames.filter { $0.hasSuffix(".png") }
        guard !references.isEmpty else {
            return .fail("No snapshot reference at all in \(folder): the folder moved, or the tests run away from the checkout.")
        }
        // The dot ends the match: `_ios26_5.` is not found in the name of a reference of iOS 26.50.
        guard references.contains(where: { $0.contains("\(suffix).") }) else {
            let missing = "No snapshot references for this device and OS (\(suffix)) in \(folder)."
            if required {
                return .fail(missing + " This run requires them: record them on this device and OS.")
            }
            return .skip(missing + " CI does not record them; the band tests cover this OS.")
        }
        return .compare
    }
}
