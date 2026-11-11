import 'package:an_ki/features/books/domain/next_volume_status.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Les mots de l'étagère : ligne « Prochain », trous, libellé TalkBack d'une
/// série. Des fonctions pures sur les textes traduits et la langue, pour que
/// la ligne, la page de la série et leurs tests disent la même chose.
class ShelfWords {
  const ShelfWords(this.l10n, this.locale);

  final AppLocalizations l10n;

  /// Code de langue (`fr`, `en`) pour `DateFormat`.
  final String locale;

  /// Trous montrés en clair sur une ligne ; au-delà, « et N autres ».
  static const int shownHoles = 5;

  /// « 3 décembre » cette année, « 3 décembre 2027 » sinon ; « décembre 2026 »
  /// pour un mois seul.
  String releaseDate(ReleaseDate date, DateTime today) {
    final day = date.day;
    if (day == null) {
      return DateFormat.yMMMM(locale).format(DateTime(date.year, date.month));
    }
    final value = DateTime(date.year, date.month, day);
    return date.year == today.year
        ? DateFormat.MMMMd(locale).format(value)
        : DateFormat.yMMMMd(locale).format(value);
  }

  /// Ligne « Prochain » d'une série : « Prochain : tome 109 · 3 décembre »,
  /// « · paru », « · date inconnue » ; « Série terminée » pour une série
  /// close. Jamais de date inventée.
  String nextLine(ShelfEntry entry, DateTime today) {
    final number = upcomingVolumeNumber(entry);
    final status = nextVolumeStatus(entry, today);
    if (number == null || status == NextVolumeStatus.complete) {
      return l10n.seriesComplete;
    }
    return switch (status) {
      NextVolumeStatus.released => l10n.seriesNextReleased(number),
      NextVolumeStatus.announced => l10n.seriesNextOn(
        number,
        releaseDate(entry.series.next!.date!, today),
      ),
      _ => l10n.seriesNextUnknown(number),
    };
  }

  /// Texte de la carte « Prochain » de la page d'une série.
  String nextCard(ShelfEntry entry, DateTime today) {
    final number = upcomingVolumeNumber(entry);
    final status = nextVolumeStatus(entry, today);
    if (number == null || status == NextVolumeStatus.complete) {
      return l10n.nextCardComplete;
    }
    return switch (status) {
      NextVolumeStatus.released => l10n.nextCardReleased(number),
      NextVolumeStatus.announced => _announced(
        entry,
        today,
        day: (date) => l10n.nextCardAnnounced(number, date),
        month: (month) => l10n.nextCardAnnouncedMonth(number, month),
      ),
      _ => l10n.nextCardUnknown(number),
    };
  }

  /// D'où vient l'information du prochain tome, et quand : « selon la BnF ·
  /// vérifié le 8 nov. », « date saisie par vous le 8 nov. », ou « Rien à la
  /// BnF · vérifié le 8 nov. » quand elle n'a pas de notice. Null quand
  /// personne n'a cherché, pour une information périmée ou une série close.
  String? nextSource(ShelfEntry entry, DateTime today) {
    final info = entry.series.next;
    if (info == null || upcomingVolumeNumber(entry) != info.number) {
      return null;
    }
    final status = nextVolumeStatus(entry, today);
    if (status == NextVolumeStatus.complete) return null;
    final checked = DateFormat.MMMd(locale).format(info.checkedAt);
    if (status == NextVolumeStatus.unknown) {
      return info.source == ReleaseSource.bnf &&
              info.status == ReleaseStatus.unknown
          ? l10n.nextSourceNothing(checked)
          : null;
    }
    return switch (info.source) {
      ReleaseSource.user => l10n.nextSourceEntered(checked),
      ReleaseSource.bnf => l10n.nextSourceChecked(l10n.nextSourceBnf, checked),
      ReleaseSource.googleBooks => l10n.nextSourceChecked(
        l10n.nextSourceGoogleBooks,
        checked,
      ),
    };
  }

  String _announced(
    ShelfEntry entry,
    DateTime today, {
    required String Function(String date) day,
    required String Function(String month) month,
  }) {
    final date = entry.series.next!.date!;
    final text = releaseDate(date, today);
    return date.isMonthOnly ? month(text) : day(text);
  }

  /// « Il vous manque 13, 14 », « … et 4 autres » ; null sans trou.
  String? holesLine(List<int> holes) {
    if (holes.isEmpty) return null;
    final shown = holes.take(shownHoles).join(', ');
    final more = holes.length - shownHoles;
    return more > 0
        ? l10n.seriesHolesMore(shown, more)
        : l10n.seriesHoles(shown);
  }

  /// Ce que TalkBack lit d'une ligne de série, dans l'ordre de l'écran :
  /// « One Piece, dernier tome 108, prochain tome 109, sortie le 3 décembre,
  /// il vous manque les tomes 13 et 14 ».
  String seriesLabel(ShelfEntry entry, DateTime today) {
    final last = entry.last;
    return [
      entry.series.name,
      if (last != null) l10n.a11ySeriesLast(last) else l10n.a11ySeriesEmpty,
      _nextSpoken(entry, today),
      ?_holesSpoken(entry.holes),
    ].join(', ');
  }

  /// Les trous lus par TalkBack, plafonnés comme [holesLine].
  String? _holesSpoken(List<int> holes) {
    if (holes.isEmpty) return null;
    final more = holes.length - shownHoles;
    if (more > 0) {
      return l10n.a11ySeriesHolesMore(holes.take(shownHoles).join(', '), more);
    }
    return l10n.a11ySeriesHoles(holes.length, numberList(holes));
  }

  String _nextSpoken(ShelfEntry entry, DateTime today) {
    final number = upcomingVolumeNumber(entry);
    final status = nextVolumeStatus(entry, today);
    if (number == null || status == NextVolumeStatus.complete) {
      return l10n.a11yNextComplete;
    }
    return switch (status) {
      NextVolumeStatus.released => l10n.a11yNextReleased(number),
      NextVolumeStatus.announced => _announced(
        entry,
        today,
        day: (date) => l10n.a11yNextAnnounced(number, date),
        month: (month) => l10n.a11yNextAnnouncedMonth(number, month),
      ),
      _ => l10n.a11yNextUnknown(number),
    };
  }

  /// « 13 », « 13 et 14 », « 13, 14 et 15 ».
  String numberList(List<int> numbers) {
    if (numbers.length == 1) return '${numbers.single}';
    final head = numbers.sublist(0, numbers.length - 1).join(', ');
    return l10n.numberListLast(head, '${numbers.last}');
  }

  /// Titre d'un tome : le sien, sinon « Tome 12 » s'il est numéroté, sinon
  /// son ISBN (scanné hors ligne), sinon « Titre inconnu ».
  String volumeTitle(Volume volume) {
    final title = volume.title.trim();
    if (title.isNotEmpty) return title;
    if (volume.number case final number?) return l10n.seriesHoleChip(number);
    if (volume.isbn case final isbn?) return l10n.volumeIsbn(isbn);
    return l10n.bookUntitled;
  }

  /// Date de parution telle que la source la donne, lisible : « Paru le
  /// 28 juin 2013 », « Paru en juin 2013 », « Paru en 2013 » ; une forme
  /// inconnue est montrée telle quelle.
  String published(String raw) {
    final text = raw.trim();
    final date = ReleaseDate.tryParse(text);
    if (date == null) return l10n.volumePublishedIn(text);
    final day = date.day;
    if (day == null) {
      return l10n.volumePublishedIn(
        DateFormat.yMMMM(locale).format(DateTime(date.year, date.month)),
      );
    }
    return l10n.volumePublished(
      DateFormat.yMMMMd(locale).format(DateTime(date.year, date.month, day)),
    );
  }

  /// Pourquoi l'étagère n'a pas pu être lue : « Pas de connexion… » hors
  /// ligne, sinon le message générique (une lecture refusée n'est pas un
  /// problème de réseau).
  String loadError(Object? error) =>
      error == ShelfFailure.offline ? l10n.errorNetwork : l10n.errorUnknown;
}
