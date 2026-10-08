import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Instances Firebase de l'application, injectées dans les repositories.
///
/// Les tests les remplacent par des fakes (`FakeFirebaseFirestore`,
/// `MockFirebaseAuth`) avec `overrideWithValue` : aucun repository ne lit
/// `FirebaseFirestore.instance` lui-même.
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);
