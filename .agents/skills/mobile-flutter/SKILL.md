---
name: mobile-flutter
description: >
  Use when modifying Flutter code: widgets, state management
  (Riverpod / BLoC), navigation (go_router), tests (flutter_test +
  mocktail), platform channels, build / release flow.
paths:
  - "**/*.dart"
  - "**/pubspec.yaml"
  - "**/pubspec.lock"
allowed-tools:
  - "Bash(flutter:*)"
  - "Bash(dart:*)"
version: "1.0.0"
---

# Flutter Skill

## Goal

Predictable Flutter apps with clear state ownership, fast rebuilds, and
tests that survive refactors. No god-widgets, no `setState` everywhere,
no business logic in widget files.

---

## Project structure

```
lib/
  features/              # one folder per feature: screens + state + widgets + tests
  shared/
    widgets/             # reusable presentational widgets
    services/            # API clients, storage, push
    theme/               # ThemeData, colors, typography
  routing/               # go_router config, route names, guards
  main.dart              # entry point only
test/                    # mirror lib/ structure
```

Rules:
- Widgets describe UI. Business logic lives in state classes (Notifier / Bloc / Cubit).
- One feature = one folder. Don't dump everything in `lib/screens/`.
- Pure Dart code (parsing, formatting, calculations) goes in `shared/` or a separate package — testable without Flutter.

---

## Dart language

- Use null safety. Never disable it.
- Prefer `final` over `var`. Reach for `const` whenever the value is compile-time known.
- Use `sealed class` (Dart 3) for closed hierarchies — exhaustive `switch` checks.
- Records `(int, String)` for ad-hoc tuples; named records `({int id, String name})` for clarity.
- Pattern matching for parsing / discriminated unions.
- Avoid `dynamic`. Use generics, or `Object?` with explicit narrowing.

---

## Widgets

- Prefer `StatelessWidget`. Reach for `StatefulWidget` only when you need lifecycle hooks (controllers, animations) and even then, lift state up if possible.
- Split widgets at 80+ lines, or when responsibilities mix.
- Keep `build()` cheap — no I/O, no computation that can be done above.
- Use `const` constructors everywhere possible — the framework reuses them.
- `Key` on items in `ListView.builder` when items can reorder.

---

## State management

Pick one per project. Don't mix.

| Tool | When to use |
|---|---|
| **Riverpod 2.x** | Default for new projects. Compile-safe, testable, no `BuildContext` needed. |
| **flutter_bloc** | Larger teams that prefer explicit event/state classes. |
| **Provider** | Legacy; existing projects only. |
| Plain `setState` | Trivial local UI state (toggle, counter). |

For Riverpod:
- `@riverpod` annotated providers (generates code). One provider per concern.
- `ref.watch` to rebuild, `ref.read` for one-shot reads inside callbacks.
- Async data with `FutureProvider` / `StreamProvider` — pattern-match on `AsyncValue`.

---

## Navigation

- **`go_router`** is the modern default — declarative, deep-link-friendly, supports nested navigators.
- Define a typed route registry. Avoid scattering route strings.
- Guards for auth: check in `redirect` callback, not in widget `initState`.

---

## Network and data

- HTTP: `dio` (rich, MIT) or `http` (official, simpler). Pick one per project.
- Always set timeouts. Wrap responses in sealed result classes (`Success` / `Failure`).
- Local persistence: `shared_preferences` for primitives, `flutter_secure_storage` for tokens, `drift` / `isar` for structured data.
- Don't make HTTP calls from widgets — go through a repository injected via Riverpod / GetIt.

---

## Performance

- Use the Flutter DevTools timeline. Don't guess.
- `const` constructors prevent unnecessary rebuilds.
- For large lists: `ListView.builder` / `SliverList` with `itemExtent` when item height is fixed.
- Images: `cached_network_image` (MIT) for remote; preload critical assets.
- Avoid `Opacity` for hiding — use `Visibility` or conditional building.
- Profile in `--profile` mode, not `--debug` (debug overhead skews results).

---

## Platform / native code

- Plugins for camera, biometrics, push: prefer official Flutter team plugins (`camera`, `local_auth`, `firebase_messaging`).
- Platform channels only when no plugin exists. Define the contract once, document expected errors.
- Permissions: `permission_handler` (MIT). Request at use time, not at app start.

---

## Accessibility

- `Semantics` widget around custom-painted UI.
- Provide `label`, `hint`, and `excludeSemantics: true` on decorative children.
- Test with TalkBack (Android) and VoiceOver (iOS).
- Respect `MediaQuery.of(context).textScaleFactor` — don't hardcode font sizes that break at 200%.

---

## Testing

- **Unit tests**: `package:test` (or `flutter_test`'s `test()`) for pure Dart. Fast, no widget tree.
- **Widget tests**: `flutter_test` with `WidgetTester`. Pump widgets, find by key/text/semantics, tap, expect.
- **Integration tests**: `integration_test` package. Real device or emulator. Few, slow, critical flows only.
- Mocks: `mocktail` (MIT, no codegen). Avoid `mockito` for new code (codegen overhead).

```dart
testWidgets('shows error on empty email', (tester) async {
  await tester.pumpWidget(MaterialApp(home: LoginScreen()));
  await tester.tap(find.byKey(const Key('signInButton')));
  await tester.pump();
  expect(find.text('Email is required'), findsOneWidget);
});
```

---

## Builds and release

- `flutter_flavorizr` or manual flavors for `dev` / `staging` / `prod`.
- Signing keys outside the repo. Use Fastlane or GitHub Actions secrets.
- Crash reporting: Firebase Crashlytics or Sentry — set up before public beta.
- Pre-flight: bump `pubspec.yaml` version, smoke test both platforms, screenshots, store metadata.

---

## What NOT to do

- No business logic in `build()`.
- No `setState` after `await` without checking `mounted`.
- No `print()` in committed code — use `developer.log` or a logging package.
- No string concatenation for URLs — use `Uri` constructors.
- No `as` casts on parsed JSON — pattern-match or validate explicitly.
- No commitment of `google-services.json` / `GoogleService-Info.plist` with real keys.
- No `Future.delayed` for waiting on UI in tests — use `tester.pump(Duration(...))` or `tester.pumpAndSettle`.

---

## Verification commands

```bash
flutter pub get
dart analyze
dart format --set-exit-if-changed lib test
flutter test
flutter test --coverage
flutter build apk --debug         # CI smoke
flutter build ios --no-codesign   # CI smoke
```

---

## Final response requirements

Always report:
- Files changed and their kind (widget / state / repository / service / route).
- Tests added (unit / widget / integration counts).
- `dart analyze` / `flutter test` / build results.
- Any new package: name, version, **license (MIT only — see `dependencies` skill)**.
- Platform-specific behavior introduced and how it was tested.
