/// Idée cadeau, rattachée à une personne ou dans la boîte « à trier ».
///
/// Modèle de domaine : Dart pur, immuable, sans Firebase ni Flutter. La
/// conversion Firestore vit dans `data/`.
class const Idea({
  required final String id,
  required final String title,
  final String? personId,
  final String? note,
  required final DateTime createdAt,
}) {
  /// Copie modifiée. Un argument null signifie « inchangé » ; `clearX` vide
  /// un champ optionnel.
  Idea copyWith({
    String? title,
    String? personId,
    bool clearPersonId = false,
    String? note,
    bool clearNote = false,
  }) => Idea(
    id: id,
    title: title ?? this.title,
    personId: clearPersonId ? null : personId ?? this.personId,
    note: clearNote ? null : note ?? this.note,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Idea &&
      other.id == id &&
      other.title == title &&
      other.personId == personId &&
      other.note == note &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, title, personId, note, createdAt);
}

/// Saisie d'une idée avant enregistrement (formulaire → contrôleur → dépôt).
class const IdeaDraft({
  required final String title,
  final String? personId,
  final String? note,
}) {
  static const maxTitleLength = 120;

  String get normalizedTitle => title.trim();

  /// Règle métier partagée : l'UI s'en sert pour activer le bouton, le
  /// contrôleur la revérifie avant d'écrire.
  bool get isValid =>
      normalizedTitle.isNotEmpty && normalizedTitle.length <= maxTitleLength;
}

/// Règles de lecture sur une liste d'idées.
extension IdeaQueries on Iterable<Idea> {
  /// Idées d'une personne (null : idées non rattachées), les plus récentes
  /// d'abord.
  List<Idea> forPerson(String? personId) =>
      where((idea) => idea.personId == personId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
