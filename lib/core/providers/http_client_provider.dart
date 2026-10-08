import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Client HTTP partagé, fermé avec le conteneur.
///
/// Les tests le remplacent par un `MockClient` (`package:http/testing.dart`)
/// avec `overrideWithValue`.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});
