//
//  Created by Anton Spivak
//

import Testing
import Tools

@Test
func `void context provides a context-free perform method`() async throws {
    let tool = StringTool<Void>(name: "identity") { arguments, _ in
        arguments.value
    }
    #expect(try await tool.perform(with: .init(value: "hello")) == "hello")
}
