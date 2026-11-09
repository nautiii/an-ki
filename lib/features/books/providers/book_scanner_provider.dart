import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tomes du carrousel du scanner : toute l'étagère, le plus récent d'abord.
final scannedVolumesProvider = Provider.autoDispose<AsyncValue<List<Volume>>>(
  (ref) => ref.watch(shelfProvider).whenData(volumesByRecency),
);
