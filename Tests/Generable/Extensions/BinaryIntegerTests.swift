//
//  Created by Anton Spivak
//

import Testing
import Generable

@Test
func `fixed-width decoding rejects out-of-range values`() {
    #expect(throws: Generable::Error.self) {
        _ = try generatedContentDecoder.decode(
            Int8.self,
            from: .integer(Int16(Int8.max) + 1),
        )
    }

    #expect(throws: Generable::Error.self) {
        _ = try generatedContentDecoder.decode(UInt8.self, from: .integer(-1))
    }
}
