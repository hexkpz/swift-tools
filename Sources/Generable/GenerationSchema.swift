//
//  Created by Anton Spivak
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

// MARK: - GenerationSchema

/// A schema for generated content.
///
/// Local validators run only in Swift and aren't included in ``generatedContent``.
///
/// ```swift
/// let schema = try GenerationSchema.structure(
///     name: "Rating",
///     properties: [
///         .init(
///             name: "score",
///             description: "A score from 1 through 5",
///             type: Int.self,
///             guides: [.range(1 ... 5)]
///         ),
///     ]
/// )
///
/// try schema.validate(GeneratedContent(properties: [
///     ("score", .integer(5)),
/// ]))
/// ```
public struct GenerationSchema: Sendable {
    // MARK: Lifecycle

    init(
        _ definition: Definition,
        registry suppliedRegistry: Graph.Registry? = nil,
    ) throws(Error) {
        let fragment = try Compiler.compile(definition)
        let registry: Graph.Registry =
            if let suppliedRegistry { suppliedRegistry }
            else { try definition.registry() }

        // Nested definitions remain fragments until the outermost build can assemble every
        // reference. Schemas created outside a definition context are complete immediately.
        let graph = if Context.current == nil {
            try Graph(root: fragment, registry: registry)
        } else {
            Graph(fragment: fragment, registry: registry)
        }

        self.init(definition: definition, graph: graph)
    }

    init(
        definition: Definition,
        graph: Graph,
    ) {
        self.definition = definition
        self.graph = graph
    }

    // MARK: Public

    /// The canonical JSON Schema representation.
    public var generatedContent: GeneratedContent {
        _read { yield graph.content }
    }

    #if canImport(FoundationEssentials) || canImport(Foundation)
    public var description: String { generatedContent.description }
    #endif

    /// Validates generated content.
    ///
    /// - Parameter content: The content to validate.
    /// - Throws: An error if the content is invalid.
    public func validate(_ content: borrowing GeneratedContent) throws(Error) {
        try graph.validate(content)
    }

    // MARK: Internal

    let definition: Definition
    let graph: Graph
}

extension GenerationSchema {
    static var never: Self {
        get throws(Error) { try .init(.init(.never)) }
    }
}

extension GenerationSchema {
    func applying(
        _ modifiers: Definition.Modifiers,
    ) throws(Error) -> Self {
        guard !modifiers.isEmpty else { return self }
        if case .reference = definition.kind, let constraint = modifiers.constraints.first {
            throw .unsupported(constraint, for: "a referenced schema")
        }

        let definition = try definition.applying(modifiers)
        // JSON-visible modifiers require recompiling the schema representation. Local validators
        // can reuse the existing graph because they don't appear in generated JSON Schema.
        guard modifiers.annotations.isEmpty, modifiers.constraints.isEmpty else {
            return try .init(definition, registry: graph.registry)
        }

        return .init(definition: definition, graph: graph.applying(modifiers.validations))
    }
}

public extension GenerationSchema {
    /// Returns a copy with a local validator.
    ///
    /// - Parameter validator: The local validator.
    func validating<Validator: GenerationSchema.Validator>(
        _ validator: Validator,
    ) throws(Error) -> Self {
        try applying(.init(validations: [.init(validator)]))
    }
}

public extension GenerationSchema {
    @_documentation(visibility: private)
    static func definition<Value: Generable>(
        of type: Value.Type,
        name: String,
        _ body: () throws(Error) -> GenerationSchema,
    ) throws(Error) -> GenerationSchema {
        // Macro-generated conformances share this context for recursive and reused definitions.
        if let context = Context.current {
            return try context.define(type, name: name, body: body)
        }

        let context = Context()
        // Definition bodies can't suspend, so the mutable context remains task-confined.
        let result: Result<GenerationSchema, Error> = Context.$current.withValue(context) {
            do {
                let schema = try context.define(type, name: name, body: body)
                return try .success(context.finalize(consume schema))
            } catch let error as Error {
                return .failure(error)
            } catch {
                preconditionFailure("Schema construction threw an unexpected error: \(error)")
            }
        }

        return try result.get()
    }
}

public extension GenerationSchema {
    /// A schema for `null`.
    static var null: Self {
        get throws(Error) { try .init(.init(.null)) }
    }

    /// Creates a Boolean schema.
    ///
    /// - Parameter description: The schema description.
    static func boolean(
        description: String? = nil,
    ) throws(Error) -> Self {
        try .init(.init(.boolean, description: description))
    }

    /// Creates an integer schema.
    ///
    /// - Parameters:
    ///   - description: The schema description.
    ///   - constraints: The schema constraints.
    static func integer(
        description: String? = nil,
        constraints: [Constraint] = [],
    ) throws(Error) -> Self {
        try .init(.init(.integer(constraints), description: description))
    }

    /// Creates a number schema.
    ///
    /// - Parameters:
    ///   - description: The schema description.
    ///   - constraints: The schema constraints.
    static func number(
        description: String? = nil,
        constraints: [Constraint] = [],
    ) throws(Error) -> Self {
        try .init(.init(.number(constraints), description: description))
    }

    /// Creates a string schema.
    ///
    /// - Parameters:
    ///   - description: The schema description.
    ///   - constraints: The schema constraints.
    static func string(
        description: String? = nil,
        constraints: [Constraint] = [],
    ) throws(Error) -> Self {
        try .init(.init(.string(constraints), description: description))
    }

    /// Creates an array schema.
    ///
    /// - Parameters:
    ///   - element: The element schema.
    ///   - description: The schema description.
    ///   - constraints: The schema constraints.
    static func array(
        _ element: GenerationSchema,
        description: String? = nil,
        constraints: [Constraint] = [],
    ) throws(Error) -> Self {
        try .init(.init(
            .array(element, constraints),
            description: description,
        ))
    }

    /// Creates a dictionary schema with arbitrary string keys.
    ///
    /// - Parameters:
    ///   - value: The value schema.
    ///   - description: The schema description.
    static func dictionary(
        _ value: GenerationSchema,
        description: String? = nil,
    ) throws(Error) -> Self {
        try .init(.init(.dictionary(value), description: description))
    }

    /// Creates a closed-object schema.
    ///
    /// - Parameters:
    ///   - name: The schema name.
    ///   - description: The schema description.
    ///   - properties: The object properties.
    static func structure(
        name: String? = nil,
        description: String? = nil,
        properties: [Property],
    ) throws(Error) -> Self {
        try .init(.init(
            .structure(properties),
            title: name,
            description: description,
        ))
    }

    /// Creates a schema for a fixed set of strings.
    ///
    /// - Parameters:
    ///   - name: The schema name.
    ///   - description: The schema description.
    ///   - values: The allowed strings.
    static func enumeration(
        name: String? = nil,
        description: String? = nil,
        values: [String],
    ) throws(Error) -> Self {
        try .init(.init(
            .enumeration(values),
            title: name,
            description: description,
        ))
    }

    /// Creates an optional schema.
    ///
    /// - Parameter wrapped: The wrapped schema.
    static func optional(
        _ wrapped: GenerationSchema,
    ) throws(Error) -> Self {
        try .init(.init(.optional(wrapped, [])))
    }

    /// Creates an `anyOf` schema.
    ///
    /// - Parameters:
    ///   - schemas: The alternative schemas.
    ///   - name: The schema name.
    ///   - description: The schema description.
    static func anyOf(
        _ schemas: [GenerationSchema],
        name: String? = nil,
        description: String? = nil,
    ) throws(Error) -> Self {
        try .init(.init(
            .anyOf(schemas),
            title: name,
            description: description,
        ))
    }

    /// Creates a `oneOf` schema.
    ///
    /// - Parameters:
    ///   - schemas: The alternative schemas.
    ///   - name: The schema name.
    ///   - description: The schema description.
    static func oneOf(
        _ schemas: [GenerationSchema],
        name: String? = nil,
        description: String? = nil,
    ) throws(Error) -> Self {
        try .init(.init(
            .oneOf(schemas),
            title: name,
            description: description,
        ))
    }
}

// MARK: - GenerationSchema + Equatable

extension GenerationSchema: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.generatedContent == rhs.generatedContent
    }
}

// MARK: - GenerationSchema + Hashable

extension GenerationSchema: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(generatedContent)
    }
}

// MARK: CustomStringConvertible

#if canImport(FoundationEssentials) || canImport(Foundation)

extension GenerationSchema: CustomStringConvertible {}

#endif

// MARK: CustomDebugStringConvertible

extension GenerationSchema: CustomDebugStringConvertible {
    public var debugDescription: String {
        "GenerationSchema(\(String(reflecting: generatedContent)))"
    }
}
