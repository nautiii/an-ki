import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dernière redirection hors d'un module désactivé (`moduleRedirect`) : le
/// module qu'un lien ou une notification voulait ouvrir. Événement ponctuel
/// (`state.md`), noté par le routeur et annoncé par la coquille, qui le vide
/// une fois sa snackbar montrée ; null sinon. Repart de rien à chaque
/// session.
class ModuleRedirectNotice extends Notifier<AppModule?> {
  @override
  AppModule? build() {
    ref.watch(currentUidProvider);
    return null;
  }

  /// Le routeur vient d'écarter un chemin de [module].
  void record(AppModule module) => state = module;

  /// La coquille l'a annoncé.
  void clear() => state = null;

  @override
  bool updateShouldNotify(AppModule? previous, AppModule? next) => true;
}

final moduleRedirectNoticeProvider =
    NotifierProvider<ModuleRedirectNotice, AppModule?>(
      ModuleRedirectNotice.new,
    );
