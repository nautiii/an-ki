import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/widgets/guest_backup_card.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_editor.dart';
import 'package:an_ki/features/birthday/providers/guest_backup_provider.dart';
import 'package:an_ki/features/birthday/providers/home_view_provider.dart';
import 'package:an_ki/features/birthday/widgets/agenda_list.dart';
import 'package:an_ki/features/birthday/widgets/belated_wish.dart';
import 'package:an_ki/features/birthday/widgets/birthday_calendar.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/home_app_bar.dart';
import 'package:an_ki/features/birthday/widgets/next_birthday.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Accueil : qui est le prochain, puis l'agenda par mois (ou le calendrier).
///
/// Une seule surface qui défile sous la barre d'app épinglée et sous la barre
/// de navigation flottante, dont le padding du bas réserve la place.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.notice});

  /// Avis d'une autre feature au-dessus du héros, dès que l'agenda a des
  /// anniversaires (les rappels désactivés) ; `app/router` le fournit, pour
  /// que `birthday` n'importe pas `reminders`. Il dit lui-même s'il a
  /// quelque chose à montrer, et porte l'écart qui le suit.
  final Widget? notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Les écritures sont optimistes (la feuille se ferme sans attendre) :
    // l'accueil, toujours monté dessous, annonce un échec tardif. Il remplace
    // le message en cours (« … supprimé ») que l'échec contredit.
    ref.listen(birthdayEditorProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.l10n.errorSavingBirthday)),
          );
      }
    });
    ref.listen(categoryEditorProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorSavingGroup)));
      }
    });
    final isLoading = ref.watch(birthdaysLoadingProvider);
    final hasBirthdays = ref.watch(
      birthdaysListProvider.select((birthdays) => birthdays.isNotEmpty),
    );
    final view = ref.watch(homeViewProvider);
    final backupCount = ref.watch(guestBackupOfferProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          HomeAppBar(canSearch: hasBirthdays),
          if (isLoading)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xs,
                AppSpacing.gutter,
                0,
              ),
              sliver: SliverToBoxAdapter(child: _HomeSkeleton()),
            )
          else if (!hasBirthdays)
            const SliverFillRemaining(hasScrollBody: false, child: _FirstRun())
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xs,
                AppSpacing.gutter,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    ?notice,
                    const NextBirthdayCard(),
                    // Hier encore à souhaiter : sous le héros, qui reste
                    // « qui est le prochain ».
                    const BelatedWishes(),
                    const SizedBox(height: AppSpacing.md),
                    _ViewSwitch(view: view),
                  ],
                ),
              ),
            ),
            if (view == HomeView.agenda) ...[
              const AgendaSliver(),
              // Invité dont l'agenda vaut la peine d'être gardé : la
              // sauvegarde, après le dernier mois, jamais en travers.
              if (backupCount != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.lg,
                    AppSpacing.gutter,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: GuestBackupCard(count: backupCount),
                  ),
                ),
            ] else
              // Marges réduites : des cases d'au moins 48 dp dès 360 dp.
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                  0,
                ),
                sliver: SliverToBoxAdapter(child: BirthdayCalendar()),
              ),
          ],
          // Place de la barre de navigation flottante, puis une respiration.
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.paddingOf(context).bottom + AppSpacing.md,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bascule Agenda | Calendrier, libellée plutôt qu'une icône seule.
class _ViewSwitch extends ConsumerWidget {
  const _ViewSwitch({required this.view});

  final HomeView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<HomeView>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: HomeView.agenda,
            icon: const Icon(Icons.view_agenda_rounded),
            label: Text(context.l10n.viewAgenda),
          ),
          ButtonSegment(
            value: HomeView.calendar,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(context.l10n.viewCalendar),
          ),
        ],
        selected: {view},
        onSelectionChanged: (selection) {
          HapticFeedback.selectionClick();
          ref.read(homeViewProvider.notifier).show(selection.single);
        },
      ),
    );
  }
}

/// Premier lancement : l'accueil vide est l'invitation à retrouver les
/// anniversaires du répertoire, le plus court chemin vers un agenda rempli ;
/// la saisie à la main reste à côté.
class _FirstRun extends StatelessWidget {
  const _FirstRun();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
      ),
      child: Center(
        child: AnKiEmptyState(
          illustration: Image.asset(AppAssets.moon),
          title: context.l10n.emptyBirthdaysTitle,
          message: context.l10n.emptyBirthdaysMessage,
          primaryLabel: context.l10n.chooseFromContacts,
          primaryIcon: Icons.contacts_rounded,
          onPrimary: () => context.push(AppRoutes.contactImport),
          secondaryLabel: context.l10n.addByHand,
          onSecondary: () => BirthdayFormSheet.show(context),
          // Ce que l'import lit, avant que la boîte système ne le demande.
          footer: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(Icons.lock_outline_rounded, size: 16, color: muted),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(
                  context.l10n.contactsPrivacy,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Squelette de l'accueil, à la forme du héros, de la bascule et des lignes.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SkeletonBox(
          height: NextBirthdayCard.skeletonHeight,
          radius: AppRadii.lg,
        ),
        const SizedBox(height: AppSpacing.md),
        const SkeletonBox(height: 40, radius: AppRadii.xl),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < 4; i++) ...[
          const SkeletonBox(height: 72, radius: AppRadii.lg),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}
