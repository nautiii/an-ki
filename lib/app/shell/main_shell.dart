import 'package:an_ki/app/shell/navigation_provider.dart';
import 'package:an_ki/core/common/bottom_bar.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/book_scanner/screens/book_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coquille de l'app connectée : l'écran de l'onglet courant et la barre du
/// bas.
///
/// Vit dans `app/` : elle assemble les écrans de plusieurs features, ce
/// qu'aucune feature n'a le droit de faire.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(navigationProvider);

    return Scaffold(
      extendBody: true, // Permet au contenu de passer sous la BottomBar floue
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.01, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.99,
                      end: 1.0,
                    ).animate(animation),
                    child: child,
                  ),
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<MainTab>(selectedTab),
              child: switch (selectedTab) {
                MainTab.birthdays => const HomeScreen(),
                MainTab.scanner => const BookScannerScreen(),
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomBar(
              destinations: [
                BottomBarDestination(
                  icon: Icons.cake_outlined,
                  selectedIcon: Icons.cake_rounded,
                  label: context.l10n.tabBirthdays,
                ),
                BottomBarDestination(
                  icon: Icons.qr_code_scanner_rounded,
                  selectedIcon: Icons.qr_code_scanner_rounded,
                  label: context.l10n.tabScanner,
                ),
              ],
              selectedIndex: selectedTab.index,
              onSelected: (index) => ref
                  .read(navigationProvider.notifier)
                  .setTab(MainTab.values[index]),
            ),
          ),
        ],
      ),
    );
  }
}
