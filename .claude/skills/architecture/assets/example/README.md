# Reference feature: gift ideas (`ideas`)

A complete, minimal feature written to the target architecture: 9 source files, 5 test files,
19 tests. It is **not part of the app** — it is the model to copy and adapt when building a
brick. It was compiled, analyzed (`flutter analyze`: no issues) and tested against the repo on
2026-10-07, and again on 2026-10-11 after M7–M9, installed as below with the architecture test
passing.

It also happens to be a first slice of backlog B4 (gift ideas per person): when that work starts,
it can be the starting point after a design pass with the ux-ui skill.

## What each file shows

| File | Pattern |
|------|---------|
| `lib/features/ideas/domain/idea.dart` | primary-constructor model, `==`/`hashCode` (no `copyWith`: nothing copies an idea), a draft with its validation rule, a pure query extension |
| `lib/features/ideas/domain/idea_failure.dart` | failures as an `enum implements Exception` |
| `lib/features/ideas/data/idea_repository.dart` | per-user path `user/{uid}/ideas`, injected Firestore, private mappers, tolerant reads, client timestamps, error translation, provider next to the class |
| `lib/features/ideas/providers/ideas_providers.dart` | session-scoped `StreamProvider`, derived `autoDispose.family` provider |
| `lib/features/ideas/providers/idea_editor.dart` | `AsyncNotifier<void>` controller for optimistic writes, `ref.mounted` after `await` |
| `lib/features/ideas/screens/ideas_screen.dart` | `switch` on `AsyncValue` (error → empty → data → loading), `ref.listen` for late failures |
| `lib/features/ideas/widgets/add_idea_sheet.dart` | sheet with `show()`, button driven by the domain rule, fire-and-close |
| `lib/features/ideas/widgets/idea_tile.dart` | dumb widget: data in, callbacks out |
| `lib/features/ideas/widgets/idea_failure_text.dart` | failure → words, in the UI only |
| `test/features/ideas/**` | one test file per layer: domain, repository on `FakeFirebaseFirestore`, providers with `ProviderContainer.test`, screen with `pumpHarness` |

## Trying it in the repo

The providers it relies on (`firestoreProvider`, `clockProvider`, `currentUidProvider`) are in
`lib/`:

```bash
S=.claude/skills/architecture/assets
cp -r $S/example/lib/features/ideas lib/features/
cp -r $S/example/test/features/ideas test/features/
```

1. Add the strings to `lib/l10n/intl_fr.arb` (template) and `intl_en.arb`, then
   `flutter gen-l10n`:

   | Key | FR | EN |
   |-----|----|----|
   | `ideasTitle` | Idées cadeaux | Gift ideas |
   | `ideasEmpty` | Aucune idée pour l'instant. | No ideas yet. |
   | `ideasLoadError` | Impossible de charger les idées. | Couldn't load ideas. |
   | `retry` | Réessayer | Retry |
   | `ideaAdd` | Ajouter une idée | Add an idea |
   | `ideaTitleLabel` | Idée | Idea |
   | `ideaFailureInvalid` | Saisissez une idée de 120 caractères au plus. | Enter an idea of 120 characters at most. |
   | `ideaFailureSignedOut` | Session expirée : reconnectez-vous. | Session expired: sign in again. |
   | `ideaFailureStorage` | Enregistrement impossible. Réessayez. | Couldn't save. Try again. |

2. Declare the feature in `test/architecture/architecture_test.dart`:
   `'ideas': {'auth'},`.
3. Allow the path in `firestore.rules`:
   ```
   match /user/{userId}/ideas/{ideaId} {
     allow read, write: if request.auth != null && request.auth.uid == userId;
   }
   ```
4. Wire a route or a tab in `app/` when it becomes a real feature.

`flutter test test/features/ideas test/architecture` should then pass.
