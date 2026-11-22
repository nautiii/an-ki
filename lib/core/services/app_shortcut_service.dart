import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

/// Raccourci du lanceur, proposé par un appui long sur l'icône de l'app.
///
/// Vit dans `core` pour que le service reste découplé des features : `app/`
/// décide des raccourcis et de leurs textes, le service les pose.
@immutable
class const AppShortcut({
  /// Identifiant du raccourci, rendu tel quel au toucher.
  required final String type,

  /// Libellé affiché, déjà traduit.
  required final String label,

  /// Nom de la ressource Android de son icône (`res/drawable`).
  required final String icon,
}) {
  @override
  bool operator ==(Object other) =>
      other is AppShortcut &&
      other.type == type &&
      other.label == label &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(type, label, icon);
}

/// Service des raccourcis du lanceur (plugin `quick_actions`) : pose ceux
/// qu'on lui donne, et rend ceux qu'on touche. Aucune règle ici : le quoi
/// vient de `app/`.
class AppShortcutService {
  @visibleForTesting
  AppShortcutService(this._plugin);

  AppShortcutService._() : _plugin = const QuickActions();

  static final AppShortcutService instance = AppShortcutService._();

  final QuickActions _plugin;

  bool _initialized = false;

  /// Raccourci qui a lancé l'app, gardé jusqu'à ce qu'on le demande.
  String? _launchAction;

  /// Le raccourci de lancement n'est rendu qu'une fois ; ceux qui suivent
  /// passent par [actions].
  bool _launchActionTaken = false;

  final _actions = StreamController<String>.broadcast();

  /// Poses en file : deux qui se chevauchent pourraient finir dans le
  /// désordre.
  Future<void> _queue = Future.value();

  /// Derniers raccourcis posés par cet isolate : une liste identique n'est
  /// pas reposée. La tâche de fond a le sien ; les deux calculent la liste
  /// par la même fonction de `app/`, avec la même langue.
  List<AppShortcut>? _last;

  /// Raccourcis touchés pendant que l'app tourne.
  Stream<String> get actions => _actions.stream;

  /// À appeler une seule fois avant `runApp` : le plugin rend alors le
  /// raccourci qui a lancé l'app ([takeLaunchAction]).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _plugin.initialize(_onAction);
    } catch (error) {
      // Sans raccourcis, l'app s'ouvre quand même.
      debugPrint('[AppShortcutService] initialize failed: $error');
    }
  }

  void _onAction(String type) {
    if (_launchActionTaken) {
      _actions.add(type);
    } else {
      _launchAction = type;
    }
  }

  /// Raccourci qui a lancé l'app, rendu une seule fois ; null si elle a
  /// démarré autrement.
  String? takeLaunchAction() {
    if (_launchActionTaken) return null;
    _launchActionTaken = true;
    final action = _launchAction;
    _launchAction = null;
    return action;
  }

  /// Remplace les raccourcis de l'app par [shortcuts], dans leur ordre (le
  /// premier au plus près de l'icône) ; une liste vide les retire tous. Ne
  /// fait rien si la liste n'a pas changé depuis la dernière pose.
  Future<void> setShortcuts(List<AppShortcut> shortcuts) {
    final next = _queue.then((_) => _apply(shortcuts));
    _queue = next;
    return next;
  }

  Future<void> _apply(List<AppShortcut> shortcuts) async {
    if (_last != null && listEquals(_last, shortcuts)) return;
    // Les noms d'icônes sont des ressources Android : iOS n'en a pas.
    final android = defaultTargetPlatform == TargetPlatform.android;
    try {
      await _plugin.setShortcutItems([
        for (final shortcut in shortcuts)
          ShortcutItem(
            type: shortcut.type,
            localizedTitle: shortcut.label,
            icon: android ? shortcut.icon : null,
          ),
      ]);
      _last = List.unmodifiable(shortcuts);
    } catch (error) {
      // Réessayé au prochain changement.
      debugPrint('[AppShortcutService] setShortcuts failed: $error');
    }
  }
}

/// Service des raccourcis de l'app. Le singleton ne sert qu'à
/// l'initialisation dans `main()` et à la tâche de fond : tout le reste lit
/// ce provider, que les tests remplacent.
final appShortcutServiceProvider = Provider<AppShortcutService>(
  (ref) => AppShortcutService.instance,
);
