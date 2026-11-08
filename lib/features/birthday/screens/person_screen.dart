import 'dart:async';

import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/common/orbit_countdown.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_wisher.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:an_ki/features/birthday/widgets/birthday_display.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/birthday_reminders_picker.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:an_ki/features/birthday/widgets/wish_message_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Page d'une personne, à consulter avant de modifier : qui, quand, quel âge,
/// ses groupes, « Souhaiter » le jour J et le lendemain, ses rappels, son
/// message de vœu et les années où elle a été souhaitée. « Modifier » ouvre la fiche d'édition.
///
/// Supprimée pendant qu'elle est ouverte (depuis sa fiche), la page se ferme
/// et l'accueil propose « Annuler ».
class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.birthdayId});

  final String birthdayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final person = ref.watch(birthdayByIdProvider(birthdayId));
    ref.listen(birthdayByIdProvider(birthdayId), (previous, next) {
      final gone = previous?.value != null && next is AsyncData<Birthday?>;
      if (gone && next.value == null && context.canPop()) context.pop();
    });

    final Widget body = switch (person) {
      AsyncValue(hasError: true) => _Message(
        illustration: Icon(
          Icons.sync_problem_rounded,
          size: AppSpacing.xxl,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: l10n.personErrorTitle,
        message: l10n.errorNetwork,
        actionLabel: l10n.retry,
        onAction: () => ref.invalidate(birthdaysProvider),
      ),
      AsyncValue(hasValue: true, :final value) when value != null =>
        _PersonDetails(birthday: value),
      AsyncValue(hasValue: true) => _Message(
        illustration: Image.asset(AppAssets.moon),
        title: l10n.personMissingTitle,
        message: l10n.personMissingMessage,
        actionLabel: l10n.personBackHome,
        onAction: () => context.go(AppRoutes.birthdays),
      ),
      _ => const _LoadingHeader(),
    };

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (person.value case final birthday?)
            IconButton(
              onPressed: () =>
                  BirthdayFormSheet.show(context, birthdayToEdit: birthday),
              tooltip: l10n.editBirthday,
              icon: const Icon(Icons.edit_rounded),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

/// Contenu de la page : en-tête, vœu du jour, groupes, rappels, historique.
class _PersonDetails extends ConsumerWidget {
  const _PersonDetails({required this.birthday});

  final Birthday birthday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final categories = birthday.categoriesFrom(ref.watch(categoriesProvider));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xs,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      children: [
        _Header(birthday: birthday, today: today),
        if (birthday.canWish(today)) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: _WishRow(birthday: birthday, today: today),
          ),
        ],
        if (categories.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(context.l10n.groups),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final category in categories)
                Chip(
                  avatar: Icon(
                    category.iconData,
                    color: category.tones(context).color,
                  ),
                  label: Text(category.localizedName(context)),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        // Écrits aussitôt : la page n'a pas de bouton « Enregistrer ».
        BirthdayRemindersPicker(
          reminders: birthday.reminders,
          onChanged: (reminders) => unawaited(
            ref
                .read(birthdayEditorProvider.notifier)
                .setReminders(birthday.id, reminders),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        WishMessageSection(birthday: birthday),
        const SizedBox(height: AppSpacing.xl),
        _WishHistory(birthday: birthday, today: today),
      ],
    );
  }
}

/// Grand avatar cerclé de ses groupes, nom, orbite (l'âge à venir, sinon les
/// jours), compte à rebours et date de naissance.
class _Header extends ConsumerWidget {
  const _Header({required this.birthday, required this.today});

  final Birthday birthday;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final picture = birthday.picture;
    final days = birthday.daysUntilNext(today);
    // Sans année de naissance, aucun âge inventé : l'orbite porte les jours.
    final age = birthday.turningAge(today);
    final categories = birthday.categoriesFrom(ref.watch(categoriesProvider));
    // Les jours déjà dans l'orbite ne se répètent pas en dessous.
    final daysInOrbit = age == null && days > 0;

    return Column(
      children: [
        AnKiAvatar(
          name: birthday.fullName,
          image: picture != null ? MemoryImage(picture) : null,
          radius: 48,
          ringColors: [
            for (final category in categories) category.tones(context).color,
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          container: true,
          header: true,
          child: Text(
            birthday.fullName,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Countdown(
          days: days,
          age: age,
          wished: days == 0 && birthday.isWished(today),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!daysInOrbit) ...[
          Text(
            switch (days) {
              0 => l10n.today,
              1 => l10n.tomorrow,
              _ => l10n.inDays(days),
            },
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        Text(
          birthday.formattedDate(context),
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// L'orbite de l'en-tête (S3) autour de l'âge à venir ou, sans année de
/// naissance, des jours restants. Le jour J elle se boucle en lotus, en
/// menthe une fois le vœu fait ; sans âge, un gâteau ou une coche la
/// remplit. TalkBack lit « Aura 36 ans », « 36 ans » ou « Dans 12 jours ».
class _Countdown extends StatelessWidget {
  const _Countdown({
    required this.days,
    required this.age,
    required this.wished,
  });

  final int days;
  final int? age;

  /// L'anniversaire du jour est souhaité.
  final bool wished;

  /// Plus grande que celle du héros : l'orbite est le chiffre de la page.
  static const double _diameter = 80;

  /// Au-delà, le chiffre se réduit dans l'orbite plutôt que de l'élargir.
  static const double _maxTextScale = 1.5;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.ankiColors;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dayColor = wished ? colors.success.color : colors.blossom.color;
    final age = this.age;

    final Widget content;
    final String? label;
    if (age == null && days == 0) {
      // « Aujourd'hui » se lit juste en dessous.
      content = Icon(
        wished ? Icons.check_rounded : Icons.cake_rounded,
        color: dayColor,
      );
      label = null;
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${age ?? days}',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            age != null ? l10n.heroAgeUnit(age) : l10n.orbitDaysUnit(days),
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.2,
            ),
          ),
        ],
      );
      label = switch (age) {
        final years? when days == 0 => l10n.ageInYears(years),
        final years? => l10n.personTurning(years),
        null => l10n.countdownDays(days),
      };
    }

    final orbit = ExcludeSemantics(
      child: OrbitCountdown(
        daysLeft: days,
        diameter: _diameter,
        maxTextScale: _maxTextScale,
        arcColor: days == 0 ? dayColor : null,
        child: content,
      ),
    );
    // Pas de « Souhaité » ici, à l'inverse de l'agenda : la pastille sous
    // l'en-tête le dit déjà.
    return label == null
        ? orbit
        : Semantics(container: true, label: label, child: orbit);
  }
}

/// « Souhaiter » et « Déjà souhaité » le jour J et le lendemain, puis
/// « ✓ Souhaité » une fois le vœu fait.
class _WishRow extends ConsumerWidget {
  const _WishRow({required this.birthday, required this.today});

  final Birthday birthday;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Une seule feuille de partage à la fois.
    final sharing = ref.watch(
      birthdayWisherProvider.select((state) => state.isLoading),
    );
    if (birthday.isWished(today)) return const WishedPill();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Builder(
          builder: (buttonContext) => FilledButton.icon(
            onPressed: sharing
                ? null
                : () => wishBirthday(
                    context,
                    birthday,
                    origin: shareOriginOf(buttonContext),
                    belated: birthday.isBelated(today),
                  ),
            icon: const Icon(Icons.send_rounded),
            label: Text(context.l10n.wish),
          ),
        ),
        TextButton(
          onPressed: () => markWishedWithUndo(context, birthday),
          child: Text(context.l10n.alreadyWished),
        ),
      ],
    );
  }
}

/// Années où la personne a été souhaitée, de la plus récente à la plus
/// ancienne. Le vœu de l'anniversaire en cours ([BirthdayWishes.wishYear])
/// s'annule, avec « Annuler » pour revenir en arrière.
class _WishHistory extends StatelessWidget {
  const _WishHistory({required this.birthday, required this.today});

  final Birthday birthday;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final success = context.ankiColors.success;
    final years = [...birthday.wishedYears]..sort((a, b) => b - a);
    final current = birthday.wishYear(today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(l10n.personWishes),
        const SizedBox(height: AppSpacing.xs),
        if (years.isEmpty)
          Text(
            l10n.personNeverWished,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        for (final year in years)
          MergeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              child: Row(
                children: [
                  Icon(Icons.check_rounded, color: success.color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.personWishedIn(year),
                      style: textTheme.bodyLarge,
                    ),
                  ),
                  if (year == current)
                    TextButton(
                      onPressed: () => _unwish(context, year),
                      child: Text(l10n.personWishRemove),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Retire le vœu de [year], avec « Annuler » qui le remet.
  void _unwish(BuildContext context, int year) {
    // Lu maintenant : la ligne disparaît avec le vœu.
    final container = ProviderScope.containerOf(context, listen: false);
    final l10n = context.l10n;
    final accessible = MediaQuery.accessibleNavigationOf(context);
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      container
          .read(birthdayEditorProvider.notifier)
          .unmarkWished(birthday.id, year),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.personWishRemoved(year)),
          // Depuis Flutter 3.44, une snackbar avec action reste sinon ouverte.
          persist: false,
          duration: accessible ? undoDelay * 2 : undoDelay,
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => unawaited(
              container
                  .read(birthdayEditorProvider.notifier)
                  .markWished(birthday.id, year),
            ),
          ),
        ),
      );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Un nœud à lui : le titre seul est un en-tête, pas la section entière.
    return Semantics(
      container: true,
      header: true,
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Personne introuvable ou liste en erreur : ce qui se passe, et l'action
/// qui en sort ([actionLabel], [onAction]).
class _Message extends StatelessWidget {
  const _Message({
    required this.illustration,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final Widget illustration;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AnKiEmptyState(
          illustration: illustration,
          title: title,
          message: message,
          primaryLabel: actionLabel,
          onPrimary: onAction,
        ),
      ),
    );
  }
}

/// Squelette de l'en-tête, le temps que la liste arrive (ouverture depuis une
/// notification, au démarrage).
class _LoadingHeader extends StatelessWidget {
  const _LoadingHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xs,
        AppSpacing.gutter,
        0,
      ),
      child: Column(
        children: [
          SkeletonBox(height: 96, width: 96, radius: 48),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 28, width: 200),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 20, width: 140),
        ],
      ),
    );
  }
}
