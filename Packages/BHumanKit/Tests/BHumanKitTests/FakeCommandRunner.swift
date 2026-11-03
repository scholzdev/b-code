//
//  FakeCommandRunner.swift
//  BHumanKitTests
//

import Foundation
@testable import BHumanKit

/// Records every invocation and answers with whatever the handler returns. Nothing is ever started.
final class FakeCommandRunner: CommandRunner, @unchecked Sendable {
    typealias Handler = @Sendable (CommandInvocation) throws -> CommandResult

    private let lock = NSLock()
    private var recorded: [CommandInvocation] = []
    private let handler: Handler

    init(handler: @escaping Handler = { _ in CommandResult() }) {
        self.handler = handler
    }

    var invocations: [CommandInvocation] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    private func record(_ invocation: CommandInvocation) {
        lock.lock()
        recorded.append(invocation)
        lock.unlock()
    }

    func run(_ invocation: CommandInvocation) async throws -> CommandResult {
        record(invocation)
        return try handler(invocation)
    }
}

/// Collects values from `@Sendable` callbacks.
final class EventRecorder<Event>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Event] = []

    var events: [Event] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ event: Event) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }
}
