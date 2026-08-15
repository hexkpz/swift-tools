//
//  Created by Anton Spivak
//

// MARK: - GenerationSchema.Property

public extension GenerationSchema {
    /// A property in a structure schema.
    struct Property: Sendable {
        // MARK: Lifecycle

        /// Creates a schema property.
        ///
        /// - Parameters:
        ///   - name: The property name.
        ///   - schema: The property schema.
        public init(name: consuming String, schema: consuming GenerationSchema) {
            self.name = name
            self.schema = schema
        }

        /// Creates a property from a ``Generable`` type.
        ///
        /// - Parameters:
        ///   - name: The property name.
        ///   - description: The property description.
        ///   - type: The property type.
        ///   - guides: The guides to apply.
        public init<Value: Generable>(
            name: String,
            description: String? = nil,
            type: Value.Type,
            guides: [GenerationGuide<Value>] = [],
        ) throws(Error) {
            let schema = try type.generationSchema
            let modifiers = Definition.Modifiers(description: description, guides: guides)

            try self.init(
                name: name,
                schema: schema.applying(modifiers),
            )
        }

        // MARK: Public

        /// The property name.
        public let name: String

        /// The property schema.
        public let schema: GenerationSchema
    }
}

// MARK: - GenerationSchema.Property + CustomStringConvertible

extension GenerationSchema.Property: CustomStringConvertible {
    public var description: String {
        "\(name): \(schema)"
    }
}

// MARK: - GenerationSchema.Property + CustomDebugStringConvertible

extension GenerationSchema.Property: CustomDebugStringConvertible {
    // swiftformat:disable wrap wrapArguments
    public var debugDescription: String {
        "GenerationSchema.Property(name: \(String(reflecting: name)), schema: \(String(reflecting: schema)))"
    }
    // swiftformat:enable wrap wrapArguments
}
