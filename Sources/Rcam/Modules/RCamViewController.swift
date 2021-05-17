//
//  Copyright © 2021 Rosberry. All rights reserved.
//

import UIKit
import AVFoundation
import Framezilla

protocol RCamViewControllerDelegate: class {
    func rCamViewController(_ viewController: RCamViewController, imageCaptured image: UIImage)
}

public final class RCamViewController: UIViewController {

    private enum Constants {
        static let zoomLevelDistance: CGFloat = 300
    }

    public override var prefersStatusBarHidden: Bool {
        true
    }

    weak var delegate: RCamViewControllerDelegate?

    var focusViewTimer: Timer?
    private var initialLongPressGesturePoint: CGPoint = .zero
    private var initialLongPressZoomRelativeValue: CGFloat = 0

    private lazy var pinchGestureRecognizer: UIPinchGestureRecognizer = {
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(viewPinched))
        pinchGestureRecognizer.delegate = self
        pinchGestureRecognizer.cancelsTouchesInView = false
        return pinchGestureRecognizer
    }()

    private let cameraService: Camera = CameraImpl()

    // MARK: - Subviews

    private lazy var cameraPreviewLayer: AVCaptureVideoPreviewLayer = .init()
    private lazy var cameraView: UIView = {
        let view = UIView()
        view.layer.addSublayer(cameraPreviewLayer)
        return view
    }()
    private lazy var cameraContainerView: UIView = .init()

    private lazy var captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.addTarget(self, action: #selector(captureButtonTouchedUp), for: .touchUpInside)
        button.backgroundColor = .red
        return button
    }()

    private lazy var torchCameraButton: UIButton = {
        let button = UIButton(type: .system)
        button.addTarget(self, action: #selector(torchCameraButtonPressed), for: .touchUpInside)
        button.backgroundColor = .white
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        return button
    }()

    private lazy var flipCameraButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("FLIP", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.addTarget(self, action: #selector(flipCameraButtonPressed), for: .touchUpInside)
        button.backgroundColor = .white
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        return button
    }()

    private lazy var focusView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemRed.cgColor
        return view
    }()

    private lazy var flashLightModeButton: UIButton = {
        let button = UIButton()
        button.setTitle("Flash mode: auto", for: .normal)
        button.setTitle("Flash mode: off", for: .selected)
        button.setTitleColor(.black, for: .normal)
        button.setTitleColor(.black, for: .selected)
        button.backgroundColor = .white
        button.addTarget(self, action: #selector(flashModeButtonPressed), for: .touchUpInside)
        return button
    }()

    private lazy var resultImageView: UIImageView = .init()

    // MARK: - Lifecycle

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 13, *) {
            view.backgroundColor = .systemBackground
        }
        else {
            view.backgroundColor = .black
        }

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(videoViewTapped))
        tapGestureRecognizer.delegate = self
        tapGestureRecognizer.cancelsTouchesInView = false
        cameraContainerView.addGestureRecognizer(tapGestureRecognizer)

        cameraContainerView.addGestureRecognizer(pinchGestureRecognizer)

        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(captureButtonLongPressed))
        longPressGestureRecognizer.delegate = self
        longPressGestureRecognizer.minimumPressDuration = 0
        longPressGestureRecognizer.cancelsTouchesInView = false
        captureButton.addGestureRecognizer(longPressGestureRecognizer)

        cameraContainerView.addSubview(cameraView)
        view.addSubview(cameraContainerView)
        view.addSubview(captureButton)
        view.addSubview(torchCameraButton)
        view.addSubview(flashLightModeButton)
        view.addSubview(flipCameraButton)
        view.addSubview(resultImageView)

        cameraService.startSession()
        cameraPreviewLayer.session = cameraService.captureSession
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
        let aspect: CGFloat = 9 / 16
        let height = width / aspect
        cameraContainerView.configureFrame { maker in
            maker.size(width: width, height: height)
                 .centerY(between: view.nui_safeArea.top, view.nui_safeArea.bottom)
        }
        cameraView.frame = cameraContainerView.bounds
        cameraPreviewLayer.frame = cameraView.bounds

        captureButton.configureFrame { maker in
            maker.size(width: 64, height: 64)
                 .cornerRadius(byHalf: .height)
                 .centerX().bottom(to: view.nui_safeArea.bottom, inset: 64)
        }

        torchCameraButton.configureFrame { maker in
            maker.size(width: 76, height: 36)
                 .cornerRadius(byHalf: .height)
                 .top(to: view.nui_safeArea.top, inset: 12)
                 .right(inset: 24)
        }

        flashLightModeButton.configureFrame { maker in
            maker.right(to: torchCameraButton.nui_left, inset: 5).centerY(to: torchCameraButton.nui_centerY).sizeToFit()
        }

        flipCameraButton.configureFrame { maker in
            maker.size(width: 76, height: 36)
                 .cornerRadius(byHalf: .height)
                 .right(inset: 24)
                 .centerY(to: captureButton.nui_centerY)
        }

        resultImageView.configureFrame { maker in
            maker.left().top(to: view.nui_safeArea.top, inset: 10).size(width: 100, height: 200)
        }
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

            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: .init(x: 0,
                                                                           y: 0,
                                                                           width: CVPixelBufferGetWidth(pixelBuffer),
                                                                           height: CVPixelBufferGetHeight(pixelBuffer))) else {
                return
            }
            let image = UIImage(cgImage: cgImage, scale: 1, orientation: uiImageOrientation)
            self.resultImageView.image = image
            self.delegate?.rCamViewController(self, imageCaptured: image)
        }
    }

    @objc private func torchCameraButtonPressed() {
        torchCameraButton.isSelected.toggle()
        if torchCameraButton.isSelected {
            cameraService.torchMode = .on
        }
        else {
            cameraService.torchMode = .off
        }
    }

    @objc private func flipCameraButtonPressed() {
        guard let cameraSnapshotView = cameraContainerView.snapshotView(afterScreenUpdates: true) else {
            return
        }

        cameraSnapshotView.frame = cameraContainerView.frame
        view.insertSubview(cameraSnapshotView, aboveSubview: cameraContainerView)
        cameraContainerView.isHidden = true

        let blurView = UIVisualEffectView(effect: nil)
        blurView.frame = view.bounds
        view.insertSubview(blurView, aboveSubview: cameraSnapshotView)

        UIView.animate(withDuration: 0.4, animations: {
            blurView.effect = UIBlurEffect(style: .prominent)
        }, completion: { _ in
            try? self.cameraService.flipCamera()
            UIView.animate(withDuration: 0.2, animations: {
                cameraSnapshotView.frame = self.cameraContainerView.frame
            }, completion: { _ in
                cameraSnapshotView.removeFromSuperview()
                blurView.removeFromSuperview()
                self.cameraContainerView.isHidden = false
            })
        })
    }

    // MARK: - Recognizers

    @objc private func videoViewTapped(recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: cameraContainerView)

        focusView.bounds = .init(origin: .zero, size: .init(width: 100, height: 100))
        focusView.center = cameraContainerView.convert(point, to: view)
        view.addSubview(focusView)

        focusView.transform = .init(scaleX: 2, y: 2)
        UIView.animate(withDuration: 0.2, animations: {
            self.focusView.transform = .identity
        }, completion: nil)

        focusViewTimer?.invalidate()
        focusViewTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            UIView.animate(withDuration: 0.2, animations: {
                self?.focusView.alpha = 0
            }, completion: { _ in
                self?.focusView.removeFromSuperview()
                self?.focusView.alpha = 1
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
            default:
                break
        }
    }

    @objc private func captureButtonLongPressed(recognizer: UILongPressGestureRecognizer) {

    }

    @objc private func flashModeButtonPressed() {
        flashLightModeButton.isSelected.toggle()
        if flashLightModeButton.isSelected {
            cameraService.flashMode = .off
        }
        else {
            cameraService.flashMode = .auto
        }
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
