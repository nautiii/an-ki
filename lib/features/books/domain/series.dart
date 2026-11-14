import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:flutter/foundation.dart';

/// Une série de livres que l'utilisateur suit (One Piece, Blacksad…).
///
/// Modèle de domaine : Dart pur, immuable. Le mapping Firestore vit dans le
/// repository.
class const Series({
  required final String id,
  required final String name,

  /// Clés de rapprochement (voir `seriesKey`) : celle du nom, plus celles de
  /// ses anciens noms après un renommage ou une fusion. Un scan est rangé dans
  /// la série qui porte la clé de son nom.
  required final List<String> keys,

  /// Vrai quand la série est terminée et que l'utilisateur l'a close : plus
  /// rien à acheter hors trous, plus de date à chercher.
  required final bool complete,

  /// Ce qu'on sait du prochain tome ; null tant que personne n'a cherché.
  final NextVolumeInfo? next,

  /// Image de la série cherchée chez AniList (D15) ; null tant que personne
  /// n'a cherché.
  final SeriesArtwork? artwork,
}) {
  @override
  bool operator ==(Object other) =>
      other is Series &&
      other.id == id &&
      other.name == name &&
      listEquals(other.keys, keys) &&
      other.complete == complete &&
      other.next == next &&
      other.artwork == artwork;

  @override
  int get hashCode =>
      Object.hash(id, name, Object.hashAll(keys), complete, next, artwork);
}

/// Ce qu'AniList a répondu pour l'image d'une série, gardé sur la série pour
/// ne pas redemander à chaque ouverture et pour se lire hors ligne.
class const SeriesArtwork({
  /// Adresse de l'image ; null quand aucun titre ne correspondait.
  final String? url,

  /// Nom de la série au moment de la recherche : un renommage la relance.
  required final String forName,

  /// Quand AniList a été interrogé.
  required final DateTime checkedAt,
}) {
  @override
  bool operator ==(Object other) =>
      other is SeriesArtwork &&
      other.url == url &&
      other.forName == forName &&
      other.checkedAt == checkedAt;

  @override
  int get hashCode => Object.hash(url, forName, checkedAt);
}

/// Ce qu'une source dit du prochain tome d'une série, gardé sur la série pour
/// être lu hors ligne et synchronisé.
class const NextVolumeInfo({
  /// Numéro du tome concerné.
  required final int number,

  /// Ce que la source affirme de ce tome.
  required final ReleaseStatus status,

  /// Date de sortie, au jour ou au mois ; null quand la source n'en donne
  /// pas. Jamais estimée d'après le rythme de la série.
  final ReleaseDate? date,

  /// D'où vient l'information.
  required final ReleaseSource source,

  /// Quand la source a été interrogée (ou l'utilisateur a saisi la date).
  required final DateTime checkedAt,
}) {
  @override
  bool operator ==(Object other) =>
      other is NextVolumeInfo &&
      other.number == number &&
      other.status == status &&
      other.date == date &&
      other.source == source &&
      other.checkedAt == checkedAt;

  @override
  int get hashCode => Object.hash(number, status, date, source, checkedAt);
}

/// Ce qu'une source affirme d'un tome : le nom est stocké tel quel.
enum ReleaseStatus {
  /// Le tome est paru (la BnF en a une notice, ou sa date est passée).
  released,

  /// Le tome est annoncé pour plus tard ; la date accompagne.
  announced,

  /// La source n'en sait rien.
  unknown,
}

/// Qui a fourni l'information sur le prochain tome ; le nom est stocké tel
/// quel.
enum ReleaseSource { bnf, googleBooks, user }
