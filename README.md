# MyFramework
<p align="center">
    <a href="https://github.com/rosberry/MyFramework/actions">
      <img src="https://github.com/rosberry/MyFramework/workflows/Build/badge.svg" />
    </a>
    <a href="https://swift.org/">
        <img src="https://img.shields.io/badge/swift-5.0-orange.svg" alt="Swift Version" />
    </a>
    <a href="https://github.com/Carthage/Carthage">
        <img src="https://img.shields.io/badge/Carthage-compatible-green.svg" alt="Carthage Compatible" />
    </a>
    <a href="https://github.com/apple/swift-package-manager">
        <img src="https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat" alt="Swift Package Manager" />
    </a>
</p>

## Requirements

- iOS 11.0+
- Xcode 11.0+

## Installation

### Depo

[Depo](https://github.com/rosberry/depo) is a universal dependency manager that combines Carthage, SPM and CocoaPods and provides common user interface to all of them.

To install `MyFramework` via Carthage using Depo you need to add this to your `Depofile`:
```yaml
carts:
  - kind: github
    identifier: rosberry/MyFramework
```

<details>
  <summary>To install MyFramework via SPM or CocoaPods</summary>

  #### Via SPM
  Add this to your Depofile:

  ```yaml
  swiftPackages:
    - name: MyFramework
      url: https://github.com/rosberry/MyFramework.git
      version:
        operation: upToNextMajor
        value: 1.0.0
  ```
  
  #### Via CocoaPods
  Add this to your Depofile:
  
  ```yaml
  pods:
    - name: MyFramework
  ```
</details>

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks. To integrate MyFramework into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "rosberry/MyFramework"
```

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate MyFramework into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'MyFramework'
```

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. Once you have your Swift package set up, adding MyFramework as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/rosberry/MyFramework.git", .upToNextMajor(from: "1.0.0"))
]
```

## Documentation

Read the [docs](https://rosberry.github.io/MyFramework). Generated with [jazzy](https://github.com/realm/jazzy). Hosted by [GitHub Pages](https://pages.github.com).

## About

<img src="https://github.com/rosberry/Foundation/blob/master/Assets/full_logo.png?raw=true" height="100" />

This project is owned and maintained by [Rosberry](http://rosberry.com). We build mobile apps for users worldwide 🌏.

Check out our [open source projects](https://github.com/rosberry), read [our blog](https://medium.com/@Rosberry) or give us a high-five on 🐦 [@rosberryapps](http://twitter.com/RosberryApps).

## License

This project is available under the MIT license. See the LICENSE file for more info.
