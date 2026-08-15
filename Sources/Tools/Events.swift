//
//  Created by Anton Spivak
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import Synchronization
import Generable

// MARK: - Events

/// An asynchronous sequence of tool call events.
///
/// Events are broadcast to every active iterator. A default iterator buffers the newest 256 pending
/// events.
///
/// ```swift
/// let events = library.events
///
/// Task {
///     for await event in events {
///         if case let .started(invocation) = event {
///             print("Started \(invocation.tool.name)")
///         }
///     }
/// }
/// ```
public struct Events: Sendable {
    // MARK: Lifecycle

    init() {}

    // MARK: Public

    /// Details shared by the events for one tool call.
    public struct Invocation: Sendable, Identifiable {
        // MARK: Lifecycle

        /// Creates an invocation.
        ///
        /// - Parameters:
        ///   - id: The identifier shared by the call's events.
        ///   - call: The originating tool call.
        ///   - tool: The tool declaration.
        public init(
            id: UUID = UUID(),
            call: Call,
            tool: Declaration,
        ) {
            self.id = id
            self.call = call
            self.tool = tool
        }

        // MARK: Public

        /// The identifier shared by the call's events.
        public let id: UUID

        /// The originating tool call.
        public let call: Call

        /// The tool declaration.
        public let tool: Declaration

        /// The tool arguments.
        public var arguments: GeneratedContent { call.arguments }
    }

    // MARK: Internal

    func send(_ event: Element) {
        storage { continuations in
            for continuation in continuations.values {
                continuation.yield(event)
            }
        }
    }

    // MARK: Private

    private let storage = Storage()
}

// MARK: Events.Storage

private extension Events {
    final class Storage: Sendable {
        // MARK: Lifecycle

        deinit {
            // Finish outside the lock so suspended iterators can resume without blocking storage.
            let continuations = self { Array($0.values) }
            for continuation in continuations {
                continuation.finish()
            }
        }

        // MARK: Internal

        typealias Function<Result: ~Copyable, E: Swift.Error> = (
            inout sending [UUID: AsyncStream<Element>.Continuation],
        ) throws(E) -> sending Result

        @inline(__always)
        func callAsFunction<Result: ~Copyable, E: Swift.Error>(
            _ body: Function<Result, E>,
        ) throws(E) -> sending Result {
            try subscribers.withLock(body)
        }

        // MARK: Private

        private let subscribers = Mutex<[UUID: AsyncStream<Element>.Continuation]>([:])
    }
}

// MARK: AsyncSequence

extension Events: AsyncSequence {
    public typealias Iterator = AsyncStream<Element>.Iterator

    /// An event from a tool call.
    public enum Element: Sendable {
        /// A tool call started.
        case started(Invocation)

        /// A tool call completed successfully.
        ///
        /// The duration is measured in seconds.
        case succeeded(Invocation, output: GeneratedContent, duration: TimeInterval)

        /// A tool call failed.
        ///
        /// The duration is measured in seconds.
        case failed(Invocation, error: any Swift.Error, duration: TimeInterval)
    }

    public func makeAsyncIterator() -> Iterator {
        makeAsyncIterator(bufferingPolicy: .bufferingNewest(256))
    }

    /// Creates an iterator with a buffering policy.
    ///
    /// - Parameter limit: The buffering policy for the iterator.
    public func makeAsyncIterator(
        bufferingPolicy limit: AsyncStream<Element>.Continuation.BufferingPolicy,
    ) -> Iterator {
        AsyncStream(Element.self, bufferingPolicy: limit, { continuation in
            let id = UUID()
            storage { $0[id] = continuation }
            // A terminated iterator must stop receiving broadcast events.
            continuation.onTermination = { [weak storage] _ in
                _ = storage? { $0.removeValue(forKey: id) }
            }
        }).makeAsyncIterator()
    }
}
