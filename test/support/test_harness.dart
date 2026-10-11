import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_providers.dart';

/// A harness to wrap widgets for testing with a standard [ProviderScope] and [MaterialApp].
class TestHarness extends StatelessWidget {
  final Widget child;
  final List<dynamic> overrides;
  final Widget? home;
  final Map<String, WidgetBuilder>? routes;

  const TestHarness({
    super.key,
    required this.child,
    this.overrides = const [],
    this.home,
    this.routes,
  });

  @override
  Widget build(BuildContext context) {
    // If overrides are provided, we assume the test knows what it's doing.
    // Otherwise, we use the defaults.
    final List<dynamic> finalOverrides = overrides.isEmpty
        ? defaultTestOverrides
        : overrides;

    return ProviderScope(
      // Pas de nouvelle tentative automatique : un provider en erreur s'affiche
      // en erreur tout de suite, sans minuteurs de retry en attente.
      retry: (_, _) => null,
      overrides: finalOverrides.map((e) => e as dynamic).toList().cast(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(body: home ?? child),
        routes: routes ?? const {},
      ),
    );
  }
}

extension WidgetTesterExt on WidgetTester {
  Future<void> pumpHarness(
    Widget widget, {
    List<dynamic> overrides = const [],
    Widget? home,
    Map<String, WidgetBuilder>? routes,
  }) async {
    view.physicalSize = const Size(800, 1200);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await pumpWidget(
      TestHarness(
        overrides: overrides,
        home: home,
        routes: routes,
        child: widget,
      ),
    );
  }

  /// Contexte localisé (français, comme le harnais) pour tester une
  /// extension d'affichage — libellé, date — sans écran.
  Future<BuildContext> pumpLocalizedContext() async {
    late BuildContext captured;
    await pumpHarness(
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    );
    return captured;
  }
}
