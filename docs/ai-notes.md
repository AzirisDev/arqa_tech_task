# AI usage log

Tool: Claude Code (Claude Opus). Used for: analysing the assignment, design spec, implementation plan, generating code and tests, reviewing.

## Where AI was wrong and what was corrected

1. **Weekday.** While designing the day screen, AI labelled 2026-10-01 as Wednesday ("ср, 1 окт"). Checked with `date` — it is Thursday. Spec and test expectations fixed to "чт, 1 окт".
2. **Monorepo layout.** AI first proposed a Dart pub workspace for server + app + shared package. On review: a workspace shares one dependency resolution, so including the Flutter app would tie resolving the server to the Flutter SDK. Switched to plain `path:` dependencies.
3. **Library API from memory.** `sqlite3` 3.x deprecates `dispose()` in favour of `close()` and bundles SQLite via build hooks. Verified the real API with a small probe script before writing the plan instead of trusting remembered 2.x API.
4. **Lints in add-trip form.** The form code from the plan passed tests but `flutter analyze` reported two `use_null_aware_elements` infos (`if (x != null) x!` in collection literals). Caught by running `flutter analyze`; changed to the null-aware element form `?x` (same behaviour).
5. **Stale validation errors.** The form from the plan kept field errors until the next submit, so corrected values were still shown in red. Caught during manual testing on the iOS simulator ("10:00" and "1000" still marked as invalid). Errors are now cleared per field on edit (`_clearErrors`; start also clears `end`, amount also clears `commission`), without re-validating; two widget tests added.
