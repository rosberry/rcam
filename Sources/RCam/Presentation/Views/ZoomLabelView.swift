import UIKit

public final class ZoomLabelView: UIView {

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

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        .init(width: 38, height: 38)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        zoomValueLabel.configureFrame { maker in
            maker.centerY().left(inset: 4).sizeToFit()
        }

        zoomXLabel.configureFrame { maker in
            maker.centerY().right(inset: 4).sizeToFit()
        }
    }

    private func setup() {
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        addSubview(zoomValueLabel)
        addSubview(zoomXLabel)
    }
}
