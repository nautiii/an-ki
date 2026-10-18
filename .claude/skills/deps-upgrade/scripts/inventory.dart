// ignore_for_file: avoid_print
//
// INVENTAIRE DES VERSIONS — outil du skill `deps-upgrade`
// (source : .claude/skills/deps-upgrade/scripts/inventory.dart).
// Lecture seule : compare le SDK Flutter, la chaîne Android et les dépendances
// pub du projet aux dernières versions stables et aux plafonds que l'outil
// Flutter connaît. Ne modifie aucun fichier. Sans réseau, les colonnes
// distantes affichent « ? ».
//
// Usage, depuis la racine du dépôt :
//   dart .claude/skills/deps-upgrade/scripts/inventory.dart [<version Flutter cible>]
// Sans argument, la cible est la dernière stable publiée.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('inventory.dart : à lancer depuis la racine du dépôt.');
    exitCode = 2;
    return;
  }
  final flutter = await _installedFlutter();
  if (flutter == null) {
    stderr.writeln('inventory.dart : `flutter --version --machine` a échoué.');
    exitCode = 1;
    return;
  }
  final target = await _flutterSection(
    flutter,
    args.isEmpty ? null : args.first,
  );
  await _androidSection(flutter, target);
  await _pubSection();
}

// ---------------------------------------------------------------- Flutter

final class _Flutter {
  const _Flutter(this.version, this.dart, this.channel, this.root);

  final String version;
  final String dart;
  final String channel;
  final String root;
}

Future<_Flutter?> _installedFlutter() async {
  final result = await _run('flutter', ['--version', '--machine']);
  if (result == null) return null;
  final start = result.indexOf('{');
  if (start < 0) return null;
  final json = jsonDecode(result.substring(start)) as Map<String, Object?>;
  return _Flutter(
    json['frameworkVersion'] as String? ?? '?',
    json['dartSdkVersion'] as String? ?? '?',
    json['channel'] as String? ?? '?',
    json['flutterRoot'] as String? ?? '',
  );
}

/// Affiche le SDK installé face à la stable ; renvoie la version cible.
Future<String> _flutterSection(_Flutter installed, String? requested) async {
  print('# Flutter');
  final os = Platform.isWindows
      ? 'windows'
      : Platform.isMacOS
      ? 'macos'
      : 'linux';
  final body = await _get(
    'https://storage.googleapis.com/flutter_infra_release/releases/releases_$os.json',
  );
  String? stable;
  String? stableDart;
  String? stableDate;
  String? requestedDart;
  if (body != null) {
    final json = jsonDecode(body) as Map<String, Object?>;
    final current = json['current_release'] as Map<String, Object?>;
    final releases = (json['releases'] as List<Object?>)
        .cast<Map<String, Object?>>();
    for (final release in releases) {
      if (release['hash'] == current['stable'] && stable == null) {
        stable = release['version'] as String?;
        stableDart = release['dart_sdk_version'] as String?;
        stableDate = (release['release_date'] as String?)?.split('T').first;
      }
      if (requested != null && release['version'] == requested) {
        requestedDart ??= release['dart_sdk_version'] as String?;
      }
    }
  }
  final env = _pubspecEnvironment();
  print(
    'installé  ${installed.version} (Dart ${installed.dart}, ${installed.channel})',
  );
  print(
    'stable    ${stable ?? '?'} (Dart ${stableDart ?? '?'}, '
    'publiée ${stableDate ?? '?'})',
  );
  if (requested != null) {
    print(
      'demandée  $requested (Dart ${requestedDart ?? 'version inconnue des releases'})',
    );
  }
  print('pubspec   sdk: ${env.sdk} · flutter: ${env.flutter}');
  if (installed.channel != 'stable') {
    print('ALERTE    canal ${installed.channel} : le projet suit stable.');
  }
  final target = requested ?? stable ?? installed.version;
  if (_compare(target, installed.version) > 0) {
    print('→ montée possible : ${installed.version} → $target');
  } else {
    print('→ SDK à jour pour la cible $target');
  }
  print('');
  return target;
}

({String sdk, String flutter}) _pubspecEnvironment() {
  final text = File('pubspec.yaml').readAsStringSync();
  final sdk = RegExp(r'^\s+sdk:\s*(\S+)', multiLine: true).firstMatch(text);
  final fl = RegExp(
    r'^\s+flutter:\s*"([^"]+)"',
    multiLine: true,
  ).firstMatch(text);
  return (sdk: sdk?.group(1) ?? '?', flutter: fl?.group(1) ?? '?');
}

// ---------------------------------------------------------------- Android

const _gradleUtils = 'packages/flutter_tools/lib/src/android/gradle_utils.dart';
const _googleMaven = 'https://dl.google.com/dl/android/maven2';

Future<void> _androidSection(_Flutter installed, String target) async {
  print('# Android');
  final project = _projectToolchain();
  // Plafonds de la cible si elle diffère du SDK installé (lus sur GitHub).
  var limits = _flutterLimits(
    File('${installed.root}/$_gradleUtils').readAsStringSync(),
  );
  var limitsFrom = 'Flutter ${installed.version} installé';
  if (target != installed.version) {
    final remote = await _get(
      'https://raw.githubusercontent.com/flutter/flutter/$target/$_gradleUtils',
    );
    if (remote != null) {
      limits = _flutterLimits(remote);
      limitsFrom = 'Flutter $target (cible)';
    } else {
      limitsFrom =
          'Flutter ${installed.version} installé (cible $target illisible)';
    }
  }
  print('plafonds connus de $limitsFrom');

  final [gradle, agp, kgp, gms, desugar] = await Future.wait([
    _gradleReleases(),
    _mavenReleases(
      '$_googleMaven/com/android/tools/build/gradle/maven-metadata.xml',
    ),
    _mavenReleases(
      'https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-gradle-plugin/maven-metadata.xml',
    ),
    _mavenReleases(
      '$_googleMaven/com/google/gms/google-services/maven-metadata.xml',
    ),
    _mavenReleases(
      '$_googleMaven/com/android/tools/desugar_jdk_libs/maven-metadata.xml',
    ),
  ]);

  final gradleMax = limits.consts['maxKnownAndSupportedGradleVersion'];
  final agpMax = limits.consts['maxKnownAndSupportedAgpVersion'];
  final kgpMax = limits.consts['maxKnownAndSupportedKgpVersion'];
  // Gradle : Flutter compare la version complète au plafond (testé en CI).
  final gradleCandidate = gradleMax == null
      ? null
      : gradle.lastWhere(
          (v) => _compare(v, gradleMax) <= 0,
          orElse: () => gradleMax,
        );

  // AGP : le plus récent sous le plafond dont le Gradle minimal (table de
  // Flutter) tient dans le candidat Gradle ; une ligne absente de la table est
  // signalée à vérifier dans la table de compatibilité d'AGP.
  String? agpSafe;
  String? agpToCheck;
  for (final v in agp.reversed) {
    if (agpMax == null || _compareMinor(v, agpMax) > 0) continue;
    final minGradle = limits.agpToGradle[_minorOf(v)];
    if (minGradle == null) {
      agpToCheck ??= v;
      continue;
    }
    if (gradleCandidate != null && _compare(minGradle, gradleCandidate) <= 0) {
      agpSafe = v;
      break;
    }
  }

  _table(
    ['outil', 'projet', 'plafond Flutter', 'candidat', 'dernière stable'],
    [
      [
        'Gradle',
        project.gradle,
        gradleMax ?? '?',
        gradleCandidate ?? '?',
        _last(gradle),
      ],
      ['AGP', project.agp, agpMax ?? '?', agpSafe ?? '?', _last(agp)],
      [
        'KGP',
        project.kgp,
        kgpMax ?? '?',
        _newestWithin(kgp, kgpMax) ?? '?',
        _last(kgp),
      ],
      ['google-services', project.gms, '—', _last(gms), _last(gms)],
      [
        'desugar_jdk_libs',
        project.desugar,
        '—',
        _last(desugar),
        _last(desugar),
      ],
    ],
  );
  if (agpToCheck != null) {
    print(
      'à vérifier : AGP $agpToCheck tient sous le plafond, mais Flutter ne '
      'connaît pas son Gradle minimal → developer.android.com/build/releases/about-agp',
    );
  }
  final mapped = limits.agpToGradle.entries.toList()
    ..sort((a, b) => _compare(b.key, a.key));
  print(
    'table Flutter AGP ↔ Gradle : '
    '${mapped.take(4).map((e) => 'AGP ${e.key}.x → Gradle ≥ ${e.value}').join(' · ')}',
  );
  print(
    'modèle Flutter : Gradle ${limits.consts['templateDefaultGradleVersion'] ?? '?'}, '
    'AGP ${limits.consts['templateAndroidGradlePluginVersion'] ?? '?'}, '
    'KGP ${limits.consts['templateKotlinGradlePluginVersion'] ?? '?'}',
  );

  // Indicateurs gradle.properties face au modèle de l'app Flutter installé.
  final template = _properties(
    File(
      '${installed.root}/packages/flutter_tools/templates/app/android.tmpl/gradle.properties.tmpl',
    ).readAsStringSync(),
  );
  final props = _properties(
    File('android/gradle.properties').readAsStringSync(),
  );
  final keys = {
    ...template.keys,
    ...props.keys,
  }.where((k) => k.startsWith('android.'));
  final drift = [
    for (final k in keys)
      if (template[k] != props[k])
        '$k : projet ${props[k] ?? '—'}, modèle ${template[k] ?? '—'}',
  ];
  print(
    drift.isEmpty
        ? 'gradle.properties : indicateurs android.* identiques au modèle'
        : 'gradle.properties ≠ modèle : ${drift.join(' · ')}',
  );
  print('JDK : ${await _jdk()}');
  print('');
}

final class _Toolchain {
  const _Toolchain(this.gradle, this.agp, this.kgp, this.gms, this.desugar);

  final String gradle;
  final String agp;
  final String kgp;
  final String gms;
  final String desugar;
}

_Toolchain _projectToolchain() {
  final wrapper = File('android/gradle/wrapper/gradle-wrapper.properties')
      .readAsStringSync();
  final settings = File('android/settings.gradle.kts').readAsStringSync();
  final app = File('android/app/build.gradle.kts').readAsStringSync();
  final plugins = {
    for (final m in RegExp(
      r'id\("([^"]+)"\)\s*version\s*\(?"([^"]+)"',
    ).allMatches(settings))
      m.group(1)!: m.group(2)!,
  };
  return _Toolchain(
    RegExp(r'gradle-([\d.]+)-').firstMatch(wrapper)?.group(1) ?? '?',
    plugins['com.android.application'] ?? '?',
    plugins['org.jetbrains.kotlin.android'] ?? '?',
    plugins['com.google.gms.google-services'] ?? '?',
    RegExp(r'desugar_jdk_libs:([\d.]+)').firstMatch(app)?.group(1) ?? '—',
  );
}

final class _Limits {
  const _Limits(this.consts, this.agpToGradle);

  final Map<String, String> consts;

  /// Ligne AGP (« 9.1 ») → Gradle minimal, selon la table de l'outil Flutter.
  final Map<String, String> agpToGradle;
}

_Limits _flutterLimits(String source) {
  final consts = {
    for (final m in RegExp(r"const (\w+) = '([^']+)';").allMatches(source))
      m.group(1)!: m.group(2)!,
  };
  final agpToGradle = <String, String>{};
  for (final m in RegExp(
    r"agpV, min: '([\d.]+)', max: '[\d.]+'\)\) \{\s*return isWithinVersionRange\(gradleV, min: '([\d.]+)'",
  ).allMatches(source)) {
    agpToGradle.putIfAbsent(_minorOf(m.group(1)!), () => m.group(2)!);
  }
  return _Limits(consts, agpToGradle);
}

Future<List<String>> _gradleReleases() async {
  final body = await _get('https://services.gradle.org/versions/all');
  if (body == null) return const [];
  final all = (jsonDecode(body) as List<Object?>).cast<Map<String, Object?>>();
  return _sorted([
    for (final v in all)
      if (v['snapshot'] == false &&
          v['nightly'] == false &&
          v['releaseNightly'] == false &&
          v['broken'] == false &&
          v['rcFor'] == '' &&
          v['milestoneFor'] == '')
        v['version'] as String,
  ]);
}

Future<List<String>> _mavenReleases(String url) async {
  final body = await _get(url);
  if (body == null) return const [];
  return _sorted([
    for (final m in RegExp(r'<version>([^<]+)</version>').allMatches(body))
      m.group(1)!,
  ]);
}

Map<String, String> _properties(String text) => {
  for (final line in const LineSplitter().convert(text))
    if (!line.trimLeft().startsWith('#') && line.contains('='))
      line.substring(0, line.indexOf('=')).trim(): line
          .substring(line.indexOf('=') + 1)
          .trim(),
};

Future<String> _jdk() async {
  final config = await _run('flutter', ['config', '--list']);
  final dir = config == null
      ? null
      : RegExp(r'jdk-dir:\s*"?([^"\r\n]+)"?')
            .firstMatch(config)
            ?.group(1)
            ?.trim();
  final java = dir == null || dir == '(Not set)' ? 'java' : '$dir/bin/java';
  try {
    final result = await Process.run(java, ['-version']);
    final first = const LineSplitter()
        .convert('${result.stderr}')
        .firstWhere((l) => l.isNotEmpty, orElse: () => '?');
    return '${dir ?? 'non configuré (java du PATH)'} — $first';
  } on ProcessException {
    return '${dir ?? 'non configuré'} — java introuvable';
  }
}

// ---------------------------------------------------------------- pub

/// Implémentations natives d'un plugin fédéré pour les cibles de l'app
/// (Android, iOS) : leur montée se teste sur appareil, même en transitive.
final _platformImpl = RegExp(r'_(android|ios|darwin|foundation)$');

const _pinnedFlag = 'épinglé dans decisions.md';

Future<void> _pubSection() async {
  print('# pub');
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final loose = [
    for (final m in RegExp(
      r'^  (\w+):\s*([\^>~<][^\n]*)$',
      multiLine: true,
    ).allMatches(pubspec))
      if (m.group(1) != 'sdk' && m.group(1) != 'flutter')
        '${m.group(1)} ${m.group(2)}',
  ];
  if (loose.isNotEmpty) {
    print('ALERTE    contraintes non épinglées : ${loose.join(', ')}');
  }

  final output = await _run('flutter', ['pub', 'outdated', '--json']);
  final start = output?.indexOf('{') ?? -1;
  if (output == null || start < 0) {
    print('`flutter pub outdated --json` a échoué.');
  } else {
    final json = jsonDecode(output.substring(start)) as Map<String, Object?>;
    final packages = (json['packages'] as List<Object?>)
        .cast<Map<String, Object?>>();
    final decisions = File(
      '.claude/skills/architecture/references/decisions.md',
    );
    // Seules les lignes qui parlent d'épinglage comptent (« pinned to 17.x »).
    final pinLines = decisions.existsSync()
        ? decisions
              .readAsLinesSync()
              .where(RegExp(r'\bpin', caseSensitive: false).hasMatch)
              .join('\n')
        : '';
    final rows = <List<String>>[];
    final transitive = <String>[];
    final impl = <String>[];
    final bumped = <String>[];
    for (final p in packages) {
      final name = '${p['package']}';
      final current = _version(p['current']);
      final resolvable = _version(p['resolvable']);
      final latest = _version(p['latest']);
      if (p['kind'] == 'transitive') {
        final upgradable = _version(p['upgradable']);
        if (_compare(upgradable, current) <= 0) continue;
        transitive.add(name);
        if (_platformImpl.hasMatch(name)) {
          impl.add('$name $current → $upgradable');
          bumped.add(name);
        }
        continue;
      }
      final flags = [
        if (p['isDiscontinued'] == true) 'abandonné',
        if (p['isCurrentRetracted'] == true) 'version retirée',
        if (p['isCurrentAffectedByAdvisory'] == true) 'faille signalée',
        if (_compare(latest, resolvable) > 0) 'bloqué < $latest',
        if (RegExp('\\b${RegExp.escape(name)}\\b').hasMatch(pinLines))
          _pinnedFlag,
      ];
      final moves = _compare(resolvable, current) > 0;
      if (!moves && !flags.any((f) => f != _pinnedFlag)) continue;
      if (moves) bumped.add(name);
      rows.add([
        name,
        p['kind'] == 'dev' ? 'dev' : 'direct',
        current,
        resolvable,
        _bump(current, resolvable),
        flags.join(', '),
      ]);
    }
    if (rows.isEmpty) {
      print('dépendances directes et dev à jour');
    } else {
      _table(['paquet', 'type', 'actuel', 'cible', 'saut', 'remarques'], rows);
    }
    print(
      'transitives montables par `flutter pub upgrade` (${transitive.length})'
      '${transitive.isEmpty ? '' : ' : ${transitive.join(', ')}'}',
    );
    if (impl.isNotEmpty) {
      print(
        'dont implémentations natives (test appareil) : ${impl.join(' · ')}',
      );
    }
    if (bumped.isNotEmpty) {
      print('changelogs (curl -s <url>) :');
      final urls = await Future.wait(bumped.map(_changelog));
      for (var i = 0; i < bumped.length; i++) {
        print('  ${bumped[i]}  ${urls[i]}');
      }
    }
  }

  // riverpod_lint est épinglé dans analysis_options.yaml, hors pubspec.
  final options = File('analysis_options.yaml').readAsStringSync();
  final pinned = RegExp(r'riverpod_lint:\s*(\S+)')
      .firstMatch(options)
      ?.group(1);
  if (pinned != null) {
    final latest = (await _pubLatest('riverpod_lint'))?['version'] ?? '?';
    print('riverpod_lint (analysis_options.yaml) : $pinned → dernière $latest');
  }
}

/// `latest.pubspec` de pub.dev pour [package], ou null hors réseau.
Future<Map<String, Object?>?> _pubLatest(String package) async {
  final body = await _get('https://pub.dev/api/packages/$package');
  if (body == null) return null;
  final latest =
      (jsonDecode(body) as Map<String, Object?>)['latest']
          as Map<String, Object?>;
  return latest['pubspec'] as Map<String, Object?>;
}

/// CHANGELOG.md brut sur GitHub (complet, exact) ; à défaut, la page pub.dev.
Future<String> _changelog(String package) async {
  final fallback = 'https://pub.dev/packages/$package/changelog';
  final pubspec = await _pubLatest(package);
  final repo = (pubspec?['repository'] ?? pubspec?['homepage']) as String?;
  final m = repo == null
      ? null
      : RegExp(
          r'^https?://github\.com/([^/]+)/([^/#?]+?)(?:\.git)?(?:/tree/([^/]+)(/[^#?]*?))?/?$',
        ).firstMatch(repo);
  if (m == null) return fallback;
  final base =
      'https://raw.githubusercontent.com/${m.group(1)}/${m.group(2)}/'
      '${m.group(3) ?? 'HEAD'}';
  final path = m.group(4) ?? '';
  // Un plugin fédéré déclare parfois le dossier du paquet principal : tenter
  // d'abord le dossier voisin qui porte son nom.
  final sibling = path.isEmpty || path.endsWith('/$package')
      ? null
      : '$base${path.substring(0, path.lastIndexOf('/'))}/$package/CHANGELOG.md';
  for (final url in [?sibling, '$base$path/CHANGELOG.md']) {
    if (await _exists(url)) return url;
  }
  return fallback;
}

String _version(Object? field) =>
    field is Map<String, Object?> ? field['version'] as String? ?? '?' : '?';

/// Nature du saut selon semver (en 0.x, le mineur casse ; un `+build` est un
/// correctif).
String _bump(String from, String to) {
  final a = _parts(from);
  final b = _parts(to);
  if (a.isEmpty || b.isEmpty || _compare(to, from) <= 0) return '—';
  if (a[0] != b[0] || (a[0] == 0 && a[1] != b[1])) return 'MAJEUR';
  return a[1] != b[1] ? 'mineur' : 'correctif';
}

// ---------------------------------------------------------------- outils

final _stable = RegExp(r'^\d+(\.\d+)*$');

/// Majeur, mineur, correctif, puis le numéro de build pub (`0.8.13+12`) ;
/// une pré-version garde ses chiffres de tête.
List<int> _parts(String v) {
  final plus = v.indexOf('+');
  final digits = RegExp(r'^\d+(\.\d+)*')
      .stringMatch(plus < 0 ? v : v.substring(0, plus));
  if (digits == null) return const [];
  final core = digits.split('.').map(int.parse).toList();
  while (core.length < 3) {
    core.add(0);
  }
  final build = plus < 0
      ? 0
      : int.tryParse(RegExp(r'\d+').stringMatch(v.substring(plus + 1)) ?? '') ??
            0;
  return [...core.take(3), build];
}

int _compare(String a, String b) {
  final x = _parts(a);
  final y = _parts(b);
  for (var i = 0; i < 4; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

String _minorOf(String v) => _parts(v).take(2).join('.');

/// Compare deux versions sur leurs seuls majeur et mineur.
int _compareMinor(String a, String b) => _compare(_minorOf(a), _minorOf(b));

/// Versions stables seulement, triées de la plus ancienne à la plus récente.
List<String> _sorted(Iterable<String> versions) =>
    versions.where(_stable.hasMatch).toList()..sort(_compare);

String _last(List<String> sorted) => sorted.isEmpty ? '?' : sorted.last;

/// Plus récente stable dont la ligne majeur.mineur ne dépasse pas le plafond :
/// l'outil Flutter traite une ligne entière comme compatible (KGP 2.4.0 à
/// 2.4.29 pour un plafond 2.4.0).
String? _newestWithin(List<String> sorted, String? ceiling) {
  if (ceiling == null) return null;
  for (final v in sorted.reversed) {
    if (_compareMinor(v, ceiling) <= 0) return v;
  }
  return null;
}

void _table(List<String> header, List<List<String>> rows) {
  final widths = [
    for (var i = 0; i < header.length; i++)
      [header, ...rows].map((r) => r[i].length).reduce((a, b) => a > b ? a : b),
  ];
  String line(List<String> cells) =>
      [for (var i = 0; i < cells.length; i++) cells[i].padRight(widths[i])]
          .join('  ')
          .trimRight();
  print(line(header));
  for (final row in rows) {
    print(line(row));
  }
}

Future<String?> _get(String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return null;
    }
    return await response.transform(utf8.decoder).join();
  } on Exception {
    return null;
  } finally {
    client.close(force: true);
  }
}

Future<bool> _exists(String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.headUrl(Uri.parse(url));
    final response = await request.close().timeout(const Duration(seconds: 30));
    await response.drain<void>();
    return response.statusCode == HttpStatus.ok;
  } on Exception {
    return false;
  } finally {
    client.close(force: true);
  }
}

Future<String?> _run(String executable, List<String> args) async {
  try {
    final result = await Process.run(
      executable,
      args,
      runInShell: Platform.isWindows,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(const Duration(minutes: 3));
    return result.exitCode == 0 ? result.stdout as String : null;
  } on Exception {
    return null;
  }
}
