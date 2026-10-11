import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source de vérité du profil : `user/{uid}` dans Firestore.
///
/// Convertit document ↔ [UserProfile]. Ni logique métier, ni texte d'UI, ni état.
class UserRepository {
  UserRepository({required this._firestore});

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('user');

  /// Profil de [uid] en temps réel ; null tant que le document n'existe pas
  /// (premier lancement d'un compte).
  Stream<UserProfile?> watchUser(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? _userFromDoc(doc) : null);

  /// Crée le document utilisateur **uniquement s'il n'existe pas déjà**.
  ///
  /// S'exécute dans une transaction afin qu'une lecture amont échouée/obsolète
  /// ne puisse jamais écraser un profil existant (pseudo, token biométrique,
  /// catégories...). Un crash pendant la connexion ne doit jamais détruire de données.
  ///
  /// Renvoie l'utilisateur effectif : le document déjà stocké s'il est présent,
  /// sinon le [user] fraîchement créé.
  Future<UserProfile> createUser(UserProfile user) async {
    final DocumentReference<Map<String, dynamic>> docRef = _users.doc(user.id);

    return _firestore.runTransaction<UserProfile>((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(docRef);

      if (snapshot.exists) {
        return _userFromDoc(snapshot);
      }

      transaction.set(docRef, _userToMap(user));
      return user;
    });
  }

  /// Met à jour les préférences données, champ par champ : deux modifications
  /// rapprochées (thème puis langue) ne s'écrasent pas, contrairement à une
  /// réécriture du profil entier lu un instant plus tôt.
  Future<void> updatePreferences(
    String uid, {
    String? pseudo,
    bool? isDark,
    String? locale,
  }) => _users.doc(uid).update({
    'pseudo': ?pseudo,
    'isDark': ?isDark,
    'locale': ?locale,
  });

  /// Ajoute des catégories au profil sans doublon (union côté Firestore).
  Future<void> addCategories(String uid, List<String> categoryIds) => _users
      .doc(uid)
      .update({'categories': FieldValue.arrayUnion(categoryIds)});

  Future<void> deleteUser(String uid) async {
    await _users.doc(uid).delete();
  }
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(firestore: ref.watch(firestoreProvider)),
);

// Conversion Firestore ↔ domaine : privée au data layer. Lecture tolérante
// (champ absent → valeur par défaut) pour survivre aux anciens documents.
UserProfile _userFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return UserProfile(
    id: doc.id,
    name: data['name'] as String? ?? '',
    surname: data['surname'] as String? ?? '',
    pseudo: data['pseudo'] as String?,
    categories: List<String>.from(
      data['categories'] as List<dynamic>? ?? const [],
    ),
    isDark: data['isDark'] as bool? ?? false,
    locale: data['locale'] as String? ?? 'fr',
    biometricToken: data['biometricToken'] as String?,
  );
}

Map<String, Object> _userToMap(UserProfile user) => {
  'name': user.name,
  'surname': user.surname,
  'pseudo': ?user.pseudo,
  'categories': user.categories,
  'isDark': user.isDark,
  'locale': user.locale,
  'biometricToken': ?user.biometricToken,
};
