#!/bin/bash
#
# PostToolUse hook: formats any Swift file Claude just edited or wrote.
# Runs SwiftFormat (and SwiftLint autocorrect, when installed) on the single
# touched file so style is enforced mechanically, not by prompt guidance.

file_path=$(python3 -c 'import json, sys; print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))' 2>/dev/null)

case "$file_path" in
    *.swift) ;;
    *) exit 0 ;;
esac

[ -f "$file_path" ] || exit 0

if command -v swiftformat >/dev/null 2>&1; then
    swiftformat "$file_path" --quiet
fi

if command -v swiftlint >/dev/null 2>&1; then
    swiftlint lint --fix --quiet "$file_path" >/dev/null 2>&1
    lint_output=$(swiftlint lint --quiet "$file_path" 2>/dev/null)
    if [ -n "$lint_output" ]; then
        # Exit 2 feeds remaining (non-autocorrectable) violations back to Claude.
        echo "$lint_output" >&2
        exit 2
    fi
fi

exit 0
