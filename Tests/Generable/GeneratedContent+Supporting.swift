//
//  Created by Anton Spivak
//

import Generable

func integerValue<Value: BinaryInteger>(
    _ content: GeneratedContent?,
    as _: Value.Type,
) -> Value? {
    guard case let .integer(value) = content else { return nil }
    return Value(exactly: value)
}

func stringValue(_ content: GeneratedContent?) -> String? {
    guard case let .string(value) = content else { return nil }
    return value
}

func stringValues(_ content: GeneratedContent?) -> [String]? {
    guard case let .array(contents) = content else { return nil }

    var values: [String] = []
    values.reserveCapacity(contents.count)

    for content in contents {
        guard case let .string(value) = content else { return nil }
        values.append(value)
    }

    return values
}
