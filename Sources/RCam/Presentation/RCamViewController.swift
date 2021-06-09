//
//  Copyright © 2021 Rosberry. All rights reserved.
//

import UIKit
import AVFoundation
import Framezilla

public protocol RCamViewControllerDelegate: class {
    func rCamViewController(_ viewController: RCamViewController, imageCaptured image: UIImage)
}

public final class RCamViewController: UIViewController {

    public override var prefersStatusBarHidden: Bool {
        true
    }

    public weak var delegate: RCamViewControllerDelegate?

    private var focusViewTimer: Timer?

    private lazy var bundle: Bundle = .init(for: Self.self)

    private lazy var pinchGestureRecognizer: UIPinchGestureRecognizer = {
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(viewPinched))
        pinchGestureRecognizer.delegate = self
        pinchGestureRecognizer.cancelsTouchesInView = false
        return pinchGestureRecognizer
    }()

    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(videoViewTapped))
        tapGestureRecognizer.delegate = self
        tapGestureRecognizer.cancelsTouchesInView = false
        return tapGestureRecognizer
    }()

    private let cameraService: Camera

    // MARK: - Subviews

    public private(set) lazy var cameraPreviewLayer: AVCaptureVideoPreviewLayer = .init()
    public private(set) lazy var cameraView: UIView = {
        let view = UIView()
        view.layer.addSublayer(cameraPreviewLayer)
        return view
    }()
    public private(set) lazy var cameraContainerView: UIView = .init()

    public private(set) lazy var captureButtonContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        return view
    }()

    public private(set) lazy var captureButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(named: "ic62TakePhoto", in: bundle, compatibleWith: nil)
        button.setImage(image, for: .normal)
        button.addTarget(self, action: #selector(captureButtonTouchedUp), for: .touchUpInside)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        return button
    }()

    public private(set) lazy var flipCameraButton: UIButton = {
        let button = UIButton()
        let image = UIImage(named: "ic32Swichcamera", in: bundle, compatibleWith: nil)
        button.setImage(image, for: .normal)
        button.addTarget(self, action: #selector(flipCameraButtonPressed), for: .touchUpInside)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        return button
    }()

    public private(set) lazy var focusImageView: UIImageView = {
        let image = UIImage(named: "elementFocus", in: bundle, compatibleWith: nil)
        let view = UIImageView(image: image)
        view.isUserInteractionEnabled = false
        return view
    }()

    public private(set) lazy var flashLightModeButton: UIButton = {
        let button = UIButton()
        let image = UIImage(named: "ic32FlashAuto", in: bundle, compatibleWith: nil)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        button.addTarget(self, action: #selector(flashModeButtonPressed), for: .touchUpInside)
        return button
    }()

    public private(set) lazy var zoomSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 1
        slider.maximumValue = 16
        slider.value = 1
        slider.addTarget(self, action: #selector(zoomSliderValueChanged), for: .valueChanged)
        return slider
    }()

    public private(set) lazy var zoomLabelContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        return view
    }()

    public private(set) lazy var zoomLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.text = "1 X"
        label.textColor = .white
        return label
    }()

    // MARK: - Lifecycle

    public init(cameraService: Camera = CameraImpl()) {
        self.cameraService = cameraService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        focusViewTimer?.invalidate()
        focusViewTimer = nil
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        cameraContainerView.addGestureRecognizer(tapGestureRecognizer)
        cameraContainerView.addGestureRecognizer(pinchGestureRecognizer)

        cameraContainerView.addSubview(cameraView)
        zoomLabelContainerView.addSubview(zoomLabel)
        view.addSubview(cameraContainerView)
        view.addSubview(captureButton)
        view.addSubview(flashLightModeButton)
        view.addSubview(flipCameraButton)
        view.addSubview(zoomSlider)
        view.addSubview(zoomLabelContainerView)

        cameraService.startSession()
        cameraPreviewLayer.session = cameraService.captureSession

        updateFlashModeIcon(for: cameraService.flashMode)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }

    // MARK: - Layout

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let availableRect = view.bounds.inset(by: view.safeAreaInsets)
        let width = availableRect.width
        let aspect: CGFloat = 3 / 4
        let height = width / aspect

        cameraContainerView.configureFrame { maker in
            maker.size(width: width, height: height)
                .centerY(between: view.nui_safeArea.top, view.nui_safeArea.bottom)
        }
        cameraView.frame = cameraContainerView.bounds
        cameraPreviewLayer.frame = cameraView.bounds

        captureButton.configureFrame { maker in
            let actualSize = captureButton.sizeThatFits(view.bounds.size)
            maker.size(width: actualSize.width + 20, height: actualSize.height + 20)
                .centerX().bottom(to: view.nui_safeArea.bottom, inset: 36).cornerRadius(byHalf: .height)
        }

        flashLightModeButton.configureFrame { maker in
            let actualSize = flashLightModeButton.sizeThatFits(view.bounds.size)
            maker.size(width: actualSize.width + 20, height: actualSize.height + 20)
                .left(inset: 45).centerY(to: captureButton.nui_centerY).sizeToFit().cornerRadius(byHalf: .height)
        }

        flipCameraButton.configureFrame { maker in
            let actualSize = flipCameraButton.sizeThatFits(view.bounds.size)
            maker.size(width: actualSize.width + 20, height: actualSize.height + 20)
                 .right(inset: 45).centerY(to: captureButton.nui_centerY).cornerRadius(byHalf: .height)
        }

        let zoomLabelSize = zoomLabel.sizeThatFits(view.bounds.size)

        zoomLabelContainerView.configureFrame { maker in
            let side = max(zoomLabelSize.width, 38) + 4
            maker.centerX().bottom(to: captureButton.nui_top, inset: 24)
                .size(width: side, height: side).cornerRadius(byHalf: .height)
        }

        zoomLabel.configureFrame { maker in
            maker.center().sizeToFit()
        }

        zoomSlider.configureFrame { maker in
            maker.left(inset: 30).right(inset: 30).heightToFit().bottom(to: zoomLabelContainerView.nui_top, inset: 10)
        }
        zoomSlider.subviews.first?.frame = zoomSlider.bounds
    }

    // MARK: - Actions

    @objc private func captureButtonTouchedUp() {
        cameraService.capturePhoto { [weak self] pixelBuffer, orientation in
            guard let self = self,
                  let pixelBuffer = pixelBuffer,
                  let orientation = orientation,
                  let uiImageOrientation = UIImage.Orientation(rawValue: Int(orientation)) else {
                return
            }

            let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.downMirrored)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: .init(x: 0,
                                                                           y: 0,
                                                                           width: CVPixelBufferGetWidth(pixelBuffer),
                                                                           height: CVPixelBufferGetHeight(pixelBuffer))) else {
                return
            }
            let image = UIImage(cgImage: cgImage, scale: 1, orientation: uiImageOrientation)
            self.delegate?.rCamViewController(self, imageCaptured: image)
        }
    }

    @objc private func flipCameraButtonPressed() {
        guard let cameraSnapshotView = cameraContainerView.snapshotView(afterScreenUpdates: true) else {
            return
        }

        cameraSnapshotView.frame = cameraContainerView.frame
        view.insertSubview(cameraSnapshotView, aboveSubview: cameraContainerView)
        cameraContainerView.alpha = 0

        let blurView = UIVisualEffectView(effect: nil)
        blurView.frame = view.bounds
        view.insertSubview(blurView, aboveSubview: cameraSnapshotView)

        UIView.animate(withDuration: 0.4, animations: {
            blurView.effect = UIBlurEffect(style: .prominent)
        }, completion: { _ in
            try? self.cameraService.flipCamera()
            UIView.animate(withDuration: 0.2, animations: {
                self.cameraContainerView.alpha = 1
                cameraSnapshotView.alpha = 0
                blurView.effect = nil
            }, completion: { _ in
                cameraSnapshotView.removeFromSuperview()
                blurView.removeFromSuperview()
            })
        })
    }

    // MARK: - Recognizers

    @objc private func videoViewTapped(recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: cameraContainerView)

        focusImageView.bounds = .init(origin: .zero, size: .init(width: 100, height: 100))
        focusImageView.center = cameraContainerView.convert(point, to: view)
        view.addSubview(focusImageView)

        focusImageView.transform = .init(scaleX: 2, y: 2)
        UIView.animate(withDuration: 0.2, animations: {
            self.focusImageView.transform = .identity
        }, completion: nil)

        focusViewTimer?.invalidate()
        focusViewTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            UIView.animate(withDuration: 0.2, animations: {
                self?.focusImageView.alpha = 0
            }, completion: { _ in
                self?.focusImageView.removeFromSuperview()
                self?.focusImageView.alpha = 1
            })
        }

        let normalizedPoint = CGPoint(x: point.x / cameraContainerView.bounds.width,
                                      y: point.y / cameraContainerView.bounds.height)
        cameraService.updateFocalPoint(with: normalizedPoint)
    }

    @objc private func viewPinched(recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
            case .began:
                if let zoomLevel = cameraService.zoomLevel {
                    recognizer.scale = zoomLevel
                }
            case .changed:
                let scale = recognizer.scale
                cameraService.zoomLevel = scale
                zoomSlider.setValue(Float(scale), animated: true)
                updateZoomLevelLabel()
            default:
                break
        }
    }

    @objc private func zoomSliderValueChanged(_ slider: UISlider) {
        cameraService.zoomLevel = CGFloat(slider.value)
        updateZoomLevelLabel()
    }

    @objc private func flashModeButtonPressed() {
        let currentFlashMode = cameraService.flashMode.rawValue
        var newFlashMode = currentFlashMode + 1
        if newFlashMode > 2 {
            newFlashMode = 0
        }

        if let flashMode = AVCaptureDevice.FlashMode(rawValue: newFlashMode) {
            updateFlashModeIcon(for: flashMode)
            cameraService.flashMode = flashMode
        }
    }

    private func updateZoomLevelLabel() {
        guard let zoomLevel = cameraService.zoomLevel else {
            return
        }

        zoomLabel.text = String(format: "%.1f X", zoomLevel)
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func updateFlashModeIcon(for flashMode: AVCaptureDevice.FlashMode) {
        let flashModeImageName: String
        switch flashMode {
        case .auto:
            flashModeImageName = "ic32FlashAuto"
        case .on:
            flashModeImageName = "ic32FlashOn"
        case .off:
            flashModeImageName = "ic32FlashOff"
        @unknown default:
            flashModeImageName = "unknown"
        }
        flashLightModeButton.setImage(UIImage(named: flashModeImageName, in: bundle, compatibleWith: nil), for: .normal)
    }

    private func cubicEaseIn<T: FloatingPoint>(_ x: T) -> T {
        x * x * x
    }

    private func deCubicEaseIn(_ x: CGFloat) -> CGFloat {
        pow(x, CGFloat(1) / CGFloat(3))
    }
}

// MARK: - UIGestureRecognizerDelegate

extension RCamViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
