//
// Copyright (c) 2018 Rosberry. All rights reserved.
//

import Foundation

/// Use this class for configuration values such as
/// API URL, specific modes for notifications, etc.
public class ConditionVariable<T> {

    @_functionBuilder
    public struct Builder {
        public static func buildBlock<T>(_ values: ConditionValue<T>...) -> [ConditionValue<T>] {
            values
        }
    }

    /// All possible values of this variable
    private let values: [ConditionValue<T>]

    /// Returns value depends on faced conditions
    public var value: T {
        for value in values where value.condition() == true {
            return value.value
        }
        fatalError("You face this exception because you didn't setup your configuration variable properly." +
                           "Please, check the values you specified and their conditions.")
    }

    /// - Parameters:
    ///   - values: All possible values of this variable.
    ///             Variables will be checked the same order they are set here.
    ///             So it is better to set variable which will be used in AppStore first.
    public init(values: [ConditionValue<T>]) {
        self.values = values
    }

    public init(@Builder builder: () -> [ConditionValue<T>]) {
        self.values = builder()
    }
}
