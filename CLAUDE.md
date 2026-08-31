# Whisky

SwiftUI macOS app that wraps Wine (CrossOver 22.1.1 + Apple's Game Porting Toolkit) so users can run Windows apps in isolated "bottles". Apple Silicon, macOS 14+.

Upstream is [no longer actively maintained](https://docs.getwhisky.app/maintenance-notice).

## Targets

| Target | What it is |
| --- | --- |
| `WhiskyKit/` | SPM package with all domain logic: `Bottle`, `Wine`, PE parsing, WhiskyWine install. No UI. |
| `Whisky/` | The SwiftUI app. Views, view models, glue. |
| `WhiskyCmd/` | `whisky` CLI (swift-argument-parser), symlinked into `/usr/local/bin`. |
| `WhiskyThumbnail/` | Quick Look thumbnail extension for `.exe` files. |

Logic goes in WhiskyKit. The app target consumes it and stays presentation-only.

## Every new Swift file needs the GPL header

SwiftLint runs `--strict` in CI and in the Xcode build phase, and `file_header` is an **error**. Copy this exactly, swapping the first two lines:

```swift
//
//  MyFile.swift
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
```

Line 3 is the target name (`Whisky`, `WhiskyKit`, `WhiskyCmd`, `WhiskyThumbnail`).

## Style

Two tools, one boundary: **swift-format owns layout, SwiftLint owns semantics.** `.swift-format` sets 4-space indent at 120 columns. `.swiftlint.yml` disables `opening_brace` because the two rewrite each other on wrapped declarations. Do not re-enable it.

- `force_unwrapping` is on: no `!`. Use `guard let`, `??`, or `try`.
- Swift 6 language mode with `SWIFT_STRICT_CONCURRENCY = complete`. `Bottle` and `BottleVM` are still `@unchecked Sendable` with a TODO on top. Do not copy that pattern into new types.
- Suppress a rule with a scoped `// swiftlint:disable:next <rule>` and only when there is no other way.
- Doc-comment public API in WhiskyKit with `///`. That is the existing convention there.

## Strings are localized, and Crowdin owns the translations

User-facing text is a key, not a literal. SwiftUI resolves keys implicitly:

```swift
Text("setup.welcome")
NSAlert().messageText = String(localized: "alert.message")
```

Add the key plus its **English** value to `Whisky/Localizable.xcstrings`. Leave every other language alone: translations land through [Crowdin](https://crowdin.com/project/whisky) via `crowdin.yml`.

## Verify with one command

```sh
./scripts/verify.sh
```

That is the whole loop. It runs swift-format, SwiftLint, the localization check, the WhiskyKit tests, and an Xcode build, cheapest first. `.github/workflows/CI.yml` runs the same script, so green locally means green on the PR.

While iterating, run one check instead of all five:

```sh
./scripts/verify.sh lint      # seconds
./scripts/verify.sh test      # seconds
./scripts/verify.sh build     # minutes
```

Formatting is not automatic. Apply it before committing:

```sh
swift format --in-place --recursive Whisky WhiskyKit/Sources WhiskyKit/Tests WhiskyCmd WhiskyThumbnail
```

`swiftlint` and `xcbeautify` come from `brew install swiftlint xcbeautify`. `swift format` ships with the toolchain, nothing to install.

Four gotchas:

- **Formatting can break lint suppressions.** swift-format moves trailing comments, which silently detaches a `// swiftlint:disable:this` from the line it was suppressing. Always run `./scripts/verify.sh lint` after reformatting.
- New files in the `Whisky`, `WhiskyCmd`, or `WhiskyThumbnail` targets must be registered in `Whisky.xcodeproj/project.pbxproj`. Adding them through Xcode is far safer than hand-editing. Files under `WhiskyKit/Sources/` and `WhiskyKit/Tests/` are picked up by SPM automatically.
- **The project pins a Developer ID certificate for upstream's team**, which no fork has. `verify.sh` builds with signing disabled. A plain `xcodebuild ... build` fails with a signing error that has nothing to do with your change.
- Tests live in `WhiskyKit/Tests/` and use swift-testing (`@Test`, `#expect`), not XCTest. Only WhiskyKit is testable; the app target has no test host.

Run `git config blame.ignoreRevsFile .git-blame-ignore-revs` once, so `git blame` skips the repo-wide reformat commit.

## Real user data lives outside the repo

Running the app touches the user's actual bottles and Wine install:

- `~/Library/Containers/com.isaacmarovitz.Whisky/Bottles/<uuid>/` per bottle, with `Metadata.plist` holding its `BottleSettings`.
- `~/Library/Containers/com.isaacmarovitz.Whisky/BottleVM.plist` is the index of bottle paths.
- `~/Library/Application Support/com.isaacmarovitz.Whisky/Libraries/Wine/bin/wine64` is the Wine binary.

`Bottle.init` prunes pins pointing at missing files, and `WhiskyWineInstaller.install` deletes and recreates the whole application folder. Say what you are about to touch before running anything that writes there.

## PRs

Follow `CONTRIBUTING.md`: branch off a fork, keep SwiftLint clean, describe the change, attach screenshots for UI work.
