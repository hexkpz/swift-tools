//
//  Created by Anton Spivak
//

import Synchronization
@_exported import Logging

// MARK: - Library

/// A named collection of tools.
///
/// Copies share their tools, logger, and events.
///
/// ```swift
/// let library = Library<Void>(name: "Assistant")
/// try library.insert(GreetingTool())
///
/// let result = await library.perform(Call(
///     named: "greet",
///     with: GeneratedContent(properties: [
///         ("name", .string("Ada")),
///     ])
/// ))
///
/// let decoder = GeneratedContentDecoder()
/// let greeting = try decoder.decode(String.self, from: result.output.get().content)
/// ```
public struct Library<Context: Sendable>: Sendable {
    // MARK: Lifecycle

    /// Creates an empty tool library.
    ///
    /// - Parameters:
    ///   - name: The library name. The default is the concrete type name.
    ///   - logger: The optional diagnostics logger.
    public init(
        name: String = String(describing: Self.self),
        logger: Logger? = nil,
    ) {
        self.name = name
        self.storage = Storage(logger: logger)
    }

    // MARK: Public

    /// The library name.
    public let name: String

    /// The optional diagnostics logger.
    public var logger: Logger? {
        get { storage { $0.logger } }
        nonmutating set { storage { $0.logger = newValue } }
    }

    /// Events emitted by tool calls.
    public var events: Events { storage.events }

    /// The registered tool declarations, sorted by name.
    public var declarations: [Declaration] {
        storage { state in state.tools.values }
            .map(\.declaration)
            .sorted { $0.name < $1.name }
    }

    /// Returns a tool declaration by name.
    ///
    /// - Parameter name: The tool name.
    /// - Returns: The declaration, or `nil` if the tool isn't registered.
    public func declaration(named name: String) -> Declaration? {
        storage { $0.tools[name]?.declaration }
    }

    // MARK: Private

    private let storage: Storage

    private func duration(
        from start: ContinuousClock.Instant,
        to end: ContinuousClock.Instant,
    ) -> Double {
        let components = start.duration(to: end).components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

// MARK: Library.Storage

private extension Library {
    final class Storage: Sendable {
        // MARK: Lifecycle

        init(logger: Logger?) {
            self.state = Mutex(.init(logger: logger, tools: [:]))
        }

        // MARK: Internal

        typealias Function<Result: ~Copyable, E: Swift.Error> = (
            inout sending State,
        ) throws(E) -> sending Result

        struct State: Sendable {
            var logger: Logger?
            var tools: [String: AnyTool<Context>]
        }

        let events = Events()

        @inline(__always)
        func callAsFunction<Result: ~Copyable, E: Swift.Error>(
            _ body: Function<Result, E>,
        ) throws(E) -> sending Result {
            try state.withLock(body)
        }

        // MARK: Private

        private let state: Mutex<State>
    }
}

// MARK: Library.Options

public extension Library {
    /// Options for concurrent tool calls.
    struct Options: Sendable, Hashable {
        // MARK: Lifecycle

        /// Creates call options.
        ///
        /// Values below `1` are clamped to `1`.
        ///
        /// - Parameter maximumConcurrentCalls: The maximum number of calls to run at once.
        public init(maximumConcurrentCalls: Int = 4) {
            self.maximumConcurrentCalls = Swift.max(1, maximumConcurrentCalls)
        }

        // MARK: Public

        /// The maximum number of calls to run at once.
        public let maximumConcurrentCalls: Int
    }
}

public extension Library {
    /// Runs a tool call.
    ///
    /// The returned result contains either the tool output or the error produced by the call.
    ///
    /// - Parameters:
    ///   - call: The call to run.
    ///   - context: The context passed to the tool.
    /// - Returns: The result of the call.
    func perform(_ call: consuming Call, in context: Context) async -> Call.Result {
        do {
            let output: Call.Result.Output = try await perform(call, in: context)
            return Call.Result(call: consume call, output: .success(output))
        } catch {
            return Call.Result(call: consume call, output: .failure(error))
        }
    }

    /// Runs tool calls concurrently.
    ///
    /// Results preserve input order. If a tool throws `CancellationError`, only that call fails and
    /// the error is stored in its result. Cancelling the task awaiting this method stops the entire
    /// batch.
    ///
    /// - Parameters:
    ///   - calls: The calls to run.
    ///   - options: The call options.
    ///   - context: The context passed to each tool.
    /// - Returns: A result for each call, in the same order as `calls`.
    /// - Throws: `CancellationError` if the task running the batch is canceled.
    func perform(
        _ calls: [Call],
        options: Options = .init(),
        in context: Context,
    ) async throws -> [Call.Result] {
        typealias Result = (index: Int, result: Call.Result)
        try Task.checkCancellation()
        return try await withThrowingTaskGroup(
            of: Result.self,
            returning: [Call.Result].self,
        ) { group in
            var next = 0
            func run() {
                guard next < calls.count else { return }

                let index = next
                let call = calls[index]

                let added = group.addTaskUnlessCancelled {
                    await Result(index: index, result: perform(call, in: context))
                }

                guard added else { return }
                next += 1
            }

            for _ in 0 ..< Swift.min(options.maximumConcurrentCalls, calls.count) {
                run()
            }

            var results: [Result] = []
            results.reserveCapacity(calls.count)
            for try await result in group {
                try Task.checkCancellation()
                results.append(result)
                // Refill the group as calls finish while keeping concurrency within the limit.
                run()
            }

            try Task.checkCancellation()
            results.sort { $0.index < $1.index }
            return results.map(\.result)
        }
    }

    private func perform(
        _ call: borrowing Call,
        in context: Context,
    ) async throws -> Call.Result.Output {
        try Task.checkCancellation()

        let tool = storage { $0.tools[call.name] }
        guard let tool else {
            let failure = Failure("Unknown tool named \(String(reflecting: call.name)).")
            let metadata = metadata(for: call.name)
            logger?.warning("Rejected an unknown tool invocation.", metadata: metadata)
            throw failure
        }

        let invocation = Events.Invocation(
            call: copy call,
            tool: tool.declaration,
        )

        emit(.started(invocation))

        let clock = ContinuousClock()
        let startedAt = clock.now

        do {
            let output = try await tool.perform(with: call.arguments, in: context)
            let duration = duration(from: startedAt, to: clock.now)
            emit(.succeeded(invocation, output: output.content, duration: duration))
            return output
        } catch {
            let duration = duration(from: startedAt, to: clock.now)
            emit(.failed(invocation, error: error, duration: duration))
            throw error
        }
    }
}

public extension Library where Context == Void {
    /// Runs a context-free tool call.
    ///
    /// - Parameter call: The call to run.
    /// - Returns: The result of the call.
    func perform(_ call: consuming Call) async -> Call.Result {
        await perform(consume call, in: ())
    }

    /// Runs context-free tool calls concurrently.
    ///
    /// - Parameters:
    ///   - calls: The calls to run.
    ///   - options: The call options.
    /// - Returns: A result for each call, in the same order as `calls`.
    /// - Throws: `CancellationError` if the task running the batch is canceled.
    func perform(
        _ calls: [Call],
        options: Options = .init(),
    ) async throws -> [Call.Result] {
        try await perform(calls, options: options, in: ())
    }
}

public extension Library {
    /// Adds a tool that uses the library's context.
    ///
    /// - Parameter tool: The tool to insert.
    /// - Throws: A `Tools.Error` if the declaration is invalid or its name is empty or already used;
    ///   `CancellationError` if the current task is canceled.
    func insert<ToolType: Tool>(
        _ tool: ToolType,
    ) throws where ToolType.Context == Context {
        let name = tool.name

        guard !name.isEmpty else {
            logger?.warning("Rejected a tool with an empty name.", metadata: metadata)
            throw Error.invalidName
        }

        let isAvailable = storage { $0.tools[name] == nil }
        guard isAvailable else {
            logger?.warning("Rejected a duplicate tool.", metadata: metadata(for: name))
            throw Error.duplicateName(name)
        }

        let erased: AnyTool<Context>
        do {
            erased = try AnyTool(tool, name: name, description: tool.description)
        } catch {
            logger?.error("Failed to insert a tool.", error: error, metadata: metadata(for: name))
            throw error
        }

        // Copies share storage, so another copy may insert the same name after the first check.
        let inserted = storage { state in
            guard state.tools[name] == nil else { return false }
            state.tools[name] = erased
            return true
        }

        guard inserted else {
            logger?.warning("Rejected a duplicate tool.", metadata: metadata(for: name))
            throw Error.duplicateName(name)
        }

        logger?.trace("Inserted a tool.", metadata: metadata(for: name))
    }

    /// Removes a tool by name.
    ///
    /// - Parameter name: The name of the tool to remove.
    /// - Returns: `true` if the tool was removed.
    @discardableResult
    func remove(named name: String) -> Bool {
        let removed = storage { $0.tools.removeValue(forKey: name) != nil }
        guard removed else { return false }

        logger?.trace("Removed a tool.", metadata: metadata(for: name))
        return true
    }
}

private extension Library {
    func emit(_ event: Events.Element) {
        switch event {
        case let .started(invocation):
            logger?.debug("Started a tool invocation.", metadata: metadata(for: invocation))
        case let .succeeded(invocation, _, duration):
            let metadata = metadata(for: invocation, duration: duration)
            logger?.debug("Completed a tool invocation.", metadata: metadata)
        case let .failed(invocation, error, duration):
            let metadata = metadata(for: invocation, duration: duration)
            if error is CancellationError {
                logger?.debug("Cancelled a tool invocation.", metadata: metadata)
            } else {
                let message: Logger.Message = error is Failure ?
                    "A tool invocation returned a model-facing failure." :
                    "A tool invocation failed."
                logger?.warning(message, error: error, metadata: metadata)
            }
        }

        events.send(event)
    }
}

private extension Library {
    var metadata: Logger.Metadata {
        ["library": .string(name)]
    }

    func metadata(for name: String) -> Logger.Metadata {
        ["library": .string(self.name), "tool": .string(name)]
    }

    func metadata(for invocation: Events.Invocation, duration: Double? = nil) -> Logger.Metadata {
        var metadata: Logger.Metadata = [
            "invocation": .string(invocation.id.uuidString),
            "library": .string(name),
            "tool": .string(invocation.tool.name),
        ]

        if let duration { metadata["duration_ms"] = .string(String(duration * 1000)) }
        return metadata
    }
}

// MARK: Identifiable

extension Library: Identifiable {
    public var id: String { name }
}

// MARK: CustomStringConvertible

extension Library: CustomStringConvertible {
    public var description: String { name }
}

// MARK: CustomDebugStringConvertible

extension Library: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        Library<\(String(reflecting: Context.self))>(
          name: \(String(reflecting: name)),
          declarations: \(String(reflecting: declarations))
        )
        """
    }
}
