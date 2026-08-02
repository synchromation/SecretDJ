#!/bin/bash
#
# Xcode build phase: uploads dSYMs (with sources) to Sentry so crash reports
# symbolicate. Wired on the app target as an install-only phase, so it runs
# for Archive/TestFlight builds and never for everyday builds or tests.
# Requires ENABLE_USER_SCRIPT_SANDBOXING = NO on the target (the upload needs
# network access, which the script sandbox blocks).
#
# Missing pieces downgrade to build-log warnings — symbol upload must never
# break a build. To make uploads work:
#   - sentry-cli:          brew install sentry-cli
#   - auth token:          sentry-cli login   (or export SENTRY_AUTH_TOKEN)
#   - org/project slugs:   fill in below, or export SENTRY_ORG/SENTRY_PROJECT

# Slugs from sentry.io → Settings; safe to commit (the auth token is not —
# it stays in ~/.sentryclirc or the environment).
SENTRY_ORG="${SENTRY_ORG:-synchromation}"
SENTRY_PROJECT="${SENTRY_PROJECT:-secret-dj}"

# Xcode build phases run with a minimal PATH that omits Homebrew.
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

warn() {
	echo "warning: [Sentry symbols] $1"
}

if [ "${CONFIGURATION:-}" = "Debug" ]; then
	exit 0
fi

if ! command -v sentry-cli >/dev/null 2>&1; then
	warn "sentry-cli not installed — skipping dSYM upload (brew install sentry-cli)"
	exit 0
fi

case "$SENTRY_ORG$SENTRY_PROJECT" in
	*"<"*)
		warn "SENTRY_ORG/SENTRY_PROJECT not configured — skipping dSYM upload (edit Scripts/upload-symbols.sh)"
		exit 0
		;;
esac

export SENTRY_ORG SENTRY_PROJECT

if ! sentry-cli debug-files upload --include-sources "${DWARF_DSYM_FOLDER_PATH:-}"; then
	warn "dSYM upload failed — crashes from this build will not symbolicate (is SENTRY_AUTH_TOKEN set? try sentry-cli login)"
fi

exit 0
