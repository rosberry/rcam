//
// Copyright (c) 2018 Rosberry. All rights reserved.
//

import UIKit

/// Based on screen size
public final class ScreenVariable<T>: ConditionVariable<T> {

    public static func heightRelated(s small: T, m medium: T, l large: T) -> ScreenVariable<T> {
        let screenHeight = UIScreen.main.bounds.height
        return .init {
            ConditionValue(value: small) { () -> Bool in
                screenHeight < 667
            }
            ConditionValue(value: medium) { () -> Bool in
                screenHeight >= 667 && screenHeight < 812
            }
            ConditionValue(value: large) { () -> Bool in
                screenHeight >= 812
            }
        }
    }

    public static func widthRelated(s small: T, m medium: T, l large: T) -> ScreenVariable<T> {
        let screenWidth = UIScreen.main.bounds.width
        return ScreenVariable<T> {
            ConditionValue(value: small) { () -> Bool in
                screenWidth == 320
            }
            ConditionValue(value: medium) { () -> Bool in
                screenWidth == 375
            }
            ConditionValue(value: large) { () -> Bool in
                screenWidth > 375
            }
        }
    }

    override public init(@Builder builder: () -> [ConditionValue<T>]) {
        super.init(builder: builder)
    }
}

public extension ScreenVariable where T == Double {

    var cgFloatValue: CGFloat {
        CGFloat(value)
    }
}

public extension ScreenVariable where T == Int {

    var cgFloatValue: CGFloat {
        CGFloat(value)
    }
}
