//
//  Copyright © 2018 Rosberry. All rights reserved.
//

import Foundation

extension Comparable {

    func clamped(min: Self, max: Self) -> Self {
        if self < min {
            return min
        }

        if self > max {
            return max
        }

        return self
    }

    func clamped(in range: ClosedRange<Self>) -> Self {
        return clamped(min: range.lowerBound, max: range.upperBound)
    }
}

extension Comparable where Self: Numeric {

    // MARK: - Wrap

    private func wrapped(min: Self, max: Self, maxComparator: (Self, Self) -> Bool) -> Self {
        var interval = max - min
        guard interval != 0 else {
            return min
        }

        if interval < 0 {
            interval *= -1
        }

        var result = self
        while result < min {
            result += interval
        }

        while maxComparator(result, max) {
            result -= interval
        }

        return result
    }

    func wrapped(from: Self, to: Self) -> Self {
        return wrapped(min: from, max: to, maxComparator: >=)
    }

    func wrapped(from: Self, through: Self) -> Self {
        return wrapped(min: from, max: through, maxComparator: >)
    }

    func wrapped(in range: ClosedRange<Self>) -> Self {
        return wrapped(min: range.lowerBound, max: range.upperBound, maxComparator: >)
    }
}

extension FloatingPoint {

    func denormalized(from: Self, through: Self) -> Self {
        return from + (through - from) * self
    }

    func denormalized(in range: ClosedRange<Self>) -> Self {
        return range.lowerBound + (range.upperBound - range.lowerBound) * self
    }

    func normalized(from: Self, through: Self) -> Self {
        return (self - from) / (through - from)
    }

    func normalized(in range: ClosedRange<Self>) -> Self {
        return (self - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    func mirrored(around value: Self) -> Self {
        return self + 2 * (value - self)
    }
}

extension Comparable where Self == Int {
    func wrappedIndex<T: Collection>(in collection: T) -> Self {
        return wrapped(from: 0, to: collection.count)
    }
}
