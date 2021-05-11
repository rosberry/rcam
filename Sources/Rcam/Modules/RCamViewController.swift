//
//  Copyright © 2021 Rosberry. All rights reserved.
//

import UIKit
import AVFoundation
import Framezilla

//public protocol CameraViewInput: class {
//    func display(_ buffer: CVPixelBuffer)
//    func displayErrorWithDescription(_ description: String)
//}

public protocol CameraViewOutput: class {

    var zoomLevel: CGFloat? { get }
    var zoomRange: ClosedRange<CGFloat>? { get }
    var videoRecordingStartDelay: TimeInterval { get }

    func viewDidLoad()
    func filterChangedToNone()
    func filterChangedToCold()
    func filterChangedToWarm()
    func captureButtonTouchedDown()
    func captureButtonTouchedUp()
    func flipCameraEventTriggered()
    func flashEventTriggered()
    func torchEventTriggered()
    func changeAspectEventTriggered()
    func updateFocusPoint(with point: CGPoint)
    func zoomEventTriggered(zoomLevel: CGFloat)
}

public final class RCamViewController: UIViewController {

    private enum Constants {
        static let zoomLevelDistance: CGFloat = 300
    }

    private let output: CameraViewOutput?

    public override var prefersStatusBarHidden: Bool {
        true
    }

    var focusViewTimer: Timer?
    private var initialLongPressGesturePoint: CGPoint = .zero
    private var initialLongPressZoomRelativeValue: CGFloat = 0

    private lazy var pinchGestureRecognizer: UIPinchGestureRecognizer = {
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(viewPinched))
        pinchGestureRecognizer.delegate = self
        pinchGestureRecognizer.cancelsTouchesInView = false
        return pinchGestureRecognizer
    }()

    // MARK: - Subviews

    private lazy var cameraPreviewLayer: AVCaptureVideoPreviewLayer = .init()
    private lazy var cameraView: UIView = {
        let view = UIView()
        view.layer.addSublayer(cameraPreviewLayer)
        return view
    }()
    private lazy var cameraContainerView: UIView = .init()

    private lazy var noneFilterButton: UIButton = {
        let button = UIButton(type: .system)
        button.addTarget(self, action: #selector(noneFilterButtonPressed), for: .touchUpInside)
        button.setTitle("N", for: .normal)
        button.backgroundColor = .white
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()

    private lazy var coldFilterButton: UIButton = {
        let button = UIButton(type: .system)
        button.addTarget(self, action: #selector(coldFilterButtonPressed), for: .touchUpInside)
        button.setTitle("C", for: .normal)
        button.backgroundColor = .white
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()

    private lazy var warmFilterButton: UIButton = {
        let button = UIButton(type: .system)
        button.addTarget(self, action: #selector(warmFilterButtonPressed), for: .touchUpInside)
        button.setTitle("W", for: .normal)
        button.backgroundColor = .white
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()

    private lazy var captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.addTarget(self, action: #selector(captureButtonTouchedDown), for: .touchDown)
        button.addTarget(self, action: #selector(captureButtonTouchedUp), for: .touchUpInside)
        button.addTarget(self, action: #selector(captureButtonTouchedUp), for: .touchUpOutside)
        button.addTarget(self, action: #selector(captureButtonTouchedUp), for: .touchCancel)
        button.backgroundColor = .red
        return button
    }()

    private lazy var flashCameraButton: UIButton = {
        let button = UIButton(type: .system)
        button.addTarget(self, action: #selector(flashCameraButtonPressed), for: .touchUpInside)
        button.backgroundColor = .white
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        return button
    }()

    private lazy var aspectButton: UIButton = {
        let button = UIButton(type: .system)
        button.addTarget(self, action: #selector(aspectButtonPressed), for: .touchUpInside)
        button.backgroundColor = .white
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        return button
    }()

    private lazy var focusView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()

    // MARK: - Lifecycle

    public init(output: CameraViewOutput?) {
        self.output = output
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

        let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewDoubleTapped))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        doubleTapGestureRecognizer.delegate = self
        doubleTapGestureRecognizer.cancelsTouchesInView = false
        cameraContainerView.addGestureRecognizer(doubleTapGestureRecognizer)

        cameraContainerView.addGestureRecognizer(pinchGestureRecognizer)

        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(captureButtonLongPressed))
        longPressGestureRecognizer.delegate = self
        longPressGestureRecognizer.minimumPressDuration = 0
        longPressGestureRecognizer.cancelsTouchesInView = false
        captureButton.addGestureRecognizer(longPressGestureRecognizer)

        cameraContainerView.addSubview(cameraView)
        view.addSubview(cameraContainerView)
        view.addSubview(captureButton)
        view.addSubview(noneFilterButton)
        view.addSubview(coldFilterButton)
        view.addSubview(warmFilterButton)
        view.addSubview(flashCameraButton)
        view.addSubview(aspectButton)

        output?.viewDidLoad()
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

        let filterButtonsSide = 48
        noneFilterButton.configureFrame { maker in
            maker.size(width: filterButtonsSide, height: filterButtonsSide)
                 .cornerRadius(byHalf: .height)
                 .centerX().bottom(to: captureButton.nui_top, inset: 32)
        }

        coldFilterButton.configureFrame { maker in
            maker.size(width: filterButtonsSide, height: filterButtonsSide)
                 .cornerRadius(byHalf: .height)
                 .bottom(to: noneFilterButton.nui_bottom)
                 .right(to: noneFilterButton.nui_left, inset: 24)
        }

        warmFilterButton.configureFrame { maker in
            maker.size(width: filterButtonsSide, height: filterButtonsSide)
                 .cornerRadius(byHalf: .height)
                 .bottom(to: noneFilterButton.nui_bottom)
                 .left(to: noneFilterButton.nui_right, inset: 24)
        }

        flashCameraButton.configureFrame { maker in
            maker.size(width: 76, height: 36)
                 .cornerRadius(byHalf: .height)
                 .top(to: view.nui_safeArea.top, inset: 12)
                 .right(inset: 24)
        }

        aspectButton.configureFrame { maker in
            maker.size(width: 76, height: 36)
                 .cornerRadius(byHalf: .height)
                 .right(inset: 24)
                 .centerY(to: captureButton.nui_centerY)
        }
    }

    // MARK: - Actions

    @objc private func noneFilterButtonPressed() {
        output?.filterChangedToNone()
    }

    @objc private func coldFilterButtonPressed() {
        output?.filterChangedToCold()
    }

    @objc private func warmFilterButtonPressed() {
        output?.filterChangedToWarm()
    }

    @objc private func captureButtonTouchedDown() {
        output?.captureButtonTouchedDown()
    }

    @objc private func captureButtonTouchedUp() {
        output?.captureButtonTouchedUp()
    }

    @objc private func flashCameraButtonPressed() {
        output?.torchEventTriggered()
    }

    @objc private func aspectButtonPressed() {
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
            self.output?.changeAspectEventTriggered()
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

        focusView.sizeToFit()
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
        output?.updateFocusPoint(with: normalizedPoint)
    }

    @objc private func viewDoubleTapped() {
        output?.flipCameraEventTriggered()
    }

    @objc private func viewPinched(recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
            case .began:
                if let zoomLevel = output?.zoomLevel {
                    recognizer.scale = zoomLevel
                }
            case .changed:
                let scale = recognizer.scale
                output?.zoomEventTriggered(zoomLevel: scale)
            default:
                break
        }
    }

    @objc private func captureButtonLongPressed(recognizer: UILongPressGestureRecognizer) {
        guard let zoomLevel = output?.zoomLevel,
              let zoomRange = output?.zoomRange else {
            return
        }
        let point = recognizer.location(in: captureButton)
        let minZoomLevel = zoomRange.lowerBound
        let zoomRangeSpread = zoomRange.upperBound - minZoomLevel

        switch recognizer.state {
        case .began:
            pinchGestureRecognizer.isEnabled = false
            let zoomPercent = (zoomLevel - minZoomLevel) / zoomRangeSpread
            initialLongPressZoomRelativeValue = deCubicEaseIn(zoomPercent) * Constants.zoomLevelDistance
            initialLongPressGesturePoint = point
        case .changed:
            let distance = max(initialLongPressZoomRelativeValue,
                               initialLongPressZoomRelativeValue + (initialLongPressGesturePoint.y - point.y))
            let normalizedZoomLevel = distance / Constants.zoomLevelDistance
            output?.zoomEventTriggered(zoomLevel: cubicEaseIn(normalizedZoomLevel) * zoomRangeSpread + minZoomLevel)
        case .ended, .failed, .cancelled:
            pinchGestureRecognizer.isEnabled = true
        default:
            break
        }
    }

    private func cubicEaseIn<T: FloatingPoint>(_ x: T) -> T {
        x * x * x
    }

    private func deCubicEaseIn(_ x: CGFloat) -> CGFloat {
        pow(x, CGFloat(1) / CGFloat(3))
    }
}

// MARK: - CameraViewInput

//extension CameraViewController: CameraViewInput {
//
//    public func displayErrorWithDescription(_ description: String) {
//        let alertController = UIAlertController(title: "Error", message: description, preferredStyle: .alert)
//        alertController.addAction(.init(title: "OK", style: .default))
//        present(alertController, animated: true)
//    }
//}

// MARK: - UIGestureRecognizerDelegate

extension RCamViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
