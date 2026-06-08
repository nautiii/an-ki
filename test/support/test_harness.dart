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
  final String? initialRoute;
  final Map<String, WidgetBuilder>? routes;

  const TestHarness({
    super.key,
    required this.child,
    this.overrides = const [],
    this.home,
    this.initialRoute,
    this.routes,
  });

  @override
  Widget build(BuildContext context) {
    // If overrides are provided, we assume the test knows what it's doing.
    // Otherwise, we use the defaults.
    final List<dynamic> finalOverrides =
        overrides.isEmpty ? defaultTestOverrides : overrides;

    return ProviderScope(
      overrides: finalOverrides.map((e) => e as dynamic).toList().cast(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(body: home ?? child),
        initialRoute: home == null ? initialRoute : null,
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
    String? initialRoute,
    Map<String, WidgetBuilder>? routes,
    Size size = const Size(800, 1200),
  }) async {
    view.physicalSize = size;
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await pumpWidget(
      TestHarness(
        overrides: overrides,
        home: home,
        initialRoute: initialRoute,
        routes: routes,
        child: widget,
      ),
    );
  }
}
