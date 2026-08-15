//
//  Created by Anton Spivak
//

import Generable

// MARK: - GenerableErrorKind

enum GenerableErrorKind {
    case constraintViolation
    case invalidValue
    case missingProperty
    case unexpectedProperty

    // MARK: Internal

    func matches(_ error: any Swift.Error) -> Bool {
        guard let error = error as? Generable::Error else { return false }

        return switch (self, error) {
        case (.constraintViolation, .constraintViolation),
             (.invalidValue, .invalidValue),
             (.missingProperty, .missingProperty),
             (.unexpectedProperty, .unexpectedProperty):
            true
        default:
            false
        }
    }
}
