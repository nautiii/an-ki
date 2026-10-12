// ignore_for_file: avoid_print
//
// UI SNAPSHOTS — outil du skill `ux-ui` (source : .claude/skills/ux-ui/scripts/).
// Rend de vrais écrans avec AppTheme (clair / sombre / texte 200 %), écrit des
// PNG et imprime un audit : erreurs de layout (fichier:ligne), cibles tactiles,
// libellés pour lecteurs d'écran, contraste (heuristique).
//
// 1. mkdir -p build/ui_snapshots/_src && cp .claude/skills/ux-ui/scripts/*.dart build/ui_snapshots/_src/
// 2. Adapter la section SCÈNES (écran, données, interaction).
// 3. flutter test build/ui_snapshots/_src/ui_snapshot_test.dart --dart-define=UI_SNAPSHOT_LABEL=before
// 4. Lire build/ui_snapshots/before/<scène>.png (planche) et <scène>.txt (audit) ;
//    zoom 2x : build/ui_snapshots/before/<scène>/<variante>.png
// build/ est ignoré par git : rien à nettoyer, rien ne fuit dans test/.
//
// Limites : Roboto remplace Outfit tant qu'elle n'est pas embarquée (métriques
// proches, pas identiques) ; pas d'emoji ; les plugins natifs appelés au build
// doivent être mockés via `prepare` (cf. test/support/platform_mocks.dart).

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:an_ki/app/router/app_router.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/themes.dart';
import 'package:an_ki/features/auth/domain/biometric_lock.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../test/support/fake_providers.dart';
import '../../../test/support/network_image_mock.dart';

// ═══ SCÈNES — la seule partie à adapter ═════════════════════════════════════
//
// Une scène = un état d'écran. `act` joue une interaction avant la capture
// (ouvrir une sheet, scroller, saisir du texte…). `prepare` installe des mocks
// de plugins. Variantes par défaut : light, dark, light-text200 ; ajouter
// UiVariant.compact (360×640) pour traquer les débordements.
//
// Recettes (ajouter l'import de l'écran) :
//   onglet      → build: () => const AppAt(AppRoutes.scanner)   // l'app routée, barre comprise
//   calendrier  → act: (t) => t.tap(find.byIcon(Icons.calendar_month_rounded))
//   chargement  → overrides: sampleOverrides(isLoading: true)
//   paramètres  → build: () => const SettingsScreen(),   // features/settings/screens/
//                 prepare: () => FakeBiometricChannels().install()   // ../../../test/support/platform_mocks.dart
//   connexion   → build: () => const AuthChoiceScreen()
//   recherche   → act: (t) => t.enterText(find.byType(TextField).first, 'Lé')
//   scroll      → act: (t) => t.drag(find.byType(Scrollable).first, const Offset(0, -400))

final List<UiScene> scenes = [
  UiScene(
    name: 'home',
    build: () => const AppAt(AppRoutes.birthdays),
    overrides: sampleOverrides(),
  ),
  UiScene(
    name: 'home_empty',
    build: () => const AppAt(AppRoutes.birthdays),
    overrides: sampleOverrides(birthdays: const []),
  ),
  UiScene(
    name: 'birthday_form',
    build: () => const AppAt(AppRoutes.birthdays),
    overrides: sampleOverrides(),
    act: (tester) => tester.tap(find.byIcon(Icons.add_rounded).first),
  ),
];

void main() => runUiSnapshots(scenes);

// ═══ DONNÉES D'EXEMPLE — réalistes, relatives à aujourd'hui ══════════════════

final List<BirthdayCategory> sampleCategories = [
  BirthdayCategory(
    id: 'family',
    name: 'family',
    icon: Icons.family_restroom_rounded.codePoint,
  ),
  BirthdayCategory(
    id: 'friend',
    name: 'friend',
    icon: Icons.favorite_rounded.codePoint,
  ),
  BirthdayCategory(
    id: 'colleague',
    name: 'colleague',
    icon: Icons.work_rounded.codePoint,
  ),
];

/// Anniversaires répartis dans le temps : aujourd'hui, cette semaine, ce mois, plus tard.
List<Birthday> sampleBirthdays() {
  final today = DateUtils.dateOnly(DateTime.now());
  Birthday person(
    String id,
    String name,
    String surname, {
    required int inDays,
    required int turning,
    List<String> categories = const [],
  }) {
    final next = today.add(Duration(days: inDays));
    return Birthday(
      id: id,
      name: name,
      surname: surname,
      date: BirthDate.fromDate(
        DateTime(next.year - turning, next.month, next.day),
      ),
      categories: categories,
    );
  }

  return [
    person(
      '1',
      'Léa',
      'Martin',
      inDays: 0,
      turning: 29,
      categories: ['friend'],
    ),
    person(
      '2',
      'Hugo',
      'Bernard',
      inDays: 3,
      turning: 34,
      categories: ['colleague'],
    ),
    person(
      '3',
      'Chloé',
      'Dubois',
      inDays: 12,
      turning: 8,
      categories: ['family'],
    ),
    person(
      '4',
      'Louis',
      'Petit',
      inDays: 45,
      turning: 61,
      categories: ['family'],
    ),
    person(
      '5',
      'Inès',
      'Moreau',
      inDays: 130,
      turning: 25,
      categories: ['friend', 'colleague'],
    ),
    person('6', 'Gabriel', 'Laurent', inDays: 280, turning: 42),
  ];
}

/// Overrides Riverpod complets : utilisateur connecté, catégories, anniversaires.
List<Override> sampleOverrides({
  List<Birthday>? birthdays,
  bool isLoading = false,
  List<BirthdayCategory>? categories,
}) {
  final cats = categories ?? sampleCategories;
  return [
    authAccessProvider.overrideWithValue(AuthAccess.granted),
    currentUidProvider.overrideWithValue('fake-uid'),
    userProfileProvider.overrideWithValue(
      AsyncData(
        UserProfile(
          id: 'fake-uid',
          name: 'Camille',
          surname: 'Durand',
          pseudo: 'Camille',
          categories: [for (final c in cats) c.id],
          isDark: false,
          locale: 'fr',
        ),
      ),
    ),
    birthdaysProvider.overrideWithValue(
      isLoading
          ? const AsyncLoading()
          : AsyncData(birthdays ?? sampleBirthdays()),
    ),
    savedBooksProvider.overrideWithValue(const AsyncData([])),
    categoryRepositoryProvider.overrideWithValue(
      RecordingCategoryRepository(cats),
    ),
    userRepositoryProvider.overrideWithValue(FakeUserRepository()),
    birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
    bookRepositoryProvider.overrideWithValue(FakeBookRepository()),
  ];
}

// ═══ MOTEUR — inutile de modifier en dessous ══════════════════════════════════

/// L'app routée (onglets, barre du bas), ouverte sur [location] ; l'accès est
/// accordé par [sampleOverrides].
class AppAt extends ConsumerStatefulWidget {
  const AppAt(this.location, {super.key});

  final String location;

  @override
  ConsumerState<AppAt> createState() => _AppAtState();
}

class _AppAtState extends ConsumerState<AppAt> {
  @override
  void initState() {
    super.initState();
    ref.read(appRouterProvider).go(widget.location);
  }

  @override
  Widget build(BuildContext context) =>
      Router.withConfig(config: ref.watch(appRouterProvider));
}

/// Un état d'écran à capturer.
class UiScene {
  const UiScene({
    required this.name,
    required this.build,
    this.overrides = const [],
    this.prepare,
    this.act,
    this.variants = const [
      UiVariant.light,
      UiVariant.dark,
      UiVariant.largeText,
    ],
    this.size = const Size(412, 915),
    this.locale = const Locale('fr'),
  });

  final String name;
  final Widget Function() build;
  final List<Override> overrides;
  final void Function()? prepare;
  final Future<void> Function(WidgetTester tester)? act;
  final List<UiVariant> variants;
  final Size size;
  final Locale locale;
}

/// Une variante de rendu : thème × échelle de texte × taille d'écran.
class UiVariant {
  const UiVariant(
    this.label, {
    this.brightness = Brightness.light,
    this.textScale = 1.0,
    this.size,
    this.auditContrast = true,
    this.auditTargets = false,
  });

  final String label;
  final Brightness brightness;
  final double textScale;
  final Size? size;
  final bool auditContrast;
  final bool auditTargets;

  static const light = UiVariant('light', auditTargets: true);
  static const dark = UiVariant('dark', brightness: Brightness.dark);
  static const largeText = UiVariant(
    'light-text200',
    textScale: 2.0,
    auditContrast: false,
  );
  static const darkLargeText = UiVariant(
    'dark-text200',
    brightness: Brightness.dark,
    textScale: 2.0,
    auditContrast: false,
  );
  static const compact = UiVariant(
    'compact-360x640',
    size: Size(360, 640),
    textScale: 1.3,
    auditContrast: false,
  );
}

const String _label = String.fromEnvironment(
  'UI_SNAPSHOT_LABEL',
  defaultValue: 'current',
);
const double _dpr = 2.0;

// Barre de statut et barre de navigation gestuelle simulées (vérifie SafeArea).
const FakeViewPadding _systemBars = FakeViewPadding(
  top: 32 * _dpr,
  bottom: 24 * _dpr,
);

void runUiSnapshots(List<UiScene> scenes) {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final brandFontsLoaded = await _warmUpTheme();
    await _loadFonts(standInForThemeFonts: !brandFontsLoaded);
  });

  for (final scene in scenes) {
    testWidgets('ui snapshot · ${scene.name}', (tester) async {
      final semantics = tester.ensureSemantics();
      final report = <String>[];
      final shots = <(UiVariant, ui.Image)>[];
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      // Les erreurs de rendu sont collectées pour le rapport au lieu de faire échouer la capture.
      FlutterError.onError = errors.add;
      // En test, Flutter dessine les ombres Material comme un contour noir :
      // on les rend réalistes le temps de la capture, puis on restaure.
      final disableShadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        scene.prepare?.call();
        await mockNetworkImages(() async {
          for (final variant in scene.variants) {
            final image = await _shoot(tester, scene, variant, report, errors);
            shots.add((variant, image));
          }
        });
      } finally {
        FlutterError.onError = originalOnError;
        debugDisableShadows = disableShadows;
      }

      final sheet = await _write(tester, scene, shots, report);
      semantics.dispose();
      print(
        [
          '',
          '── ${scene.name} → $sheet',
          if (report.isEmpty) '   ✓ aucun problème détecté' else ...report,
        ].join('\n'),
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}

Future<ui.Image> _shoot(
  WidgetTester tester,
  UiScene scene,
  UiVariant variant,
  List<String> report,
  List<FlutterErrorDetails> errors,
) async {
  final size = variant.size ?? scene.size;
  tester.view
    ..physicalSize = size * _dpr
    ..devicePixelRatio = _dpr
    ..padding = _systemBars
    ..viewPadding = _systemBars;
  tester.platformDispatcher.platformBrightnessTestValue = variant.brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  errors.clear();
  final boundary = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: ProviderScope(
        key: UniqueKey(),
        overrides: scene.overrides,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: variant.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          locale: scene.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(variant.textScale)),
            child: child!,
          ),
          home: scene.build(),
        ),
      ),
    ),
  );
  await _settle(tester);
  if (scene.act != null) {
    await scene.act!(tester);
    await _settle(tester);
  }
  await _decodeImages(tester);

  _reportErrors(variant, errors, report);
  if (variant.auditTargets) {
    await _audit(
      tester,
      variant,
      'cibles tactiles < 48dp',
      androidTapTargetGuideline,
      report,
    );
    await _audit(
      tester,
      variant,
      'éléments tactiles sans libellé',
      labeledTapTargetGuideline,
      report,
    );
  }
  if (variant.auditContrast) {
    await _audit(
      tester,
      variant,
      'contraste (heuristique, à confirmer)',
      textContrastGuideline,
      report,
    );
  }

  final image = await tester.runAsync(
    () =>
        (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(pixelRatio: _dpr),
  );
  return image!;
}

// Fige les animations : settle borné, puis instant fixe si animation infinie (spinner).
Future<void> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  } on FlutterError {
    await tester.pump(const Duration(milliseconds: 600));
  }
}

// Les images (assets, base64, réseau mocké) ne se décodent qu'en vrai async.
Future<void> _decodeImages(WidgetTester tester) async {
  final pending = <(ImageProvider, Element)>[
    for (final element in find.byType(Image).evaluate())
      ((element.widget as Image).image, element),
    for (final element in find.byType(DecoratedBox).evaluate())
      if ((element.widget as DecoratedBox).decoration case BoxDecoration(
        image: DecorationImage(:final image),
      ))
        (image, element),
  ];
  if (pending.isEmpty) return;
  await tester.runAsync(() async {
    for (final (provider, element) in pending) {
      await precacheImage(provider, element);
    }
  });
  await tester.pump();
}

// Une ligne par erreur distincte : message + emplacement dans lib/.
void _reportErrors(
  UiVariant variant,
  List<FlutterErrorDetails> errors,
  List<String> report,
) {
  final seen = <String>{};
  for (final details in errors) {
    final message = _firstLine(details.exceptionAsString());
    final where = RegExp(r'(lib/[\w/]+\.dart):(\d+)')
        .firstMatch(details.toString());
    final line = where == null ? message : '$message — ${where[1]}:${where[2]}';
    if (seen.add(line)) report.add('   ✗ [${variant.label}] $line');
  }
  errors.clear();
}

Future<void> _audit(
  WidgetTester tester,
  UiVariant variant,
  String name,
  AccessibilityGuideline guideline,
  List<String> report,
) async {
  final evaluation = await guideline.evaluate(tester);
  if (evaluation.passed) return;
  // Le verdict suit le nœud sur la même ligne (« ): expected… ») ou la suivante.
  final lines = (evaluation.reason ?? '')
      .split('\n')
      .map((l) => l.trim())
      .toList();
  final issues = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].startsWith('SemanticsNode')) continue;
    final split = lines[i].lastIndexOf('): ');
    final verdict = split >= 0
        ? lines[i].substring(split + 3)
        : (i + 1 < lines.length ? lines[i + 1] : '');
    try {
      issues.add(_compactNode(lines[i], verdict));
    } on Object {
      // Format inattendu : le verdict brut reste plus utile qu'un crash.
      issues.add(verdict);
    }
  }
  // Contraste : les ratios proches du seuil sont les plus souvent réels ; sous
  // ~2:1 il s'agit en général d'un fond composite mal échantillonné.
  double ratio(String issue) =>
      double.tryParse(
        RegExp(r'contraste (\d+(?:\.\d+)?)').firstMatch(issue)?[1] ?? '',
      ) ??
      double.infinity;
  issues.sort((a, b) => ratio(b).compareTo(ratio(a)));
  const maxLines = 6;
  report.add('   ✗ [${variant.label}] $name (${issues.length})');
  report.addAll(issues.take(maxLines).map((l) => '       · $l'));
  if (issues.length > maxLines) {
    report.add('       · … +${issues.length - maxLines}');
  }
}

// Nœud sémantique + verdict → « @(x,y) l×h "libellé" — problème ».
String _compactNode(String node, String verdict) {
  int n(String? v) => double.parse(v!).round();
  const number = r'(-?\d+(?:\.\d+)?)';
  final rect = RegExp('Rect\\.fromLTRB\\($number, $number, $number, $number\\)')
      .firstMatch(node);
  final label = RegExp(r'label: "([^"]*)"').firstMatch(node)?[1];
  final where = rect == null
      ? ''
      : '@(${n(rect[1])},${n(rect[2])}) '
            '${n(rect[3]) - n(rect[1])}×${n(rect[4]) - n(rect[2])} ';
  final target = RegExp('but found Size\\($number, $number\\)')
      .firstMatch(verdict);
  final contrast = RegExp(
    'at least $number but found $number(?: for a font size of $number)?',
  ).firstMatch(verdict);
  final problem = switch (verdict) {
    _ when target != null => 'cible ${n(target[1])}×${n(target[2])} < 48×48',
    _ when verdict.contains('semantic label') =>
      'aucun libellé lu par TalkBack',
    _ when contrast != null =>
      'contraste ${contrast[2]} < ${contrast[1]}'
          '${contrast[3] == null ? '' : ' (texte ${n(contrast[3])}px)'}',
    _ => verdict,
  };
  return '$where${label == null ? '' : '"$label" '}— $problem';
}

Future<String> _write(
  WidgetTester tester,
  UiScene scene,
  List<(UiVariant, ui.Image)> shots,
  List<String> report,
) async {
  final root = 'build/ui_snapshots/$_label';
  final sheetPath = '$root/${scene.name}.png';
  await tester.runAsync(() async {
    await Directory('$root/${scene.name}').create(recursive: true);
    for (final (variant, image) in shots) {
      await File('$root/${scene.name}/${variant.label}.png')
          .writeAsBytes(await _png(image));
    }
    await File(sheetPath).writeAsBytes(await _png(await _contactSheet(shots)));
    await File('$root/${scene.name}.txt')
        .writeAsString(report.isEmpty ? 'OK' : report.join('\n'));
  });
  return File(sheetPath).absolute.path;
}

// Planche contact à l'échelle 1x : variantes côte à côte, libellées.
Future<ui.Image> _contactSheet(List<(UiVariant, ui.Image)> shots) {
  const gap = 16.0;
  const header = 32.0;
  final sizes = [
    for (final (_, image) in shots)
      Size(image.width / _dpr, image.height / _dpr),
  ];
  final width = sizes.fold<double>(gap, (w, s) => w + s.width + gap);
  final height = header + sizes.map((s) => s.height).reduce(math.max) + gap;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawColor(const Color(0xFF3C4043), BlendMode.src);
  var x = gap;
  for (var i = 0; i < shots.length; i++) {
    final (variant, image) = shots[i];
    final paragraph =
        (ui.ParagraphBuilder(
                ui.ParagraphStyle(fontFamily: 'Roboto', fontSize: 14),
              )
              ..pushStyle(ui.TextStyle(color: const Color(0xFFFFFFFF)))
              ..addText(variant.label))
            .build()
          ..layout(ui.ParagraphConstraints(width: sizes[i].width));
    canvas
      ..drawParagraph(paragraph, Offset(x, 8))
      ..drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        Offset(x, header) & sizes[i],
        Paint()..filterQuality = FilterQuality.medium,
      );
    x += sizes[i].width + gap;
  }
  return recorder.endRecording().toImage(width.ceil(), height.ceil());
}

Future<List<int>> _png(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();

String _firstLine(String text) => text
    .split('\n')
    .map((l) => l.trim())
    .firstWhere((l) => l.isNotEmpty, orElse: () => text);

// Construit AppTheme hors fake-async. Sans réseau, google_fonts échoue en
// silence ; retourne true seulement si les polices du thème sont embarquées.
Future<bool> _warmUpTheme() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {};
  try {
    await GoogleFonts.pendingFonts([AppTheme.light, AppTheme.dark]);
    return true;
  } catch (_) {
    return false;
  } finally {
    debugPrint = originalDebugPrint;
  }
}

// En test, toute police inconnue s'affiche en carrés (police « FlutterTest »).
// 1) on charge les polices déclarées dans le pubspec (dont MaterialIcons) ;
// 2) pour chaque famille du thème non embarquée (ex. « Outfit_700 » de
//    google_fonts), on enregistre Roboto du SDK à la graisse la plus proche.
Future<void> _loadFonts({required bool standInForThemeFonts}) async {
  final declared = <String>{};
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<Object?>;
  for (final entry in manifest.cast<Map<String, Object?>>()) {
    final family = entry['family']! as String;
    final loader = FontLoader(family);
    for (final font
        in (entry['fonts']! as List<Object?>).cast<Map<String, Object?>>()) {
      loader.addFont(rootBundle.load(font['asset']! as String));
    }
    await loader.load();
    declared.add(family);
  }

  final sdkFonts = _materialFontsDir();
  if (sdkFonts == null) {
    print(
      'ui snapshot: polices du SDK introuvables, le texte restera illisible.',
    );
    return;
  }
  Future<ByteData> roboto(FontWeight weight) async {
    final file = switch (weight.value) {
      <= 200 => 'roboto-thin.ttf',
      300 => 'roboto-light.ttf',
      400 => 'roboto-regular.ttf',
      500 => 'roboto-medium.ttf',
      600 || 700 => 'roboto-bold.ttf',
      _ => 'roboto-black.ttf',
    };
    return ByteData.sublistView(
      await File('${sdkFonts.path}/$file').readAsBytes(),
    );
  }

  final standIns = <String, Set<FontWeight>>{
    'Roboto': {...FontWeight.values},
  };
  if (standInForThemeFonts) {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final t = theme.textTheme;
      for (final style in [
        t.displayLarge,
        t.displayMedium,
        t.displaySmall,
        t.headlineLarge,
        t.headlineMedium,
        t.headlineSmall,
        t.titleLarge,
        t.titleMedium,
        t.titleSmall,
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelMedium,
        t.labelSmall,
        theme.appBarTheme.titleTextStyle,
      ]) {
        final family = style?.fontFamily;
        if (family == null || declared.contains(family)) continue;
        (standIns[family] ??= {}).add(style!.fontWeight ?? FontWeight.w400);
      }
    }
  }
  for (final MapEntry(key: family, value: weights) in standIns.entries) {
    if (declared.contains(family)) continue;
    final loader = FontLoader(family);
    for (final weight in weights) {
      loader.addFont(roboto(weight));
    }
    await loader.load();
  }
}

Directory? _materialFontsDir() {
  final root = Platform.environment['FLUTTER_ROOT'];
  final candidates = [
    if (root != null) '$root/bin/cache/artifacts/material_fonts',
    // flutter_tester vit dans <flutter>/bin/cache/artifacts/engine/<plateforme>/.
    '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts',
  ];
  for (final path in candidates) {
    if (Directory(path).existsSync()) return Directory(path);
  }
  return null;
}
