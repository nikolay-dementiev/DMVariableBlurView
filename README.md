# DMVariableBlurView
![](https://raw.githubusercontent.com/nikolay-dementiev/DMVariableBlurView/main/Sources/Helpers/Assets/blurredCenterClearTopBottom_blurredTopClearBottom_blurredBottomClearTop_blurredFully.jpeg)


## Overview
`DMVariableBlurView` is a SwiftUI-compatible SDK for applying dynamic blur effects with customizable configurations. It extends the work of:

- jtrivedi: [VariableBlurView](https://github.com/jtrivedi/VariableBlurView) .
- nikstar: [VariableBlur](https://github.com/nikstar/VariableBlur).

This version introduces:
- [x] Support for new blur modes: `blurredCenterClearTopBottom` and `blurredFully`.
- [x] Improved error handling by replacing force unwrapping with descriptive error throwing.
- [x] Code refinements for better readability and maintainability.

For original implementation details, see [nikstar's GitHub page](https://github.com/nikstar/VariableBlur).


## Features
- Blur Directions:
1. `.blurredTopClearBottom`: Blurs from top to bottom.
2. `.blurredBottomClearTop`: Blurs from bottom to top.
3. `.blurredCenterClearTopBottom(centerBandProportion: CGFloat)`: Blurs the center band while keeping top and bottom clear.
4. `.blurredFully`: Fully blurs the entire view.
- Dynamic Blur Radius:
Blur intensity depends on the alpha value of the gradient mask.
- Error Handling:
Descriptive errors for invalid configurations or runtime issues.

## Installation
### SPM
Add the following dependency to your Package.swift:
```Swift 
dependencies: [
    .package(url: "https://github.com/nikolay-dementiev/DMVariableBlurView.git", from: "1.0.0")
````
### OR
Copy `DMVariableBlurView.swift` to your project.

## Usage

### Example

```Swift 
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
````

## Credits
- [jtrivedi](https://github.com/jtrivedi/VariableBlurView): Original implementation.
- [nikstar](https://github.com/nikstar/VariableBlur): Enhanced version with additional features.

## License
MIT License
