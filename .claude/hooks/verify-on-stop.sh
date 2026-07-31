#!/bin/bash
#
# Stop hook: refuses to let Claude finish a turn while the project fails to
# build or any test fails. Runs Scripts/verify.sh and, on failure, blocks the
# stop and feeds the failure output back so Claude fixes it before finishing.
#
# To avoid pointless multi-minute xcodebuild runs after conversation-only
# turns, the hook fingerprints the project sources and skips verification when
# nothing changed since the last successful run.

input=$(cat)

# If we already blocked once this turn, let Claude's next stop attempt through
# even if things are still red — otherwise a stubborn failure loops forever.
if printf '%s' "$input" | grep -q '"stop_hook_active": *true'; then
	exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$project_dir" || exit 0

state_file=".claude/.last-green-fingerprint"

fingerprint() {
	{
		git rev-parse HEAD 2>/dev/null
		git status --porcelain 2>/dev/null
		git diff 2>/dev/null
		git diff --cached 2>/dev/null
		git ls-files --others --exclude-standard -z 2>/dev/null | xargs -0 shasum 2>/dev/null
	} | shasum | cut -d' ' -f1
}

current=$(fingerprint)
[ -f "$state_file" ] && [ "$(cat "$state_file")" = "$current" ] && exit 0

log=$(mktemp)
if ./Scripts/verify.sh test >"$log" 2>&1; then
	printf '%s' "$current" > "$state_file"
	rm -f "$log"
	exit 0
fi

{
	echo "Build or tests failed. Fix the failures before finishing — do not lower or delete tests to get past this check unless they assert genuinely wrong behavior. Output:"
	tail -80 "$log"
} >&2
rm -f "$log"
exit 2
