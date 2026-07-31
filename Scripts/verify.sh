#!/bin/bash
#
# Builds the app and runs the full test suite against a pinned iOS Simulator.
# This is the single source of truth for "does the project pass?" — Claude Code
# hooks, developers, and CI should all call this script rather than invoking
# xcodebuild with their own flags.
#
# Usage: Scripts/verify.sh [build|test] [suite-or-test ...]
#   Scripts/verify.sh                       # build + full test suite (default)
#   Scripts/verify.sh build                 # build only
#   Scripts/verify.sh test CounterModelTests   # only the named suite(s) — the
#       fast loop for TDD red/green checks. Bare names are resolved inside the
#       unit test target; pass Target/Suite/testName for anything else.

set -o pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/Untitled Project.xcodeproj"
SCHEME="Untitled Project"
DERIVED_DATA="$PROJECT_DIR/build/DerivedData"
TEST_TARGET="Untitled ProjectTests"
ACTION="${1:-test}"
[ $# -gt 0 ] && shift

ONLY_TESTING=()
for filter in "$@"; do
	case "$filter" in
		*/*) ONLY_TESTING+=("-only-testing:$filter") ;;
		*) ONLY_TESTING+=("-only-testing:$TEST_TARGET/$filter") ;;
	esac
done

# Pick the newest available iPhone simulator so results are reproducible
# without hard-coding a device name that breaks on the next Xcode release.
destination_id() {
	xcrun simctl list devices available --json | python3 -c '
import json, sys

data = json.load(sys.stdin)
candidates = []
for runtime, devices in data["devices"].items():
	if "iOS" not in runtime:
		continue
	for device in devices:
		if device.get("isAvailable") and "iPhone" in device["name"]:
			candidates.append((runtime, device["udid"]))

if not candidates:
	sys.exit("error: no available iPhone simulator found")
print(sorted(candidates)[-1][1])
'
}

UDID="$(destination_id)" || exit 1

xcodebuild "$ACTION" \
	-project "$PROJECT" \
	-scheme "$SCHEME" \
	-destination "id=$UDID" \
	-derivedDataPath "$DERIVED_DATA" \
	${ONLY_TESTING[@]+"${ONLY_TESTING[@]}"} \
	-quiet
