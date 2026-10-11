# Foundation files

Additive building blocks of the target architecture, to copy at the same path under the repo
root. None changes existing behaviour. M0 installed the architecture test (2026-10-08; the repo
copy is now the source of truth); M1 installs the rest, and a brick may install the ones it needs
earlier (then say so in `references/migration.md`).

Validated on 2026-10-07 in a copy of the repo: `flutter analyze` clean, full suite green
(310 tests, with the example feature).

| File | Provides | Tests |
|------|----------|-------|
| `test/architecture/architecture_test.dart` | import, layer and feature-graph rules, debt ratchet (`knownViolations` = today's 25) | itself |
| `lib/core/providers/clock_provider.dart` | `clockProvider` (injectable now), `todayProvider` (midnight, rolls over, DST-safe) | `test/core/providers/clock_provider_test.dart` |
| `lib/core/providers/firebase_providers.dart` | `firestoreProvider`, `firebaseAuthProvider` | none: they only expose SDK singletons, and every test overrides them |
| `lib/features/auth/providers/session_providers.dart` | installed by M1, rebuilt by M9 (session, biometric lock, access, `currentUidProvider`): the repo copy is the source of truth, no asset copy | `test/features/auth/providers/session_providers_test.dart` |

```bash
S=.claude/skills/architecture/assets/foundation
mkdir -p lib/core/providers lib/features/auth/providers test/architecture test/core/providers test/features/auth/providers
cp $S/lib/core/providers/clock_provider.dart lib/core/providers/
cp $S/test/core/providers/clock_provider_test.dart test/core/providers/
```

Copy only what the current step or brick needs.
