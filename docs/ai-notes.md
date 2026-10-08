# AI usage log

Tool: Claude Code (Claude Opus). Used for: analysing the assignment, design spec, implementation plan, generating code and tests, reviewing.

## Where AI was wrong and what was corrected

1. **Weekday.** While designing the day screen, AI labelled 2026-10-01 as Wednesday ("ср, 1 окт"). Checked with `date` — it is Thursday. Spec and test expectations fixed to "чт, 1 окт".
2. **Monorepo layout.** AI first proposed a Dart pub workspace for server + app + shared package. On review: a workspace shares one dependency resolution, so including the Flutter app would tie resolving the server to the Flutter SDK. Switched to plain `path:` dependencies.
3. **Library API from memory.** `sqlite3` 3.x deprecates `dispose()` in favour of `close()` and bundles SQLite via build hooks. Verified the real API with a small probe script before writing the plan instead of trusting remembered 2.x API.
