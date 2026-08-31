#!/bin/bash
#
# Fails when Swift code references a localization key that is missing from the
# English string catalog. A missing key is not a build error: SwiftUI silently
# renders the raw key, so "config.myFlag" ships to users as visible text.
#
# CONTRIBUTING requires every new string to land in the EN catalog, and this is
# what enforces it. Translations for other languages come from Crowdin and are
# deliberately not checked here.

set -euo pipefail

cd "$(dirname "$0")/.."

CATALOG="Whisky/Localizable.xcstrings"

# Keys the code asks for. Two shapes cover every call site in the app: a SwiftUI
# view built straight from a LocalizedStringKey, and an explicit String(localized:).
used=$(
    {
        grep -rhoE '(Text|Button|Toggle|Label|Section|Picker|Stepper|Link)\("[a-z][A-Za-z0-9._%@]*"' \
            Whisky --include='*.swift' || true
        grep -rhoE '\.(help|navigationTitle|accessibilityLabel)\("[a-z][A-Za-z0-9._%@]*"' \
            Whisky --include='*.swift' || true
        grep -rhoE 'String\(localized: *"[^"]+"' Whisky --include='*.swift' || true
    } | grep -oE '"[^"]+"' | tr -d '"' | sort -u
)

# Keys the catalog actually defines, straight from Apple's own tool.
defined=$(xcrun xcstringstool print "$CATALOG" | sort -u)

missing=$(comm -23 <(echo "$used") <(echo "$defined"))
unused=$(comm -13 <(echo "$used") <(echo "$defined"))

used_count=$(echo "$used" | grep -c . || true)
defined_count=$(echo "$defined" | grep -c . || true)
echo "  $used_count keys referenced in code, $defined_count defined in the catalog"

if [ -n "$unused" ]; then
    # Only a hint. Keys built at runtime and keys used from WhiskyCmd are invisible
    # to the greps above, so this list is never authoritative enough to fail on.
    unused_count=$(echo "$unused" | grep -c . || true)
    echo "  note: $unused_count defined keys were not spotted in code (may be dynamic)"
fi

if [ -n "$missing" ]; then
    echo
    echo "  Missing from $CATALOG:"
    echo "$missing" | sed 's/^/    /'
    echo
    echo "  Add each key with its English value. Leave other languages to Crowdin."
    exit 1
fi
