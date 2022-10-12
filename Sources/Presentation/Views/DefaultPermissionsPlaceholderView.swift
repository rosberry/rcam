import UIKit

public final class DefaultPermissionsPlaceholderView: UIView {

    public var allowAccessEventHandler: (() -> Void)?

    public let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Give access to your camera, to take a shot"
        label.textColor = .white
        return label
    }()

    public let button: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Open Settings", for: .normal)
        button.addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)
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

    public override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.configureFrame { maker in
            maker.sizeToFit()
                 .center()
        }
        button.configureFrame { maker in
            maker.sizeToFit()
                 .top(to: titleLabel.nui_bottom, inset: 16)
                 .centerX()
        }
    }

    private func setup() {
        addSubview(titleLabel)
        addSubview(button)
        backgroundColor = .black
    }

    @objc private func buttonPressed() {
        allowAccessEventHandler?()
    }
}
