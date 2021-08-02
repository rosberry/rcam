//
// Copyright (c) 2018 Rosberry. All rights reserved.
//

import Foundation

/// Class for storing the value and the condition when it should be used.
public class ConditionValue<T> {

    /// The actual value
    public let value: T
    /// If it returns `true` then the value should be used
    public let condition: (() -> Bool)

    /// - Parameters:
    ///   - value: Actual value
    ///   - value: If it returns `true` then the value should be used
    public init(value: T, condition: @escaping (() -> Bool)) {
        self.value = value
        self.condition = condition
    }
}
