//
//  Created by Anton Spivak
//

import Generable

struct NonemptyIdentifierValidator: GenerationSchema.Validator {
    typealias Value = String

    let expected = "a nonempty identifier"

    func matches(_ content: GeneratedContent) -> Bool {
        guard case let .string(value) = content else { return false }
        return !value.isEmpty
    }
}
