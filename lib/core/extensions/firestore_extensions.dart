import 'package:cloud_firestore/cloud_firestore.dart';

/// Écritures groupées au-delà de la limite Firestore d'opérations par lot.
extension BatchedWrites on FirebaseFirestore {
  /// Limite Firestore d'opérations par lot.
  static const batchLimit = 500;

  /// Applique [write] à chaque élément de [items], par lots d'au plus
  /// [batchLimit] opérations, tous envoyés d'un coup : Firestore les applique
  /// au cache local aussitôt, le Future attend l'accusé du serveur.
  Future<void> writeInBatches<T>(
    Iterable<T> items,
    void Function(WriteBatch batch, T item) write,
  ) {
    final list = items.toList();
    final commits = <Future<void>>[];
    for (var start = 0; start < list.length; start += batchLimit) {
      final batch = this.batch();
      for (final item in list.skip(start).take(batchLimit)) {
        write(batch, item);
      }
      commits.add(batch.commit());
    }
    return Future.wait(commits);
  }
}
