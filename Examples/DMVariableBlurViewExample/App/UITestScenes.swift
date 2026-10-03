import DMVariableBlurView
import SwiftUI

/// Fixed scenes for the UI tests, chosen with the launch argument `-uiTestScene <name>`.
enum UITestScene: String {
    /// Stripes under a blur of the top 70 % of the screen, and a button that switches the
    /// app to the dark appearance.
    case appearance
    /// A button under a full blur that lets touches through with `.allowsHitTesting(false)`.
    case passThrough
    /// The same button under a full blur that keeps its default and takes touches.
    case blocking

    /// The scene the launch arguments ask for, or `nil` for the gallery.
    static func requested(by arguments: [String] = ProcessInfo.processInfo.arguments) -> UITestScene? {
        guard let index = arguments.firstIndex(of: "-uiTestScene"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return UITestScene(rawValue: arguments[index + 1])
    }

    @MainActor
    @ViewBuilder
    var view: some View {
        switch self {
        case .appearance:
            AppearanceScene()
        case .passThrough:
            TapScene(blurLetsTouchesThrough: true)
        case .blocking:
            TapScene(blurLetsTouchesThrough: false)
        }
    }
}

/// The top 70 % of the screen is blurred over stripes; the stripes from 74 % to 84 % stay
/// bare and serve as the reference of the measurement.
struct AppearanceScene: View {
    /// The share of the height the blur covers. The UI test measures the same share of its
    /// screenshot, so the two numbers change together.
    static let blurredShare = 0.7

    @State private var isDark: Bool

    init(isDark: Bool = false) {
        _isDark = State(initialValue: isDark)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                StripedBackground()
                DMVariableBlurView(maxBlurRadius: 6, direction: .blurredTopClearBottom)
                    .frame(height: proxy.size.height * Self.blurredShare)
                    .allowsHitTesting(false)
                VStack {
                    Spacer()
                    Button("Switch to dark") { isDark = true }
                        .accessibilityIdentifier("switch-to-dark")
                        .padding()
                        .background(Color.white)
                    DarkAppearanceLabel()
                }
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .preferredColorScheme(isDark ? .dark : .light)
    }
}

/// Shows "Dark" once the views receive the dark appearance. It follows the environment,
/// not the button, so the UI test measures only after the change reached the views.
private struct DarkAppearanceLabel: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            Text(verbatim: "Dark")
                .foregroundStyle(.black)
                .accessibilityIdentifier("appearance-dark")
                .background(Color.white)
        }
    }
}

/// A button under a full blur and a label that counts the taps the button receives.
struct TapScene: View {
    let blurLetsTouchesThrough: Bool

    @State private var taps = 0

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Button("Tap me") { taps += 1 }
                    .accessibilityIdentifier("tap-target")
                    .font(.title)
                // Verbatim: a localized number could be written with other digits.
                Text(verbatim: "Taps: \(taps)")
                    .accessibilityIdentifier("tap-count")
            }
            DMVariableBlurView(direction: .blurredFully)
                .allowsHitTesting(!blurLetsTouchesThrough)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Previews

#Preview("Appearance scene") {
    AppearanceScene()
}

#Preview("Appearance scene, dark") {
    AppearanceScene(isDark: true)
}

#Preview("Touches pass through") {
    TapScene(blurLetsTouchesThrough: true)
}

#Preview("Touches blocked") {
    TapScene(blurLetsTouchesThrough: false)
}
