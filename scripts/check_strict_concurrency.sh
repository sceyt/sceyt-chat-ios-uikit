#!/bin/bash
# Builds the package with complete strict-concurrency checking (what Swift 6 makes errors)
# and fails on any warning in the transfer layer.
# Usage: scripts/check_strict_concurrency.sh "<xcodebuild destination>" [derived data path]
set -uo pipefail
cd "$(dirname "$0")/.."
DESTINATION="${1:-platform=iOS Simulator,name=iPhone 17}"
DERIVED="${2:-.build/strict-concurrency}"
LOG="$(mktemp)"
xcodebuild build -scheme SceytChatUIKit -destination "$DESTINATION" -derivedDataPath "$DERIVED" \
  OTHER_SWIFT_FLAGS='$(inherited) -strict-concurrency=complete' CODE_SIGNING_ALLOWED=NO > "$LOG" 2>&1
status=$?
if [ $status -ne 0 ]; then
  grep -E "error:" "$LOG" | sort -u | head -20
  echo "strict-concurrency build failed"
  exit $status
fi
warnings=$(grep -E "/DataTransfer/.*warning:" "$LOG" | sort -u)
if [ -n "$warnings" ]; then
  echo "$warnings"
  echo "$(echo "$warnings" | wc -l | tr -d ' ') strict-concurrency warning(s) in DataTransfer"
  exit 1
fi
echo "DataTransfer: 0 strict-concurrency warnings"
