import UIKit

public final class FooterView: UIView {

    public final class CaptureButtonView: UIView {

        public var captureButtonEventHandler: (() -> Void)?

        private lazy var bundle: Bundle = .init(for: Self.self)
        private let captureButtonSize = CGSize(width: 57, height: 57)

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

        override init(frame: CGRect) {
            super.init(frame: frame)
            setup()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }

        public override func sizeThatFits(_ size: CGSize) -> CGSize {
            .init(width: 96, height: 96)
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            captureButtonContainerView.configureFrame { maker in
                maker.size(width: captureButtonSize.width + 10, height: captureButtonSize.height + 10)
                     .center().cornerRadius(byHalf: .height)
            }

            captureButton.configureFrame { maker in
                maker.size(captureButtonSize)
                     .center().cornerRadius(byHalf: .height)
            }
        }

        private func setup() {
            addSubview(captureButtonContainerView)
            addSubview(captureButton)
        }

        @objc private func captureButtonPressed() {
            captureButtonEventHandler?()
        }
    }

    public var flashModeEventHandler: (() -> Void)?
    public var flipCameraEventHandler: (() -> Void)?
    private lazy var bundle: Bundle = .init(for: Self.self)

    public private(set) lazy var flashLightModeButton: UIButton = {
        let button = UIButton()
        let image = UIImage(named: "ic32FlashAuto", in: bundle, compatibleWith: nil)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        button.addTarget(self, action: #selector(flashModeButtonPressed), for: .touchUpInside)
        return button
    }()

    public private(set) lazy var captureButtonView: CaptureButtonView = {
        .init()
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let footerContainerViewHeight: CGFloat = 96 + 36 + 36
        return .init(width: min(size.width, UIScreen.main.bounds.width), height: footerContainerViewHeight)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        captureButtonView.configureFrame { maker in
            maker.sizeToFit().center().cornerRadius(byHalf: .height)
        }

        flashLightModeButton.configureFrame { maker in
            let actualSize = flashLightModeButton.sizeThatFits(bounds.size)
            maker.size(width: actualSize.width + 20, height: actualSize.height + 20).cornerRadius(byHalf: .height)
            maker.right(to: captureButtonView.nui_left, inset: 50)
                 .centerY()
        }

        flipCameraButton.configureFrame { maker in
            let actualSize = flipCameraButton.sizeThatFits(bounds.size)
            maker.size(width: actualSize.width + 20, height: actualSize.height + 20).cornerRadius(byHalf: .height)
            maker.left(to: captureButtonView.nui_right, inset: 50)
                 .centerY()
        }
    }

    private func setup() {
        addSubview(flashLightModeButton)
        addSubview(captureButtonView)
        addSubview(flipCameraButton)
    }

    @objc private func flashModeButtonPressed() {
        flashModeEventHandler?()
    }

    @objc private func flipCameraButtonPressed() {
        flipCameraEventHandler?()
    }
}
