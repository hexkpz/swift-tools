//
//  Created by Anton Spivak
//

// MARK: - Graph.Structure

extension Graph {
    struct Structure: Sendable {
        let properties: [Property]
    }
}

// MARK: - Graph.Structure.Property

extension Graph.Structure {
    struct Property: Sendable {
        // MARK: Lifecycle

        init(
            name: consuming String,
            node: consuming Graph.Node,
            isOptional: Bool,
        ) {
            self.name = name
            self.node = node
            self.isOptional = isOptional
        }

        // MARK: Internal

        let name: String
        let node: Graph.Node
        let isOptional: Bool
    }
}

extension Graph.Structure {
    func validate(
        _ values: GeneratedContent.Object,
        references: [Graph.Reference.ID: Graph.Node],
    ) throws(Error) {
        try validate(shapeOf: values)

        var propertyIndex = properties.startIndex
        for value in values {
            while properties[propertyIndex].name < value.name {
                propertyIndex = properties.index(after: propertyIndex)
            }

            try properties[propertyIndex].node.validate(
                value.value,
                references: references,
            )

            propertyIndex = properties.index(after: propertyIndex)
        }
    }

    func validate(
        shapeOf values: GeneratedContent.Object,
    ) throws(Error) {
        guard values.hasUniquePropertyNames
        else { throw .duplicateObjectPropertyNames() }

        var propertyIndex = properties.startIndex
        var valueIndex = values.startIndex

        // Both collections are name-sorted, so one merge-style pass detects missing and
        // unexpected properties without allocating lookup tables.
        while propertyIndex < properties.endIndex, valueIndex < values.endIndex {
            let property = properties[propertyIndex]
            let value = values[valueIndex]

            if property.name < value.name {
                guard property.isOptional else { throw .missingProperty(property.name) }
                propertyIndex = properties.index(after: propertyIndex)
            } else if value.name < property.name {
                throw .unexpectedProperty(value.name)
            } else {
                propertyIndex = properties.index(after: propertyIndex)
                valueIndex = values.index(after: valueIndex)
            }
        }

        if valueIndex < values.endIndex {
            throw .unexpectedProperty(values[valueIndex].name)
        }

        if let property = properties[propertyIndex...].first(where: { !$0.isOptional }) {
            throw .missingProperty(property.name)
        }
    }
}

extension Graph.Structure {
    func property(named name: String) -> Property? {
        let lowerBound = properties.lowerBound(for: name, by: \.name)
        guard lowerBound < properties.endIndex, properties[lowerBound].name == name
        else { return nil }

        return properties[lowerBound]
    }
}
