// CHERCHEUR DE CODE MORT — outil du skill `dead-code`
// (source : .claude/skills/dead-code/scripts/bin/find_dead_code.dart).
// Lecture seule : résout lib/ et test/ dans UN seul contexte d'analyse et
// compare les éléments déclarés dans lib/ à ceux que lib/ et test/
// référencent. Ne modifie aucun fichier.
//
// Usage (le skill copie scripts/ dans build/dead_code/) :
//   cd build/dead_code && dart pub get --offline
//   dart run bin/find_dead_code.dart ../..
//
// Pièges d'analyzer 14 évités ici :
// - une seule AnalysisContextCollection sur la racine : deux chemins inclus
//   créent deux contextes dont les Element diffèrent, et « utilisé seulement
//   par les tests » devient silencieusement « inutilisé » ;
// - pas d'isSynthetic : un getter ou setter implicite (isOriginDeclaration
//   faux) est ramené à son champ ou à sa variable ;
// - un constructeur primaire (`class const X({…})`) n'est pas une
//   Declaration : visité à part, ses paramètres déclarants sont des champs
//   (isDeclaring) ;
// - la collection exige des chemins absolus normalisés (C:\…, pas C:/…).

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';

final _path = PhysicalResourceProvider.INSTANCE.pathContext;

Future<void> main(List<String> args) async {
  final root = _path.normalize(
    Directory(args.isEmpty ? '.' : args.first).absolute.path,
  );
  final lib = _path.join(root, 'lib');
  final test = _path.join(root, 'test');
  final pubspec = File(_path.join(root, 'pubspec.yaml'));
  if (!pubspec.existsSync() || !Directory(lib).existsSync()) {
    stderr.writeln(
      'find_dead_code.dart : racine du dépôt attendue (pubspec.yaml et lib/), '
      'reçu $root',
    );
    exitCode = 2;
    return;
  }
  final package = RegExp(
    r'^name:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync())?.group(1);
  if (package == null) {
    stderr.writeln('find_dead_code.dart : `name:` absent de pubspec.yaml');
    exitCode = 2;
    return;
  }
  final watch = Stopwatch()..start();
  final finder = _Finder(root, package, _L10n.read(root));
  final files = [
    for (final dir in [lib, test])
      if (Directory(dir).existsSync())
        for (final entity in Directory(dir).listSync(recursive: true))
          if (entity is File && entity.path.endsWith('.dart'))
            _path.normalize(entity.path),
  ]..sort();

  final collection = AnalysisContextCollection(includedPaths: [root]);
  final contexts = <AnalysisContext>{};
  var libCount = 0;
  var testCount = 0;
  for (final file in files) {
    final context = collection.contextFor(file);
    final result = await context.currentSession.getResolvedUnit(file);
    if (result is! ResolvedUnitResult) {
      stderr.writeln('non résolu : $file');
      continue;
    }
    contexts.add(context);
    final side = _path.isWithin(lib, file) ? _Side.lib : _Side.test;
    side == _Side.lib ? libCount++ : testCount++;
    result.unit.accept(_Visitor(finder, result, side));
  }
  await collection.dispose();

  print('# Code mort — $package');
  print(
    '$libCount fichiers lib/, $testCount test/ · ${contexts.length} contexte(s) '
    '· ${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)} s',
  );
  if (contexts.length > 1) {
    print(
      'ALERTE    lib/ et test/ résolus dans ${contexts.length} contextes : '
      'leurs éléments diffèrent, les résultats ci-dessous sont faux.',
    );
  }
  finder.report();
}

enum _Side { lib, test }

const _arbKind = 'clé ARB';

/// Utile, réservé aux tests ou mort : l'ordre sert à prendre le pire.
enum _Status { live, testOnly, dead }

/// Déclarations suivies qui englobent une référence, la plus proche en tête.
final class _Frame {
  const _Frame(this.element, this.parent);

  final Element element;
  final _Frame? parent;

  Iterable<Element> get chain sync* {
    for (_Frame? f = this; f != null; f = f.parent) {
      yield f.element;
    }
  }
}

/// Une référence (ou un argument passé) : d'où elle vient.
final class _Use {
  const _Use(this.side, this.path, this.frame);

  final _Side side;
  final String path;
  final _Frame? frame;
}

final class _Decl {
  const _Decl(this.element, this.kind, this.label, this.location);

  final Element element;
  final String kind;
  final String label;

  /// `chemin/relatif.dart:ligne` (ou la ligne de la clé dans l'ARB modèle).
  final String location;
}

final class _Param {
  const _Param(this.element, this.executable, this.label, this.location);

  final FormalParameterElement element;
  final Element executable;
  final String label;
  final String location;
}

/// Configuration de gen-l10n (l10n.yaml) : fichiers générés, classe, ARB modèle.
final class _L10n {
  const _L10n(
    this.outputDir,
    this.stem,
    this.mainFile,
    this.className,
    this.arb,
    this.arbLines,
  );

  factory _L10n.read(String root) {
    final file = File(_path.join(root, 'l10n.yaml'));
    final yaml = file.existsSync() ? file.readAsStringSync() : '';
    String value(String key, String fallback) {
      final raw = RegExp(
        '^$key:\\s*(.+)\$',
        multiLine: true,
      ).firstMatch(yaml)?.group(1)?.trim();
      return raw == null
          ? fallback
          : raw.replaceAll(RegExp('^[\'"]|[\'"]\$'), '');
    }

    final arbDir = _path.join(
      root,
      _path.normalize(value('arb-dir', 'lib/l10n')),
    );
    final outputDir = _path.join(
      root,
      _path.normalize(value('output-dir', _path.relative(arbDir, from: root))),
    );
    final output = value('output-localization-file', 'app_localizations.dart');
    final arb = _path.join(arbDir, value('template-arb-file', 'app_en.arb'));
    final arbLines = <String, int>{};
    if (File(arb).existsSync()) {
      final lines = const LineSplitter().convert(File(arb).readAsStringSync());
      for (var i = 0; i < lines.length; i++) {
        final key = RegExp(r'^\s*"([^"@][^"]*)"\s*:').firstMatch(lines[i]);
        if (key != null) arbLines.putIfAbsent(key.group(1)!, () => i + 1);
      }
    }
    return _L10n(
      outputDir,
      _path.basenameWithoutExtension(output),
      _path.join(outputDir, output),
      value('output-class', 'AppLocalizations'),
      arb,
      arbLines,
    );
  }

  final String outputDir;
  final String stem;
  final String mainFile;
  final String className;
  final String arb;
  final Map<String, int> arbLines;

  bool isGenerated(String path) =>
      _path.dirname(path) == outputDir &&
      _path.basename(path).startsWith(stem) &&
      path.endsWith('.dart');
}

final class _Finder {
  _Finder(this.root, this.package, this.l10n);

  final String root;
  final String package;
  final _L10n l10n;

  final decls = <Element, _Decl>{};
  final params = <_Param>[];
  final uses = <Element, List<_Use>>{};
  final passes = <Element, List<_Use>>{};

  /// Classes abstraites qui déclarent un constructeur privé sans paramètre.
  final idioms = <String>{};

  String relative(String path) =>
      _path.relative(path, from: root).replaceAll(r'\', '/');

  /// Déclaration de lib/ : écartée si elle redéfinit un membre (comptée via
  /// le membre redéfini), si c'est un point d'entrée, ou si gen-l10n l'a
  /// écrite (sauf les clés ARB, membres abstraits de la classe générée).
  void declare(
    Element element,
    ResolvedUnitResult unit, {
    required int offset,
    List<Annotation> metadata = const [],
    FormalParameterList? parameters,
  }) {
    if (l10n.isGenerated(unit.path)) {
      final owner = element.enclosingElement;
      if (unit.path == l10n.mainFile &&
          owner is ClassElement &&
          owner.name == l10n.className &&
          element is ExecutableElement &&
          element.isAbstract &&
          !element.isStatic) {
        final key = element.name ?? '?';
        final line = l10n.arbLines[key];
        decls[element] = _Decl(
          element,
          _arbKind,
          key,
          line == null
              ? '${relative(unit.path)}:${_line(unit, offset)}'
              : '${relative(l10n.arb)}:$line',
        );
      }
      return;
    }
    if (metadata.any((a) => a.name.name == 'override')) return;
    if (metadata.any((a) => a.toSource().contains('vm:entry-point'))) return;
    if (element is TopLevelFunctionElement && element.name == 'main') return;
    // `const X._();` d'une classe abstraite de constantes : idiome, rappelé
    // en une ligne plutôt que listé.
    final owner = element.enclosingElement;
    if (element is ConstructorElement &&
        (element.name ?? '').startsWith('_') &&
        element.formalParameters.isEmpty &&
        owner is ClassElement &&
        owner.isAbstract) {
      idioms.add(owner.name ?? '?');
      return;
    }
    final label = _label(element);
    decls[element] = _Decl(
      element,
      _kind(element),
      label,
      '${relative(unit.path)}:${_line(unit, offset)}',
    );

    for (final p in parameters?.parameters ?? const <FormalParameter>[]) {
      final pe = p.declaredFragment?.element;
      // `key` des widgets : convention Flutter, jamais signalé.
      if (pe == null || !pe.isOptional || pe.name == 'key') continue;
      final name = pe.name ?? '?';
      params.add(
        _Param(
          pe,
          element,
          '$label(${pe.isNamed ? '{$name}' : '[$name]'})',
          '${relative(unit.path)}:${_line(unit, p.declaredFragment?.nameOffset ?? p.offset)}',
        ),
      );
    }
  }

  /// Champ déclaré par un paramètre de constructeur primaire.
  void declareField(
    FieldElement field,
    FormalParameter node,
    ResolvedUnitResult unit,
  ) {
    decls[field] = _Decl(
      field,
      'champ',
      _label(field),
      '${relative(unit.path)}:${_line(unit, node.declaredFragment?.nameOffset ?? node.offset)}',
    );
  }

  /// Référence à [element] ; un membre utilise aussi son conteneur, `values`
  /// utilise toutes les valeurs de l'enum, et un membre qui en redéfinit un
  /// autre utilise le membre redéfini (le contrat reste nécessaire).
  void use(Element? element, _Side side, String path, _Frame? frame) {
    final e = _canonical(element);
    if (e == null || !_ours(e)) return;
    final at = _Use(side, path, frame);
    (uses[e] ??= []).add(at);
    final owner = e.enclosingElement;
    if (owner is InstanceElement) (uses[owner] ??= []).add(at);
    if (e is FieldElement && e.isOriginEnumValues && owner is EnumElement) {
      for (final constant in owner.constants) {
        (uses[constant] ??= []).add(at);
      }
    }
    for (final overridden in _overridden(e)) {
      final o = _canonical(overridden);
      if (o != null && _ours(o)) (uses[o] ??= []).add(at);
    }
  }

  /// Argument passé à [parameter] (et au paramètre homologue des membres
  /// redéfinis, qu'un appel via le sous-type alimente aussi).
  void pass(Element? parameter, _Side side, String path, _Frame? frame) {
    final p = parameter?.baseElement;
    if (p is! FormalParameterElement) return;
    final at = _Use(side, path, frame);
    (passes[p] ??= []).add(at);
    final executable = p.enclosingElement;
    if (executable is! ExecutableElement) return;
    final index = executable.formalParameters.indexOf(p);
    for (final overridden in _overridden(executable)) {
      if (overridden is! ExecutableElement) continue;
      final others = overridden.baseElement.formalParameters;
      final match = p.isNamed
          ? others.where((q) => q.isNamed && q.name == p.name).firstOrNull
          : (index >= 0 && index < others.length ? others[index] : null);
      if (match != null) (passes[match.baseElement] ??= []).add(at);
    }
  }

  /// Fonction ou méthode passée sans être appelée : ses paramètres optionnels
  /// peuvent recevoir des arguments de n'importe quel appelant.
  void tearOff(Element? element, _Side side, String path, _Frame? frame) {
    final e = element?.baseElement;
    if (e is! ExecutableElement || e is PropertyAccessorElement) return;
    for (final p in e.formalParameters) {
      if (p.isOptional) pass(p, side, path, frame);
    }
  }

  bool _ours(Element e) {
    final uri = e.library?.uri;
    return uri != null &&
        uri.scheme == 'package' &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first == package;
  }

  // ------------------------------------------------------------- rapport

  void report() {
    final keys = decls.values.where((d) => d.kind == _arbKind).length;
    print(
      'suivis : ${decls.length - keys} déclarations de lib/, '
      '${params.length} paramètres optionnels, $keys clés ARB',
    );
    final status = _statuses();
    // Statut au premier ordre : la différence signale un ricochet (référencé
    // seulement depuis du code mort ou réservé aux tests).
    final firstOrder = {
      for (final e in decls.keys) e: _statusOf(e, const {}).status,
    };

    bool hidden(_Decl d) {
      final owner = status[d.element.enclosingElement];
      return owner == _Status.dead ||
          (owner == _Status.testOnly && status[d.element] == _Status.testOnly);
    }

    String notes(_Decl d, List<String> sources) {
      final e = d.element;
      return [
        if (e.metadata.hasVisibleForTesting) '@visibleForTesting',
        if (e.name == 'copyWith') 'copyWith',
        if (sources.isNotEmpty &&
            sources.every((s) => s.startsWith('test/architecture/')))
          'seulement test/architecture',
        if (firstOrder[e] != status[e]) 'ricochet',
      ].map((n) => ' [$n]').join();
    }

    final sorted = decls.values.toList()
      ..sort((a, b) => _compareLocation(a.location, b.location));
    final dead = <List<String>>[];
    final testOnly = <List<String>>[];
    final arb = <List<String>>[];
    for (final d in sorted) {
      final s = status[d.element]!;
      if (s == _Status.live || hidden(d)) continue;
      final sources = _statusOf(d.element, status).sources;
      if (d.kind == _arbKind) {
        arb.add([
          d.location,
          d.label,
          s == _Status.dead
              ? 'inutilisée'
              : 'tests seuls ← ${_summary(sources)}',
        ]);
        continue;
      }
      (s == _Status.dead ? dead : testOnly).add([
        d.location,
        d.kind,
        '${d.label}${notes(d, sources)}',
        if (s == _Status.testOnly) '← ${_summary(sources)}',
      ]);
    }

    final never = <List<String>>[];
    params.sort((a, b) => _compareLocation(a.location, b.location));
    for (final p in params) {
      final owner = p.executable.enclosingElement;
      if (status[p.executable] != _Status.live ||
          (owner != null && status[owner] == _Status.dead)) {
        continue;
      }
      var lib = false;
      final tests = <String>{};
      for (final u in passes[p.element] ?? const <_Use>[]) {
        final worst = _worst(u.frame, status);
        if (worst == _Status.dead) continue;
        if (u.side == _Side.lib && worst == _Status.live) {
          lib = true;
          break;
        }
        tests.add(
          u.side == _Side.test ? relative(u.path) : _via(u.frame, status),
        );
      }
      if (lib) continue;
      never.add([
        p.location,
        p.label,
        tests.isEmpty
            ? 'jamais passé'
            : 'passé par les tests seuls ← ${_summary(tests.toList())}',
      ]);
    }

    _section('Inutilisé dans lib/ et test/', dead);
    _section('Utilisé seulement par les tests', testOnly);
    _section('Paramètres optionnels jamais passés par lib/', never);
    _section('Clés ARB mortes', arb);
    print('');
    if (idioms.isNotEmpty) {
      print(
        'Jamais listé : le constructeur privé sans paramètre des classes '
        'abstraites ${(idioms.toList()..sort()).join(', ')} (idiome de classe '
        'de constantes).',
      );
    }
    print(
      'Écarté par construction : membres @override (comptés via le membre '
      'redéfini), main, @pragma(\'vm:entry-point\'), paramètres `key`, '
      'fichiers générés par gen-l10n hors clés, membres d\'un conteneur déjà '
      'signalé. Une suppression peut en révéler d\'autres : relancer.',
    );
  }

  /// Point fixe : une référence depuis du code mort ne compte pas, une
  /// référence depuis du code réservé aux tests compte comme un test.
  Map<Element, _Status> _statuses() {
    final status = {for (final e in decls.keys) e: _Status.live};
    var changed = true;
    while (changed) {
      changed = false;
      for (final e in decls.keys) {
        final next = _statusOf(e, status).status;
        if (next != status[e]) {
          status[e] = next;
          changed = true;
        }
      }
    }
    return status;
  }

  ({_Status status, List<String> sources}) _statusOf(
    Element e,
    Map<Element, _Status> status,
  ) {
    final sources = <String>{};
    for (final u in uses[e] ?? const <_Use>[]) {
      // Auto-référence (récursion, classe qui se nomme elle-même).
      if (u.frame?.chain.contains(e) ?? false) continue;
      if (u.side == _Side.test) {
        sources.add(relative(u.path));
        continue;
      }
      switch (_worst(u.frame, status)) {
        case _Status.live:
          return (status: _Status.live, sources: const []);
        case _Status.testOnly:
          sources.add(_via(u.frame, status));
        case _Status.dead:
          break;
      }
    }
    return (
      status: sources.isEmpty ? _Status.dead : _Status.testOnly,
      sources: sources.toList()..sort(),
    );
  }

  _Status _worst(_Frame? frame, Map<Element, _Status> status) {
    var worst = _Status.live;
    for (final e in frame?.chain ?? const <Element>[]) {
      final s = status[e];
      if (s != null && s.index > worst.index) worst = s;
    }
    return worst;
  }

  /// « via X » : le conteneur de lib/ réservé aux tests d'où vient l'usage.
  String _via(_Frame? frame, Map<Element, _Status> status) {
    for (final e in frame?.chain ?? const <Element>[]) {
      if (status[e] == _Status.testOnly)
        return 'via ${decls[e]?.label ?? e.name}';
    }
    return 'via ?';
  }

  String _summary(List<String> sources) => sources.length <= 3
      ? sources.join(', ')
      : '${sources.take(3).join(', ')} +${sources.length - 3}';

  void _section(String title, List<List<String>> rows) {
    print('');
    print('## $title (${rows.length})');
    if (rows.isEmpty) {
      print('rien');
      return;
    }
    final columns = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final widths = [
      for (var i = 0; i < columns - 1; i++)
        rows
            .map((r) => i < r.length ? r[i].length : 0)
            .reduce((a, b) => a > b ? a : b),
    ];
    for (final row in rows) {
      print(
        [
          for (var i = 0; i < row.length; i++)
            i < row.length - 1 ? row[i].padRight(widths[i]) : row[i],
        ].join('  '),
      );
    }
  }
}

final class _Visitor extends GeneralizingAstVisitor<void> {
  _Visitor(this.finder, this.unit, this.side);

  final _Finder finder;
  final ResolvedUnitResult unit;
  final _Side side;
  _Frame? frame;

  void _use(Element? element) => finder.use(element, side, unit.path, frame);

  @override
  void visitDeclaration(Declaration node) {
    final element = node.declaredFragment?.element;
    if (element == null || !_tracked(element)) {
      super.visitDeclaration(node);
      return;
    }
    if (side == _Side.lib) {
      // L'annotation d'un champ est portée par la déclaration qui l'englobe.
      final list = node is VariableDeclaration ? node.parent?.parent : null;
      finder.declare(
        element,
        unit,
        offset: node.declaredFragment?.nameOffset ?? node.offset,
        metadata: [
          ...node.metadata,
          if (list is AnnotatedNode) ...list.metadata,
        ],
        parameters: switch (node) {
          MethodDeclaration(:final parameters) => parameters,
          ConstructorDeclaration(:final parameters) => parameters,
          FunctionDeclaration(:final functionExpression) =>
            functionExpression.parameters,
          _ => null,
        },
      );
    }
    frame = _Frame(element, frame);
    if (element is InterfaceElement) {
      // `super()` implicite et constructeur par défaut appellent le parent.
      for (final constructor in element.constructors) {
        _use(constructor.superConstructor);
      }
    }
    super.visitDeclaration(node);
    frame = frame!.parent;
  }

  /// `class const X({…})` : pas une [Declaration] dans l'AST d'analyzer 14.
  @override
  void visitPrimaryConstructorDeclaration(PrimaryConstructorDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element == null) {
      super.visitPrimaryConstructorDeclaration(node);
      return;
    }
    if (side == _Side.lib) {
      finder.declare(
        element,
        unit,
        offset: node.declaredFragment?.nameOffset ?? node.offset,
        parameters: node.formalParameters,
      );
    }
    frame = _Frame(element, frame);
    super.visitPrimaryConstructorDeclaration(node);
    frame = frame!.parent;
  }

  @override
  void visitFormalParameter(FormalParameter node) {
    final element = node.declaredFragment?.element;
    final field = element is FieldFormalParameterElement && element.isDeclaring
        ? element.field
        : null;
    if (side == _Side.lib && field != null) {
      finder.declareField(field, node, unit);
    }
    super.visitFormalParameter(node);
  }

  @override
  void visitSuperFormalParameter(SuperFormalParameter node) {
    final element = node.declaredFragment?.element;
    if (element is SuperFormalParameterElement) {
      finder.pass(element.superConstructorParameter, side, unit.path, frame);
    }
    super.visitSuperFormalParameter(node);
  }

  // Ni les références de dartdoc ni `show`/`hide` ne sont des usages.
  @override
  void visitComment(Comment node) {}

  @override
  void visitCombinator(Combinator node) {}

  @override
  void visitConstructorFieldInitializer(ConstructorFieldInitializer node) {
    // `: champ = …` initialise sans lire : seule l'expression compte.
    node.expression.accept(this);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _use(node.element);
    final parent = node.parent;
    final invoked =
        (parent is MethodInvocation && parent.methodName == node) ||
        (parent is DotShorthandInvocation && parent.memberName == node);
    final element = node.element;
    if (!invoked && element is! ConstructorElement) {
      finder.tearOff(element, side, unit.path, frame);
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitExpression(Expression node) {
    if (node is MethodReferenceExpression) _use(node.element);
    if (node is CompoundAssignmentExpression) {
      _use(node.readElement);
      _use(node.writeElement);
    }
    super.visitExpression(node);
  }

  @override
  void visitNamedType(NamedType node) {
    _use(node.element);
    super.visitNamedType(node);
  }

  @override
  void visitConstructorName(ConstructorName node) {
    _use(node.element);
    super.visitConstructorName(node);
  }

  @override
  void visitConstructorReference(ConstructorReference node) {
    finder.tearOff(node.constructorName.element, side, unit.path, frame);
    super.visitConstructorReference(node);
  }

  @override
  void visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    _use(node.element);
    super.visitSuperConstructorInvocation(node);
  }

  @override
  void visitRedirectingConstructorInvocation(
    RedirectingConstructorInvocation node,
  ) {
    _use(node.element);
    super.visitRedirectingConstructorInvocation(node);
  }

  @override
  void visitAnnotation(Annotation node) {
    _use(node.element);
    super.visitAnnotation(node);
  }

  @override
  void visitExtensionOverride(ExtensionOverride node) {
    _use(node.element);
    super.visitExtensionOverride(node);
  }

  @override
  void visitPatternField(PatternField node) {
    _use(node.element);
    super.visitPatternField(node);
  }

  @override
  void visitArgumentList(ArgumentList node) {
    for (final argument in node.arguments) {
      finder.pass(argument.correspondingParameter, side, unit.path, frame);
    }
    super.visitArgumentList(node);
  }
}

/// Déclarations de premier niveau et membres ; ni locaux ni paramètres.
bool _tracked(Element e) =>
    e is InstanceElement ||
    e is TypeAliasElement ||
    e is TopLevelFunctionElement ||
    e is TopLevelVariableElement ||
    e is MethodElement ||
    e is FieldElement ||
    e is PropertyAccessorElement ||
    e is ConstructorElement;

/// Élément déclaré : sans substitution de types génériques, et le champ ou
/// la variable à la place d'un getter ou setter implicite.
Element? _canonical(Element? element) {
  var e = element?.baseElement;
  if (e is PropertyAccessorElement && !e.isOriginDeclaration) {
    e = e.variable.baseElement;
  }
  return e;
}

/// Membres de même nom dans les supertypes, que [e] redéfinit.
Iterable<Element> _overridden(Element e) sync* {
  final owner = e.enclosingElement;
  final name = e.name;
  if (owner is! InterfaceElement || name == null) return;
  if (e is ConstructorElement) return;
  if ((e is ExecutableElement && e.isStatic) ||
      (e is FieldElement && e.isStatic)) {
    return;
  }
  for (final type in owner.allSupertypes) {
    final s = type.element;
    if (e is MethodElement) {
      final m = s.getMethod(name);
      if (m != null) yield m;
    } else if (e is SetterElement) {
      final m = s.getSetter(name);
      if (m != null) yield m;
    } else {
      final g = s.getGetter(name);
      if (g != null) yield g;
      if (e is FieldElement) {
        final m = s.getSetter(name);
        if (m != null) yield m;
      }
    }
  }
}

String _kind(Element e) => switch (e) {
  ClassElement() => 'classe',
  MixinElement() => 'mixin',
  EnumElement() => 'enum',
  ExtensionTypeElement() => "type d'extension",
  ExtensionElement() => 'extension',
  TypeAliasElement() => 'typedef',
  TopLevelFunctionElement() => 'fonction',
  TopLevelVariableElement() => 'variable',
  ConstructorElement() => 'constructeur',
  MethodElement() => 'méthode',
  GetterElement() => 'getter',
  SetterElement() => 'setter',
  FieldElement(isEnumConstant: true) => "valeur d'enum",
  FieldElement() => 'champ',
  _ => e.kind.displayName,
};

String _label(Element e) {
  final owner = e.enclosingElement;
  final name = e is ConstructorElement ? (e.name ?? 'new') : (e.name ?? '?');
  return owner is InstanceElement ? '${owner.name ?? 'extension'}.$name' : name;
}

int _line(ResolvedUnitResult unit, int offset) =>
    unit.lineInfo.getLocation(offset).lineNumber;

int _compareLocation(String a, String b) {
  final ia = a.lastIndexOf(':');
  final ib = b.lastIndexOf(':');
  final byPath = a.substring(0, ia).compareTo(b.substring(0, ib));
  if (byPath != 0) return byPath;
  return int.parse(a.substring(ia + 1))
      .compareTo(int.parse(b.substring(ib + 1)));
}
