//
//  Created by Anton Spivak
//

extension RandomAccessCollection {
    @inline(__always)
    func lowerBound<Value: Comparable>(
        for value: Value,
        by projection: (Element) -> Value,
    ) -> Index {
        var lowerBound = startIndex
        var upperBound = endIndex

        while lowerBound != upperBound {
            let middle = index(lowerBound, offsetBy: distance(from: lowerBound, to: upperBound) / 2)
            if projection(self[middle]) < value {
                lowerBound = index(after: middle)
            } else {
                upperBound = middle
            }
        }

        return lowerBound
    }
}
