//
//  Copyright © 2019 Rosberry. All rights reserved.
//

import AVFoundation

public typealias BufferHandler = (AVCaptureConnection, CMSampleBuffer) -> Void

public final class CameraImpl: Camera {

    private enum Constants {
        static let lowBrightnessThreshold: Double = -0.18
    }

    private(set) public var captureSession: AVCaptureSession?
    public var videoBuffersHandler: BufferHandler?
    public var audioBuffersHandler: BufferHandler?
    var photoOutputHandler: PhotoHandler?
    private(set) public var recommendedAudioSettings: [AnyHashable: Any]?
    private(set) public var recommendedVideoSettings: [AnyHashable: Any]?
    public var isTorchAvailable: Bool = true

    private var needTurnOnTorchIfBrightnessIsLow: Bool = false

    // swiftlint:disable:next weak_delegate
    private lazy var videoOutputDelegate: CaptureVideoOutput = .init { [weak self] connection, buffer in
        guard let `self` = self else {
            return
        }
        if self.needTurnOnTorchIfBrightnessIsLow {
            if let brightnessLevel = self.brightnessLevel(for: buffer),
               brightnessLevel < Constants.lowBrightnessThreshold {
                self.updateTorch(isEnabled: true)
            }
            self.needTurnOnTorchIfBrightnessIsLow = false
        }
        self.videoBuffersHandler?(connection, buffer)
    }
    private lazy var audioOutputDelegate: CaptureAudioOutput = .init(handler: audioBuffersHandler) // swiftlint:disable:this weak_delegate
    private lazy var photoOutputDelegate: PhotoOutput = .init(handler: photoOutputHandler) // swiftlint:disable:this weak_delegate
    private lazy var photoOutput: AVCapturePhotoOutput = .init()
    private lazy var videoOutput: AVCaptureVideoDataOutput = .init()

    public var captureMode: CaptureMode = .onlyPhoto
    private(set) public var usingBackCamera: Bool = true
    public var flashMode: AVCaptureDevice.FlashMode = .off
    public var torchMode: AVCaptureDevice.TorchMode {
        get {
            guard let captureSession = captureSession else {
                return .off
            }

            for input in captureSession.inputs {
                if let input = input as? AVCaptureDeviceInput {
                    let device = input.device
                    if device.isTorchAvailable && device.hasTorch {
                        return device.torchMode
                    }
                }
            }
            return .off
        }
        set {
            updateTorch(isEnabled: newValue != .off)
        }
    }

    public var orientation: AVCaptureVideoOrientation = .portrait

    public var zoomLevel: CGFloat? {
        get {
            guard let captureSession = captureSession else {
                return nil
            }

            for input in captureSession.inputs {
                for port in input.ports where port.mediaType == .video {
                    if let input = input as? AVCaptureDeviceInput {
                        let device = input.device
                        return device.videoZoomFactor
                    }
                }
            }
            return nil
        }
        set {
            if let newValue = newValue {
                update(zoomLevel: newValue)
            }
        }
    }

    public var zoomRangeLimits: ClosedRange<CGFloat>? = 1...5

    public var availableDeviceZoomRange: ClosedRange<CGFloat>? {
        guard let captureSession = captureSession else {
            return nil
        }
        for input in captureSession.inputs {
            for port in input.ports where port.mediaType == .video {
                if let input = input as? AVCaptureDeviceInput {
                    let device = input.device
                    return device.minAvailableVideoZoomFactor...device.maxAvailableVideoZoomFactor
                }
            }
        }
        return nil
    }

    public init() {
    }

    public func videoPermissions() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    public func askVideoPermissions(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    public func microphonePermissions() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    public func askMicrophonePermissions(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    public func startSession() {
        let cameraSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        guard let camera = cameraSession.devices.first else {
            return
        }

        let session = AVCaptureSession()
        setupAudioSession(for: session)

        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
            }

            if captureMode != .onlyPhoto {
                let micSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone],
                                                                  mediaType: .audio,
                                                                  position: .unspecified)
                for device in micSession.devices {
                    let input = try AVCaptureDeviceInput(device: device)
                    if session.canAddInput(input) {
                        session.addInput(input)
                    }
                }
            }

            try camera.lockForConfiguration()
            camera.activeVideoMinFrameDuration = .init(value: 1, timescale: 30)
            camera.activeVideoMaxFrameDuration = .init(value: 1, timescale: 30)
            camera.unlockForConfiguration()

            setupVideoOutput(for: session)
            setupAudioOutput(for: session)
            setupPhotoOutput(for: session)

            session.beginConfiguration()
            session.sessionPreset = .photo
            session.commitConfiguration()

            session.startRunning()
            captureSession = session

            usingBackCamera = false
            isTorchAvailable = camera.isTorchAvailable
        }
        catch {
            captureSession = nil
            print(error)
        }

        if !usingBackCamera {
            zoomLevel = 1.3
        }
    }

    public func stopSession() {
        captureSession?.stopRunning()
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func flipCamera() throws {
        guard let captureSession = captureSession else {
            throw CameraError.noCaptureSession
        }

        captureSession.beginConfiguration()

        for input in captureSession.inputs {
            for port in input.ports where port.mediaType == .video {
                if let input = input as? AVCaptureDeviceInput {
                    let device = input.device
                    if device.isTorchAvailable {
                        try? device.lockForConfiguration()
                        device.torchMode = .off
                        device.unlockForConfiguration()
                    }
                }
                captureSession.removeInput(input)
            }
        }

        let position: AVCaptureDevice.Position = usingBackCamera ? .front : .back
        let cameraSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                             mediaType: .video,
                                                             position: position)

        guard let camera = cameraSession.devices.first else {
            throw CameraError.cameraNotFound
        }

        let cameraInput = try AVCaptureDeviceInput(device: camera)
        if captureSession.canAddInput(cameraInput) {
            captureSession.addInput(cameraInput)
        }
        else {
            throw CameraError.cameraSwitchFailed
        }

        for output in captureSession.outputs {
            if let output = output as? AVCaptureVideoDataOutput {
                if let connection = output.connection(with: .video),
                   connection.isVideoOrientationSupported {
                    connection.videoOrientation = orientation
                }
            }
        }

        usingBackCamera.toggle()
        if !usingBackCamera {
            zoomLevel = 1.3
        }
        if usingBackCamera {
            needTurnOnTorchIfBrightnessIsLow = true
        }
        isTorchAvailable = camera.isTorchAvailable

        captureSession.commitConfiguration()
    }

    public func updateFocalPoint(with point: CGPoint) {
        guard let captureSession = captureSession else {
            return
        }

        var focusPoint = CGPoint(x: point.y, y: point.x)

        for input in captureSession.inputs {
            if let input = input as? AVCaptureDeviceInput {
                let device = input.device

                if device.isFocusPointOfInterestSupported,
                   device.isFocusModeSupported(.autoFocus) {
                    do {
                        try device.lockForConfiguration()

                        if device.position == .back {
                            focusPoint.y = 1 - focusPoint.y
                        }

                        device.focusPointOfInterest = focusPoint
                        device.focusMode = .autoFocus

                        if device.isExposurePointOfInterestSupported,
                           device.isExposureModeSupported(.continuousAutoExposure) {
                            device.exposurePointOfInterest = focusPoint
                            device.exposureMode = .continuousAutoExposure
                        }

                        device.unlockForConfiguration()
                    }
                    catch {
                        print(error)
                    }
                }
            }
        }
    }

    func update(zoomLevel: CGFloat) {
        guard let captureSession = captureSession else {
            return
        }

        for input in captureSession.inputs {
            for port in input.ports where port.mediaType == .video {
                if let input = input as? AVCaptureDeviceInput {
                    let device = input.device
                    let zoomRange = self.zoomRangeLimits ?? device.minAvailableVideoZoomFactor...device.maxAvailableVideoZoomFactor
                    let finalZoomLevel = zoomLevel.clamped(in: zoomRange)
                    do {
                        try device.lockForConfiguration()
                        device.videoZoomFactor = finalZoomLevel
                        device.unlockForConfiguration()
                    }
                    catch {
                        print(error)
                    }
                }
            }
        }
    }

    public func capturePhoto(completion: @escaping PhotoHandler) {
        photoOutputHandler = completion
        let settings = AVCapturePhotoSettings(format: [String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA])
        photoOutput.update(orientation: orientation)

        if photoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        settings.isAutoStillImageStabilizationEnabled = true
        
        photoOutput.capturePhoto(with: settings, delegate: photoOutputDelegate)
    }

    public func recordingStarted() {
        guard usingBackCamera,
              flashMode != .off else {
            return
        }

        switch flashMode {
        case .on:
            updateTorch(isEnabled: true)
        case .auto:
            needTurnOnTorchIfBrightnessIsLow = true
        default:
            break
        }
    }

    public func recordingFinished() {
        updateTorch(isEnabled: false)
    }

    // MARK: - Private

    private func setupVideoOutput(for session: AVCaptureSession) {
        videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(videoOutputDelegate, queue: .init(label: "Video output"))
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        videoOutput.update(orientation: orientation)
        recommendedVideoSettings = videoOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mp4)
    }

    private func setupAudioOutput(for session: AVCaptureSession) {
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(audioOutputDelegate, queue: .init(label: "Audio output"))
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
        }
        recommendedAudioSettings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mp4)
    }

    private func setupPhotoOutput(for session: AVCaptureSession) {
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        photoOutput.update(orientation: orientation)
    }

    private func setupAudioSession(for session: AVCaptureSession) {
        session.automaticallyConfiguresApplicationAudioSession = false
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.mixWithOthers, .allowBluetoothA2DP])
        }
        catch {
            print(error)
        }
    }

    private func updateTorch(isEnabled: Bool) {
        guard let captureSession = captureSession else {
            return
        }

        for input in captureSession.inputs {
            if let input = input as? AVCaptureDeviceInput {
                let device = input.device
                if device.isTorchAvailable {
                    do {
                        try device.lockForConfiguration()
                        device.torchMode = isEnabled ? .on : .off
                        device.unlockForConfiguration()
                    }
                    catch {
                        print(error)
                    }
                }
            }
        }
    }

    private func brightnessLevel(for sampleBuffer: CMSampleBuffer) -> Double? {
        let rawMetadata = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault,
                                                        target: sampleBuffer,
                                                        attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
        let metadata = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, rawMetadata) as NSMutableDictionary
        let exifData = metadata.value(forKey: String(kCGImagePropertyExifDictionary)) as? NSMutableDictionary
        guard let brightness = exifData?[String(kCGImagePropertyExifBrightnessValue)] as? NSNumber else {
            return nil
        }
        return brightness.doubleValue
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

private final class CaptureVideoOutput: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let handler: BufferHandler?

    init(handler: BufferHandler?) {
        self.handler = handler
        super.init()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.sync {
            handler?(connection, sampleBuffer)
        }
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

private final class CaptureAudioOutput: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {

    private let handler: BufferHandler?

    init(handler: BufferHandler?) {
        self.handler = handler
        super.init()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        handler?(connection, sampleBuffer)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

private final class PhotoOutput: NSObject, AVCapturePhotoCaptureDelegate {

    private let handler: PhotoHandler?

    init(handler: PhotoHandler?) {
        self.handler = handler
        super.init()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async {
            self.handler?(photo)
        }
    }
}

private extension AVCaptureOutput {
    func update(orientation: AVCaptureVideoOrientation) {
        if let videoConnection = connection(with: .video),
           videoConnection.isVideoOrientationSupported {
            videoConnection.videoOrientation = orientation
        }
    }
}
