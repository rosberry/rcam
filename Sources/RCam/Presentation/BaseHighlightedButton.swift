//
//  Copyright © 2019 Rosberry. All rights reserved.
//

import UIKit

public class BaseHighlightedButton: UIButton {

    var isHighlightingEnabled: Bool = true

    public override var isHighlighted: Bool {
        get {
            return super.isHighlighted
        }
        set {
            guard isHighlightingEnabled else {
                super.isHighlighted = false
                return
            }
            super.isHighlighted = newValue
            UIView.animate(withDuration: 0.15, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut], animations: {
                self.backgroundColor = newValue ? UIColor.lightGray.withAlphaComponent(0.8) : .white
            }, completion: nil)
        }
    }
}
