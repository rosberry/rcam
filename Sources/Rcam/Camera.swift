//
//  Copyright © 2019 Rosberry. All rights reserved.
//

import AVFoundation

public protocol HasCamera {
    var camera: Camera { get }
}

public typealias PhotoHandler = (_ pixelBuffer: CVPixelBuffer?, _ exifOrientation: Int32?) -> Void

public protocol Camera: class {
    var captureSession: AVCaptureSession? { get }
    var videoBuffersHandler: ((CMSampleBuffer) -> Void)? { get set }
    var audioBuffersHandler: ((CMSampleBuffer) -> Void)? { get set }
    var recommendedAudioSettings: [AnyHashable: Any]? { get }
    var recommendedVideoSettings: [AnyHashable: Any]? { get }
    var usingBackCamera: Bool { get }
    var isTorchAvailable: Bool { get }
    var zoomLevel: CGFloat? { get set }
    var zoomRange: ClosedRange<CGFloat>? { get }
    var flashMode: AVCaptureDevice.FlashMode { get set }
    var torchMode: AVCaptureDevice.TorchMode { get set }

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
