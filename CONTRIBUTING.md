# How to contribute

Thanks for your interest! First, make a fork of Whisky, make a new branch for your changes, and get coding!

# Build environment

Whisky is built with Xcode 26 on macOS Tahoe. External dependencies are handled through the Swift Package Manager.

One extra tool is needed:

```sh
brew install swiftlint xcbeautify
```

`swift-format` ships inside the Swift toolchain, so there is nothing to install for it.

# Checking your work

```sh
./scripts/verify.sh
```

This runs formatting, linting, the localization check, the WhiskyKit tests, and a full build, cheapest first. CI runs the same script, so a green run locally is a green run on your PR. While iterating, run a single check: `./scripts/verify.sh lint`, `test`, `build`, `format`, or `strings`.

Note that a plain `xcodebuild ... build` fails with a code-signing error, because the project pins a Developer ID certificate that only the release machine holds. `verify.sh` builds with signing disabled, which is what you want for local work.

# Code style

Formatting is handled by `swift-format`, configured in `.swift-format` (4-space indent, 120 columns). Apply it before committing:

```sh
swift format --in-place --recursive Whisky WhiskyKit/Sources WhiskyKit/Tests WhiskyCmd WhiskyThumbnail
```

SwiftLint covers everything formatting cannot: correctness, naming, and size. The split is deliberate, so please do not re-enable the `opening_brace` rule, which fights swift-format on wrapped declarations.

Reformatting sometimes moves a `// swiftlint:disable` comment away from the line it was suppressing. Run the lint check after formatting rather than assuming it held.

Generally, it is not advised to disable a SwiftLint rule, but there are certain situations where it is necessary. Please use your discretion when disabling rules temporarily.

All added strings must be properly localised and added to the EN strings file. Do not add keys for other languages or translate within your PR. All translations should be handled on [Crowdin](https://crowdin.com/project/whisky). `./scripts/verify.sh strings` catches a key you forgot to add.

# Tests

Tests live in `WhiskyKit/Tests/` and use swift-testing (`@Test` and `#expect`, not XCTest). Only WhiskyKit is covered: it holds the logic worth testing, and it builds as a plain Swift package, so `swift test` works without Xcode.

Tests are not required for every change, but logic changes in WhiskyKit should come with one.

# Making your PR

Please provide a detailed description of your changes in your PR. If your commits contain UI changes, we ask that you provide screenshots.

# Review

Once your pull request passes CI, it will be ready for review. You may receive feedback on code that should changed. Once you have received an approval, your code will be merged!
