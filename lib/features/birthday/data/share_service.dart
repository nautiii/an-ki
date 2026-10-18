import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Issue d'un partage, telle que le système la rapporte.
enum ShareOutcome {
  /// Une app a été choisie. Sur Android, rien ne dit que le message est
  /// vraiment parti.
  shared,

  /// La feuille a été fermée sans choisir d'app.
  dismissed,

  /// La feuille n'a pas pu s'ouvrir, ou le système ne sait pas dire ce qui
  /// s'est passé.
  unavailable,
}

/// Feuille de partage du système (`share_plus`) : le texte part vers l'app que
/// la personne choisit. Ni règle ni texte à elle.
class ShareService {
  const ShareService();

  /// Ouvre la feuille de partage avec [text] ; [origin] situe la bulle sur
  /// iPad (ignoré ailleurs).
  Future<ShareOutcome> shareText(String text, {Rect? origin}) async {
    final result = await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
    return switch (result.status) {
      ShareResultStatus.success => ShareOutcome.shared,
      ShareResultStatus.dismissed => ShareOutcome.dismissed,
      ShareResultStatus.unavailable => ShareOutcome.unavailable,
    };
  }
}

/// Partage système de l'app ; les tests le remplacent.
final shareServiceProvider = Provider<ShareService>(
  (ref) => const ShareService(),
);
