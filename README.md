# DMVariableBlurView
[![Swift](https://img.shields.io/badge/Swift-5\*-orange?style=flat-square)](https://img.shields.io/badge/Swift-5\*-blue?style=flat-square) [![Swift-tools-version](https://img.shields.io/badge/Swift--tools-6.0-darkorange?style=flat-square)](https://img.shields.io/badge/Swift--tools-6.0-darkorange?style=flat-square)

[![Platforms](https://img.shields.io/badge/Platforms-iOS-yellowgreen?style=flat-square)](https://img.shields.io/badge/Platforms-iOS-yellowgreen?style=flat-square)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/DMVariableBlurView.svg?style=flat-square)](https://img.shields.io/cocoapods/v/DMVariableBlurView.svg)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)
![](https://raw.githubusercontent.com/nikolay-dementiev/DMVariableBlurView/main/Sources/Helpers/Assets/blurredCenterClearTopBottom_blurredTopClearBottom_blurredBottomClearTop_blurredFully.jpeg)

## Overview
`DMVariableBlurView` is a SwiftUI-compatible SDK for applying dynamic blur effects with customizable configurations. It extends the work of:

- jtrivedi: [VariableBlurView](https://github.com/jtrivedi/VariableBlurView).
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
### CocoaPods

```ruby
pod 'DMVariableBlurView'
```
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

[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fnikolay-dementiev%2FDMVariableBlurView.svg?type=large&issueType=license)](https://app.fossa.com/projects/git%2Bgithub.com%2Fnikolay-dementiev%2FDMVariableBlurView?ref=badge_large&issueType=license)
