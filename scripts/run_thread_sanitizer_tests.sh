#!/bin/bash

# Run the package unit tests with Thread Sanitizer. A reported data race stops
# the test process and fails the test that triggered it. Set TEST_DESTINATION to
# choose the simulator; extra arguments are passed to xcodebuild.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Tests that report existing data races, skipped so the check can still catch new
# ones. Remove an entry once its race is fixed.
# PeerPresencePollingTests subscribes to PresenceProvider.default, which starts its
# polling timer. The timer reads isStartedChecking on its own queue while subscribe
# and unsubscribe write it on the main thread without synchronization. The race is
# reported whenever the timer next fires, during whichever test is running then, so
# the whole class is listed.
readonly KNOWN_RACES=(
    PeerPresencePollingTests
)

# The database performance tests are skipped in every CI run.
skip_arguments=(-skip-testing:SceytChatUIKitTests/GlobalSearchMessagesViewModelDBPerformanceTests)
for test in ${KNOWN_RACES[@]+"${KNOWN_RACES[@]}"}; do
    skip_arguments+=("-skip-testing:SceytChatUIKitTests/${test}")
done

destination="${TEST_DESTINATION:-}"
if [[ -z "${destination}" ]]; then
    destination="platform=iOS Simulator,id=$(python3 -I "${SCRIPT_DIR}/pick_simulator.py")"
fi

cd "${PROJECT_ROOT}"
# A race ends the test process. Skip the simulator diagnostics that xcodebuild then
# collects for up to 10 minutes; the race report is in the log.
xcodebuild test \
    -scheme SceytChatUIKit \
    -destination "${destination}" \
    -enableThreadSanitizer YES \
    -collect-test-diagnostics never \
    "${skip_arguments[@]}" \
    CODE_SIGNING_ALLOWED=NO \
    "$@"
