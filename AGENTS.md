# Repository Guidelines

## Project Structure & Module Organization

FreshFlag is a Flutter food-expiry tracker with Firebase as the backend. Client code lives in `lib/`: `screens/` for UI, `viewmodels/` for state, `services/` for Firebase/local integrations, `models/` for domain objects, `config/` for branding, and `utils/` or `theme/` for shared presentation helpers. Flutter tests are in `test/`. Firebase Cloud Functions TypeScript source and tests are in `functions/src/`; compiled output goes to `functions/lib/`. Firestore rules are in `firestore.rules`, with emulator tests in `security-tests/`. Static assets are grouped under `assets/images/`, `assets/icons/`, and `assets/sounds/`. Release and architecture notes live in `docs/`, `ARCHITECTURE.md`, `PROJECT_CONTEXT.md`, and `CHANGELOG.md`.

## Build, Test, and Development Commands

- `flutter pub get`: install Flutter dependencies.
- `flutter test`: run Dart/Flutter unit and widget tests.
- `dart analyze` or `flutter analyze`: run analyzer checks.
- `flutter build linux --release`: validate a Linux release build.
- `cd functions && npm install`: install Cloud Functions dependencies.
- `cd functions && npm run build`: compile TypeScript.
- `cd functions && npm test`: build Functions and run Node tests.
- `cd security-tests && npm install && npm test`: run Firestore rules tests in the emulator.

## Coding Style & Naming Conventions

Use Flutter's standard two-space indentation and the `flutter_lints` rules in `analysis_options.yaml`. Name Dart files with `snake_case.dart`, classes with `PascalCase`, and methods, variables, providers, and services with `lowerCamelCase`. Keep feature logic in services/viewmodels rather than embedding Firebase calls directly in screens. TypeScript Functions compile through `tsconfig.json`; keep source in `functions/src/` and do not edit generated `functions/lib/` output by hand.

## Testing Guidelines

Add or update tests close to the changed surface: Flutter tests in `test/*_test.dart`, Functions tests in `functions/src/*.test.ts`, and Firestore rule tests in `security-tests/*.rules.test.js`. Prefer deterministic tests for household roles, reminder logic, favourites behavior, and authorization boundaries. Include emulator security tests when changing `firestore.rules` or Firestore access patterns.

## Commit & Pull Request Guidelines

Follow the existing Conventional Commit style: `feat:`, `fix:`, `test:`, `docs:`, and `chore:`. Keep commits focused and mention user-visible behavior or validation when relevant. PRs should include a short summary, tests run, linked issues if any, and screenshots or screen recordings for UI changes. Update `CHANGELOG.md` after meaningful implementation, validation, architectural decisions, migrations, or blockers.

## Security & Configuration Tips

Do not restore the old StayFresh Firebase configuration. `lib/firebase_options.dart` is intentionally a safe stub until FreshFlag-owned Firebase settings are generated. Keep secrets, signing material, APNs credentials, and production Firebase credentials out of Git.
# FreshFlag context instructions to add to AGENTS.md

Add the following section to the repository's existing `AGENTS.md` rather than replacing the rest of its workflow instructions.

```md
## FreshFlag project context

Before planning or changing FreshFlag code, read these files in order:

1. `docs/CURRENT_STATE.md`
2. `docs/NEXT_WORK.md`
3. `docs/DECISIONS.md`
4. `docs/PROJECT_CONTEXT_ORIGINAL.md`

Treat `docs/CURRENT_STATE.md` as the source of truth for what has already been implemented/tested. Treat the original project context as product and architecture background, not as a literal current phase checklist.

Important current invariants:

- household-owned inventory must remain household-owned;
- consumed items must remain reachable and restorable;
- invite/join and shared household inventory already work in real-device testing;
- reminders already exist and have been manually tested;
- household/member management and role elevation are implemented in the current phone build and have been tested;
- authorization must be enforced in Firestore/backend rules, not only hidden/shown in Flutter UI;
- preserve the implemented Guest/read-only access level while allowing Admin/trusted members to manage alert/reminder rules.

Before each task, inspect the repository and reconcile these docs with current code/tests. If code proves a document stale, do not silently follow stale text: update the documentation as part of the change.
```
