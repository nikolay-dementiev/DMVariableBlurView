import DMVariableBlurView
import UIKit

/// Records what a blur view asks its installer and passes every call on to the real
/// installer, so the view runs against the real system and a test can still count.
///
/// It stands in for the installer port of the library, not for a system interface: every
/// answer is the real installer's.
@MainActor
final class ForwardingInstallerSpy: VariableBlurInstaller {
    private let installer = SystemVariableBlurInstaller()

    /// How many times the view asked to install the blur.
    private(set) var installCount = 0
    /// What the real installer answered each time the view asked whether its blur is still on.
    private(set) var answers: [Bool] = []
    /// When set, every installation is answered with it and the layer is left as it is.
    private var refusal: VariableBlurInstallation?

    /// Makes the system refuse the blur from now on, as the installer does when the layer does
    /// not take the filter: it answers `outcome` and touches nothing.
    func refuseInstallations(with outcome: VariableBlurInstallation) {
        refusal = outcome
    }

    func install(maxBlurRadius: CGFloat, mask: CGImage, on effectView: UIVisualEffectView) -> VariableBlurInstallation {
        installCount += 1
        if let refusal {
            return refusal
        }
        return installer.install(maxBlurRadius: maxBlurRadius, mask: mask, on: effectView)
    }

    func isInstalled(maxBlurRadius: CGFloat, mask: CGImage, on effectView: UIVisualEffectView) -> Bool {
        let answer = installer.isInstalled(maxBlurRadius: maxBlurRadius, mask: mask, on: effectView)
        answers.append(answer)
        return answer
    }

    func setBackdropScale(_ scale: CGFloat, on effectView: UIVisualEffectView) {
        installer.setBackdropScale(scale, on: effectView)
    }
}
