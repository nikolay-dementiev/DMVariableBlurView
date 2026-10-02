import SwiftUI
import DMVariableBlurView

// The code samples of README.md, kept identical to the README. A sample that no longer
// compiles fails this fixture.

// README.md, "Usage", "Example".
struct ContentView: View {
    var body: some View {
        ZStack {
            Text("My content that should be blured")

            DMVariableBlurView(
                maxBlurRadius: 7,
                direction: .blurredCenterClearTopBottom(centerBandProportion: 0.2)
            )

            Text("My content that should be displayed over blured content")
        }
        .ignoresSafeArea()
    }
}
