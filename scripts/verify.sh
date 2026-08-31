#!/bin/bash
#
# The one command that says whether the tree is good. CI runs exactly this, so a
# green run here means a green run there.
#
#   ./scripts/verify.sh          every check, fastest first
#   ./scripts/verify.sh format   swift-format layout check
#   ./scripts/verify.sh lint     SwiftLint, strict
#   ./scripts/verify.sh strings  localization keys resolve
#   ./scripts/verify.sh test     WhiskyKit unit tests
#   ./scripts/verify.sh build    compile the app, CLI and extension
#
# Checks are ordered cheapest first so a mistake surfaces in seconds rather than
# after a full Xcode build. Pass a name to run one in isolation while iterating.

set -uo pipefail

cd "$(dirname "$0")/.."

TARGET="${1:-all}"
FAILED=()

# Signing is off on purpose. The project pins a Developer ID certificate belonging
# to upstream's team, which nobody working on a fork has, and which compiling does
# not need. Release builds still sign through Xcode as configured.
readonly NO_SIGNING=(
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGN_IDENTITY=""
)

run() {
    local name="$1" description="$2"
    shift 2

    if [ "$TARGET" != "all" ] && [ "$TARGET" != "$name" ]; then
        return
    fi

    echo "==> $description"
    if "$@"; then
        echo "    ok"
    else
        echo "    FAILED"
        FAILED+=("$name")
    fi
    echo
}

check_format() {
    swift format lint --strict --recursive \
        Whisky WhiskyKit/Sources WhiskyKit/Tests WhiskyCmd WhiskyThumbnail
}

check_lint() {
    if ! command -v swiftlint >/dev/null 2>&1; then
        echo "    swiftlint not found. Install it with: brew install swiftlint"
        return 1
    fi
    swiftlint lint --strict --quiet
}

check_tests() {
    (cd WhiskyKit && swift test)
}

check_build() {
    # xcbeautify turns compiler errors into inline GitHub annotations when it is
    # present. Plain xcodebuild output is the fallback so this works on a bare machine.
    if command -v xcbeautify >/dev/null 2>&1; then
        local renderer=()
        [ -n "${GITHUB_ACTIONS:-}" ] && renderer=(--renderer github-actions)
        xcodebuild -scheme Whisky -configuration Debug \
            -destination 'platform=macOS,arch=arm64' \
            "${NO_SIGNING[@]}" build 2>&1 | xcbeautify "${renderer[@]}"
        return "${PIPESTATUS[0]}"
    fi

    xcodebuild -scheme Whisky -configuration Debug \
        -destination 'platform=macOS,arch=arm64' \
        "${NO_SIGNING[@]}" build | tail -20
    return "${PIPESTATUS[0]}"
}

run format  "swift-format: layout is consistent"      check_format
run lint    "SwiftLint: no violations, strict mode"   check_lint
run strings "Localization: every key resolves"        ./scripts/check-localization.sh
run test    "WhiskyKit: unit tests"                   check_tests
run build   "Xcode: app, CLI and extension compile"   check_build

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "FAILED: ${FAILED[*]}"
    echo "Re-run one check on its own with: ./scripts/verify.sh ${FAILED[0]}"
    exit 1
fi

echo "All checks passed."
