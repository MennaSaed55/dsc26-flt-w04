# Agent Instructions — Tawseel

## Project and Toolchain
- This is the Tawseel Flutter Week 4 project. Read the relevant README section before changing code.
- Use Flutter 3.47.6 and Dart 3.13.
- Keep the package name `dsc26_flt_w04`; grader tests import it directly.
- Install dependencies with `flutter pub get`.
- Run tests with `flutter test` and static analysis with `flutter analyze`.

## Project Structure
- Outbox logic: `lib/data/outbox.dart`.
- Storage implementations: `lib/data/local_store.dart`.
- Delivery models: `lib/domain/delivery_outcome.dart` and `lib/domain/stop.dart`.
- Stop-list UI: `lib/ui/stops/`.
- Sample stops, including a long Arabic address: `lib/ui/sample_data.dart`.
- Public tests: `test/public_test.dart`.
- Read relevant source files before proposing changes.

## Project Conventions
- Do not change the supplied domain models or local store unless explicitly required.
- Keep the `TawseelStopsApp` constructor and README-required widget keys.
- Store money as integer piastres; never use floating-point values for money.
- Delivery timestamps must be UTC and serialized in ISO-8601 format ending in `Z`.
- Store the outbox under `tawseel.outbox.v1`.
- Await persistence before reporting a queue change as complete.
- Preserve an entry's ID when retrying; use it as the `Idempotency-Key`.
- Treat HTTP 409 as success because the server already has the entry.
- Replace a correction only when the pending entry has never been attempted; otherwise append it.
- Use directional layout properties to support both LTR and RTL.
- Keep tappable controls at least 48×48 logical pixels and provide accessible labels.
- Let stop rows grow with their text; avoid fixed heights around customer names and addresses.
- Stop-list selection is local widget state; do not add another state-management solution without a requirement.

## Known Traps and Verification
- The stop-list breakpoint is compact below 600 px and expanded at 600 px or above.
- The sync banner must expose exactly one semantics label and be a live region.
- Tests use fake HTTP responses; do not depend on a live backend.
- Transient sync failures must stop the run without skipping the oldest pending entry.
- Before finishing, run `flutter test` and `flutter analyze`.
- Report actual test results; never claim a check passed if it was not run.
- Never commit API keys, tokens, passwords, or real customer data.
- Import project files using the package name `dsc26_flt_w04` and their actual paths under `lib/`.
- Inspect the existing widget implementation before proposing tests; do not assume its API or semantics structure.
