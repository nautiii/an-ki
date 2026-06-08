import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/providers/home_view_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/features/user/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Header extends ConsumerWidget {
  final bool showViewToggle;

  const Header({super.key, this.showViewToggle = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider.select((value) => value.user));
    final viewType = ref.watch(homeViewProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.hello,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              user != null
                  ? (user.pseudo != null && user.pseudo!.isNotEmpty
                      ? user.pseudo!
                      : "${user.surname} ${user.name}")
                  : "...",
              style: textTheme.headlineMedium?.copyWith(fontSize: 26),
            ),
          ],
        ),
        Row(
          children: [
            if (showViewToggle) ...[
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(10),
                ),
                onPressed: () {
                  ref.read(homeViewProvider.notifier).toggle();
                },
                icon: Icon(
                  viewType == HomeViewType.list
                      ? Icons.calendar_month_rounded
                      : Icons.view_list_rounded,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHighest,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(10),
              ),
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  ),
              icon: Icon(Icons.settings_rounded, color: colorScheme.onSurface),
            ),
          ],
        ),
      ],
    );
  }
}
