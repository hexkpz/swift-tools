//
//  Created by Anton Spivak
//

public extension Generable
    where
    Self: RandomAccessCollection & RangeReplaceableCollection,
    Element: Generable
{
    static var generationSchema: GenerationSchema {
        get throws(Error) { try .array(Element.generationSchema) }
    }

    init(from decoder: inout GenerationDecoder) throws {
        self = try decoder.decode()
    }

    func encode(to encoder: inout GenerationEncoder) throws {
        try encoder.encode(self)
    }
}

public extension GenerationGuide
    where
    Value: RandomAccessCollection & RangeReplaceableCollection,
    Value.Element: Generable
{
    /// Sets the minimum generated element count.
    static func minimum(count: Int) -> Self {
        .init(.minimum(count: count))
    }

    /// Sets the maximum generated element count.
    static func maximum(count: Int) -> Self {
        .init(.maximum(count: count))
    }
}

@_documentation(visibility: private)
public extension GenerationGuide where Value == [Never] {
    @_documentation(visibility: private)
    static func minimum(count: Int) -> Self {
        // These concrete overloads let the guide macro type-check count constraints before it
        // knows the annotated property's collection type.
        fatalError("GenerationGuide<[Never]>.\(#function) should not be called.")
    }

    @_documentation(visibility: private)
    static func maximum(count: Int) -> Self {
        fatalError("GenerationGuide<[Never]>.\(#function) should not be called.")
    }
}

// MARK: - Array + Generable

extension Array: Generable where Element: Generable {}

// MARK: - ArraySlice + Generable

extension ArraySlice: Generable where Element: Generable {}

// MARK: - ContiguousArray + Generable

extension ContiguousArray: Generable where Element: Generable {}
