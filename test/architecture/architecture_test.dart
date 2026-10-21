// Test d'architecture : spécification exécutable des frontières du code.
//
// Lit les directives `import`/`export` de `lib/` et vérifie les règles de
// dépendance entre zones (`app/`, `core/`, `features/`) et entre les couches
// d'une feature (`domain/`, `data/`, `providers/`, `screens/`, `widgets/`).
// Règles et raisons : `.claude/skills/architecture/references/structure.md`.
//
// Quand modifier ce fichier :
// - nouvelle feature → la déclarer dans [featureDependencies] ;
// - dette résorbée → retirer sa ligne de [knownViolations] (le test l'exige) ;
// - jamais pour faire passer une nouvelle violation : corriger le code.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Features que chaque feature a le droit d'importer.
///
/// Le graphe doit rester acyclique. Une arête de plus se décide (voir le
/// skill), elle ne s'ajoute pas pour faire taire le test.
const featureDependencies = <String, Set<String>>{
  'auth': {},
  'user': {'auth'},
  'birthday': {'auth', 'user'},
  'book_scanner': {'auth', 'user'},
  'reminders': {'auth', 'birthday'},
  'settings': {'auth', 'user', 'birthday', 'book_scanner', 'reminders'},
};

/// Dossiers autorisés directement sous `lib/features/<feature>/`.
const featureLayers = {'domain', 'data', 'providers', 'screens', 'widgets'};

/// Dette connue : vide depuis le 2026-10-11 et elle doit le rester — une
/// nouvelle violation se corrige dans le code, jamais ici.
/// Format : `<fichier> -> <cible> [règle]`. Le test échoue aussi quand une
/// ligne ne correspond plus à rien : la retirer.
const knownViolations = <String>{};

/// Ce que chaque règle protège, et comment corriger.
const ruleHints = <String, String>{
  'core-isolation':
      'core/ ne dépend d\'aucune feature ni de app/ : déplacer le code dans la '
      'feature ou dans app/, ou faire mapper la feature vers un type de core.',
  'app-only':
      'seul main.dart importe app/ : une feature ou core ne connaît pas la '
      'composition de l\'application.',
  'feature-graph':
      'dépendance entre features non déclarée : orchestrer dans la feature qui '
      'dépend déjà des deux ou dans app/, composer par un slot, ou déclarer '
      'l\'arête (sans cycle) après accord.',
  'screens-private':
      'les écrans d\'une feature ne s\'importent pas d\'une autre : naviguer par '
      'les routes (core/routing, table dans app/router).',
  'repositories-isolated':
      'un repository ne connaît pas ceux des autres features : combiner les '
      'sources dans un provider.',
  'domain-purity':
      'domain/ est du Dart pur : ni Flutter UI, ni Firebase, ni Riverpod, ni '
      'plugin, ni l10n, ni autre couche.',
  'data-no-ui':
      'data/ ignore l\'UI et l\'état : pas de widgets, de providers d\'état, de '
      'thème ni de l10n.',
  'ui-no-backend':
      'screens/ et widgets/ passent par les providers : pas de data/ ni de SDK '
      'backend (Firebase, http, stockage sécurisé, plugins système).',
  'state-no-ui':
      'providers/ ne dépend ni des widgets ni de l10n : exposer un état ou un '
      'échec typé, l\'UI le traduit avec context.l10n.',
  'layout':
      'fichier hors des couches connues : le ranger dans domain/, data/, '
      'providers/, screens/ ou widgets/.',
};

/// Imports externes autorisés dans `domain/` (en plus des autres `domain/`).
final _domainExternalAllowed = <RegExp>[
  RegExp(r'^dart:(async|collection|convert|core|math|typed_data)$'),
  RegExp(r'^package:flutter/foundation\.dart$'),
  RegExp(r'^package:(meta|collection)/'),
];

/// SDK backend et plugins système interdits dans l'UI (passer par un provider).
final _backendPackages = RegExp(
  r'^package:(cloud_firestore|firebase_auth|firebase_core|firebase_storage|'
  r'google_sign_in|http|flutter_secure_storage|local_auth|flutter_contacts|'
  r'flutter_local_notifications|flutter_timezone|timezone)/',
);

/// Bibliothèques d'UI Flutter interdites dans `data/`.
final _flutterUi = RegExp(
  r'^package:flutter/(material|widgets|cupertino)\.dart$',
);

/// Dossiers de `core/` qui relèvent de l'UI (interdits à data/ et providers/).
final _coreUi = RegExp(r'^lib/core/(common|theme|animations)/');

void main() {
  final packageName = _readPackageName();

  test('feature graph is declared and acyclic', () {
    final featureDirs = Directory('lib/features')
        .listSync()
        .whereType<Directory>()
        .map((d) => _segments(d.path).last)
        .toSet();
    final declared = featureDependencies.keys.toSet();

    expect(
      featureDirs.difference(declared),
      isEmpty,
      reason: 'Déclarer ces features dans featureDependencies.',
    );
    expect(
      featureDependencies.values
          .expand((deps) => deps)
          .toSet()
          .difference(declared),
      isEmpty,
      reason: 'featureDependencies cite des features inexistantes.',
    );
    expect(_findCycle(featureDependencies), isNull);
  });

  test('imports respect layer and feature boundaries', () {
    final violations = <String>{};
    for (final file in _dartSources()) {
      final source = _Location.of(file);
      if (source.zone == _Zone.feature &&
          !featureLayers.contains(source.layer)) {
        violations.add('$file -> (emplacement) [layout]');
      }
      for (final uri in _directives(File(file).readAsStringSync())) {
        final target = _Location.resolve(uri, from: file, package: packageName);
        final rule = _check(source, target);
        if (rule != null) violations.add('$file -> ${target.label} [$rule]');
      }
    }

    final added = violations.difference(knownViolations);
    final fixed = knownViolations.difference(violations);
    expect(
      added.isEmpty && fixed.isEmpty,
      isTrue,
      reason: _report(added: added, fixed: fixed),
    );
  });
}

/// Règle enfreinte par l'import de [target] depuis [source], sinon null.
String? _check(_Location source, _Location target) {
  if (source.zone == _Zone.core &&
      (target.zone == _Zone.feature || target.zone == _Zone.app)) {
    return 'core-isolation';
  }
  if (source.zone != _Zone.app &&
      source.zone != _Zone.entrypoint &&
      (target.zone == _Zone.app || target.zone == _Zone.entrypoint)) {
    return 'app-only';
  }
  if (source.zone != _Zone.feature) return null;

  final layer = source.layer;
  if (target.zone == _Zone.feature && target.feature != source.feature) {
    final allowed = featureDependencies[source.feature] ?? const {};
    if (!allowed.contains(target.feature)) return 'feature-graph';
    if (target.layer == 'screens') return 'screens-private';
    if (layer == 'data' && target.layer == 'data') {
      return 'repositories-isolated';
    }
  }

  switch (layer) {
    case 'domain':
      if (target.zone == _Zone.external) {
        final ok = _domainExternalAllowed.any((r) => r.hasMatch(target.label));
        return ok ? null : 'domain-purity';
      }
      final ok = target.zone == _Zone.feature && target.layer == 'domain';
      return ok ? null : 'domain-purity';
    case 'data':
      if (_flutterUi.hasMatch(target.label) ||
          target.zone == _Zone.l10n ||
          _coreUi.hasMatch(target.label) ||
          const {'providers', 'screens', 'widgets'}.contains(target.layer)) {
        return 'data-no-ui';
      }
    case 'providers':
      if (target.zone == _Zone.l10n ||
          _coreUi.hasMatch(target.label) ||
          const {'screens', 'widgets'}.contains(target.layer)) {
        return 'state-no-ui';
      }
    case 'screens' || 'widgets':
      if (_backendPackages.hasMatch(target.label) || target.layer == 'data') {
        return 'ui-no-backend';
      }
  }
  return null;
}

enum _Zone { entrypoint, app, core, feature, l10n, other, external }

/// Position d'un fichier (ou d'une cible d'import) dans l'architecture.
class _Location {
  const _Location(this.zone, this.label, {this.feature, this.layer});

  /// Classe un chemin `lib/...` relatif à la racine du package.
  factory _Location.of(String path) {
    final parts = _segments(path);
    final label = parts.join('/');
    if (parts.length < 2 || parts.first != 'lib') {
      return _Location(_Zone.other, label);
    }
    if (parts.length == 2) {
      final isMain = parts[1] == 'main.dart';
      return _Location(isMain ? _Zone.entrypoint : _Zone.other, label);
    }
    return switch (parts[1]) {
      'app' => _Location(_Zone.app, label),
      'core' => _Location(_Zone.core, label),
      'l10n' => _Location(_Zone.l10n, label),
      'features' => _Location(
        _Zone.feature,
        label,
        feature: parts[2],
        layer: parts.length > 4 ? parts[3] : null,
      ),
      _ => _Location(_Zone.other, label),
    };
  }

  /// Résout une URI d'import en position (interne au package ou externe).
  factory _Location.resolve(
    String uri, {
    required String from,
    required String package,
  }) {
    final prefix = 'package:$package/';
    if (uri.startsWith(prefix)) {
      return _Location.of('lib/${uri.substring(prefix.length)}');
    }
    if (uri.startsWith('dart:') || uri.startsWith('package:')) {
      return _Location(_Zone.external, uri);
    }
    final path = _segments(from)..removeLast();
    for (final part in uri.split('/')) {
      if (part == '..') {
        path.removeLast();
      } else if (part != '.') {
        path.add(part);
      }
    }
    return _Location.of(path.join('/'));
  }

  final _Zone zone;
  final String label;
  final String? feature;
  final String? layer;
}

/// Fichiers Dart écrits à la main sous `lib/` (le code généré est ignoré).
List<String> _dartSources() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => _segments(f.path).join('/'))
        .where((p) => p.endsWith('.dart') && !p.startsWith('lib/l10n/'))
        .where((p) => !p.endsWith('.g.dart') && !p.endsWith('.freezed.dart'))
        .toList()
      ..sort();

final _directive = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

Iterable<String> _directives(String source) =>
    _directive.allMatches(source).map((m) => m.group(1)!);

List<String> _segments(String path) =>
    path.replaceAll(r'\', '/').split('/').where((s) => s.isNotEmpty).toList();

String _readPackageName() => RegExp(
  r'^name:\s*(\S+)',
  multiLine: true,
).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;

/// Premier cycle trouvé dans [graph] (ex. `a -> b -> a`), sinon null.
String? _findCycle(Map<String, Set<String>> graph) {
  final done = <String>{};
  final path = <String>[];

  String? visit(String node) {
    final index = path.indexOf(node);
    if (index != -1) return [...path.sublist(index), node].join(' -> ');
    if (!done.add(node)) return null;
    path.add(node);
    for (final next in graph[node] ?? const <String>{}) {
      final cycle = visit(next);
      if (cycle != null) return cycle;
    }
    path.removeLast();
    return null;
  }

  for (final node in graph.keys) {
    final cycle = visit(node);
    if (cycle != null) return cycle;
  }
  return null;
}

String _report({required Set<String> added, required Set<String> fixed}) {
  final buffer = StringBuffer();
  if (added.isNotEmpty) {
    buffer.writeln('\n${added.length} violation(s) d\'architecture :');
    final byRule = <String, List<String>>{};
    for (final violation in added) {
      final rule = RegExp(r'\[(.+)\]$').firstMatch(violation)!.group(1)!;
      byRule.putIfAbsent(rule, () => []).add(violation);
    }
    for (final MapEntry(key: rule, value: lines) in byRule.entries) {
      buffer.writeln('\n[$rule] ${ruleHints[rule]}');
      for (final line in lines..sort()) {
        buffer.writeln('  $line');
      }
    }
  }
  if (fixed.isNotEmpty) {
    buffer.writeln('\nDette résorbée — retirer de knownViolations :');
    for (final line in fixed.toList()..sort()) {
      buffer.writeln("  '$line',");
    }
  }
  return buffer.toString();
}
