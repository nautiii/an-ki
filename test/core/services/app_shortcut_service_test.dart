import 'package:an_ki/core/services/app_shortcut_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_actions/quick_actions.dart';

/// Plugin simulé : garde le gestionnaire, relève les raccourcis posés, et
/// rend le raccourci [launch] à l'initialisation, comme le plugin Android.
class _FakeQuickActions extends Fake implements QuickActions {
  _FakeQuickActions({
    this.launch,
    this.failSet = false,
    this.failInitialize = false,
  });

  final String? launch;
  bool failSet;
  final bool failInitialize;
  QuickActionHandler? handler;
  int initializeCalls = 0;
  final List<List<ShortcutItem>> sets = [];

  @override
  Future<void> initialize(QuickActionHandler handler) async {
    initializeCalls++;
    if (failInitialize) throw Exception('no plugin');
    this.handler = handler;
    if (launch case final action?) handler(action);
  }

  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) async {
    if (failSet) throw Exception('no launcher');
    sets.add(items);
  }
}

const _add = AppShortcut(type: 'add', label: 'Ajouter', icon: 'ic_add');
const _search = AppShortcut(
  type: 'search',
  label: 'Rechercher',
  icon: 'ic_search',
);

void main() {
  group('launch action', () {
    test('gives the shortcut that launched the app once', () async {
      final service = AppShortcutService(_FakeQuickActions(launch: 'add'));
      await service.initialize();

      expect(service.takeLaunchAction(), 'add');
      expect(service.takeLaunchAction(), isNull);
    });

    test('is null when the app started otherwise', () async {
      final service = AppShortcutService(_FakeQuickActions());
      await service.initialize();

      expect(service.takeLaunchAction(), isNull);
    });

    test('keeps the action that arrived before anyone asked', () async {
      final plugin = _FakeQuickActions();
      final service = AppShortcutService(plugin);
      await service.initialize();
      final live = <String>[];
      service.actions.listen(live.add);

      plugin.handler!('search');
      await pumpEventQueue();

      expect(live, isEmpty);
      expect(service.takeLaunchAction(), 'search');
    });

    test('streams the shortcuts touched once the launch was taken', () async {
      final plugin = _FakeQuickActions(launch: 'add');
      final service = AppShortcutService(plugin);
      await service.initialize();
      final live = <String>[];
      service.actions.listen(live.add);
      service.takeLaunchAction();

      plugin.handler!('search');
      await pumpEventQueue();

      expect(live, ['search']);
      expect(service.takeLaunchAction(), isNull);
    });

    test('initializes the plugin only once', () async {
      final plugin = _FakeQuickActions(launch: 'add');
      final service = AppShortcutService(plugin);
      await service.initialize();
      await service.initialize();

      expect(plugin.initializeCalls, 1);
    });

    test('gives a launch delivered twice by the plugin once', () async {
      // À froid, le plugin Android peut rendre le raccourci à l'attache de
      // l'activité puis par getLaunchAction.
      final plugin = _FakeQuickActions(launch: 'add');
      final service = AppShortcutService(plugin);
      await service.initialize();
      final live = <String>[];
      service.actions.listen(live.add);
      plugin.handler!('add');

      expect(service.takeLaunchAction(), 'add');
      await pumpEventQueue();
      expect(live, isEmpty);
    });

    test('opens without shortcuts when the plugin fails', () async {
      final service = AppShortcutService(
        _FakeQuickActions(failInitialize: true),
      );

      await service.initialize();

      expect(service.takeLaunchAction(), isNull);
    });
  });

  group('setShortcuts', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('sets them in order with their Android icons', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final plugin = _FakeQuickActions();
      final service = AppShortcutService(plugin);

      await service.setShortcuts([_add, _search]);

      final items = plugin.sets.single;
      expect(items.map((item) => item.type), ['add', 'search']);
      expect(items.map((item) => item.localizedTitle), [
        'Ajouter',
        'Rechercher',
      ]);
      expect(items.map((item) => item.icon), ['ic_add', 'ic_search']);
    });

    test('leaves the Android icons out on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final plugin = _FakeQuickActions();
      final service = AppShortcutService(plugin);

      await service.setShortcuts([_add]);

      expect(plugin.sets.single.single.icon, isNull);
    });

    test('never sets the same list twice', () async {
      final plugin = _FakeQuickActions();
      final service = AppShortcutService(plugin);

      await service.setShortcuts([_add, _search]);
      await service.setShortcuts([_add, _search]);
      await service.setShortcuts([_add]);
      await service.setShortcuts(const []);
      await service.setShortcuts(const []);

      expect(plugin.sets.map((items) => items.length), [2, 1, 0]);
    });

    test('applies overlapping calls in order', () async {
      final plugin = _FakeQuickActions();
      final service = AppShortcutService(plugin);

      await Future.wait([
        service.setShortcuts([_add]),
        service.setShortcuts([_add]),
        service.setShortcuts([_add, _search]),
      ]);

      // En file : le second voit la liste posée par le premier.
      expect(plugin.sets.map((items) => items.length), [1, 2]);
    });

    test('tries a failed list again at the next call', () async {
      final plugin = _FakeQuickActions(failSet: true);
      final service = AppShortcutService(plugin);

      await service.setShortcuts([_add]);
      plugin.failSet = false;
      await service.setShortcuts([_add]);

      expect(plugin.sets, hasLength(1));
    });
  });

  test('a shortcut equals another with the same fields', () {
    expect(
      const AppShortcut(type: 'add', label: 'Ajouter', icon: 'ic_add'),
      _add,
    );
    expect(_add, isNot(_search));
    expect(_add.hashCode, _add.hashCode);
  });
}
