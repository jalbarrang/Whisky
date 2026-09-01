//
//  BottleEnvironmentTests.swift
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
import Testing

@testable import WhiskyKit

/// `environmentVariables(wineEnv:)` is where every toggle in the config UI turns into a real
/// wine flag. It is pure, so it is the cheapest place in the codebase to catch a regression
/// that would otherwise only show up as a game failing to launch.
@Suite("Bottle environment variables")
struct BottleEnvironmentTests {
    /// Runs `settings` through the env builder and returns just the variables it added.
    private func environment(for settings: BottleSettings) -> [String: String] {
        var env: [String: String] = [:]
        settings.environmentVariables(wineEnv: &env)
        return env
    }

    @Test("DXVK stays out of the environment until it is switched on")
    func dxvkOffAddsNoOverrides() {
        var settings = BottleSettings()
        settings.dxvk = false

        let env = environment(for: settings)

        #expect(env["WINEDLLOVERRIDES"] == nil)
        #expect(env["DXVK_HUD"] == nil)
    }

    @Test("Enabling DXVK overrides the D3D DLLs")
    func dxvkOnOverridesD3DLibraries() {
        var settings = BottleSettings()
        settings.dxvk = true

        let env = environment(for: settings)

        #expect(env["WINEDLLOVERRIDES"] == "dxgi,d3d9,d3d10core,d3d11=n,b")
    }

    @Test(
        "Each HUD level maps to its DXVK_HUD value",
        arguments: [
            (DXVKHUD.full, "full"),
            (DXVKHUD.partial, "devinfo,fps,frametimes"),
            (DXVKHUD.fps, "fps")
        ]
    )
    func hudLevelMapsToValue(hud: DXVKHUD, expected: String) {
        var settings = BottleSettings()
        settings.dxvk = true
        settings.dxvkHud = hud

        #expect(environment(for: settings)["DXVK_HUD"] == expected)
    }

    @Test("The off HUD level sets no variable at all")
    func hudOffSetsNothing() {
        var settings = BottleSettings()
        settings.dxvk = true
        settings.dxvkHud = .off

        #expect(environment(for: settings)["DXVK_HUD"] == nil)
    }

    /// Deliberate, and easy to mistake for a bug. D3DMetal inspects WINEESYNC and changes
    /// behaviour when it is absent, which breaks under msync, so Whisky sets both. The values
    /// are hardcoded in libd3dshared.dylib, so dropping WINEESYNC here breaks games silently.
    @Test("msync sets WINEESYNC too, to keep D3DMetal happy")
    func msyncAlsoAdvertisesEsync() {
        var settings = BottleSettings()
        settings.enhancedSync = .msync

        let env = environment(for: settings)

        #expect(env["WINEMSYNC"] == "1")
        #expect(env["WINEESYNC"] == "1")
    }

    @Test("esync sets only WINEESYNC")
    func esyncSetsOnlyEsync() {
        var settings = BottleSettings()
        settings.enhancedSync = .esync

        let env = environment(for: settings)

        #expect(env["WINEESYNC"] == "1")
        #expect(env["WINEMSYNC"] == nil)
    }

    @Test("Disabling enhanced sync sets neither variable")
    func syncNoneSetsNeither() {
        var settings = BottleSettings()
        settings.enhancedSync = .none

        let env = environment(for: settings)

        #expect(env["WINEESYNC"] == nil)
        #expect(env["WINEMSYNC"] == nil)
    }

    /// DXVK_ASYNC is set from its own flag, which defaults to true, so it appears even when
    /// DXVK itself is off. Surprising, but load-bearing: flipping it would change the
    /// environment of every existing bottle.
    @Test("DXVK_ASYNC follows its own flag, independent of DXVK")
    func asyncIsIndependentOfDxvk() {
        var settings = BottleSettings()
        settings.dxvk = false

        #expect(settings.dxvkAsync == true)
        #expect(environment(for: settings)["DXVK_ASYNC"] == "1")
    }

    @Test("Metal and Rosetta toggles map to their documented variables")
    func metalAndRosettaToggles() {
        var settings = BottleSettings()
        settings.metalHud = true
        settings.metalTrace = true
        settings.dxrEnabled = true
        settings.avxEnabled = true

        let env = environment(for: settings)

        #expect(env["MTL_HUD_ENABLED"] == "1")
        #expect(env["METAL_CAPTURE_ENABLED"] == "1")
        #expect(env["D3DM_SUPPORT_DXR"] == "1")
        #expect(env["ROSETTA_ADVERTISE_AVX"] == "1")
    }

    @Test("Toggles that are off contribute nothing")
    func defaultsStayQuiet() {
        let env = environment(for: BottleSettings())

        #expect(env["MTL_HUD_ENABLED"] == nil)
        #expect(env["METAL_CAPTURE_ENABLED"] == nil)
        #expect(env["D3DM_SUPPORT_DXR"] == nil)
        #expect(env["ROSETTA_ADVERTISE_AVX"] == nil)
    }
}
