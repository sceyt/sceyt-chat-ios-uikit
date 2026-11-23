# How to contribute to the Sceyt Chat iOS UIKit

Set up the checkout, verify your change locally, and include the results in your pull request.

## Set up a checkout

1. Clone this repository or your fork and run the commands below from the repository root. To work in Xcode, open `Package.swift` and select the `SceytChatUIKit` scheme.
2. Install Xcode and at least one iOS Simulator runtime. GitHub CI uses the latest stable Xcode on the `macos-latest` runner. Confirm the active Xcode and the available simulators.

   ```sh
   xcodebuild -version
   xcrun simctl list devices available iOS
   ```

3. Xcode resolves the Sceyt Chat iOS SDK from the branch named in [Package.swift](Package.swift). `Package.resolved` is not committed.

Run a focused test class to verify setup.

```sh
xcodebuild test -scheme SceytChatUIKit \
  -destination "platform=iOS Simulator,id=$(python3 -I scripts/pick_simulator.py)" \
  -only-testing:SceytChatUIKitTests/LazyDatabaseObserverRestartTests \
  CODE_SIGNING_ALLOWED=NO
```

The run should end with `** TEST SUCCEEDED **` and report a positive number of executed tests.

### Troubleshoot setup

- **No simulator is found.** `scripts/pick_simulator.py` prints an available iPhone on the newest iOS runtime. Install an iOS Simulator runtime in Xcode, or pass `-destination "platform=iOS Simulator,id=<UDID>"` with an ID from `xcrun simctl list devices available iOS`.
- **Package resolution fails.** Check that Xcode can reach `https://github.com/sceyt/sceyt-chat-ios-sdk.git` and download its binary.
- **A focused run executes zero tests.** Check the test class name. Test files must be under `Tests/SceytChatUIKitTests/`.
- **The demo app does not build.** `Example/SceytDemoApp` also needs a `sceyt-call-ios-uikit` checkout next to this repository. See its [README](Example/SceytDemoApp/README.md).

## Make and verify a change

Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) and match the surrounding code. Keep the patch focused and cover changed behavior with a regression test where practical. For public or `open` API changes, check source compatibility and behavior for apps that subclass UIKit components or replace them through `SceytChatUIKit.Components`. See [AGENTS.md](AGENTS.md) for the repository's review and verification rules, and the [channel message flow guide](Sources/ARCHITECTURE.md) before changing how messages are stored, observed, or shown.

| Check | Command |
|---|---|
| Run the unit tests, as in CI | `xcodebuild test -scheme SceytChatUIKit -destination "platform=iOS Simulator,id=$(python3 -I scripts/pick_simulator.py)" -skip-testing:SceytChatUIKitTests/GlobalSearchMessagesViewModelDBPerformanceTests CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete` |
| Run one test class | Replace `-skip-testing:...` with `-only-testing:SceytChatUIKitTests/LazyDatabaseObserverRestartTests` (substitute the affected class) |
| Run the tests with Thread Sanitizer, as in CI | `scripts/run_thread_sanitizer_tests.sh` |
| Check the public API | `scripts/check_public_api.sh` |
| Test the CI scripts | `python3 -B -m unittest discover -s scripts/tests` and `node --test .github/tests/slack-alerts.test.cjs` |

Start with the narrowest check that exercises the change. CI skips `GlobalSearchMessagesViewModelDBPerformanceTests`, which builds stores of 500,000 and 1,000,000 messages; run it on a quiet machine when you change global search queries. For UI changes, check the behavior in an app that integrates the package and report the device or simulator and what you observed.

### Check the data transfer layer

CI runs three extra checks on `Sources/SceytChatUIKit/DataTransfer/` for every push and pull request.

```sh
python3 -I scripts/check_code_size.py Sources/SceytChatUIKit/DataTransfer
python3 -I scripts/check_transfer_logs.py Sources/SceytChatUIKit/DataTransfer
scripts/check_strict_concurrency.sh "platform=iOS Simulator,id=$(python3 -I scripts/pick_simulator.py)"
```

- **Code size.** Files have at most 600 lines, functions at most 60, and code nests at most 5 blocks deep.
- **Transfer logs.** Every transfer failure leaves a tagged log line: no untagged or empty messages, no empty `catch`, and no silent `try?` on a file change.
- **Strict concurrency.** The layer builds without warnings under complete concurrency checking.

### Check changed lines before pushing

Pull request runs check the files and lines that your change adds or modifies. To run the same checks locally, commit your changes and run these commands with a clean checkout. Substitute the target branch for `dev`.

```sh
git fetch origin dev
python3 -B scripts/pr_checks.py format origin/dev
rm -rf build/results && mkdir -p build/results
xcodebuild test -scheme SceytChatUIKit \
  -destination "platform=iOS Simulator,id=$(python3 -I scripts/pick_simulator.py)" \
  -skip-testing:SceytChatUIKitTests/GlobalSearchMessagesViewModelDBPerformanceTests \
  -enableCodeCoverage YES -resultBundlePath build/results/TestResults.xcresult \
  CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete 2>&1 | tee build/results/build.log
python3 -B scripts/pr_checks.py warnings origin/dev build/results/build.log
python3 -B scripts/pr_checks.py coverage origin/dev build/results/TestResults.xcresult
```

- **Formatting.** Changed Swift and Objective-C files must be UTF-8, use LF line endings and space indentation, and end with a newline. These rules come from [.editorconfig](.editorconfig). The check reads whole files, so changing a file that already breaks a rule reports it.
- **Compiler warnings.** The check fails when the test build reports a warning on a changed line. Existing warnings on unchanged lines do not fail it. CI builds with complete concurrency checking (`SWIFT_STRICT_CONCURRENCY=complete`), so a change also has to fix concurrency warnings, such as non-`Sendable` captures, on the lines it touches.
- **Coverage.** The check requires **80% line coverage of added or modified executable lines in `Sources/SceytChatUIKit/`** and lists uncovered line numbers. Files without executable code, such as declaration-only files, have no coverage data and are skipped. A changed Swift file that the package does not compile, because `Package.swift` excludes it or declares it as a resource, fails the check.

On GitHub, these checks run in the `unit-tests` job for pull requests. When a check fails, the job uploads the test result bundle and log.

Complete concurrency checking is set on the CI build command rather than in `Package.swift`, so apps that build the package do not get its concurrency warnings, and CocoaPods builds are unaffected.

### Check for data races

The **Thread Sanitizer** job runs the unit tests with Thread Sanitizer in parallel with `unit-tests`. A reported data race stops the test process, and the test that was running fails. Run the same check locally before changing code that crosses threads, queues, or tasks.

```sh
scripts/run_thread_sanitizer_tests.sh
```

The script skips the tests listed in `KNOWN_RACES`, which report data races that already exist: all of `PeerPresencePollingTests`, because the polling timer of `PresenceProvider.default` reads `isStartedChecking` on its own queue while `subscribe` writes it on the main thread without synchronization. The race is reported when the timer next fires, during whichever test is running then. When you fix one of those races, remove its entry in the same change. Do not add a test to the list to work around a new race.

### Review public API changes

The `unit-tests` job runs `scripts/check_public_api.sh`. It builds the `SceytChatUIKit` module in Release for iOS devices with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, which makes the compiler print the module's public Swift interface, and compares that interface with the checked-in [api/SceytChatUIKit.swiftinterface](api/SceytChatUIKit.swiftinterface). It first removes the differences in how Xcode 26 and Xcode 27 print the same API, such as compiler feature guards, module-qualified names, and the order of `@available` platforms. The packages that apps build are not changed: `Package.swift` and the podspec do not enable library evolution.

For an intentional API change, run `scripts/check_public_api.sh --update`, then review and include the reference diff in the pull request. A newer Xcode can print the interface in a new way. If CI reports differences that your change did not make, extend the normalization in the script or take the generated `SceytChatUIKit.swiftinterface` from the job's `test-results` artifact and commit it as the reference.

## Submit a pull request

Use the [commit message conventions](.github/git-commit-instructions.md). Include the following in the description.

- What changed and why. Link the Jira issue when one exists.
- The exact checks you ran, their results, executed test counts, and any skipped checks. Include the device and iOS version for UI checks.
- Any impact on apps that use the package, including public or `open` API, appearance and component customization, Core Data model versions, dependencies, or migration steps.

GitHub [iOS CI](.github/workflows/ios-ci.yml) runs for pull requests to `main` and `dev`, pushes to `main`, `dev`, and `v*` release branches, and manual runs. See the [README](README.md#continuous-integration) for the checks and Slack alerts.
