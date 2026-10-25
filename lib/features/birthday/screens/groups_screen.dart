import 'dart:async';

import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday_groups.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/providers/group_entries.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:an_ki/features/birthday/widgets/group_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Groupes de l'utilisateur, ouverts depuis Réglages › Anniversaires : dans
/// l'ordre de la ligne de puces, chacun avec son nombre de personnes. Ceux
/// proposés à tous sont verrouillés.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entries = ref.watch(groupEntriesProvider);

    final Widget body = switch (entries) {
      AsyncValue(hasError: true) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AnKiEmptyState(
            illustration: Icon(
              Icons.sync_problem_rounded,
              size: AppSpacing.xxl,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: l10n.groupsErrorTitle,
            message: l10n.errorNetwork,
            primaryLabel: l10n.retry,
            onPrimary: () => ref
              ..invalidate(sharedCategoriesProvider)
              ..invalidate(ownCategoriesProvider),
          ),
        ),
      ),
      AsyncData(:final value) => _GroupList(entries: value),
      _ => const _LoadingRows(),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.groups)),
      body: SafeArea(top: false, child: body),
    );
  }
}

/// Les groupes dans un même conteneur arrondi, séparés d'un filet.
class _GroupList extends StatelessWidget {
  const _GroupList({required this.entries});

  final List<GroupEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, entry) in entries.indexed) ...[
                if (index > 0)
                  const Divider(
                    height: 1,
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md,
                  ),
                _GroupTile(entry: entry),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Un groupe : sa pastille à sa teinte, son nom, ses personnes ; un cadenas
/// pour un groupe proposé à tous.
class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.entry});

  final GroupEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final group = entry.category;
    final tones = group.tones(context);
    final locked = entry.kind == GroupKind.preset;
    final people = l10n.groupPeople(entry.count);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tones.container,
        child: Icon(group.iconData, color: tones.onContainer),
      ),
      title: Text(group.localizedName(context)),
      subtitle: Text(locked ? '$people · ${l10n.groupPreset}' : people),
      trailing: Icon(
        locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
      ),
      onTap: switch (entry.kind) {
        GroupKind.own => () => unawaited(GroupEditSheet.show(context, group)),
        GroupKind.shared || GroupKind.preset => null,
      },
    );
  }
}

/// Squelette de la liste pendant le chargement : la forme des lignes.
class _LoadingRows extends StatelessWidget {
  const _LoadingRows();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.xs,
      ),
      children: [
        for (var i = 0; i < 5; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                SkeletonBox(height: 40, width: 40, radius: 20),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 16, width: 160),
                      SizedBox(height: AppSpacing.xs),
                      SkeletonBox(height: 12, width: 96),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
