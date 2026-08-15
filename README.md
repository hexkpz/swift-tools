# Tools

A Swift package for defining typed model tools, publishing their schemas, and executing tool calls.

[![CI](https://github.com/hexkpz/swift-tools/actions/workflows/ci.yml/badge.svg)](https://github.com/hexkpz/swift-tools/actions/workflows/ci.yml)
![Swift 6.3](https://img.shields.io/badge/Swift-6.3-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-Apple%20%7C%20Android%20%7C%20Linux-555555)

`Tools` is built on the included `Generable` module, which describes structured Swift values and
their JSON schemas. Together, the modules provide tool declarations, calls, results, and execution.

## Contents

- [Installation](#installation)
- [Tool Library](#tool-library)
  - [Defining a Tool](#defining-a-tool)
  - [Registering and Calling Tools](#registering-and-calling-tools)
  - [Tool Declarations](#tool-declarations)
  - [Shared Context](#shared-context)
  - [Batch Execution and Errors](#batch-execution-and-errors)
  - [Events and Logging](#events-and-logging)
- [Generable](#generable)
  - [Guided Types](#guided-types)
  - [Ignored Properties](#ignored-properties)
  - [Guides](#guides)
  - [Manual Schemas](#manual-schemas)
- [Requirements](#requirements)
- [License](#license)
- [Author](#author)

## Installation

Add the package to `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/hexkpz/swift-tools.git",
        branch: "main"
    ),
]
```

Add `Tools` to the target that defines or executes tools:

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Tools", package: "swift-tools"),
    ]
)
```

The `Tools` module reexports `Generable`. The `Generable` product can also be imported independently
for structured values and schemas.

## Tool Library

A `Tool` declares typed arguments and output. A `Library` registers tools, exposes their schemas,
and executes calls produced by a model or another caller.

### Defining a Tool

Conform a type to `Tool` and describe its arguments with `@Generable` and `@Guide`:

```swift
import Tools

struct GreetingTool: Tool {
    @Generable
    struct Arguments {
        @Guide(description: "The person's name")
        var name: String
    }

    let name = "greet"
    let description = "Creates a greeting."

    func perform(with arguments: Arguments, in _: Void) async throws -> String {
        guard !arguments.name.isEmpty else {
            throw Failure("Provide a name.")
        }

        return "Hello, \(arguments.name)!"
    }
}
```

The argument and output types must conform to `Generable`. Standard scalar and collection types,
including `String`, already conform.

Throw `Failure` when the model can correct the problem and try again. Other errors remain ordinary
Swift errors for the caller to handle.

### Registering and Calling Tools

Create a library, insert tools, and pass it calls containing structured arguments:

```swift
let library = Library<Void>(name: "Assistant")
try library.insert(GreetingTool())

let encoder = GeneratedContentEncoder()
let arguments = try encoder.encode(GreetingTool.Arguments(name: "Ada"))

let results = try await library.perform([
    Call(id: "call-1", named: "greet", with: arguments),
])

let decoder = GeneratedContentDecoder()
let greeting = try decoder.decode(String.self, from: results[0].output.get())
print(greeting) // Hello, Ada!
```

Use `Library<Void>` for tools with a `Void` context.

### Tool Declarations

Each registered tool exposes its name, description, argument schema, and output schema. A model
integration can translate these declarations into its own tool format:

```swift
let declaration = library.declaration(named: "greet")
let argumentSchema = declaration?.arguments.document
let outputSchema = declaration?.output.document
```

Both schemas are represented as canonical JSON Schema in `GeneratedContent`.

### Shared Context

Use `Library<Context>` when tools need state supplied by the application. Every tool in a library
uses the same context type:

```swift
struct ApplicationContext: Sendable {
    let locale: String
}

struct LocalizedGreetingTool: Tool {
    @Generable
    struct Arguments {
        var name: String
    }

    let name = "localized-greeting"
    let description = "Creates a localized greeting."

    func perform(
        with arguments: Arguments,
        in context: ApplicationContext
    ) async throws -> String {
        "Hello, \(arguments.name)! [\(context.locale)]"
    }
}

let library = Library<ApplicationContext>()
try library.insert(LocalizedGreetingTool())

let context = ApplicationContext(locale: "en_US")

let encoder = GeneratedContentEncoder()
let arguments = try encoder.encode(LocalizedGreetingTool.Arguments(name: "Ada"))

let results = try await library.perform(
    [Call(named: "localized-greeting", with: arguments)],
    in: context
)
```

### Batch Execution and Errors

`Library.perform` runs calls concurrently. `Library.Options` limits the number of active calls, and
the returned results remain in input order:

```swift
let results = try await library.perform(
    calls,
    options: .init(maximumConcurrentCalls: 2)
)
```

Each call stores its output or error in `Call.Result.output`. A `CancellationError` thrown by a tool
is recorded for that call while the remaining calls continue. Cancelling the task awaiting
`Library.perform` stops the whole batch and makes `Library.perform` throw `CancellationError`.

### Events and Logging

Observe calls through the library's asynchronous event sequence:

```swift
let events = library.events

Task {
    for await event in events {
        switch event {
        case let .started(invocation):
            print("Started \(invocation.tool.name)")
        case let .succeeded(invocation, _, duration):
            print("Finished \(invocation.tool.name) in \(duration) seconds")
        case let .failed(invocation, error, _):
            print("Failed \(invocation.tool.name): \(error)")
        }
    }
}
```

Events are broadcast to every active iterator. By default, each iterator buffers the newest 256
pending events.

`Library` accepts an optional `swift-log` `Logger`. Copies of a library share their registered
tools, logger, and event stream.

## Generable

`Generable` is the structured-value layer used by tools. It connects a Swift type to a
`GenerationSchema` and converts values to and from `GeneratedContent`.

### Guided Types

The `@Generable` macro synthesizes the schema, encoder, and decoder for structures and enumerations:

```swift
import Generable

@Generable(description: "A movie recommendation")
struct Movie {
    @Guide(description: "The title")
    var title: String

    @Guide(description: "A score from 1 through 5", .range(1 ... 5))
    var score: Int
}

let movie = Movie(title: "Arrival", score: 5)

let encoder = GeneratedContentEncoder()
let content = try encoder.encode(movie)

let decoder = GeneratedContentDecoder()
let decoded = try decoder.decode(Movie.self, from: content)

let schema = try Movie.generationSchema
print(schema.document)
```

`GeneratedContent` stores JSON-compatible values without losing integer precision. Object keys are
sorted, so `description` and `data()` produce stable output. Use `GeneratedContentEncoder` and
`GeneratedContentDecoder` to encode and decode `Generable` values.

`GenerationSchema.document` returns the JSON Schema document. Local Swift validators still run
when values are encoded, decoded, or validated, but they aren't included in that document. Use the
`using:` overloads to reuse an existing schema.

### Ignored Properties

Use `@GenerableIgnored` for local state that remains outside the generated schema and content. The
property keeps its declared default value when the containing value is decoded:

```swift
@Generable
struct Request {
    var query: String

    @GenerableIgnored
    var attempt = 0
}
```

An ignored property must declare a default value. Its type is unrestricted.

### Guides

Use `@Guide` to add a description, a JSON Schema constraint, or a local Swift validator to a
generated property:

```swift
@Generable
struct SearchRequest {
    @Guide(description: "The search query")
    var query: String

    @Guide(description: "The maximum result count", .range(1 ... 20))
    var limit: Int

    @Guide(description: "Up to five result tags", .maximum(count: 5))
    var tags: [String]
}
```

Built-in guides cover numeric bounds, allowed strings and URLs, URL schemes, and collection counts.
Schema constraints appear in the generated JSON Schema, while local validators run in Swift.

### Manual Schemas

Use `GenerationSchema` to build and validate schemas directly:

```swift
let schema = try GenerationSchema.structure(
    name: "Rating",
    properties: [.init(
        name: "score",
        description: "A score from 1 through 5",
        type: Int.self,
        guides: [.range(1 ... 5)]
    )]
)

let content = GeneratedContent(properties: [("score", .integer(5))])
try schema.validate(content)
```

The schema's `document` property contains its canonical JSON Schema representation.

## Requirements

- Swift 6.3+
- macOS 15+
- iOS 18+
- Mac Catalyst 18+
- tvOS 18+
- watchOS 11+
- visionOS 2+
- Android 9+ (API 28+)
- Linux

## License

This package is available under the [MIT License](LICENSE).

## Author

[hexkpz@gmail.com](mailto:hexkpz@gmail.com)
