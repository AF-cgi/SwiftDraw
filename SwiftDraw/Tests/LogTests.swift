//
//  LogTests.swift
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
@testable import SwiftDraw

struct LogLevelTests {

    @Test
    func levelsAreOrderedBySeverity() {
        #expect(Log.Level.info < Log.Level.warning)
        #expect(Log.Level.warning < Log.Level.error)
        #expect(Log.Level.allCases == [.info, .warning, .error])
    }
}

@Suite(.serialized)
struct LogTests {

    @Test
    func handlerReceivesEveryLevel() {
        let messages = Messages()
        let original = Log.handler
        defer { Log.handler = original }

        Log.handler = messages.append
        let handler = Log.handler

        handler(.info, "alignment")
        handler(.warning, "unsupported")
        handler(.error, "invalid")

        #expect(messages.lines == [
            "info: alignment",
            "warning: unsupported",
            "error: invalid"
        ])
    }

    @Test
    func handlerCanBeRestored() {
        let messages = Messages()
        let original = Log.handler
        defer { Log.handler = original }

        Log.handler = messages.append
        let restored = Log.handler

        Log.handler = Log.silent
        Log.handler = restored

        Log.handler(.warning, "unsupported")

        #expect(messages.lines == ["warning: unsupported"])
    }

    @Test
    func silentDiscardsMessages() {
        let original = Log.handler
        defer { Log.handler = original }

        Log.handler = Log.silent

        Log.handler(.info, "alignment")
        Log.handler(.warning, "unsupported")
        Log.handler(.error, "invalid")
    }
}

private final class Messages: @unchecked Sendable {

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    @Sendable
    func append(_ level: Log.Level, _ message: String) {
        lock.lock()
        defer { lock.unlock() }
        stored.append("\(level): \(message)")
    }

    private let lock = NSLock()
    private var stored = [String]()
}
