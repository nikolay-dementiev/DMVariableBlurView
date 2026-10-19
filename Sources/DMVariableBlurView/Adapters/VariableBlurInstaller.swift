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
    /// put on it: the filter that call created, alone on the backdrop, with this radius and
    /// mask, and the tint hidden. A filter that call did not create is not asked for its
    /// radius or its mask.
    func isInstalled(maxBlurRadius: CGFloat, mask: CGImage, on effectView: UIVisualEffectView) -> Bool

    /// Tells the backdrop of the effect view the scale it renders at.
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
///
/// An installer remembers the filters it put on effect views. Copies of it share that memory;
/// another installer knows nothing of what this one installed.
@MainActor
package struct SystemVariableBlurInstaller: VariableBlurInstaller {
    private let filterClassName: String
    private let filterType: String

    /// The filter that ``install(maxBlurRadius:mask:on:)`` last put on each effect view. It is
    /// the only filter whose keys the installer reads: another filter, left on the backdrop by
    /// a host or a later system, may not define them, and the exception that raises cannot be
    /// caught. Both sides are weak: the layer owns the filter, so the entry goes when the
    /// system lets the filter go, and it does not keep the effect view alive.
    private let installedFilters = NSMapTable<UIVisualEffectView, NSObject>(
        keyOptions: [.weakMemory, .objectPointerPersonality],
        valueOptions: [.weakMemory, .objectPointerPersonality]
    )

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
        guard backdrop.layer.carriesOnly(filter, withRadius: maxBlurRadius, mask: mask) else {
            backdrop.layer.filters = standardFilters
            return .unavailable(.notApplied)
        }
        // Only a blur that took is remembered. After a failure the layer has what it had, and
        // so has the entry.
        installedFilters.setObject(filter, forKey: effectView)

        // Without its tint the effect view shows no hard line where the blur ends. The content
        // view holds what a host puts over the blur and stays as the host left it.
        let contentView = effectView.contentView
        for subview in effectView.subviews where subview !== backdrop && subview !== contentView {
            subview.alpha = 0
        }
        return .installed
    }

    package func isInstalled(maxBlurRadius: CGFloat, mask: CGImage, on effectView: UIVisualEffectView) -> Bool {
        guard let backdrop = backdropView(of: effectView),
              let filter = installedFilters.object(forKey: effectView),
              backdrop.layer.carriesOnly(filter, withRadius: maxBlurRadius, mask: mask) else {
            return false
        }
        let contentView = effectView.contentView
        return effectView.subviews.allSatisfy { $0 === backdrop || $0 === contentView || $0.alpha == 0 }
    }

    package func setBackdropScale(_ scale: CGFloat, on effectView: UIVisualEffectView) {
        backdropView(of: effectView)?.layer.setValue(scale, forKey: "scale")
    }

    /// The backdrop is found by what it does, not by its private class name: it is the
    /// subview whose layer carries filters.
    private func backdropView(of effectView: UIVisualEffectView) -> UIView? {
        effectView.subviews.first { $0.layer.filters?.isEmpty == false }
    }
}

private extension CALayer {
    /// The layer took the filter when it carries that filter and nothing else, and the filter
    /// holds the radius and the mask it was given. The filter is the object the installer
    /// created, found by identity before any key is read from it.
    func carriesOnly(_ filter: NSObject, withRadius radius: CGFloat, mask: CGImage) -> Bool {
        guard let carried = filters, carried.count == 1, carried[0] as AnyObject === filter else {
            return false
        }
        guard filter.value(forKey: "inputMaskImage") as AnyObject === mask else {
            return false
        }
        guard let storedRadius = (filter.value(forKey: "inputRadius") as? NSNumber)?.doubleValue else {
            return false
        }
        return storedRadius == Double(radius)
    }
}
