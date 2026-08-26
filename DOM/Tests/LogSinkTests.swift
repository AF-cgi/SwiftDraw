//
//  LogSinkTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 26/8/26.
//  Copyright 2026 Simon Whitty
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/SwiftDraw
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

import Foundation
import Testing
@testable import SwiftDrawDOM

struct LogSinkTests {

    @Test
    func levelsAreOrderedBySeverity() {
        #expect(LogSink.Level.info < LogSink.Level.warning)
        #expect(LogSink.Level.warning < LogSink.Level.error)
        #expect(LogSink.Level.allCases == [.info, .warning, .error])
    }

    @Test
    func infoIsWrittenToStandardOutput() {
        let streams = Streams()

        streams.makeHandler()(.info, "Alignment: --insets 1,2,3,4")

        #expect(streams.lines == ["out: Alignment: --insets 1,2,3,4"])
    }

    @Test
    func warningIsPrefixedAndWrittenToStandardError() {
        let streams = Streams()

        streams.makeHandler()(.warning, "PDF does not support transparency masks")

        #expect(streams.lines == ["err: Warning: PDF does not support transparency masks"])
    }

    @Test
    func errorIsWrittenToStandardErrorWithoutPrefix() {
        let streams = Streams()

        streams.makeHandler()(.error, "[parsing error] file.svg <style> error: invalid")

        #expect(streams.lines == ["err: [parsing error] file.svg <style> error: invalid"])
    }

    @Test
    func minimumLevelInfoKeepsEveryMessage() {
        let streams = Streams()
        let handler = streams.makeHandler(minimumLevel: .info)

        for level in LogSink.Level.allCases {
            handler(level, "message")
        }

        #expect(streams.lines == [
            "out: message",
            "err: Warning: message",
            "err: message"
        ])
    }

    @Test
    func minimumLevelWarningDiscardsInfo() {
        let streams = Streams()
        let handler = streams.makeHandler(minimumLevel: .warning)

        for level in LogSink.Level.allCases {
            handler(level, "message")
        }

        #expect(streams.lines == [
            "err: Warning: message",
            "err: message"
        ])
    }

    @Test
    func minimumLevelErrorDiscardsInfoAndWarning() {
        let streams = Streams()
        let handler = streams.makeHandler(minimumLevel: .error)

        for level in LogSink.Level.allCases {
            handler(level, "message")
        }

        #expect(streams.lines == ["err: message"])
    }
}

@Suite(.serialized)
struct LogSinkHandlerTests {

    @Test
    func messagesAreForwardedToHandler() {
        let streams = Streams()
        let original = LogSink.handler
        defer { LogSink.handler = original }

        LogSink.handler = { level, message in
            guard message.hasPrefix(token) else { return }
            streams.append("\(level): \(message)")
        }

        LogSink.info("\(token) alignment")
        LogSink.warning("\(token) unsupported")
        LogSink.error("\(token) invalid")

        #expect(streams.lines == [
            "info: \(token) alignment",
            "warning: \(token) unsupported",
            "error: \(token) invalid"
        ])
    }

    @Test
    func replacedHandlerNoLongerReceivesMessages() {
        let streams = Streams()
        let original = LogSink.handler
        defer { LogSink.handler = original }

        LogSink.handler = { _, message in streams.append(message) }
        LogSink.warning("\(token) unsupported")

        LogSink.handler = { _, _ in }
        LogSink.warning("\(token) discarded")

        #expect(streams.lines == ["\(token) unsupported"])
    }
}

private let token = "LogSinkHandlerTests"

private final class Streams: @unchecked Sendable {

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func makeHandler(minimumLevel: LogSink.Level = .info) -> LogSink.Handler {
        LogSink.makeHandler(
            minimumLevel: minimumLevel,
            standardOutput: { [self] in append("out: \($0)") },
            standardError: { [self] in append("err: \($0)") }
        )
    }

    @Sendable
    func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        stored.append(line)
    }

    private let lock = NSLock()
    private var stored = [String]()
}
