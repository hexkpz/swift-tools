//
//  Created by Anton Spivak
//

import Generable

// MARK: - GenerableModuleNameCollisionFixture

private enum GenerableModuleNameCollisionFixture {
    struct GeneratedContent {}
    struct GenerationSchema {}

    @Generable
    struct Value {
        var number: Int
    }
}

// MARK: - PublicGenerableExtensionFixture

public enum PublicGenerableExtensionFixture {}

// MARK: PublicGenerableExtensionFixture.Value

public extension PublicGenerableExtensionFixture {
    @Generable
    struct Value {
        var number: Int
    }
}
