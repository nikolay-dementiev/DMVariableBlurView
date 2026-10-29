import Foundation

/// The device and the OS a run draws on, and the names of the snapshot references that belong
/// to them.
struct SnapshotReference: Equatable {
    /// What a run does with the references it finds.
    enum Availability: Equatable {
        case compare
        case skip(String)
        case fail(String)
    }

    /// The run cannot name its device.
    struct MissingDevice: Error, CustomStringConvertible {
        let description = "SIMULATOR_DEVICE_NAME is not set: the references are named after the device, and a run does not guess it."
    }

    let device: String
    let major: Int
    let minor: Int

    init(deviceName: String, major: Int, minor: Int) {
        device = deviceName.filter { !$0.isWhitespace }
        self.major = major
        self.minor = minor
    }

    static func current(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        version: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    ) throws -> SnapshotReference {
        SnapshotReference(deviceName: environment["SIMULATOR_DEVICE_NAME"] ?? "", major: version.majorVersion, minor: version.minorVersion)
    }

    var suffix: String {
        "_ios\(major)_\(minor)"
    }

    func name(for scene: String) -> String {
        scene + suffix
    }

    func availability(among fileNames: [String], in folder: String, required: Bool) -> Availability {
        let references = fileNames.filter { $0.hasSuffix(".png") }
        guard !references.isEmpty else {
            return .fail("No snapshot reference at all in \(folder): the folder moved, or the tests run away from the checkout.")
        }
        guard references.contains(where: { $0.contains("\(suffix).") }) else {
            let missing = "No snapshot references for this runtime (\(suffix)) in \(folder)."
            if required {
                return .fail(missing + " This run requires them: record them on this runtime.")
            }
            return .skip(missing + " CI does not record them; the band tests cover this runtime.")
        }
        return .compare
    }
}
