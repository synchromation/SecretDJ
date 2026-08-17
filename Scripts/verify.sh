#!/bin/bash
#
# Builds the app(s) and runs the full test suite against pinned iOS
# Simulators. This is the single source of truth for "does the project
# pass?" — Claude Code hooks, developers, and CI should all call this
# script rather than invoking xcodebuild with their own flags.
#
# Usage: Scripts/verify.sh [build|test] [suite-or-test ...]
#   Scripts/verify.sh                       # build + full test suite (default)
#   Scripts/verify.sh build                 # build only
#   Scripts/verify.sh test CounterModelTests   # only the named suite(s) — the
#       fast loop for TDD red/green checks. Bare names are resolved inside
#       the consumer unit test target; pass Target/Suite/testName for
#       anything else, e.g. SecretDJKioskTests/Suite for the kiosk app.
#
# A second app scheme "<project>Kiosk" is picked up automatically when its
# shared scheme file exists, and runs the same action against the newest
# available iPad simulator (the primary scheme always runs against the
# newest available iPhone simulator). A targeted run addresses only the
# scheme whose test target its filters name; with no filters, every scheme
# that exists runs.

set -o pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Auto-discover the project so this script transfers between projects
# unchanged. Convention: the shared scheme matches the project name, and the
# unit test target is "<project>Tests". A second, optional "<project>Kiosk"
# shared scheme/test target follows the same convention for a kiosk app.
PROJECT="$(find "$PROJECT_DIR" -maxdepth 1 -name '*.xcodeproj' -print -quit)"
if [ -z "$PROJECT" ]; then
	echo "error: no .xcodeproj found in $PROJECT_DIR" >&2
	exit 1
fi
APP_NAME="$(basename "$PROJECT" .xcodeproj)"
SCHEME="$APP_NAME"
TEST_TARGET="${APP_NAME}Tests"
KIOSK_SCHEME="${APP_NAME}Kiosk"
KIOSK_TEST_TARGET="${APP_NAME}KioskTests"
KIOSK_SCHEME_FILE="$PROJECT/xcshareddata/xcschemes/${KIOSK_SCHEME}.xcscheme"
DERIVED_DATA="$PROJECT_DIR/build/DerivedData"
ACTION="${1:-test}"
[ $# -gt 0 ] && shift
FILTERS_GIVEN=$#

HAS_KIOSK=0
[ -f "$KIOSK_SCHEME_FILE" ] && HAS_KIOSK=1

# Route each filter to the scheme whose test target it addresses: anything
# qualified with the kiosk test target resolves against the kiosk scheme;
# bare names and any other Target/Suite form resolve against the consumer
# scheme, as before.
ONLY_TESTING=()
KIOSK_ONLY_TESTING=()
for filter in "$@"; do
	case "$filter" in
		"$KIOSK_TEST_TARGET"/*) KIOSK_ONLY_TESTING+=("-only-testing:$filter") ;;
		*/*) ONLY_TESTING+=("-only-testing:$filter") ;;
		*) ONLY_TESTING+=("-only-testing:$TEST_TARGET/$filter") ;;
	esac
done

if [ ${#KIOSK_ONLY_TESTING[@]} -gt 0 ] && [ "$HAS_KIOSK" -eq 0 ]; then
	echo "error: no shared scheme found at $KIOSK_SCHEME_FILE for kiosk-qualified filters" >&2
	exit 1
fi

# With no filters, run every scheme that exists. With filters, run only the
# scheme(s) a filter actually addressed.
RUN_CONSUMER=1
RUN_KIOSK=$HAS_KIOSK
if [ "$FILTERS_GIVEN" -gt 0 ]; then
	RUN_CONSUMER=0
	[ ${#ONLY_TESTING[@]} -gt 0 ] && RUN_CONSUMER=1
	RUN_KIOSK=0
	[ "$HAS_KIOSK" -eq 1 ] && [ ${#KIOSK_ONLY_TESTING[@]} -gt 0 ] && RUN_KIOSK=1
fi

# Pick the newest available simulator whose name contains the given
# substring (e.g. "iPhone" or "iPad"), so results are reproducible without
# hard-coding a device name that breaks on the next Xcode release.
destination_id() {
	xcrun simctl list devices available --json | python3 -c '
import json, sys

family = sys.argv[1]
data = json.load(sys.stdin)
candidates = []
for runtime, devices in data["devices"].items():
	if "iOS" not in runtime:
		continue
	for device in devices:
		if device.get("isAvailable") and family in device["name"]:
			candidates.append((runtime, device["udid"]))

if not candidates:
	sys.exit(f"error: no available {family} simulator found")
print(sorted(candidates)[-1][1])
' "$1"
}

# Package logic tests run natively on macOS — the fastest part of the loop.
# They are part of every full test run; targeted runs skip them.
if [ "$ACTION" = "test" ] && [ "$FILTERS_GIVEN" -eq 0 ]; then
	for manifest in "$PROJECT_DIR"/Packages/*/Package.swift; do
		[ -f "$manifest" ] || continue
		swift test --package-path "$(dirname "$manifest")" || exit 1
	done
fi

if [ "$RUN_CONSUMER" -eq 1 ]; then
	UDID="$(destination_id iPhone)" || exit 1

	xcodebuild "$ACTION" \
		-project "$PROJECT" \
		-scheme "$SCHEME" \
		-destination "id=$UDID" \
		-derivedDataPath "$DERIVED_DATA" \
		${ONLY_TESTING[@]+"${ONLY_TESTING[@]}"} \
		-quiet || exit 1
fi

if [ "$RUN_KIOSK" -eq 1 ]; then
	UDID="$(destination_id iPad)" || exit 1

	xcodebuild "$ACTION" \
		-project "$PROJECT" \
		-scheme "$KIOSK_SCHEME" \
		-destination "id=$UDID" \
		-derivedDataPath "$DERIVED_DATA" \
		${KIOSK_ONLY_TESTING[@]+"${KIOSK_ONLY_TESTING[@]}"} \
		-quiet || exit 1
fi
