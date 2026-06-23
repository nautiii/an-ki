import 'package:an_ki/features/user/data/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserRepository {
  final FirebaseFirestore? _firestoreOverride;

  UserRepository({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('user');

  Future<UserModel?> fetchUser(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _users.doc(uid).get();

    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  /// Crée le document utilisateur **uniquement s'il n'existe pas déjà**.
  ///
  /// S'exécute dans une transaction afin qu'une lecture amont échouée/obsolète
  /// ne puisse jamais écraser un profil existant (pseudo, token biométrique,
  /// catégories...). Un crash pendant la connexion ne doit jamais détruire de données.
  ///
  /// Renvoie l'utilisateur effectif : le document déjà stocké s'il est présent,
  /// sinon le [user] fraîchement créé.
  Future<UserModel> createUser(UserModel user) async {
    final DocumentReference<Map<String, dynamic>> docRef = _users.doc(user.id);

    return _firestore.runTransaction<UserModel>((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(docRef);

      if (snapshot.exists) {
        return UserModel.fromFirestore(snapshot);
      }

      transaction.set(docRef, user.toJson());
      return user;
    });
  }

  Future<void> updateUser(UserModel user) async {
    await _users.doc(user.id).update(user.toJson());
  }

  Future<void> deleteUser(String uid) async {
    await _users.doc(uid).delete();
  }
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);
