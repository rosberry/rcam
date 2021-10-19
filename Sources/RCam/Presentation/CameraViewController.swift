//
//  Copyright © 2021 Rosberry. All rights reserved.
//

import UIKit
import AVFoundation
import Framezilla

public protocol CameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ viewController: CameraViewController, imageCaptured image: UIImage)
    func cameraViewControllerCloseEventTriggered(_ viewController: CameraViewController)
}

public final class CameraViewController: UIViewController {

    public override var prefersStatusBarHidden: Bool {
        true
    }

    public weak var delegate: CameraViewControllerDelegate?

    private var focusViewTimer: Timer?

    private lazy var bundle: Bundle = .init(for: Self.self)

    private lazy var pinchGestureRecognizer: UIPinchGestureRecognizer = {
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(viewPinched))
        pinchGestureRecognizer.delegate = self
        pinchGestureRecognizer.cancelsTouchesInView = false
        return pinchGestureRecognizer
    }()

    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(cameraViewTapped))
        tapGestureRecognizer.delegate = self
        tapGestureRecognizer.cancelsTouchesInView = false
        return tapGestureRecognizer
    }()

    private let cameraService: Camera

    // MARK: - Subviews

    public private(set) lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(named: "ic_close_xs", in: bundle, compatibleWith: nil)
        button.setImage(image, for: .normal)
        button.addTarget(self, action: #selector(closeButtonPressed), for: .touchUpInside)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        return button
    }()

    public private(set) lazy var cameraPreviewLayer: AVCaptureVideoPreviewLayer = .init()

    public private(set) lazy var cameraView: UIView = {
        let view = UIView()
        view.layer.addSublayer(cameraPreviewLayer)
        return view
    }()
    public private(set) lazy var cameraContainerView: UIView = .init()

    public private(set) lazy var captureButtonBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        return view
    }()

    public private(set) lazy var captureButtonContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()

    public private(set) lazy var captureButton: BaseHighlightedButton = {
        let button = BaseHighlightedButton()
        button.addTarget(self, action: #selector(captureButtonPressed), for: .touchUpInside)
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.black.cgColor
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

    public private(set) lazy var zoomLabelContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        return view
    }()

    public private(set) lazy var zoomValueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.text = "1.0"
        label.textColor = .white
        return label
    }()

    public private(set) lazy var zoomXLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.text = "X"
        label.textColor = .white
        return label
    }()

    public private(set) lazy var blurView: UIVisualEffectView = .init(effect: nil)
    private lazy var footerContainerView: UIView = .init()

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
        
        cameraContainerView.addSubview(cameraView)
        
        view.addSubview(footerContainerView)
        
        footerContainerView.addSubview(flashLightModeButton)
        
        captureButtonBackgroundView.addSubview(captureButtonContainerView)
        captureButtonContainerView.addSubview(captureButton)
        footerContainerView.addSubview(captureButtonBackgroundView)
        
        footerContainerView.addSubview(flipCameraButton)
        view.backgroundColor = .black
        cameraContainerView.addGestureRecognizer(tapGestureRecognizer)
        cameraContainerView.addGestureRecognizer(pinchGestureRecognizer)

        zoomLabelContainerView.addSubview(zoomValueLabel)
        zoomLabelContainerView.addSubview(zoomXLabel)

        view.addSubview(blurView)
        view.addSubview(closeButton)
        view.addSubview(cameraContainerView)
        view.addSubview(zoomLabelContainerView)

        cameraService.startSession()
        cameraPreviewLayer.session = cameraService.captureSession

        updateFlashModeIcon(for: cameraService.flashMode)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if let videoPreviewLayerConnection = cameraPreviewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            let newVideoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation)
            guard deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
                return
            }
            
            cameraService.orientation = newVideoOrientation
            videoPreviewLayerConnection.videoOrientation = newVideoOrientation
        }
    }

    // MARK: - Layout

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
                
        closeButton.configureFrame { maker in
            maker.size(width: 40, height: 40).cornerRadius(byHalf: .height)
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                maker.top(inset: 24).left(inset: 24)
            case .landscapeRight:
                maker.top(inset: 24).right(inset: 24)
            default:
                maker.top(inset: 24).left(inset: 24)
            }
        }
        
        footerContainerView.configureFrame { maker in
            let footerContainerViewHeight: CGFloat = 96 + 36 + 36
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                maker.width(footerContainerViewHeight).right(to: view.nui_safeArea.right).top().bottom()
            case .landscapeRight:
                maker.width(footerContainerViewHeight).left(to: view.nui_safeArea.left).top().bottom()
            default:
                maker.height(footerContainerViewHeight).bottom(to: view.nui_safeArea.bottom).left().right()
            }
        }
        
        cameraContainerView.configureFrame { maker in
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                let measure = view.bounds.height
                maker.size(width: measure * 4/3, height: measure)
                     .right(to: footerContainerView.nui_left)
                     .centerY()
            case .landscapeRight:
                let measure = view.bounds.height
                maker.size(width: measure * 4/3, height: measure)
                     .left(to: footerContainerView.nui_right)
                     .centerY()
            default:
                let measure = view.bounds.width
                maker.size(width: measure, height: measure * 4/3)
                     .bottom(to: footerContainerView.nui_top)
                     .centerX()
            }
        }
        cameraView.frame = cameraContainerView.bounds
        cameraPreviewLayer.frame = cameraView.bounds

        let captureButtonSize = CGSize(width: 57, height: 57)

        captureButtonBackgroundView.configureFrame { maker in
            maker.size(width: 96, height: 96).center().cornerRadius(byHalf: .height)
        }

        captureButtonContainerView.configureFrame { maker in
            maker.size(width: captureButtonSize.width + 10, height: captureButtonSize.height + 10)
                 .center().cornerRadius(byHalf: .height)
        }

        captureButton.configureFrame { maker in
            maker.size(captureButtonSize)
                 .center().cornerRadius(byHalf: .height)
        }

        flashLightModeButton.configureFrame { maker in
            let actualSize = flashLightModeButton.sizeThatFits(view.bounds.size)
            maker.size(width: actualSize.width + 20, height: actualSize.height + 20).cornerRadius(byHalf: .height)
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                maker.top(to: captureButtonBackgroundView.nui_bottom, inset: 50)
                    .centerX()
            case .landscapeRight:
                maker.bottom(to: captureButtonBackgroundView.nui_top, inset: 50)
                    .centerX()
            default:
                maker.right(to: captureButtonBackgroundView.nui_left, inset: 50)
                     .centerY()
            }
        }

        flipCameraButton.configureFrame { maker in
            let actualSize = flipCameraButton.sizeThatFits(view.bounds.size)
            maker.size(width: actualSize.width + 20, height: actualSize.height + 20).cornerRadius(byHalf: .height)
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                maker.bottom(to: captureButtonBackgroundView.nui_top, inset: 50)
                    .centerX()
            case .landscapeRight:
                maker.top(to: captureButtonBackgroundView.nui_bottom, inset: 50)
                    .centerX()
            default:
                maker.left(to: captureButtonBackgroundView.nui_right, inset: 50)
                     .centerY()
            }
        }

        zoomLabelContainerView.configureFrame { maker in
            let side = 38
            maker.size(width: side, height: side).cornerRadius(byHalf: .height)
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                maker.centerY(to: captureButtonBackgroundView.nui_centerY)
                    .right(to: cameraContainerView.nui_right, inset: 4)
            case .landscapeRight:
                maker.centerY(to: captureButtonBackgroundView.nui_centerY)
                    .left(to: cameraContainerView.nui_left, inset: 4)
            default:
                maker.centerX(to: captureButtonBackgroundView.nui_centerX)
                    .bottom(to: cameraContainerView.nui_bottom, inset: 4)
            }
        }

        zoomValueLabel.configureFrame { maker in
            maker.centerY().left(inset: 4).sizeToFit()
        }

        zoomXLabel.configureFrame { maker in
            maker.centerY().right(inset: 4).sizeToFit()
        }

        blurView.frame = cameraContainerView.frame
    }

    // MARK: - Actions

    @objc private func closeButtonPressed() {
        delegate?.cameraViewControllerCloseEventTriggered(self)
    }

    @objc private func captureButtonPressed() {
        cameraService.capturePhoto { [weak self] capturePhoto in
            guard let self = self,
                  let data = capturePhoto.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                return
            }

            self.delegate?.cameraViewController(self, imageCaptured: image)
        }
    }

    @objc private func flipCameraButtonPressed() {
        guard let cameraSnapshotView = cameraContainerView.snapshotView(afterScreenUpdates: true) else {
            return
        }

        view.isUserInteractionEnabled = false
        cameraSnapshotView.frame = cameraContainerView.frame
        view.insertSubview(cameraSnapshotView, aboveSubview: cameraView)
        cameraContainerView.alpha = 0

        view.insertSubview(blurView, aboveSubview: cameraSnapshotView)

        UIView.animate(withDuration: 0.4, animations: {
            self.blurView.effect = UIBlurEffect(style: .dark)
        }, completion: { _ in
            try? self.cameraService.flipCamera()
            self.updateZoomLevelLabel()
            UIView.animate(withDuration: 0.2, animations: {
                self.cameraContainerView.alpha = 1
                cameraSnapshotView.alpha = 0
                self.blurView.effect = nil
            }, completion: { _ in
                cameraSnapshotView.removeFromSuperview()
                self.blurView.removeFromSuperview()
                self.view.isUserInteractionEnabled = true
            })
        })
    }

    @objc private func flashModeButtonPressed() {
        let currentFlashMode = cameraService.flashMode.rawValue
        let newFlashMode = (currentFlashMode + 1) % 3

        if let flashMode = AVCaptureDevice.FlashMode(rawValue: newFlashMode) {
            updateFlashModeIcon(for: flashMode)
            cameraService.flashMode = flashMode
        }
    }

    @objc private func zoomSliderValueChanged(_ slider: UISlider) {
        cameraService.zoomLevel = CGFloat(slider.value)
        updateZoomLevelLabel()
    }

    // MARK: - Recognizers

    @objc private func cameraViewTapped(recognizer: UITapGestureRecognizer) {
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
            updateZoomLevelLabel()
        default:
            break
        }
    }

    // MARK: - Private

    private func updateZoomLevelLabel() {
        guard let zoomLevel = cameraService.zoomLevel else {
            return
        }

        zoomValueLabel.text = String(format: "%.1f", zoomLevel)
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
}

// MARK: - UIGestureRecognizerDelegate

extension CameraViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

private extension AVCaptureVideoOrientation {
    init(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .landscapeLeft:
            self = .landscapeRight
        case .landscapeRight:
            self = .landscapeLeft
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        default:
            self = .portrait
        }
    }
}
