import 'package:flutter/widgets.dart';

/// Ferme le clavier avant de quitter un écran.
extension FocusContextX on BuildContext {
  /// Rend le focus du champ en cours (une recherche) avant d'ouvrir une page
  /// ou une feuille : sans cela, la route le rend au retour et le clavier se
  /// rouvre tout seul.
  void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();
}
