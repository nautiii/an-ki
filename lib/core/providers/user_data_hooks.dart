import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Efface toutes les données d'un module pour le compte [uid] (suppression du
/// compte). Lu sur le serveur : hors ligne, il échoue avant de commencer.
typedef UserDataEraser = Future<void> Function(String uid);

/// Reprend pour le compte [targetUid], qui vient de s'ouvrir, les données
/// qu'un invité a marquées pour lui.
typedef GuestDataTakeOver = Future<void> Function(String targetUid);

/// Marque les données de l'invité [guestUid] pour le compte Google [email]
/// (lues sur le serveur, marques attendues jusqu'à son accusé), et renvoie de
/// quoi les reprendre une fois ce compte ouvert.
typedef GuestDataTransfer = Future<GuestDataTakeOver> Function(
  String guestUid,
  String email,
);

/// Effaceurs des données de chaque module, actif ou non : `app/` les fournit
/// depuis son registre, les features qui suppriment un compte ignorent les
/// modules. Sans eux, la suppression échoue plutôt que d'oublier des données.
final userDataErasersProvider = Provider<List<UserDataEraser>>(
  (ref) => throw UnimplementedError(
    'userDataErasersProvider is overridden by app/.',
  ),
);

/// Reprises d'invité de chaque module, actif ou non, hormis celles qu'une
/// feature fait elle-même (les anniversaires et leurs doublons) : `app/` les
/// fournit depuis son registre.
final guestDataTransfersProvider = Provider<List<GuestDataTransfer>>(
  (ref) => throw UnimplementedError(
    'guestDataTransfersProvider is overridden by app/.',
  ),
);
