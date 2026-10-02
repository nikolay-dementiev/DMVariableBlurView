import UIKit

/// What happened when the variable blur was put on an effect view.
package enum VariableBlurInstallation: Equatable, Sendable {
    /// The backdrop of the effect view carries the variable blur and nothing else.
    case installed
    /// The system does not offer the effect or did not take it. The effect view shows
    /// what it showed before.
    case unavailable(Reason)

    package enum Reason: Equatable, Sendable {
        /// The system has no filter class of the expected name.
        case filterClassMissing
        /// The filter class does not answer the two calls the library makes.
        case filterFactoryMissing
        /// The system does not list the variable blur among its filter types.
        case filterTypeMissing
        /// The system returned no filter for the variable blur type.
        case filterCreationFailed
        /// The effect view has no backdrop to put the filter on.
        case backdropMissing
        /// The backdrop does not carry the filter with its radius and its mask after the
        /// installation.
        case notApplied
    }
}

/// Puts the variable blur on the backdrop of an effect view.
@MainActor
package protocol VariableBlurInstaller {
    /// Replaces the standard filters of the backdrop with the variable blur and hides the
    /// tint of the effect view.
    ///
    /// - Parameters:
    ///   - maxBlurRadius: The radius where the alpha of the mask is 1.
    ///   - mask: The image whose alpha sets the radius of every row.
    func install(maxBlurRadius: CGFloat, mask: CGImage, on effectView: UIVisualEffectView) -> VariableBlurInstallation

    /// Whether the effect view still shows the blur that ``install(maxBlurRadius:mask:on:)``
    /// put on it: the one filter with this radius and mask, and the tint hidden.
    func isInstalled(maxBlurRadius: CGFloat, mask: CGImage, on effectView: UIVisualEffectView) -> Bool

    /// Tells the backdrop of the effect view the scale of the screen it is shown on.
    func setBackdropScale(_ scale: CGFloat, on effectView: UIVisualEffectView)
}

/// The installer that talks to the system. It is the only place in the library that uses
/// private system interfaces: a filter class, two of its calls, the keys of the filter and
/// one key of the backdrop layer.
///
/// The guards contain the risk of that, they do not remove it. A missing class, a missing
/// call, a missing filter type and an empty result each end in
/// ``VariableBlurInstallation/unavailable(_:)``. An exception that the system raises inside
/// one of these calls cannot be caught from Swift.
package struct SystemVariableBlurInstaller: VariableBlurInstaller {
    private let filterClassName: String
    private let filterType: String

    /// - Parameters:
    ///   - filterClassName: The name of the filter class of the system.
    ///   - filterType: The filter type that draws the variable blur.
    ///
    /// The defaults are the names the system uses. A test passes other names to see the
    /// installer on a system that lacks them.
    package init(filterClassName: String = "CAFilter", filterType: String = "variableBlur") {
        self.filterClassName = filterClassName
        self.filterType = filterType
    }

    package func install(
        maxBlurRadius: CGFloat,
        mask: CGImage,
        on effectView: UIVisualEffectView
    ) -> VariableBlurInstallation {
        guard let filterClass = NSClassFromString(filterClassName) as? NSObject.Type else {
            return .unavailable(.filterClassMissing)
        }
        let listSelector = NSSelectorFromString("filterTypes")
        let factorySelector = NSSelectorFromString("filterWithType:")
        guard filterClass.responds(to: listSelector), filterClass.responds(to: factorySelector) else {
            return .unavailable(.filterFactoryMissing)
        }
        // For a type it does not know the factory returns a filter that does nothing, so
        // the list of types is the only way to learn that the effect is gone.
        let filterTypes = filterClass.perform(listSelector)?.takeUnretainedValue() as? [String]
        guard filterTypes?.contains(filterType) == true else {
            return .unavailable(.filterTypeMissing)
        }
        guard let filter = filterClass.perform(factorySelector, with: filterType)?
            .takeUnretainedValue() as? NSObject else {
            return .unavailable(.filterCreationFailed)
        }
        guard let backdrop = backdropView(of: effectView) else {
            return .unavailable(.backdropMissing)
        }

        // The blur radius of a pixel follows the alpha of the mask there: an alpha of 1
        // gives the full radius, an alpha of 0 leaves the pixel sharp.
        filter.setValue(maxBlurRadius, forKey: "inputRadius")
        filter.setValue(mask, forKey: "inputMaskImage")
        filter.setValue(true, forKey: "inputNormalizeEdges")

        // The variable blur replaces the standard filters of the effect, such as the
        // uniform blur and the saturation.
        let standardFilters = backdrop.layer.filters
        backdrop.layer.filters = [filter]
        guard carriesOneFilter(withRadius: maxBlurRadius, mask: mask, on: backdrop.layer) else {
            backdrop.layer.filters = standardFilters
            return .unavailable(.notApplied)
        }

        // Without its tint the effect view shows no hard line where the blur ends.
        for subview in effectView.subviews where subview !== backdrop {
            subview.alpha = 0
        }
        return .installed
    }

    package func isInstalled(maxBlurRadius: CGFloat, mask: CGImage, on effectView: UIVisualEffectView) -> Bool {
        guard let backdrop = backdropView(of: effectView),
              carriesOneFilter(withRadius: maxBlurRadius, mask: mask, on: backdrop.layer) else {
            return false
        }
        return effectView.subviews.allSatisfy { $0 === backdrop || $0.alpha == 0 }
    }

    package func setBackdropScale(_ scale: CGFloat, on effectView: UIVisualEffectView) {
        backdropView(of: effectView)?.layer.setValue(scale, forKey: "scale")
    }

    /// The backdrop is found by what it does, not by its private class name: it is the
    /// subview whose layer carries filters.
    private func backdropView(of effectView: UIVisualEffectView) -> UIView? {
        effectView.subviews.first { $0.layer.filters?.isEmpty == false }
    }

    /// The layer took the filter when it carries one filter and nothing else, and that
    /// filter holds the radius and the mask it was given.
    private func carriesOneFilter(withRadius radius: CGFloat, mask: CGImage, on layer: CALayer) -> Bool {
        guard let filters = layer.filters, filters.count == 1, let filter = filters.first as? NSObject else {
            return false
        }
        guard filter.value(forKey: "inputMaskImage") as AnyObject === mask else {
            return false
        }
        guard let storedRadius = (filter.value(forKey: "inputRadius") as? NSNumber)?.doubleValue else {
            return false
        }
        // A radius that is not a number never equals itself, and it is still the value
        // that was asked for.
        return storedRadius == Double(radius) || (storedRadius.isNaN && radius.isNaN)
    }
}
