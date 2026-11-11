import 'dart:async';
import 'dart:ui';

import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/core/services/device_settings.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/data/share_service.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/books/data/bnf_catalog.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/data/google_books_catalog.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/legacy_import.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/domain/volume_number.dart';
import 'package:an_ki/features/books/providers/volume_lookup.dart';
import 'package:an_ki/features/reminders/data/reminder_preferences_repository.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';

class MockUser extends Fake implements firebase_auth.User {
  MockUser({this.uid = 'fake-uid', this.isAnonymous = false});

  @override
  final String uid;

  @override
  String? get displayName => 'Fake User';

  @override
  final bool isAnonymous;

  /// Aucun fournisseur : un compte e-mail pour `signInMethodProvider` (les
  /// `UserInfo` ne se construisent pas hors du SDK ; un test Google remplace
  /// ce provider).
  @override
  List<firebase_auth.UserInfo> get providerData => const [];
}

// --- Repositories ---

class FakeUserRepository extends Fake implements UserRepository {
  @override
  Stream<UserProfile?> watchUser(String uid) => Stream.value(null);

  @override
  Future<UserProfile> createUser(UserProfile user) async => user;

  @override
  Future<void> updatePreferences(
    String uid, {
    String? pseudo,
    ThemePreference? theme,
    String? locale,
  }) async {}

  @override
  Future<void> updateNames(
    String uid, {
    required String name,
    required String surname,
  }) async {}

  @override
  Future<void> setModuleEnabled(
    String uid,
    String moduleId, {
    required bool enabled,
  }) async {}

  @override
  Future<void> deleteUser(String uid) async {}
}

/// [user] après une mise à jour partielle, comme Firestore fusionne les
/// champs écrits : un argument null laisse le champ tel quel, et [modules]
/// s'ajoute aux choix déjà enregistrés.
UserProfile _merged(
  UserProfile user, {
  String? name,
  String? surname,
  String? pseudo,
  ThemePreference? theme,
  String? locale,
  Map<String, bool> modules = const {},
}) => UserProfile(
  id: user.id,
  name: name ?? user.name,
  surname: surname ?? user.surname,
  pseudo: pseudo ?? user.pseudo,
  theme: theme ?? user.theme,
  locale: locale ?? user.locale,
  biometricToken: user.biometricToken,
  moduleChoices: {...user.moduleChoices, ...modules},
);

/// Dépôt de profils en mémoire : [watchUser] reflète chaque écriture, comme
/// le cache local de Firestore, pour tester les écritures optimistes.
class RecordingUserRepository extends FakeUserRepository {
  RecordingUserRepository({this._stored, this.failure});

  UserProfile? _stored;

  /// Erreur levée par chaque écriture quand elle est définie.
  final Exception? failure;

  final _changes = StreamController<UserProfile?>.broadcast();
  final created = <UserProfile>[];
  final updated = <UserProfile>[];
  final deleted = <String>[];

  UserProfile? get stored => _stored;

  @override
  Stream<UserProfile?> watchUser(String uid) {
    // Abonnement immédiat : aucune écriture n'est perdue entre deux émissions.
    final controller = StreamController<UserProfile?>();
    final changes = _changes.stream.listen(controller.add);
    controller
      ..onCancel = () async {
        await changes.cancel();
        await controller.close();
      }
      ..add(_stored);
    return controller.stream;
  }

  @override
  Future<UserProfile> createUser(UserProfile user) async {
    _maybeFail();
    created.add(user);
    // Comme le vrai « créer si absent » : le profil existant gagne.
    final effective = _stored ?? user;
    _emit(effective);
    return effective;
  }

  @override
  Future<void> updatePreferences(
    String uid, {
    String? pseudo,
    ThemePreference? theme,
    String? locale,
  }) async {
    _maybeFail();
    final user = _merged(
      _stored!,
      pseudo: pseudo,
      theme: theme,
      locale: locale,
    );
    updated.add(user);
    _emit(user);
  }

  @override
  Future<void> updateNames(
    String uid, {
    required String name,
    required String surname,
  }) async {
    _maybeFail();
    final user = _merged(_stored!, name: name, surname: surname);
    updated.add(user);
    _emit(user);
  }

  @override
  Future<void> setModuleEnabled(
    String uid,
    String moduleId, {
    required bool enabled,
  }) async {
    _maybeFail();
    final user = _merged(_stored!, modules: {moduleId: enabled});
    updated.add(user);
    _emit(user);
  }

  @override
  Future<void> deleteUser(String uid) async {
    _maybeFail();
    deleted.add(uid);
    _emit(null);
  }

  void _emit(UserProfile? user) {
    _stored = user;
    _changes.add(user);
  }

  void _maybeFail() {
    if (failure case final failure?) throw failure;
  }
}

class FakeBirthdayRepository extends Fake implements BirthdayRepository {
  @override
  Stream<List<Birthday>> watchBirthdays(String uid) => Stream.value([]);

  var _nextId = 0;

  /// Ids tirés dans l'ordre : `new-1`, `new-2`…
  @override
  String newBirthdayId() => 'new-${++_nextId}';

  @override
  Future<void> createBirthday(
    String uid,
    String birthdayId,
    BirthdayDraft draft,
  ) async {}

  @override
  Future<void> createBirthdays(String uid, List<BirthdayDraft> drafts) async {}

  @override
  Future<void> updateReminders(
    String birthdayId,
    Set<ReminderLead>? reminders,
  ) async {}

  @override
  Future<void> updateWishMessage(String birthdayId, String? message) async {}

  @override
  Future<void> updateBirthday(
    String uid,
    String birthdayId,
    BirthdayDraft draft,
  ) async {}

  @override
  Future<void> deleteBirthday(String birthdayId) async {}

  @override
  Future<void> markWished(String birthdayId, int year) async {}

  @override
  Future<void> unmarkWished(String birthdayId, int year) async {}

  @override
  Future<void> deleteAllUserBirthdays(String uid) async {}
}

/// Dépôt d'anniversaires qui sert [initial] par utilisateur et enregistre
/// chaque écriture : les tests observent les effets sans faux notifier.
class RecordingBirthdayRepository extends FakeBirthdayRepository {
  RecordingBirthdayRepository({this.initial = const [], this.failure});

  final List<Birthday> initial;

  /// Erreur levée par chaque écriture quand elle est définie.
  final Exception? failure;

  final watchedUids = <String>[];
  final created = <BirthdayDraft>[];
  final updated = <String>[];
  final deleted = <String>[];
  final erasedUids = <String>[];

  /// Vœux marqués puis annulés, dans l'ordre : (id, année).
  final wished = <(String, int)>[];
  final unwished = <(String, int)>[];

  @override
  Stream<List<Birthday>> watchBirthdays(String uid) {
    watchedUids.add(uid);
    return Stream.value(initial);
  }

  @override
  Future<void> markWished(String birthdayId, int year) async {
    _maybeFail();
    wished.add((birthdayId, year));
  }

  @override
  Future<void> unmarkWished(String birthdayId, int year) async {
    _maybeFail();
    unwished.add((birthdayId, year));
  }

  /// Ids des anniversaires créés un à un, dans l'ordre.
  final createdIds = <String>[];

  /// Rappels propres écrits, dans l'ordre : (id, rappels).
  final reminderUpdates = <(String, Set<ReminderLead>?)>[];

  @override
  Future<void> createBirthday(
    String uid,
    String birthdayId,
    BirthdayDraft draft,
  ) async {
    _maybeFail();
    createdIds.add(birthdayId);
    created.add(draft);
  }

  @override
  Future<void> updateReminders(
    String birthdayId,
    Set<ReminderLead>? reminders,
  ) async {
    _maybeFail();
    reminderUpdates.add((birthdayId, reminders));
  }

  /// Messages de vœu écrits, dans l'ordre : (id, message).
  final wishMessageUpdates = <(String, String?)>[];

  @override
  Future<void> updateWishMessage(String birthdayId, String? message) async {
    _maybeFail();
    wishMessageUpdates.add((birthdayId, message));
  }

  @override
  Future<void> createBirthdays(String uid, List<BirthdayDraft> drafts) async {
    _maybeFail();
    created.addAll(drafts);
  }

  @override
  Future<void> updateBirthday(
    String uid,
    String birthdayId,
    BirthdayDraft draft,
  ) async {
    _maybeFail();
    updated.add(birthdayId);
    created.add(draft);
  }

  @override
  Future<void> deleteBirthday(String birthdayId) async {
    _maybeFail();
    deleted.add(birthdayId);
  }

  @override
  Future<void> deleteAllUserBirthdays(String uid) async {
    _maybeFail();
    erasedUids.add(uid);
  }

  void _maybeFail() {
    if (failure case final failure?) throw failure;
  }
}

class FakeCategoryRepository extends Fake implements CategoryRepository {
  /// Ne publie jamais : les catégories restent en chargement.
  @override
  Stream<List<BirthdayCategory>> watchCategories() => Stream.multi((_) {});

  /// Ne publie jamais : les groupes privés restent en chargement.
  @override
  Stream<List<BirthdayCategory>> watchOwnCategories(String uid) =>
      Stream.multi((_) {});

  @override
  String newCategoryId() => 'new-cat-id';

  @override
  Future<void> createCategory(String uid, BirthdayCategory category) async {}

  @override
  Future<void> updateCategory(String uid, BirthdayCategory category) async {}

  @override
  Future<void> deleteCategory(
    String uid,
    String categoryId, {
    Iterable<String> carriers = const [],
  }) async {}

  @override
  Future<void> deleteAllUserCategories(String uid) async {}
}

/// Dépôt de catégories qui sert les partagées [categories] (ou [watchError])
/// et les groupes privés [own], et enregistre les créations avec des ids
/// locaux prévisibles (`new-cat-1`, `new-cat-2`…). [watchOwnCategories]
/// reflète chaque création, comme le cache local de Firestore.
class RecordingCategoryRepository extends Fake implements CategoryRepository {
  RecordingCategoryRepository(
    this.categories, {
    this.watchError,
    List<BirthdayCategory> own = const [],
    this.failure,
  }) : _own = [...own];

  final List<BirthdayCategory> categories;

  /// Erreur émise par [watchCategories] à la place des catégories.
  final Exception? watchError;

  /// Erreur levée par chaque écriture quand elle est définie.
  final Exception? failure;

  final List<BirthdayCategory> _own;
  final _changes = StreamController<List<BirthdayCategory>>.broadcast();

  final created = <BirthdayCategory>[];
  final createdFor = <String>[];
  final erasedUids = <String>[];
  var _lastId = 0;

  @override
  Stream<List<BirthdayCategory>> watchCategories() => switch (watchError) {
    final error? => Stream.error(error),
    null => Stream.value(categories),
  };

  @override
  Stream<List<BirthdayCategory>> watchOwnCategories(String uid) {
    // Abonnement immédiat : aucune création n'est perdue entre deux émissions.
    final controller = StreamController<List<BirthdayCategory>>();
    final changes = _changes.stream.listen(controller.add);
    controller
      ..onCancel = () async {
        await changes.cancel();
        await controller.close();
      }
      ..add([..._own]);
    return controller.stream;
  }

  @override
  String newCategoryId() => 'new-cat-${++_lastId}';

  @override
  Future<void> createCategory(String uid, BirthdayCategory category) async {
    created.add(category);
    createdFor.add(uid);
    // Comme Firestore : le cache local montre le groupe avant l'accusé.
    _own.add(category);
    _changes.add([..._own]);
    if (failure case final error?) throw error;
  }

  /// Groupes modifiés puis supprimés, dans l'ordre.
  final edited = <BirthdayCategory>[];
  final deleted = <String>[];

  /// Anniversaires dont chaque groupe supprimé a été retiré : id du groupe →
  /// ids des anniversaires.
  final deletedCarriers = <String, List<String>>{};

  @override
  Future<void> updateCategory(String uid, BirthdayCategory category) async {
    edited.add(category);
    _own[_own.indexWhere((group) => group.id == category.id)] = category;
    _changes.add([..._own]);
    if (failure case final error?) throw error;
  }

  @override
  Future<void> deleteCategory(
    String uid,
    String categoryId, {
    Iterable<String> carriers = const [],
  }) async {
    // Une suppression refusée laisse le groupe en place.
    if (failure case final error?) throw error;
    deleted.add(categoryId);
    deletedCarriers[categoryId] = carriers.toList();
    _own.removeWhere((group) => group.id == categoryId);
    _changes.add([..._own]);
  }

  @override
  Future<void> deleteAllUserCategories(String uid) async {
    if (failure case final error?) throw error;
    erasedUids.add(uid);
  }
}

/// Étagère vide, écritures ignorées.
class FakeBookshelfRepository extends Fake implements BookshelfRepository {
  @override
  Stream<List<Series>> watchSeries(String uid) => Stream.value(const []);

  @override
  Stream<List<Volume>> watchVolumes(String uid) => Stream.value(const []);

  @override
  Stream<bool> watchFromCache(String uid) => Stream.value(false);

  @override
  Future<List<LegacyBook>> fetchLegacyBooks(String uid) async => const [];

  @override
  Future<void> deleteAllUserData(String uid) async {}
}

/// Étagère gardée en mémoire qui enregistre les écritures ; ses flux
/// reflètent les écritures, comme le cache de Firestore.
class RecordingBookshelfRepository extends FakeBookshelfRepository {
  RecordingBookshelfRepository({
    List<Series> series = const [],
    List<Volume> volumes = const [],
    this.legacyBooks = const [],
    this.failure,
  }) : _series = {for (final s in series) s.id: s},
       _volumes = {for (final v in volumes) v.id: v};

  final Map<String, Series> _series;
  final Map<String, Volume> _volumes;

  /// Anciens livres servis par [fetchLegacyBooks].
  final List<LegacyBook> legacyBooks;

  /// Erreur levée par chaque écriture quand elle est définie.
  final Exception? failure;

  final _changes = StreamController<void>.broadcast();
  var _nextId = 0;

  /// Tomes écrits par [saveScannedVolume], dans l'ordre.
  final savedVolumes = <Volume>[];
  final createdSeries = <Series>[];
  final erasedUids = <String>[];
  final importedPlans = <LegacyImportPlan>[];

  List<Series> get series => [..._series.values];
  List<Volume> get volumes => [..._volumes.values];

  Stream<T> _watch<T>(T Function() read) {
    final controller = StreamController<T>();
    final changes = _changes.stream.listen((_) => controller.add(read()));
    controller
      ..onCancel = () async {
        await changes.cancel();
        await controller.close();
      }
      ..add(read());
    return controller.stream;
  }

  Future<void> _write(void Function() apply) async {
    if (failure case final error?) throw error;
    apply();
    _changes.add(null);
  }

  final _fromCache = StreamController<bool>.broadcast();
  var _offline = false;

  /// Simule la perte ([value] vrai) ou le retour du réseau : [watchFromCache]
  /// le dit aussitôt.
  set offline(bool value) {
    _offline = value;
    _fromCache.add(value);
  }

  @override
  Stream<bool> watchFromCache(String uid) async* {
    yield _offline;
    yield* _fromCache.stream;
  }

  @override
  Stream<List<Series>> watchSeries(String uid) => _watch(() => series);

  @override
  Stream<List<Volume>> watchVolumes(String uid) => _watch(() => volumes);

  @override
  Future<ShelfContents> fetchShelf(String uid) async =>
      (series: series, volumes: volumes);

  @override
  Future<List<LegacyBook>> fetchLegacyBooks(String uid) async => legacyBooks;

  @override
  String newSeriesId(String uid) => 'series-${_nextId++}';

  @override
  Future<void> saveScannedVolume(
    String uid,
    Volume volume, {
    ({Series series, DateTime createdAt})? withSeries,
  }) => _write(() {
    if (withSeries case (:final series, createdAt: _)) {
      createdSeries.add(series);
      _series[series.id] = series;
    }
    savedVolumes.add(volume);
    _volumes[volume.id] = volume;
  });

  @override
  Future<void> createSeries(
    String uid,
    Series series, {
    required DateTime createdAt,
  }) => _write(() {
    createdSeries.add(series);
    _series[series.id] = series;
  });

  @override
  Future<void> classifyVolume(
    String uid,
    String volumeId, {
    required String? seriesId,
    required int? number,
  }) => _write(() {
    final volume = _volumes[volumeId]!;
    _volumes[volumeId] = Volume(
      id: volume.id,
      seriesId: seriesId,
      number: number,
      isbn: volume.isbn,
      title: volume.title,
      authors: volume.authors,
      imageUrl: volume.imageUrl,
      publisher: volume.publisher,
      publishedDate: volume.publishedDate,
      lookup: volume.lookup,
      addedAt: volume.addedAt,
    );
  });

  @override
  Future<void> deleteVolume(String uid, String volumeId) =>
      _write(() => _volumes.remove(volumeId));

  @override
  String newVolumeId(String uid) => 'volume-${_nextId++}';

  @override
  Future<void> addManualVolumes(
    String uid,
    List<Volume> volumes, {
    ({Series series, DateTime createdAt})? withSeries,
    String? completeSeriesId,
  }) => _write(() {
    if (withSeries case (:final series, createdAt: _)) {
      createdSeries.add(series);
      _series[series.id] = series;
    }
    for (final volume in volumes) {
      _volumes[volume.id] = volume;
    }
    if (completeSeriesId != null) {
      final series = _series[completeSeriesId]!;
      _series[completeSeriesId] = Series(
        id: series.id,
        name: series.name,
        keys: series.keys,
        complete: true,
        next: series.next,
      );
    }
  });

  @override
  Future<void> deleteSeries(String uid, String seriesId) => _write(() {
    // Comme Firestore : les tomes rangés partent, ceux sans numéro valable
    // sont détachés.
    for (final volume in volumes.where((v) => v.seriesId == seriesId)) {
      final number = volume.number;
      if (number != null && number >= 1 && number <= maxVolumeNumber) {
        _volumes.remove(volume.id);
      } else {
        _volumes[volume.id] = Volume(
          id: volume.id,
          isbn: volume.isbn,
          title: volume.title,
          authors: volume.authors,
          imageUrl: volume.imageUrl,
          publisher: volume.publisher,
          publishedDate: volume.publishedDate,
          lookup: volume.lookup,
          addedAt: volume.addedAt,
        );
      }
    }
    _series.remove(seriesId);
  });

  @override
  Future<void> renameSeries(
    String uid,
    String seriesId, {
    required String name,
    required String key,
  }) => _write(() {
    final series = _series[seriesId]!;
    _series[seriesId] = Series(
      id: seriesId,
      name: name,
      keys: {...series.keys, key}.toList(),
      complete: series.complete,
      next: series.next,
    );
  });

  @override
  Future<void> mergeSeries(
    String uid, {
    required String sourceId,
    required String targetId,
    required List<String> keys,
  }) => _write(() {
    for (final volume in volumes.where((v) => v.seriesId == sourceId)) {
      _volumes[volume.id] = Volume(
        id: volume.id,
        seriesId: targetId,
        number: volume.number,
        isbn: volume.isbn,
        title: volume.title,
        authors: volume.authors,
        imageUrl: volume.imageUrl,
        publisher: volume.publisher,
        publishedDate: volume.publishedDate,
        lookup: volume.lookup,
        addedAt: volume.addedAt,
      );
    }
    final target = _series[targetId]!;
    _series[targetId] = Series(
      id: targetId,
      name: target.name,
      keys: {...target.keys, ...keys}.toList(),
      complete: target.complete,
      next: target.next,
    );
    _series.remove(sourceId);
  });

  @override
  Future<void> setSeriesComplete(
    String uid,
    String seriesId, {
    required bool complete,
  }) => _write(() {
    final series = _series[seriesId]!;
    _series[seriesId] = Series(
      id: seriesId,
      name: series.name,
      keys: series.keys,
      complete: complete,
      next: series.next,
    );
  });

  @override
  Future<void> setNextVolume(
    String uid,
    String seriesId,
    NextVolumeInfo? next,
  ) => _write(() {
    final series = _series[seriesId]!;
    _series[seriesId] = Series(
      id: seriesId,
      name: series.name,
      keys: series.keys,
      complete: series.complete,
      next: next,
    );
  });

  @override
  Future<void> applyLegacyImport(
    String uid,
    LegacyImportPlan plan, {
    required DateTime importedAt,
  }) => _write(() {
    importedPlans.add(plan);
    for (final entry in plan.entries) {
      if (entry.newSeries case final series?) _series[series.id] = series;
      if (entry.volume case final volume?) _volumes[volume.id] = volume;
    }
  });

  @override
  Future<void> deleteAllUserData(String uid) async {
    if (failure case final error?) throw error;
    erasedUids.add(uid);
  }
}

/// Recherche de livres configurable : [found] pour tout ISBN, ou [failure]
/// levée ; compte les recherches.
class RecordingVolumeLookup extends Fake implements VolumeLookup {
  RecordingVolumeLookup({this.found, this.failure});

  /// Identifie l'ISBN demandé avec ces métadonnées ; null : livre inconnu.
  final IdentifiedVolume Function(String isbn)? found;
  final Exception? failure;

  final lookedUp = <String>[];

  @override
  Future<IdentifiedVolume?> lookUp(String isbn) async {
    lookedUp.add(isbn);
    if (failure case final error?) throw error;
    return found?.call(isbn);
  }
}

// --- Notifiers ---

/// Dépôt d'authentification en mémoire. La session suit les appels
/// (connexions, déconnexion, suppression) et [userChanges] la diffuse, comme
/// Firebase. [failure] fait échouer les connexions et la liaison,
/// [deleteFailure] la suppression, [tokenCheckFailure] la vérification du
/// jeton d'empreinte, [resetFailure] l'envoi du lien du mot de passe oublié.
class FakeAuthRepository extends Fake implements AuthRepository {
  FakeAuthRepository({
    this._user,
    this.failure,
    this.deleteFailure,
    this.reauthFailure,
    this.reauthGate,
    this.tokenCheckFailure,
    this.resetFailure,
  });

  firebase_auth.User? _user;

  /// Refus des connexions et de la liaison ; un test peut le changer en cours.
  Exception? failure;
  final Exception? deleteFailure;

  /// Refus de la confirmation d'identité, quand il est défini.
  final Exception? reauthFailure;

  /// Confirmation d'identité en attente tant qu'il n'est pas complété.
  final Completer<void>? reauthGate;
  final Exception? tokenCheckFailure;
  final Exception? resetFailure;

  /// Méthodes appelées, dans l'ordre.
  final calls = <String>[];

  /// Liens du mot de passe oublié envoyés : (adresse, langue de l'e-mail).
  final passwordResets = <(String, String)>[];

  @override
  Future<void> sendPasswordReset(
    String email, {
    required String languageCode,
  }) async {
    calls.add('sendPasswordReset');
    if (resetFailure case final error?) throw error;
    passwordResets.add((email, languageCode));
  }

  /// Jetons d'empreinte enregistrés sur les profils, par uid.
  final biometricTokens = <String, String?>{};

  final _changes = StreamController<firebase_auth.User?>.broadcast();

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Stream<firebase_auth.User?> userChanges() {
    // Abonnement immédiat : aucun changement n'est perdu entre deux émissions.
    final controller = StreamController<firebase_auth.User?>();
    final changes = _changes.stream.listen(controller.add);
    controller
      ..onCancel = () async {
        await changes.cancel();
        await controller.close();
      }
      ..add(_user);
    return controller.stream;
  }

  @override
  Future<firebase_auth.User?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) => _signIn('signUp', MockUser());

  @override
  Future<firebase_auth.User?> signInWithEmail({
    required String email,
    required String password,
  }) => _signIn('signInWithEmail', MockUser());

  @override
  Future<firebase_auth.User?> signInWithGoogle() =>
      _signIn('signInWithGoogle', MockUser());

  @override
  Future<firebase_auth.User?> signInAnonymously() =>
      _signIn('signInAnonymously', MockUser(isAnonymous: true));

  /// Compte Google déjà connu d'AnKi qu'ouvre [signInWithGoogleAccount].
  static const googleUid = 'google-uid';
  static const googleEmail = 'lea@gmail.com';

  /// Refus de [signInWithGoogleAccount], quand il est défini.
  Exception? googleAccountFailure;

  /// Comme Firebase : [prepare] reçoit l'adresse du compte pendant que la
  /// session courante est encore ouverte ; s'il renvoie false, rien ne
  /// s'ouvre.
  @override
  Future<firebase_auth.User?> signInWithGoogleAccount(
    Future<bool> Function(String email) prepare,
  ) async {
    calls.add('signInWithGoogleAccount');
    if (googleAccountFailure case final error?) throw error;
    if (!await prepare(googleEmail)) return null;
    final user = MockUser(uid: googleUid);
    _emit(user);
    return user;
  }

  /// Comme Firebase : le compte lié garde l'uid de l'invité.
  @override
  Future<firebase_auth.User?> linkCurrentUserWithGoogle() => _signIn(
    'linkCurrentUserWithGoogle',
    MockUser(uid: _user?.uid ?? 'fake-uid'),
  );

  @override
  Future<void> signOutFirebase() async {
    calls.add('signOutFirebase');
    _emit(null);
  }

  @override
  Future<void> signOutGoogle() async => calls.add('signOutGoogle');

  /// Mots de passe donnés pour confirmer l'identité, dans l'ordre.
  final reauthPasswords = <String>[];

  @override
  Future<void> reauthenticateWithGoogle() async {
    calls.add('reauthenticateWithGoogle');
    await reauthGate?.future;
    if (reauthFailure case final error?) throw error;
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    calls.add('reauthenticateWithPassword');
    reauthPasswords.add(password);
    await reauthGate?.future;
    if (reauthFailure case final error?) throw error;
  }

  @override
  Future<void> deleteCurrentUser() async {
    calls.add('deleteCurrentUser');
    if (deleteFailure case final error?) throw error;
    _emit(null);
  }

  /// Comme les règles Firestore : seul le compte connecté écrit son profil.
  @override
  Future<void> setBiometricToken(String uid, String? token) async {
    if (_user?.uid != uid) throw Exception('permission-denied');
    biometricTokens[uid] = token;
  }

  @override
  Future<bool> isBiometricTokenValid(String uid, String token) async {
    if (tokenCheckFailure case final error?) throw error;
    return biometricTokens[uid] == token;
  }

  Future<firebase_auth.User?> _signIn(
    String call,
    firebase_auth.User user,
  ) async {
    calls.add(call);
    if (failure case final error?) throw error;
    _emit(user);
    return user;
  }

  void _emit(firebase_auth.User? user) {
    _user = user;
    _changes.add(user);
  }
}

/// Feuille de partage simulée : renvoie [outcome], ou l'issue que le test
/// donne à [pending] (feuille restée ouverte), et relève les textes partagés.
class FakeShareService extends Fake implements ShareService {
  FakeShareService({this.outcome = ShareOutcome.shared, this.error});

  ShareOutcome outcome;

  /// Erreur levée à l'ouverture quand elle est définie.
  final Exception? error;

  /// Feuille ouverte jusqu'à ce que le test complète ce `Completer`.
  Completer<ShareOutcome>? pending;

  final shared = <String>[];

  @override
  Future<ShareOutcome> shareText(String text, {Rect? origin}) async {
    shared.add(text);
    if (error case final error?) throw error;
    return pending?.future ?? outcome;
  }
}

/// Service biométrique en mémoire : capteur [available] ou non, jeton et
/// compte enregistrés sur l'appareil, empreinte acceptée si [authenticates].
class FakeBiometricService extends Fake implements BiometricService {
  FakeBiometricService({
    this.available = false,
    this.token,
    this.userId,
    this.authenticates = true,
  });

  bool available;
  String? token;
  String? userId;
  bool authenticates;

  @override
  Future<bool> canUseFingerprint() async => available;

  /// Texte de la dernière invite d'empreinte.
  String? lastReason;

  @override
  Future<bool> authenticate({required String reason}) async {
    lastReason = reason;
    return authenticates;
  }

  @override
  String generateToken() => 'generated-token';

  @override
  Future<void> saveBiometricData(String userId, String token) async {
    this.userId = userId;
    this.token = token;
  }

  @override
  Future<String?> getStoredToken() async => token;

  @override
  Future<String?> getStoredUserId() async => userId;

  @override
  Future<void> clearBiometricData() async {
    token = null;
    userId = null;
  }
}

/// Réglages de l'appareil en mémoire : la carte « Rappels désactivés »
/// masquée ou non ([remindersOffDismissedValue]) ; [failure] fait échouer
/// l'enregistrement. Relève les masquages.
class FakeDeviceSettings extends Fake implements DeviceSettings {
  FakeDeviceSettings({this.remindersOffDismissedValue = false, this.failure});

  bool remindersOffDismissedValue;
  final Exception? failure;
  int dismissals = 0;

  @override
  Future<bool> remindersOffDismissed() async => remindersOffDismissedValue;

  @override
  Future<void> dismissRemindersOff() async {
    dismissals++;
    if (failure case final error?) throw error;
    remindersOffDismissedValue = true;
  }
}

/// Répertoire simulé : l'accès [access], les anniversaires [contacts], ou
/// [failure] à la lecture ; [accessFailure] fait échouer la relecture de
/// l'accès. Relève les demandes d'accès, les lectures et les ouvertures des
/// réglages ; [pendingRead] fait attendre la lecture.
class FakeContactsService extends Fake implements ContactsService {
  FakeContactsService({
    this.access = ContactsAccess.granted,
    this.contacts = const [],
    this.failure,
  });

  ContactsAccess access;
  List<ImportedBirthday> contacts;
  final Exception? failure;
  Exception? accessFailure;
  Completer<void>? pendingRead;

  int requests = 0;
  int reads = 0;
  int settingsOpened = 0;

  @override
  Future<ContactsAccess> requestReadAccess() async {
    requests++;
    return access;
  }

  @override
  Future<ContactsAccess> readAccess() async {
    if (accessFailure case final error?) throw error;
    return access;
  }

  @override
  Future<void> openAppSettings() async => settingsOpened++;

  @override
  Future<List<ImportedBirthday>> fetchBirthdays() async {
    reads++;
    await pendingRead?.future;
    if (failure case final error?) throw error;
    return contacts;
  }
}

/// Overrides du harnais : dépôts factices, personne de connecté, pas
/// d'empreinte. Une nouvelle liste (et de nouveaux faux) à chaque lecture.
List<Object> get defaultTestOverrides => [
  userRepositoryProvider.overrideWithValue(FakeUserRepository()),
  birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
  categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
  bookshelfRepositoryProvider.overrideWithValue(FakeBookshelfRepository()),
  authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  biometricServiceProvider.overrideWithValue(FakeBiometricService()),
  shareServiceProvider.overrideWithValue(FakeShareService()),
];

/// Réglage des rappels gardé en mémoire : chaque enregistrement est émis
/// aussitôt, comme le cache de Firestore.
class RecordingReminderPreferencesRepository extends Fake
    implements ReminderPreferencesRepository {
  RecordingReminderPreferencesRepository({
    this._stored = const ReminderPreferences(),
    this.failure,
  });

  ReminderPreferences _stored;

  /// Erreur levée par chaque écriture quand elle est définie.
  final Exception? failure;

  final _changes = StreamController<ReminderPreferences>.broadcast();
  final saved = <ReminderPreferences>[];

  ReminderPreferences get stored => _stored;

  @override
  Stream<ReminderPreferences> watchPreferences(String uid) {
    final controller = StreamController<ReminderPreferences>();
    final changes = _changes.stream.listen(controller.add);
    controller
      ..onCancel = () async {
        await changes.cancel();
        await controller.close();
      }
      ..add(_stored);
    return controller.stream;
  }

  @override
  Future<void> savePreferences(
    String uid,
    ReminderPreferences preferences,
  ) async {
    if (failure case final failure?) throw failure;
    saved.add(preferences);
    _stored = preferences;
    _changes.add(preferences);
  }
}

/// Catalogue BnF dont les recherches de tome ([searchVolume]) répondent par
/// (série, numéro) ; il retient chaque question.
class RecordingBnfCatalog extends Fake implements BnfCatalog {
  RecordingBnfCatalog([this.answers = const {}]);

  /// Notices rendues pour (nom de série, numéro) ; aucune sinon.
  final Map<(String, int), List<BookMetadata>> answers;

  /// Les recherches reçues, dans l'ordre.
  final asked = <(String, int)>[];

  /// Levé par chaque recherche quand il est défini.
  BookFailure? failure;

  /// Retient chaque réponse jusqu'à ce qu'il se termine.
  Future<void>? gate;

  @override
  Future<List<BookMetadata>> searchVolume(String seriesName, int number) async {
    asked.add((seriesName, number));
    if (gate case final gate?) await gate;
    if (failure case final failure?) throw failure;
    return answers[(seriesName, number)] ?? const [];
  }
}

/// Catalogue Google Books dont les recherches de tome ([searchVolume])
/// répondent par (série, numéro) ; il retient chaque question.
class RecordingGoogleBooksCatalog extends Fake implements GoogleBooksCatalog {
  RecordingGoogleBooksCatalog([this.answers = const {}]);

  /// Volumes rendus pour (nom de série, numéro) ; aucun sinon.
  final Map<(String, int), List<BookMetadata>> answers;

  /// Les recherches reçues, dans l'ordre.
  final asked = <(String, int)>[];

  /// Levé par chaque recherche quand il est défini.
  BookFailure? failure;

  /// Retient chaque réponse jusqu'à ce qu'il se termine.
  Future<void>? gate;

  @override
  Future<List<BookMetadata>> searchVolume(String seriesName, int number) async {
    asked.add((seriesName, number));
    if (gate case final gate?) await gate;
    if (failure case final failure?) throw failure;
    return answers[(seriesName, number)] ?? const [];
  }
}
