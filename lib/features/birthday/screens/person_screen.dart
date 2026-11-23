import 'dart:async';

import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/contact_links.dart';
import 'package:an_ki/features/birthday/providers/birthday_wisher.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:an_ki/features/birthday/widgets/person_contact_section.dart';
import 'package:an_ki/features/birthday/widgets/person_header.dart';
import 'package:an_ki/features/birthday/widgets/person_reminders_tile.dart';
import 'package:an_ki/features/birthday/widgets/wish_years.dart';
import 'package:an_ki/features/birthday/widgets/wish_bubble.dart';
import 'package:an_ki/features/birthday/widgets/wish_message_section.dart';
import 'package:flutter/material.dart';
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

/// Contenu de la page : l'en-tête (et le vœu du jour J dedans), le vœu en
/// retard du lendemain, les groupes, le message, les rappels, les années
/// souhaitées.
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
        PersonHeader(birthday: birthday, today: today),
        // Le lendemain, le vœu en retard sous la carte, sur la surface
        // calme : un oubli se rattrape sans fanfare.
        if (birthday.isBelated(today)) ...[
          const SizedBox(height: AppSpacing.md),
          _BelatedWish(birthday: birthday),
        ],
        if (categories.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _GroupChips(categories: categories),
        ],
        const SizedBox(height: AppSpacing.lg),
        // Appeler ou écrire, une fois la personne reliée à son contact ;
        // l'écart qui la suit est le sien (rien hors Android).
        PersonContactSection(birthday: birthday),
        // Le jour du vœu, la bulle montre déjà ce message et la feuille des
        // autres permet d'écrire le sien : pas deux fois le même texte.
        if (!birthday.canWish(today) || birthday.isWished(today)) ...[
          WishMessageSection(birthday: birthday),
          const SizedBox(height: AppSpacing.sm),
        ],
        // La tâche la plus rare, sur une ligne : le choix s'ouvre en feuille.
        PersonRemindersTile(birthday: birthday),
        if (birthday.wishedYears.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          WishYears(birthday: birthday, today: today),
        ],
      ],
    );
  }
}

/// Les groupes de la personne en puces tonales, chacune à sa teinte : un
/// toucher ouvre la recherche filtrée sur ce groupe.
class _GroupChips extends StatelessWidget {
  const _GroupChips({required this.categories});

  final List<BirthdayCategory> categories;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final category in categories)
          ActionChip(
            avatar: Icon(
              category.iconData,
              color: category.tones(context).color,
            ),
            label: Text(category.localizedName(context)),
            labelStyle: TextStyle(color: category.tones(context).onContainer),
            color: WidgetStatePropertyAll(category.tones(context).container),
            side: BorderSide.none,
            onPressed: () => unawaited(
              context.push(AppRoutes.searchInCategory(category.id)),
            ),
          ),
      ],
    );
  }
}

/// Le lendemain, tant qu'il n'est pas souhaité : le message dans sa bulle,
/// « Souhaiter » (« Message » par SMS, la personne reliée à son contact) et
/// « Déjà souhaité ». La bulle est en nuage : une information calme à côté
/// de l'action en lotus.
class _BelatedWish extends ConsumerWidget {
  const _BelatedWish({required this.birthday});

  final Birthday birthday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Une seule feuille de partage à la fois.
    final sharing = ref.watch(
      birthdayWisherProvider.select((state) => state.isLoading),
    );
    final scheme = Theme.of(context).colorScheme;
    final linked = ref.watch(contactLinkProvider(birthday.id)) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        WishBubble(
          birthday: birthday,
          fill: scheme.tertiaryContainer,
          onFill: scheme.onTertiaryContainer,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
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
                      ),
                icon: Icon(linked ? Icons.sms_rounded : Icons.send_rounded),
                label: Text(
                  linked ? context.l10n.contactMessage : context.l10n.wish,
                ),
              ),
            ),
            TextButton(
              onPressed: () => markWishedWithUndo(context, birthday),
              child: Text(context.l10n.alreadyWished),
            ),
          ],
        ),
      ],
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
      child: SkeletonBox(
        height: PersonHeader.skeletonHeight,
        radius: AppRadii.lg,
      ),
    );
  }
}
