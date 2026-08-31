//
//  BottleSettingsTests.swift
//  WhiskyKit
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import Foundation
import SemanticVersion
import Testing

@testable import WhiskyKit

/// `BottleSettings` decodes field by field with `decodeIfPresent ?? default`, which is the
/// only migration mechanism bottles have. These tests pin that contract: a plist written by
/// an older Whisky must still load, and every field it omits must fall back to its default.
@Suite("BottleSettings persistence")
struct BottleSettingsTests {
    /// Writes `plist` to a throwaway file and hands the URL to `body`.
    private func withMetadataFile(
        containing plist: String, _ body: (URL) throws -> Void
    ) throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appending(path: "Metadata").appendingPathExtension("plist")
        try plist.write(to: url, atomically: true, encoding: .utf8)
        try body(url)
    }

    @Test("A plist with no keys at all decodes to the documented defaults")
    func emptyPlistFallsBackToDefaults() throws {
        let empty = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict/></plist>
            """

        try withMetadataFile(containing: empty) { url in
            let settings = try BottleSettings.decode(from: url)

            #expect(settings.name == "Bottle")
            #expect(settings.windowsVersion == .win10)
            #expect(settings.enhancedSync == .msync)
            #expect(settings.pins.isEmpty)
            #expect(settings.blocklist.isEmpty)
            #expect(settings.dxvk == false)
            #expect(settings.dxvkAsync == true)
            #expect(settings.avxEnabled == false)
        }
    }

    @Test("Settings survive a write/read round trip")
    func roundTripPreservesValues() throws {
        try withMetadataFile(containing: "<plist version=\"1.0\"><dict/></plist>") { url in
            var written = BottleSettings()
            written.name = "Test Bottle"
            written.windowsVersion = .win11
            written.enhancedSync = .esync
            written.dxvk = true
            written.dxvkHud = .fps
            written.avxEnabled = true
            written.blocklist = [URL(filePath: "/tmp/blocked.exe")]
            try written.encode(to: url)

            let read = try BottleSettings.decode(from: url)

            #expect(read.name == "Test Bottle")
            #expect(read.windowsVersion == .win11)
            #expect(read.enhancedSync == .esync)
            #expect(read.dxvk == true)
            #expect(read.dxvkHud == .fps)
            #expect(read.avxEnabled == true)
            #expect(read.blocklist == [URL(filePath: "/tmp/blocked.exe")])
        }
    }

    /// A pin whose target file has vanished is dropped by `Bottle.init`, not by decoding,
    /// so decoding must hand back whatever was on disk, missing target or not.
    @Test("Pins decode with their removable flag intact")
    func pinsRoundTrip() throws {
        try withMetadataFile(containing: "<plist version=\"1.0\"><dict/></plist>") { url in
            var written = BottleSettings()
            written.pins = [PinnedProgram(name: "Game", url: URL(filePath: "/tmp/Game.exe"))]
            try written.encode(to: url)

            let read = try BottleSettings.decode(from: url)

            #expect(read.pins.count == 1)
            #expect(read.pins.first?.name == "Game")
            #expect(read.pins.first?.url == URL(filePath: "/tmp/Game.exe"))
        }
    }

    /// Characterisation test, not an endorsement. `decode` silently rewrites any stored wine
    /// version back to the current default, so a bottle cannot record which wine it was built
    /// against. Change this test deliberately if that behaviour is ever fixed.
    @Test("Decoding resets a stored wine version to the current default")
    func storedWineVersionIsOverwritten() throws {
        try withMetadataFile(containing: "<plist version=\"1.0\"><dict/></plist>") { url in
            var written = BottleSettings()
            written.wineVersion = SemanticVersion(9, 9, 9)
            try written.encode(to: url)

            let read = try BottleSettings.decode(from: url)

            #expect(read.wineVersion != SemanticVersion(9, 9, 9))
            #expect(read.wineVersion == SemanticVersion(7, 7, 0))
        }
    }

    /// Characterisation test for a real bug. The `guard` in `decode(from:)` is inverted: the
    /// branch taken when the file is *missing* tries to read that missing file, so it throws
    /// instead of returning defaults. `Bottle.init` catches the throw and falls back, so the
    /// app behaves correctly by accident. `ProgramSettings.decode` has the correct guard.
    @Test("Decoding a missing metadata file throws rather than returning defaults")
    func missingFileThrows() throws {
        let missing = URL.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension("plist")

        #expect(throws: (any Error).self) {
            try BottleSettings.decode(from: missing)
        }
    }
}
