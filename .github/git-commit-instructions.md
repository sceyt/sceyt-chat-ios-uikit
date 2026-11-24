Generate a Git commit message based on the provided code changes.

Use this format:

<type>(<scope>): <short summary>

- <change 1>
- <change 2>
- <change 3>

Rules:
- Use Conventional Commits for the first line, such as `feat`, `fix`, `refactor`, `test`, `chore`, `perf`, `ci`, or `docs`.
- This repository contains one package, `SceytChatUIKit`. When one area of it clearly owns the change, use that area as a lowercase scope, as in the existing `fix(reply): ...` commit:
  - `fix(reply): ...`
  - `feat(search): ...`
  - `fix(ci): ...`
- Determine the scope from the files and behavior changed, such as `channel-list`, `channel`, `channel-info`, `reply`, `pin`, `poll`, `search`, `transfer`, `database`, `appearance`, `demo`, or `ci`.
- If the change spans several areas or has no clear owner, omit the scope:
  - `fix: ...`

Commit summary rules:
- Keep the first line concise and describe the main purpose of the change.
- Do not include a UIKit or Chat SDK version number in the summary.
- Do not end the first line with a period.
- Use lowercase after the type/scope unless a proper noun requires capitalization.

Commit body rules:
- Add a blank line after the summary.
- Add bullet points describing meaningful changes.
- Each bullet must start with `- `.
- Use concise present-tense or imperative wording.
- Focus on behavior and meaningful implementation changes rather than listing every changed file.
- Mention tests when tests were added or updated.
- Mention a public API change and update of `api/SceytChatUIKit.swiftinterface` when the public interface changes.
- Mention a new Core Data model version when the schema changes.
- Avoid vague bullets such as `update code`, `fix issues`, or `make improvements`.

Version update rules:
- When `s.version` changes in `SceytChatUIKit.podspec`, do not put the version number in the commit summary.
- Mention the version update as a normal change bullet.
- Add the exact resulting version as a separate final bullet using:
  - `- Version: \`<version>\``
- Use the final version value from the changed podspec, not the previous version.
- If only the version changed, use `chore` as the commit type.
- If a feature/fix and a version bump are part of the same commit, keep the main feature/fix as the commit summary and mention the version only in the body.
- A Chat SDK dependency update is a `chore` unless it comes with a fix or feature. Name the new branch or version in a bullet, not in the summary.

Example — fix without a scope:

fix: keep one member row per user in a channel

- collapse duplicate member rows when a member is fetched or created
- delete every duplicate row when a member is removed
- add regression tests for member deduplication

Example — fix with a scope:

fix(transfer): cancel an upload while its file is being prepared

- stop the upload when the user cancels before the prepared file is ready
- add a regression test for cancelling during preparation

Example — version-only change:

chore: bump pod version

- update s.version in SceytChatUIKit.podspec
- Version: `1.6.17`

Do not include explanations before or after the commit message.
Return only the commit message.
