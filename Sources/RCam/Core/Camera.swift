//
//  Copyright © 2019 Rosberry. All rights reserved.
//

import AVFoundation

public protocol HasCamera {
    var camera: Camera { get }
}

public typealias PhotoHandler = (_ capturePhoto: AVCapturePhoto) -> Void

public protocol Camera: AnyObject {
    var captureSession: AVCaptureSession? { get }
    var videoBuffersHandler: BufferHandler? { get set }
    var audioBuffersHandler: BufferHandler? { get set }
    var recommendedAudioSettings: [AnyHashable: Any]? { get }
    var recommendedVideoSettings: [AnyHashable: Any]? { get }
    var usingBackCamera: Bool { get }
    var isTorchAvailable: Bool { get }
    var zoomLevel: CGFloat? { get set }
    var zoomRangeLimits: ClosedRange<CGFloat>? { get }
    var availableDeviceZoomRange: ClosedRange<CGFloat>? { get }
    var flashMode: AVCaptureDevice.FlashMode { get set }
    var torchMode: AVCaptureDevice.TorchMode { get set }
    var orientation: AVCaptureVideoOrientation { get set }
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
