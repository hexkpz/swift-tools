//
//  Created by Anton Spivak
//

import Testing
import Tools

// MARK: - ExecutionGate

private actor ExecutionGate {
    // MARK: Internal

    private(set) var maximumActive = 0

    func enter(_ value: String) async {
        active += 1
        maximumActive = max(maximumActive, active)

        if value == "0" {
            firstStarted = true
            firstStartedContinuation?.resume()
            firstStartedContinuation = nil
            guard !secondCompleted else { return }
            await withCheckedContinuation { firstCompletionContinuation = $0 }
        } else if value == "1", !firstStarted {
            await withCheckedContinuation { firstStartedContinuation = $0 }
        }
    }

    func leave(_ value: String) {
        active -= 1
        guard value == "1" else { return }
        secondCompleted = true
        firstCompletionContinuation?.resume()
        firstCompletionContinuation = nil
    }

    // MARK: Private

    private var active = 0
    private var firstStarted = false
    private var firstStartedContinuation: CheckedContinuation<Void, Never>?
    private var firstCompletionContinuation: CheckedContinuation<Void, Never>?
    private var secondCompleted = false
}

// MARK: - LocalCancellationProbe

private actor LocalCancellationProbe {
    // MARK: Internal

    func runUntilReleased() async -> String {
        started = true
        startedContinuation?.resume()
        startedContinuation = nil

        guard !released else { return "completed" }
        await withCheckedContinuation { releaseContinuation = $0 }
        return "completed"
    }

    func cancelAfterStart() async throws -> String {
        if !started {
            await withCheckedContinuation { startedContinuation = $0 }
        }

        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
        throw CancellationError()
    }

    // MARK: Private

    private var released = false
    private var started = false
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var startedContinuation: CheckedContinuation<Void, Never>?
}

// MARK: - BatchCancellationProbe

private actor BatchCancellationProbe {
    // MARK: Lifecycle

    init(expectedStarts: Int) {
        self.expectedStarts = expectedStarts
    }

    // MARK: Internal

    private(set) var cancelled = 0
    private(set) var started = 0

    func run(_ value: String) async throws -> String {
        started += 1
        if started == expectedStarts {
            startedContinuation?.resume()
            startedContinuation = nil
        }

        do {
            try await Task.sleep(for: .seconds(10))
            return value
        } catch {
            if error is CancellationError { cancelled += 1 }
            throw error
        }
    }

    func waitUntilStarted() async {
        guard started < expectedStarts else { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }

    // MARK: Private

    private let expectedStarts: Int
    private var startedContinuation: CheckedContinuation<Void, Never>?
}

@Test
func `batch limits concurrency and preserves input order`() async throws {
    let gate = ExecutionGate()
    let library = Library<ApplicationContext>()
    try library.insert(StringTool(name: "tracked") { arguments, _ in
        await gate.enter(arguments.value)
        await gate.leave(arguments.value)
        return arguments.value
    })

    let results = try await library.perform(
        (0 ..< 4).map { index in
            try Call(id: String(index), named: "tracked", with: content(String(index)))
        },
        options: .init(maximumConcurrentCalls: 2),
        in: context,
    )

    #expect(await gate.maximumActive == 2)
    #expect(results.map(\.id) == ["0", "1", "2", "3"])

    for (index, result) in results.enumerated() {
        #expect(try generatedContentDecoder.decode(
            String.self,
            from: result.output.get(),
        ) == String(index))
    }
}

@Test
func `cancellation from one call doesn't cancel other calls`() async throws {
    let probe = LocalCancellationProbe()
    let library = Library<ApplicationContext>()

    try library.insert(StringTool(name: "blocking") { _, _ in
        await probe.runUntilReleased()
    })

    try library.insert(StringTool(name: "cancelling") { _, _ in
        try await probe.cancelAfterStart()
    })
    try library.insert(prefixTool())

    let results = try await library.perform(
        [
            Call(id: "blocking", named: "blocking", with: content()),
            Call(id: "cancelling", named: "cancelling", with: content()),
            Call(id: "successful", named: "prefix", with: content()),
        ],
        options: .init(maximumConcurrentCalls: 2),
        in: context,
    )

    #expect(results.map(\.id) == ["blocking", "cancelling", "successful"])
    #expect(try generatedContentDecoder.decode(
        String.self,
        from: results[0].output.get(),
    ) == "completed")
    #expect(results[1].output.error is CancellationError)
    #expect(try generatedContentDecoder.decode(
        String.self,
        from: results[2].output.get(),
    ) == "before value")
}

@Test
func `cancelling a batch cancels running calls and doesn't start queued calls`() async throws {
    let maximumConcurrentCalls = 2
    let probe = BatchCancellationProbe(expectedStarts: maximumConcurrentCalls)
    let library = Library<ApplicationContext>()
    try library.insert(StringTool(name: "blocking") { arguments, _ in
        try await probe.run(arguments.value)
    })

    let batchLibrary = library
    let batch = Task {
        try await batchLibrary.perform(
            (0 ..< 3).map { index in
                try Call(id: String(index), named: "blocking", with: content(String(index)))
            },
            options: .init(maximumConcurrentCalls: maximumConcurrentCalls),
            in: context,
        )
    }

    await probe.waitUntilStarted()
    batch.cancel()

    await #expect(throws: CancellationError.self) {
        _ = try await batch.value
    }
    #expect(await probe.started == maximumConcurrentCalls)
    #expect(await probe.cancelled == maximumConcurrentCalls)
}
