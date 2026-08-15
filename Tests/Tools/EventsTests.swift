//
//  Created by Anton Spivak
//

import Testing
import Tools

// MARK: - StartBarrier

private actor StartBarrier {
    // MARK: Lifecycle

    init(participants: Int) {
        self.participants = participants
    }

    // MARK: Internal

    func arrive() async {
        arrived += 1
        guard arrived == participants else {
            await withCheckedContinuation { self.continuations.append($0) }
            return
        }

        let continuations = continuations
        self.continuations.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }

    // MARK: Private

    private let participants: Int
    private var arrived = 0
    private var continuations: [CheckedContinuation<Void, Never>] = []
}

private extension Events.Element {
    var orderingKey: String {
        switch self {
        case let .started(invocation):
            "started:\(invocation.id)"
        case let .succeeded(invocation, _, _):
            "succeeded:\(invocation.id)"
        case let .failed(invocation, _, _):
            "failed:\(invocation.id)"
        }
    }
}

@Test
func `events report complete lifecycles to every observer`() async throws {
    let library = Library<ApplicationContext>()
    try library.insert(prefixTool())
    try library.insert(StringTool(name: "failing") { _, _ in
        throw Tools::Failure("Try another value.")
    })
    let copy = library

    var first = library.events.makeAsyncIterator()
    var second = copy.events.makeAsyncIterator()
    _ = try await copy.perform(
        [
            Call(id: "successful", named: "prefix", with: content()),
            Call(id: "failing", named: "failing", with: content()),
        ],
        options: .init(maximumConcurrentCalls: 1),
        in: context,
    )

    var firstEvents: [Events.Element] = []
    var secondEvents: [Events.Element] = []
    for _ in 0 ..< 4 {
        try firstEvents.append(#require(await first.next()))
        try secondEvents.append(#require(await second.next()))
    }

    #expect(firstEvents.map(\.orderingKey) == secondEvents.map(\.orderingKey))
    guard case let .started(successful) = firstEvents[0],
          case let .succeeded(completed, output, successfulDuration) = firstEvents[1],
          case let .started(failing) = firstEvents[2],
          case let .failed(failed, error, failedDuration) = firstEvents[3]
    else {
        Issue.record("Expected successful and failed invocation lifecycles.")
        return
    }

    #expect(successful.id == completed.id)
    #expect(successful.call.id == "successful")
    #expect(successful.tool.name == "prefix")
    #expect(try successful.arguments.decode(Arguments.self) == .init(value: "value"))
    #expect(try output.decode(String.self) == "before value")
    #expect(successfulDuration >= 0)
    #expect(failing.id == failed.id)
    #expect(failing.call.id == "failing")
    #expect(error is Tools::Failure)
    #expect(failedDuration >= 0)
}

@Test
func `concurrent events have the same order for every observer`() async throws {
    let count = 4
    let barrier = StartBarrier(participants: count)
    let library = Library<ApplicationContext>()
    try library.insert(StringTool(name: "concurrent") { arguments, _ in
        await barrier.arrive()
        return arguments.value
    })

    var first = library.events.makeAsyncIterator()
    var second = library.events.makeAsyncIterator()
    _ = try await library.perform(
        (0 ..< count).map { index in
            try Call(named: "concurrent", with: content(String(index)))
        },
        options: .init(maximumConcurrentCalls: count),
        in: context,
    )

    var firstOrder: [String] = []
    var secondOrder: [String] = []
    for _ in 0 ..< count * 2 {
        try firstOrder.append(#require(await first.next()).orderingKey)
        try secondOrder.append(#require(await second.next()).orderingKey)
    }

    #expect(firstOrder == secondOrder)
}

@Test
func `cancelling an observer doesn't cancel tool execution`() async throws {
    let library = Library<ApplicationContext>()
    try library.insert(prefixTool())
    let events = library.events

    let observer = Task {
        for await _ in events {}
    }
    await Task.yield()
    observer.cancel()
    await observer.value

    let results = try await library.perform(
        [Call(named: "prefix", with: content())],
        in: context,
    )
    #expect(try results[0].output.get().decode(String.self) == "before value")
}

@Test
func `events release a pending observer with their owner`() async throws {
    var events: Events? = Library<Void>().events
    var iterator = try #require(events?.makeAsyncIterator())
    let observer = Task { await iterator.next() }

    events = nil

    let finished = await withTaskGroup(of: Bool.self) { group in
        group.addTask { await observer.value == nil }
        group.addTask {
            try? await Task.sleep(for: .seconds(1))
            return false
        }

        let result = await group.next() ?? false
        observer.cancel()
        group.cancelAll()
        return result
    }

    #expect(finished)
}
