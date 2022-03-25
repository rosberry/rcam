# RCam
<p>Reusable component that presents camera flow with ability to capture image. Components presents custom UI where you can have access to all UI components of view controller.</p>

## Features
- Camera flip
- Flashlight mode
- Zoom by pinch
- Selecting focus object
- Automatically apply orientation metadata

## Usage

1. Create and present view controller: 
```swift
let cameraViewController = CameraViewController()
navigationController?.present(viewController, animated: true)
```
2. Pass delegate to handle incoming image and closing event
```swift
cameraViewController.delegate = self

...

extension AppDelegate: CameraViewControllerDelegate {
    func cameraViewController(_ viewController: CameraViewController, imageCaptured image: UIImage, orientationApplied: Bool) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    func cameraViewControllerCloseEventTriggered(_ viewController: CameraViewController) {
        navigationController?.dismiss(animated: true)
    }
}
```
3. Additions
Captured image by default is raw with recorded orientation in metadata. If you need image with applied orientation, you can set `automaticallyApplyOrientationToImage` flag in `CameraViewController` to true (by default its false).

You can use `CameraService` separately from `CameraViewController` or create your own `CameraService` and pass it to `CameraViewController` constructor
```swift
let cameraViewController = CameraViewController(cameraService: YourCameraService())
```
`Camera` protocol has following interface

```swift
public protocol Camera: AnyObject {
    var captureSession: AVCaptureSession? { get }
    var videoBuffersHandler: BufferHandler? { get set }
    var audioBuffersHandler: BufferHandler? { get set }
    var recommendedAudioSettings: [AnyHashable: Any]? { get }
    var recommendedVideoSettings: [AnyHashable: Any]? { get }
    var usingBackCamera: Bool { get }
    var isTorchAvailable: Bool { get }
    var zoomLevel: CGFloat? { get set }
    var zoomRangeLimits: ClosedRange<CGFloat>? { get set }
    var availableDeviceZoomRange: ClosedRange<CGFloat>? { get }
    var flashMode: AVCaptureDevice.FlashMode { get set }
    var torchMode: AVCaptureDevice.TorchMode { get set }
    var captureMode: CaptureMode { get set }

    func videoPermissions() -> AVAuthorizationStatus
    func askVideoPermissions(completion: @escaping (Bool) -> Void)
    func microphonePermissions() -> AVAuthorizationStatus
    func askMicrophonePermissions(completion: @escaping (Bool) -> Void)

    func startSession()
    func stopSession()

    func flipCamera() throws
    func updateFocalPoint(with point: CGPoint)

    func capturePhoto(completion: @escaping PhotoHandler)
    func recordingStarted()
    func recordingFinished()
}
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
```
github "rosberry/rcam"
```

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
