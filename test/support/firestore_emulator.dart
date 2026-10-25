import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Client REST minimal de l'émulateur Firestore, pour éprouver
/// `firestore.rules` comme le ferait l'app.
///
/// Seul l'émulateur évalue fidèlement les règles : `FakeFirebaseFirestore`
/// ignore `resource` et `request.resource`, sur lesquels reposent celles
/// d'AnKi. `firebase emulators:exec` (script `scripts/test_firestore_rules.ps1`)
/// annonce l'émulateur dans `FIRESTORE_EMULATOR_HOST` ; sans lui, les tests de
/// règles sont ignorés.
///
/// Chaque requête part au nom d'un uid (jeton non signé, que l'émulateur
/// accepte) ou de personne (`null`) ; [seed] contourne les règles pour poser
/// les données de départ.
class FirestoreEmulator {
  FirestoreEmulator._(this._host, this._projectId);

  /// Projet de démonstration : l'émulateur ne parle jamais à la production.
  static const demoProjectId = 'demo-anki';

  /// L'émulateur lancé par `firebase emulators:exec`, null en dehors.
  static FirestoreEmulator? fromEnvironment() {
    final host = Platform.environment['FIRESTORE_EMULATOR_HOST'];
    if (host == null || host.isEmpty) return null;
    return FirestoreEmulator._(host, demoProjectId);
  }

  final String _host;
  final String _projectId;
  final http.Client _client = http.Client();

  String get _database =>
      'http://$_host/v1/projects/$_projectId/databases/(default)/documents';

  void close() => _client.close();

  /// Efface toutes les données de l'émulateur : chaque test part de zéro.
  Future<void> clear() async {
    final response = await _client.delete(
      Uri.parse(
        'http://$_host/emulator/v1/projects/$_projectId/databases/(default)/documents',
      ),
    );
    _expectSuccess(response);
  }

  /// Écrit [data] en [path] sans passer par les règles (données de départ).
  Future<void> seed(String path, Map<String, Object?> data) async {
    final response = await _client.patch(
      Uri.parse('$_database/$path'),
      headers: _headers(null, admin: true),
      body: jsonEncode({'fields': _encodeFields(data)}),
    );
    _expectSuccess(response);
  }

  /// `get` d'un document ; un document absent mais permis compte comme permis.
  Future<bool> canGet(String? uid, String path) async {
    final response = await _client.get(
      Uri.parse('$_database/$path'),
      headers: _headers(uid),
    );
    return _decision(response, absentIsAllowed: true);
  }

  /// Création d'un nouveau document (`add`, `doc().set` sur un id neuf).
  Future<bool> canCreate(
    String? uid,
    String path,
    Map<String, Object?> data,
  ) async {
    final slash = path.lastIndexOf('/');
    final response = await _client.post(
      Uri.parse('$_database/${path.substring(0, slash)}')
          .replace(queryParameters: {'documentId': path.substring(slash + 1)}),
      headers: _headers(uid),
      body: jsonEncode({'fields': _encodeFields(data)}),
    );
    return _decision(response);
  }

  /// `update` des seuls champs de [data] sur un document existant, comme
  /// `DocumentReference.update` : les règles voient le document fusionné.
  Future<bool> canUpdate(
    String? uid,
    String path,
    Map<String, Object?> data,
  ) async {
    final response = await _client.patch(
      Uri.parse('$_database/$path').replace(
        queryParameters: {
          'updateMask.fieldPaths': data.keys.toList(),
          'currentDocument.exists': 'true',
        },
      ),
      headers: _headers(uid),
      body: jsonEncode({'fields': _encodeFields(data)}),
    );
    return _decision(response);
  }

  /// `set(data, SetOptions(merge: true))` : crée ou complète le document.
  Future<bool> canMerge(
    String? uid,
    String path,
    Map<String, Object?> data,
  ) async {
    final response = await _client.patch(
      Uri.parse(
        '$_database/$path',
      ).replace(queryParameters: {'updateMask.fieldPaths': data.keys.toList()}),
      headers: _headers(uid),
      body: jsonEncode({'fields': _encodeFields(data)}),
    );
    return _decision(response);
  }

  Future<bool> canDelete(String? uid, String path) async {
    final response = await _client.delete(
      Uri.parse('$_database/$path'),
      headers: _headers(uid),
    );
    return _decision(response);
  }

  /// Requête sur la collection [collectionPath] (`birthday`,
  /// `user/alice/categories`), filtrée par `field == value` si donnés, triée
  /// par [orderByDescending]. Les règles ne filtrent pas : une requête qui
  /// pourrait rendre un document interdit est refusée entière.
  Future<bool> canQuery(
    String? uid,
    String collectionPath, {
    String? whereField,
    Object? isEqualTo,
    String? orderByDescending,
  }) async {
    final slash = collectionPath.lastIndexOf('/');
    final parent = slash < 0 ? '' : '/${collectionPath.substring(0, slash)}';
    final response = await _client.post(
      Uri.parse('$_database$parent:runQuery'),
      headers: _headers(uid),
      body: jsonEncode({
        'structuredQuery': {
          'from': [
            {'collectionId': collectionPath.substring(slash + 1)},
          ],
          if (whereField != null)
            'where': {
              'fieldFilter': {
                'field': {'fieldPath': whereField},
                'op': 'EQUAL',
                'value': _encodeValue(isEqualTo),
              },
            },
          if (orderByDescending != null)
            'orderBy': [
              {
                'field': {'fieldPath': orderByDescending},
                'direction': 'DESCENDING',
              },
            ],
        },
      }),
    );
    return _decision(response);
  }

  /// En-têtes d'une requête de [uid] (null : personne n'est connecté) ;
  /// [admin] prend le jeton `owner` de l'émulateur, qui contourne les règles.
  Map<String, String> _headers(String? uid, {bool admin = false}) => {
    'Content-Type': 'application/json',
    if (admin)
      'Authorization': 'Bearer owner'
    else if (uid != null)
      'Authorization': 'Bearer ${_userToken(uid)}',
  };

  /// Jeton d'identité Firebase non signé (`alg: none`) pour [uid] :
  /// l'émulateur l'accepte, la production jamais.
  String _userToken(String uid) {
    String part(Map<String, Object?> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    const issuedAt = 1700000000; // 2023-11-14
    const expiresAt = 4102444800; // 2100-01-01
    final header = {'alg': 'none', 'typ': 'JWT'};
    final claims = {
      'iss': 'https://securetoken.google.com/$_projectId',
      'aud': _projectId,
      'iat': issuedAt,
      'exp': expiresAt,
      'auth_time': issuedAt,
      'sub': uid,
      'user_id': uid,
      'firebase': {'sign_in_provider': 'custom'},
    };
    // Signature vide : le jeton finit par un point.
    return '${part(header)}.${part(claims)}.';
  }

  /// 200 : permis ; 403 : refusé par les règles. Toute autre réponse est une
  /// erreur du test (requête mal formée, document existant…), pas un refus.
  bool _decision(http.Response response, {bool absentIsAllowed = false}) {
    if (response.statusCode == HttpStatus.ok) return true;
    if (absentIsAllowed && response.statusCode == HttpStatus.notFound) {
      return true;
    }
    if (response.statusCode == HttpStatus.forbidden) return false;
    throw StateError(
      'Émulateur Firestore : HTTP ${response.statusCode} ${response.body}',
    );
  }

  void _expectSuccess(http.Response response) {
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(
        'Émulateur Firestore : HTTP ${response.statusCode} ${response.body}',
      );
    }
  }
}

/// Valeurs Dart → valeurs typées de l'API REST Firestore.
Map<String, Object?> _encodeFields(Map<String, Object?> data) => {
  for (final MapEntry(:key, :value) in data.entries) key: _encodeValue(value),
};

Map<String, Object?> _encodeValue(Object? value) => switch (value) {
  null => {'nullValue': null},
  final bool flag => {'booleanValue': flag},
  final int number => {'integerValue': '$number'},
  final double number => {'doubleValue': number},
  final String text => {'stringValue': text},
  final DateTime time => {'timestampValue': time.toUtc().toIso8601String()},
  final List<Object?> items => {
    'arrayValue': {'values': items.map(_encodeValue).toList()},
  },
  final Map<String, Object?> map => {
    'mapValue': {'fields': _encodeFields(map)},
  },
  _ => throw ArgumentError.value(value, 'value', 'type non pris en charge'),
};
