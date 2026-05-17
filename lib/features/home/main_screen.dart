import 'package:an_ki/core/common/bottom_bar.dart';
import 'package:an_ki/core/providers/navigation_provider.dart';
import 'package:an_ki/features/birthday/home_page.dart';
import 'package:an_ki/features/book_scanner/screens/book_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(navigationProvider);

    return Scaffold(
      extendBody: true, // Permet au contenu de passer sous la BottomBar floue
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.02, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<MainTab>(selectedTab),
              child: _getScreen(selectedTab),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _getScreen(MainTab tab) {
    switch (tab) {
      case MainTab.birthdays:
        return const HomePage();
      case MainTab.scanner:
        return const BookScannerScreen();
    }
  }
}
