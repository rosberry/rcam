# RCam
<p>Reusable component to get image from device camera.</p>
<p align="center">
    <img width="250px" src="https://user-images.githubusercontent.com/15152385/113264837-3f34cd80-92f5-11eb-8b05-7153abf257e4.jpeg"></img>
</p>

## Features
- Camera flip
- Flashlight mode
- Zoom by pinch
- Selecting focus object

## Usage

1. Create and present view controller: 
    ```swift
    let rCamViewController = RCamViewController()
    navigationController?.present(viewController, animated: true)
    ```
2. Pass delegate to handle incoming image and closing event

    ```swift
    rCamViewController.delegate = self

    ...

    extension AppDelegate: RCamViewControllerDelegate {
    func rCamViewController(_ viewController: RCamViewController, imageCaptured image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    func rCamViewControllerCloseEventTriggered(_ viewController: RCamViewController) {
        navigationController?.dismiss(animated: true)
    }
}

    ```

Also you use `CameraService` separately from `RCamViewController` or create your own `CameraService` and pass it to `RCamViewController` init method

     ```swift
    let rCamViewController = RCamViewController(cameraService: YourOwnCameraService())
    ```

## Installation
### Depo

[Depo](https://github.com/rosberry/depo) is a universal dependency manager that combines Carthage, SPM and CocoaPods and provides common user interface to all of them.

To install `RCam` via Carthage using Depo you need to add this to your `Depofile`:
```yaml
carts:
  - kind: github
    identifier: rosberry/rcam
```

### Carthage
Create a `Cartfile` that lists the framework and run `carthage update`. Follow the [instructions](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application) to add the framework to your project.

### SPM

Add SPM dependency to your Package.swift:
```swift
dependencies: [
    ...
    .package(url: "https://github.com/rosberry/rcam")
],
targets: [
    .target(
    ...
        dependencies: [
            ...
            .product(name: "RCam", package: "rcam")
        ]
    )
]
```

## About

<img src="https://github.com/rosberry/Foundation/blob/master/Assets/full_logo.png?raw=true" height="100" />

This project is owned and maintained by [Rosberry](http://rosberry.com). We build mobile apps for users worldwide 🌏.

Check out our [open source projects](https://github.com/rosberry), read [our blog](https://medium.com/@Rosberry) or give us a high-five on 🐦 [@rosberryapps](http://twitter.com/RosberryApps).

## License

The project is available under the MIT license. See the LICENSE file for more info.
