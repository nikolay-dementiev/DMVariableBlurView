//
//  DMVariableBlurView
//
//  Created by Mykola Dementiev
//

import DMVariableBlurView
import SwiftUI

struct ContentView: View {
    @State var direction: DMVariableBlurDirection
    @State var textDescription: String = "someTextHere"

    var body: some View {
        ZStack {
            Image(.parrot)
                .resizable()
                .aspectRatio(0.4, contentMode: .fill)

            DMVariableBlurView(
                maxBlurRadius: 5,
                direction: direction
            )

            Text(textDescription)
                .tint(Color.white)
                .font(Font.title2.bold())
                .padding()
                .background(.white)
                .clipShape(Capsule())

        }.ignoresSafeArea()
    }
}

#Preview("blurredCenterClearTopBottom") {

    ContentView(
        direction: .blurredCenterClearTopBottom(centerBandProportion: 0.4),
        textDescription: ".blurredCenterClearTopBottom"
    )
}

#Preview("blurredTopClearBottom") {

    ContentView(
        direction: .blurredTopClearBottom,
        textDescription: ".blurredTopClearBottom"
    )
}

#Preview("blurredBottomClearTop") {

    ContentView(
        direction: .blurredBottomClearTop,
        textDescription: ".blurredBottomClearTop"
    )
}

#Preview("blurredFully") {

    ContentView(
        direction: .blurredFully,
        textDescription: ".blurredFully"
    )
}
