//
//  Created by Anton Spivak
//

import Testing
import Generable

@Test
func `fixed-width decoding rejects out-of-range values`() {
    #expect(throws: Generable::Error.self) {
        _ = try GeneratedContent.integer(Int16(Int8.max) + 1).decode(Int8.self)
    }

    #expect(throws: Generable::Error.self) {
        _ = try GeneratedContent.integer(-1).decode(UInt8.self)
    }
}
