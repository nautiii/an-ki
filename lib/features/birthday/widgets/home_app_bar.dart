import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/greeting_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Barre d'app de l'accueil, épinglée : salutation de l'heure et nom, puis
/// recherche, ajout et réglages (l'avatar).
class HomeAppBar extends ConsumerWidget {
  const HomeAppBar({super.key, required this.canSearch});

  /// Affiche la recherche : rien à chercher dans un carnet vide.
  final bool canSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final period = ref.watch(greetingProvider).name;
    final name = ref.watch(
      userProfileProvider.select((profile) => profile.value?.displayName),
    );

    return SliverAppBar(
      pinned: true,
      centerTitle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      titleSpacing: AppSpacing.gutter,
      title: Text(
        name == null ? l10n.greeting(period) : l10n.greetingName(period, name),
      ),
      actions: [
        if (canSearch)
          IconButton(
            onPressed: () => context.push(AppRoutes.search),
            tooltip: l10n.searchTooltip,
            icon: const Icon(Icons.search_rounded),
          ),
        IconButton.filledTonal(
          onPressed: () => BirthdayFormSheet.show(context),
          tooltip: l10n.addBirthday,
          icon: const Icon(Icons.add_rounded),
        ),
        IconButton(
          onPressed: () => context.push(AppRoutes.settings),
          tooltip: l10n.settings,
          icon: AnKiAvatar(name: name ?? '', radius: 16),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}
