# Patterns — how to write each building block

Riverpod 3.4 without codegen, Firebase, Dart 3.13, Flutter 3.47. Every snippet here was compiled
and exercised against the repo's dependencies when written. A complete, minimal feature to copy is the
gift-ideas example in `assets/example/` (the seed of backlog B4); the app's own features follow
the same patterns, `birthday` being the most complete. This file explains the choices and the
variants.

## Contents
1. Domain model
2. Business rules and time
3. Failures
4. Repository (Firestore)
5. Service (plugin wrapper)
6. Session-scoped data
7. Derived and family providers
8. UI-state notifiers
9. Controllers: optimistic writes vs awaited operations
10. Side effects on data changes
11. Rendering state in widgets
12. Navigation and composition across features
13. Cross-feature orchestration
14. Tests per layer
15. Riverpod 3 / Firebase gotchas

---

## 1. Domain model

```dart
/// Idée cadeau, rattachée à une personne ou dans la boîte « à trier ».
class const Idea({
  required final String id,
  required final String title,
  final String? personId,
  required final DateTime createdAt,
}) {
  @override
  bool operator ==(Object other) =>
      other is Idea &&
      other.id == id &&
      other.title == title &&
      other.personId == personId &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, title, personId, createdAt);
}
```

- `class const X({required final …})` is a Dart 3.13 primary constructor: fields and `const`
  constructor declared once. Use it for new types; convert an existing model when you rework it,
  not in a sweep.
- No `copyWith` by default. Write one when code builds a modified copy — a state its notifier
  replaces (`BiometricLock`), a value edited in memory; then `null` means "unchanged" and a
  `clearX` flag resets a nullable field. Tests build their variants with a local factory
  (`Birthday birthday({List<String> categories = const ['family']})`).
- `==`/`hashCode` on every model and state that flows through providers: Riverpod 3 filters
  updates with `==`, and tests compare values. Lists: `listEquals(a, b)` and `Object.hashAll`
  from `package:flutter/foundation.dart`.
- No `fromFirestore`/`toJson` on domain models: mapping lives in private functions of the
  repository.
- Form input is its own type (`IdeaDraft`) carrying the validation rule (`isValid`) used by both
  the button state and the controller. Files picked by the user become bytes or a path in the
  draft, never an `XFile` (that is a plugin type).

## 2. Business rules and time

Rules are pure functions or extensions in `domain/` that receive everything they need, the
current date included. Providers supply the date from `clockProvider`.

```dart
// domain/birthday_dates.dart
extension BirthdayDates on Birthday {
  /// Prochaine occurrence à partir de [today] (inclus).
  DateTime nextOccurrence(DateTime today) {
    final thisYear = DateTime(today.year, date.month, date.day);
    return thisYear.isBefore(today)
        ? DateTime(today.year + 1, date.month, date.day)
        : thisYear;
  }
}
```

```dart
/// Date du jour (à minuit), recalculée quand le jour change.
final todayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(clockProvider)();
  final today = DateTime(now.year, now.month, now.day);
  final timer = Timer(
    DateTime(now.year, now.month, now.day + 1).difference(now), // calendaire : sûr au changement d'heure
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return today;
});
```

Both live in `lib/core/providers/clock_provider.dart` (with tests).
`clockProvider` is `Provider<DateTime Function()>`; tests pin it with
`clockProvider.overrideWithValue(() => DateTime(2026, 3, 12))`, widget tests pin `todayProvider`
directly. One implementation per rule: the notification scheduler and the home screen call the
same domain function. A widget may *apply* a rule (`isWishedThisYear(b.wishedYears, today)` with
`today` watched from `todayProvider`); it never re-implements one inline.

## 3. Failures

```dart
/// Échecs métier des idées, traduits en texte par l'UI.
enum IdeaFailure implements Exception { invalidDraft, signedOut, storage }
```

- An `enum` when cases carry no data; a `sealed class … implements Exception` with `final class`
  cases when they do (`QuotaExceeded(retryAfter)`).
- Repositories translate SDK errors at the boundary and keep the stack trace:

```dart
Future<T> _guard<T>(Future<T> Function() write) async {
  try {
    return await write();
  } on FirebaseException catch (_, stackTrace) {
    Error.throwWithStackTrace(IdeaFailure.storage, stackTrace);
  }
}
```

  Auth follows the same shape: `AuthRepository` maps `FirebaseAuthException.code` to an
  `AuthFailure`, so no layer above knows Firebase codes or takes `l10n`.
- The UI maps failures to words with an exhaustive `switch` (`widgets/idea_failure_text.dart`),
  with a fallback for unexpected errors (`l10n.errorUnknown`).
- No `Result`/`Either` type: `AsyncValue` already carries data-or-error up to the UI, and typed
  failures make the error side explicit (decision D6).

## 4. Repository (Firestore)

Full example: `assets/example/lib/features/ideas/data/idea_repository.dart`.

```dart
class IdeaRepository {
  const IdeaRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _ideas(String uid) =>
      _firestore.collection('user').doc(uid).collection('ideas');

  Stream<List<Idea>> watchIdeas(String uid) =>
      _ideas(uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(_ideaFromDoc).toList());
}

final ideaRepositoryProvider = Provider<IdeaRepository>(
  (ref) => IdeaRepository(ref.watch(firestoreProvider)),
);
```

- Dependencies come in through the constructor, from infrastructure providers
  (`firestoreProvider`, `httpClientProvider`, …). No `FirebaseFirestore.instance` default:
  tests build `IdeaRepository(FakeFirebaseFirestore())` directly.
- **Paths**: new per-user data lives under `user/{uid}/<collection>` — isolation comes from the
  path, rules stay one line, no `uid` field or `where` needed:
  ```
  match /user/{userId}/{collection}/{docId} {
    allow read, write: if request.auth != null && request.auth.uid == userId;
  }
  ```
  Existing top-level collections (`birthday`, `books`) keep `where('uid', isEqualTo: uid)` on
  every query (rules are not filters: a query without it is rejected) and set `uid` on create.
  Ownership on update and delete is the rules' job — `resource.data.uid == request.auth.uid`,
  plus `request.resource.data.uid == resource.data.uid` on update so a document can't change
  owner. No read-before-write in the client: it duplicates the rules and delays optimistic
  writes. Account deletion must delete subcollection documents explicitly (batches of ≤ 500).
- **A new field on an existing collection**: tolerant read (absent → default, so old documents
  stay valid), written by the repository, covered by a repository test with an old-shape
  document. Touch `firestore.rules` only if they validate fields.
- **Streams are the source of truth.** Firestore's offline cache already serves reads and emits
  local writes immediately (`hasPendingWrites`); don't add a second cache.
- **Writes resolve on server acknowledgement** — offline, only when the network is back. Return
  the `Future` (honest API) but don't make the UI wait on it (section 9). Generate ids client-side
  (`collection.doc()`), so the caller knows the id at once.
- Timestamps come from the clock (`now:` parameter). `FieldValue.serverTimestamp()` reads as
  `null` in local snapshots until the server acknowledges.
- Mapping: private `_xFromDoc` / `_xToMap` at the bottom of the file; tolerant reads
  (`data['title'] as String? ?? ''`, never `data()!`); null-aware map entries to omit optionals
  (`'note': ?draft.note`). A schema change (birth year made optional) reads both shapes in the
  mapper and writes the new one — no migration script needed for additive changes.
- Multi-document operations go through `writeInBatches` (`core/extensions/firestore_extensions.dart`,
  `WriteBatch`es of ≤ 500 operations); repositories never call another feature's repository.

## 5. Service (plugin wrapper)

A service is a thin, stateless door to a plugin or remote API: no business rules, no UI strings.

```dart
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService.instance,
);
```

- Plugins needing one-time init keep a singleton for `main()`; everything else reads the
  provider, so tests override it.
- Policy belongs above the service: *when* to remind (J-0, J-7, 10:00) is a domain rule of
  `reminders`; the service only schedules what it is given.
- Used by one feature → that feature's `data/`; by several or by `app/` → `core/services/`.

## 6. Session-scoped data

```dart
final ideasProvider = StreamProvider<List<Idea>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(ideaRepositoryProvider).watchIdeas(uid);
});
```

- This replaces `startListening(uid)` + `clear()`: sign-in, account switch and sign-out rebuild
  the provider, which cancels the old Firestore listener and opens the new one. Riverpod's docs:
  providers initialize themselves; there is no "reset all", so user data must depend on the user.
- `currentUidProvider` (`features/auth/providers/session_providers.dart`) derives from the
  session stream (`authUserProvider`) only: the fingerprint unlocks a session, never replaces
  one.
- A single document: `StreamProvider<UserProfile?>` the same way.
- Use a `StreamNotifier` only if the same object must also expose methods; usually actions go to
  a separate controller (section 9).

## 7. Derived and family providers

```dart
final personIdeasProvider = Provider.autoDispose
    .family<AsyncValue<List<Idea>>, String?>(
      (ref, personId) => ref
          .watch(ideasProvider)
          .whenData((ideas) => ideas.forPerson(personId)),
    );
```

- The provider wires; the rule (`forPerson`) is a domain function, tested without Riverpod.
- One family argument; several → a record `(String?, int)` (value equality).
- `autoDispose` for per-screen or per-id providers; session data stays alive.
- Narrow rebuilds with `select`:
  `ref.watch(userProfileProvider.select((profile) => profile.value?.pseudo))`.

## 8. UI-state notifiers

```dart
class IdeaSearch extends Notifier<String> {
  @override
  String build() {
    ref.watch(currentUidProvider); // repart de zéro au changement d'utilisateur
    return '';
  }

  void update(String query) => state = query;
}

final ideaSearchProvider = NotifierProvider<IdeaSearch, String>(IdeaSearch.new);
```

Search text, filters, selected view mode. Watching the session in `build` resets them at
sign-out. Text-field controllers and focus stay in the widget's `State`.

## 9. Controllers: optimistic writes vs awaited operations

A controller is the ViewModel of one family of actions: it resolves the user, validates with the
domain, calls repositories, and publishes progress and failure as `AsyncValue`. It never builds
strings and never touches `BuildContext`.

**Optimistic writes** (Firestore create/update/delete) — the UI fires and moves on:

```dart
class IdeaEditor extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> add(IdeaDraft draft) => _write((uid) {
    if (!draft.isValid) throw IdeaFailure.invalidDraft;
    final now = ref.read(clockProvider)();
    return ref.read(ideaRepositoryProvider).addIdea(uid, draft, now: now);
  });

  Future<void> _write(Future<Object?> Function(String uid) write) async {
    final uid = ref.read(currentUidProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      if (uid == null) throw IdeaFailure.signedOut;
      await write(uid);
    });
    if (ref.mounted) state = result; // provider libéré pendant l'attente ?
  }
}

final ideaEditorProvider = AsyncNotifierProvider.autoDispose<IdeaEditor, void>(
  IdeaEditor.new,
);
```

```dart
// La feuille : valide, lance, ferme.
unawaited(ref.read(ideaEditorProvider.notifier).add(_draft));
Navigator.of(context).pop();

// L'écran hôte, toujours monté, annonce un échec tardif.
ref.listen(ideaEditorProvider, (_, next) {
  if (next case AsyncError(:final error)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ideaFailureText(context.l10n, error))),
    );
  }
});
```

The host screen's listener also keeps the `autoDispose` controller alive while the write is
pending. No re-entrancy guard: the sheet is already closed.

**Awaited operations** (sign-in, ISBN lookup — they need the network and their result drives the
UI):

```dart
/// Recherche d'un livre par ISBN : réseau requis, le résultat pilote l'UI.
class IsbnLookup extends AsyncNotifier<Book?> {
  @override
  FutureOr<Book?> build() => null;

  Future<void> lookUp(String isbn) async {
    if (state.isLoading) return; // anti double scan
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(bookRepositoryProvider).fetchBookByIsbn(isbn),
    );
    if (ref.mounted) state = result;
  }
}

final isbnLookupProvider =
    AsyncNotifierProvider.autoDispose<IsbnLookup, Book?>(IsbnLookup.new);
```

The button is disabled while `isLoading`; `ref.listen` reports success or failure. A method may
return a `bool` when the caller must navigate on success.

**Mixed operations** (contacts import): await the local part (permission, reading the contacts),
write everything in one `WriteBatch` whose commit is not awaited (`unawaited(batch.commit())`,
Firestore applies it locally at once), and publish the count. Awaiting the commit would hang
offline.

Riverpod's experimental **Mutations** (`package:flutter_riverpod/experimental/mutation.dart`)
target the same need with less code but may break without a major version — not used until they
leave `experimental/` (decision D3).

## 10. Side effects on data changes

```dart
/// Garde les notifications locales alignées sur les anniversaires.
final reminderSyncProvider = Provider<void>((ref) {
  final notifications = ref.watch(notificationServiceProvider);
  ref.listen(birthdaysProvider, fireImmediately: true, (_, next) {
    if (next case AsyncData(:final value)) {
      unawaited(notifications.scheduleAll(planReminders(value)));
    }
  });
});
```

(Simplified: the real `features/reminders/providers/reminder_sync_provider.dart` also passes
`now` from `clockProvider` and maps the plan to `core`'s `ReminderNotification`.)
Activate it from an always-mounted widget in `app/` (`ref.watch(reminderSyncProvider)` in the
app or shell `build`). Riverpod 3 pauses providers whose listeners are all paused or gone, so
a side-effect provider nobody watches simply stops.

## 11. Rendering state in widgets

```dart
body: switch (ref.watch(ideasProvider)) {
  AsyncValue(hasError: true) => _LoadError(
    onRetry: () => ref.invalidate(ideasProvider),
  ),
  AsyncValue(:final value?) when value.isEmpty => const _Empty(),
  AsyncValue(:final value?) => _IdeaList(ideas: value),
  _ => const Center(child: CircularProgressIndicator()),
},
```

- Order: error, empty, data, loading. A provider being retried is `AsyncLoading` *with* an error
  (`hasError` is true), so testing `hasError` first shows the error instead of an endless
  spinner. Refreshes keep the previous `value`, so data stays visible while reloading.
- `ref.watch` in `build`, `ref.read` in callbacks, `ref.listen` for one-off effects (snackbar,
  navigation). Never `ref.read(provider.future)` to "load" data from a widget.
- Each state is designed (empty with a call to action, error with retry): see the ux-ui skill.

## 12. Navigation and composition across features

go_router (decision D9): paths in `core/routing/app_routes.dart`, the router in `app/router/`
(`appRouterProvider`, redirects from `authAccessProvider`, tabs as branches of a
`StatefulShellRoute`).

```dart
// core/routing/app_routes.dart — chemins seulement, aucun écran importé.
abstract final class AppRoutes {
  const AppRoutes._();

  static const login = '/auth/login';
  static const settings = '/settings';
}

// Dans une feature :
context.go(AppRoutes.login); // sous-page : la pile suit le chemin (/auth puis /auth/login)
context.push(AppRoutes.settings); // page au-dessus de l'onglet courant, qui reste en place
context.pop(); // retour
```

Sign-in and sign-out never navigate: the router redirects when the access changes. Dialogs and
sheets stay on `Navigator` (`showDialog`, `Navigator.pop(context)`). Inside one feature, a
private sub-page may still be pushed directly; across features, always a path.

Composition with a slot, when the lower feature must show something owned by a higher one:

```dart
/// Page d'une personne. La section « idées » vient d'une autre feature :
/// `app/router` la branche, cette feature ne l'importe pas.
class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.personId, this.ideasSection});

  final String personId;
  final Widget? ideasSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ideasSection = this.ideasSection;
    return Scaffold(body: ListView(children: [Text(personId), ?ideasSection]));
  }
}
// app/router : PersonScreen(personId: id, ideasSection: PersonIdeas(personId: id))
```

## 13. Cross-feature orchestration

A flow touching several features lives in the lowest feature that already depends on all of them
(`structure.md` §6). Shape of account deletion in `settings` (depends on auth, user, birthday):

```dart
class AccountDeletion extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> run() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final uid = ref.read(currentUidProvider);
      if (uid == null) throw SettingsFailure.signedOut;
      await ref.read(birthdayRepositoryProvider).deleteAllUserBirthdays(uid);
      await ref.read(userRepositoryProvider).deleteUser(uid);
      await ref.read(authRepositoryProvider).deleteCurrentUser();
    });
    if (ref.mounted) state = result;
  }
}
```

Nothing to "clear" afterwards: every session-scoped provider resets when `currentUidProvider`
turns null. Flows triggered by the app lifecycle (create the profile on first sign-in, offer the
reminders after a capture or a sign-in, give a guest's profile the Google names once linked)
live in `app/bootstrap/` and react to providers (`currentUidProvider`,
`birthdayAdditionsProvider`, `freshSignInProvider`, `guestLinksProvider`).

## 14. Tests per layer

| Layer | Tool | Pattern |
|-------|------|---------|
| domain | `test()` | pure inputs → outputs; dates passed explicitly |
| data | `FakeFirebaseFirestore`, `MockClient`, `mock_exceptions` | real repository on a fake backend; isolation per uid; failure translation |
| providers | `ProviderContainer.test` | real providers over fake backends or fake repositories; assert `AsyncValue` transitions |
| screens/widgets | `tester.pumpHarness` | override data providers with fixed `AsyncValue`s and repositories with fakes; assert every state and interaction |
| structure | `test/architecture/` | runs with the suite |

```dart
ProviderContainer makeContainer() => ProviderContainer.test(
  retry: (_, _) => null, // une erreur reste une erreur
  overrides: [
    firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    currentUidProvider.overrideWithValue('u1'),
    clockProvider.overrideWithValue(() => DateTime(2026, 10, 7)),
  ],
);

test('streams the ideas of the signed-in user', () async {
  final container = makeContainer();
  container.listen(ideasProvider, (_, _) {}); // sinon le provider reste en pause
  expect(await container.read(ideasProvider.future), isEmpty);
});
```

- `ProviderContainer.test` disposes itself at the end of the test.
- **Listen before you await**: a provider without listener is paused (a `StreamProvider` never
  emits) and an `autoDispose` one is disposed. `container.listen(p, (_, _) {})` first.
- Switch accounts in a test with a small test-only notifier:
  `currentUidProvider.overrideWith((ref) => ref.watch(testSessionProvider))`.
- Fix async state for widget tests: `ideasProvider.overrideWithValue(const AsyncData([]))`
  (works for `StreamProvider`/`FutureProvider`), no stream to simulate.
- Fake **repositories** (`class _FakeIdeaRepository extends Fake implements IdeaRepository`),
  not Notifiers: Riverpod's docs discourage mocking Notifiers, and fake repositories exercise the
  real logic. To start a Notifier in a given state, `overrideWithBuild((ref, notifier) => …)`.
  Families: `overrideWith2((arg) => …)` (`overrideWith` is deprecated since 3.2).
- `pumpHarness(widget, overrides: [...])`: a non-empty list *replaces* `defaultTestOverrides`.
- A repository that gains a method needs it in its shared fake (`test/support/fake_providers.dart`):
  `Fake` throws on anything not overridden, and every harness test using the default overrides
  crashes.
- Pin time with `todayProvider.overrideWithValue(DateTime(2026, 3, 12))` when an assertion
  depends on the day; otherwise no override is needed (§15).
- Dependents are recomputed lazily: after changing a source in a test, re-read the dependent
  provider rather than counting synchronous listener calls.
- Exceptions on fake Firestore: `whenCalling(Invocation.method(#delete, null)).on(docRef)
  .thenThrow(FirebaseException(plugin: 'x'))` — references compare by path.

## 15. Riverpod 3 / Firebase gotchas

- After an `await`, check `ref.mounted` before touching `state`: a disposed Notifier throws.
  Read every dependency (`ref.read(x)`) before the first `await`: a `ref` used once its notifier
  is disposed throws too.
- Methods use `ref.read`; only `build` uses `ref.watch`. A `ref.watch` getter called from a
  method is a bug waiting to happen.
- Automatic retry is on by default (10 tries, 200 ms → 6.4 s) for exceptions: render `hasError`
  first. Tests turn it off — the widget harness does, `ProviderContainer.test` takes
  `retry: (_, _) => null`.
- Paused providers: hidden widgets (`TickerMode`) pause their listeners; side-effect providers
  must be watched from an always-visible widget.
- `AsyncValue.value` returns the previous value during loading/error; `valueOrNull` is gone.
  `requireValue` throws when there is none.
- Errors rethrown by `ref.read`/`ref.watch` are wrapped in `ProviderException`;
  `AsyncValue.error` is the original.
- `StateProvider` / `StateNotifierProvider` live in `legacy.dart`: never use them.
- A family takes one argument; use a record for several.
- Timers inside providers (`todayProvider`) need no override in widget tests: the test
  unmounts the `ProviderScope` before checking timers, which disposes the provider and cancels
  its timer. Pin the day only when an assertion depends on it.
- An `autoDispose` controller with optimistic writes needs an always-mounted screen (home,
  scanner, settings) that `ref.listen`s it: that keeps it alive and announces late failures. A
  failure contradicting the snackbar on screen replaces it (`hideCurrentSnackBar`) instead of
  queuing behind it.
- `riverpod_lint` (analyzer plugin) reports in the IDE and with `dart analyze`; `flutter analyze`
  does not run plugins (checked with Flutter 3.47.6). Suppress a plugin diagnostic with
  `// ignore: riverpod_lint/<rule>`: `flutter analyze`'s `unnecessary_ignore` accepts it.
- Firestore: write futures wait for the server; snapshots carry local writes at once;
  `serverTimestamp()` is null until acknowledged; security rules don't filter queries.
- Firestore: write only the fields that changed (`update`, `FieldValue.arrayUnion`) — rewriting a
  document read a moment earlier loses a concurrent edit (theme, then language). `orderBy` leaves
  out documents missing the field: always write the sort key.
- Dates: local midnights are 23 h or 25 h apart around DST changes. Count days between
  `DateTime.utc(y, m, d)` values and step in calendar days (`DateTime(y, m, d - 7)`), never with
  `Duration(days: n)`.
- Images: `MemoryImage` is keyed by its bytes instance; decode base64 once (in the repository),
  never in `build`, or every rebuild decodes the picture again.
- A callback reading a `StreamProvider` with `ref.read` gets nothing when no one listens to it:
  a screen watches (`select`) the session data it uses, even if `App` keeps it alive.
- go_router asserts when the last page is popped: the test harness shows the widget above a
  blank page, so a sheet that closes itself has somewhere to go. `tester.pageBack()` looks for
  the English « Back » tooltip: in the French tests, tap `find.byType(BackButton)`.
- Test doubles: `fake_cloud_firestore` applies a transaction one tick late to snapshot listeners
  and enforces the 500-operation batch limit (a 501-document test proves batching);
  `firebase_auth_mocks` asserts that `signInAnonymously` gets an anonymous mock user.
- Dart 3.13: `final` on a constructor parameter that doesn't declare a field is an error;
  `require_trailing_commas` has been a no-op since the 3.7 formatter.
