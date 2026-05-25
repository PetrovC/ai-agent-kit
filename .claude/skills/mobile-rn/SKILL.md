---
name: mobile-rn
description: >
  Use when modifying React Native code: Expo or bare RN, navigation,
  native modules, gesture handling, tests with Jest + RNTL, EAS builds.
paths:
  - "**/app.json"
  - "**/app.config.*"
  - "**/*.native.ts"
  - "**/*.native.tsx"
  - "**/metro.config.*"
  - "**/eas.json"
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(npx:*)"
  - "Bash(expo:*)"
---

# React Native Skill

## Goal

Cross-platform mobile UI that feels native, ships predictably, and has tests
that catch real regressions. No "works on my emulator" — design for slow
networks, low-end Android, gesture interruption.

---

## Project structure

```
src/
  features/        # one folder per feature: screens + hooks + types + tests
  components/      # presentational, reusable
  navigation/      # navigators, route types
  services/        # API clients, storage, push
  hooks/           # cross-cutting hooks
  theme/           # colors, spacing, typography tokens
app.json / app.config.ts
```

Same React rules apply (see `react` skill). Mobile-specific guidance below.

---

## Expo vs bare RN

- **Default to Expo (managed workflow)** for new projects. EAS Build handles native config.
- Switch to bare workflow only when a native module is unavailable in Expo SDK and you've confirmed there's no alternative.
- Keep `expo-modules-core` and Expo packages aligned with the SDK version. Don't pin random versions.

---

## Navigation

- **React Navigation** (`@react-navigation/native`) is the standard.
- Type your stacks:

```tsx
type RootStackParamList = {
  Home: undefined;
  Profile: { userId: string };
};
const Stack = createNativeStackNavigator<RootStackParamList>();
```

- Use `useNavigation<NativeStackNavigationProp<RootStackParamList>>()` — get type-checked navigation everywhere.
- Deep links: declare prefixes + linking config once, in the top-level NavigationContainer.

---

## Performance / responsiveness

- **Lists**: use `FlatList` or `FlashList` (Shopify, MIT). Never `.map()` over big arrays inside `ScrollView`.
- Pass `keyExtractor`. Set `getItemLayout` when item size is fixed — huge perf win.
- Images: `expo-image` (MIT) — handles caching, placeholders, transitions. Avoid the bare `<Image>` for remote content.
- Animations: Reanimated 3 (MIT), not the legacy Animated API. Run on the UI thread.
- Avoid `setState` in scroll/gesture callbacks. Use `useAnimatedScrollHandler` / `runOnJS` correctly.
- Memoize list item components (`React.memo`) when row count is high.

---

## State and data

- Server state: TanStack Query (MIT). Works the same as on web.
- Local persistent state: `expo-secure-store` for secrets, `@react-native-async-storage/async-storage` for non-sensitive.
- Forms: React Hook Form + zod. The same patterns as web.

---

## Platform-specific code

- Use `Platform.OS === 'ios' | 'android'` only for branching behavior, not styling (use theme).
- File-level: `Component.ios.tsx` / `Component.android.tsx` for full splits. Avoid unless really needed.
- iOS / Android permissions: declare in `app.json` (or Info.plist / AndroidManifest). Request at use time, not at app start.

---

## Network and offline

- Always handle the network error path. Mobile networks fail.
- Show optimistic UI when safe; reconcile with server response.
- Cache reads with TanStack Query `staleTime` tuned to your data.
- For background sync: `expo-task-manager` + `expo-background-fetch`. Document battery / iOS limits.

---

## Accessibility

- `accessibilityLabel`, `accessibilityRole`, `accessibilityHint` on every interactive element.
- Test with VoiceOver (iOS) and TalkBack (Android) at least once per release.
- Respect `Appearance.getColorScheme()` for dark mode if the design supports it.
- Respect `AccessibilityInfo.isReduceMotionEnabled()` for animations.

---

## Testing

- **Unit / component**: Jest + `@testing-library/react-native`.
- Mock native modules with `jest.mock('expo-secure-store', () => ...)`.
- Avoid relying on `act()` warnings — fix the underlying async issue.
- Use `userEvent` from RNTL for typing/pressing.
- **End-to-end**: Detox or Maestro. Detox is more invasive but precise; Maestro is YAML and fast to write. Either is fine — pick one per project.

```tsx
import { render, screen } from '@testing-library/react-native';
import userEvent from '@testing-library/user-event';

test('shows error when email is invalid', async () => {
  render(<LoginScreen />);
  const user = userEvent.setup();
  await user.type(screen.getByLabelText(/email/i), 'not-an-email');
  await user.press(screen.getByRole('button', { name: /sign in/i }));
  expect(await screen.findByText(/invalid email/i)).toBeOnTheScreen();
});
```

---

## Builds and release

- EAS Build for Expo. Pin `eas-cli` version in CI.
- Separate `development`, `preview`, `production` channels.
- App secrets: EAS Secrets, never in `app.json`.
- OTA updates (EAS Update) for JS-only changes. Full store builds for native changes.
- Pre-flight checklist: bumping version, smoke test on iOS + Android, screenshots, store metadata.

---

## What NOT to do

- No raw `fetch()` without timeout — wrap with `AbortController` or use TanStack Query.
- No console-logging tokens, user PII, or full API responses.
- No animations that drop frames — measure on a low-end Android, not just iPhone Pro.
- No inline styles for repeated values — extract to theme tokens.
- No commitment of `.env`, `google-services.json`, or `GoogleService-Info.plist` with real credentials.
- No `setTimeout` for waiting on navigation transitions in tests — use `findBy*` instead.

---

## Verification commands

```bash
pnpm tsc --noEmit
pnpm lint
pnpm test                        # jest
pnpm test --coverage
npx expo doctor                  # config sanity
eas build --platform ios --profile preview --non-interactive   # CI smoke
```

---

## Final response requirements

Always report:
- Files changed (screen / component / hook / navigator / service).
- Tests added (RNTL queries, mocked native modules).
- TS / lint / test results, plus `expo doctor` if config touched.
- Any new dependency: name, version, **license (MIT only — see `dependencies` skill)**.
- Platform-specific behavior introduced (iOS / Android) and how it was tested.
