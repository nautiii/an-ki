import 'dart:ui';

import 'package:an_ki/core/providers/navigation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomBar extends ConsumerWidget {
  const BottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(navigationProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 32, right: 32, bottom: 20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? colorScheme.surface.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color:
                        isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : colorScheme.primary.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _BottomBarItem(
                      isSelected: selectedTab == MainTab.birthdays,
                      icon: Icons.cake_outlined,
                      activeIcon: Icons.cake_rounded,
                      label: "Anniversaires",
                      onTap: () {
                        if (selectedTab != MainTab.birthdays) {
                          HapticFeedback.selectionClick();
                          ref
                              .read(navigationProvider.notifier)
                              .setTab(MainTab.birthdays);
                        }
                      },
                    ),
                    _BottomBarItem(
                      isSelected: selectedTab == MainTab.scanner,
                      icon: Icons.qr_code_scanner_rounded,
                      activeIcon: Icons.qr_code_scanner_rounded,
                      label: "Scanner",
                      onTap: () {
                        if (selectedTab != MainTab.scanner) {
                          HapticFeedback.selectionClick();
                          ref
                              .read(navigationProvider.notifier)
                              .setTab(MainTab.scanner);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatefulWidget {
  final bool isSelected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  const _BottomBarItem({
    required this.isSelected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_BottomBarItem> createState() => _BottomBarItemState();
}

class _BottomBarItemState extends State<_BottomBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_BottomBarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.fastOutSlowIn,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isSelected ? 20 : 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color:
                widget.isSelected
                    ? colorScheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  widget.isSelected ? widget.activeIcon : widget.icon,
                  key: ValueKey(widget.isSelected),
                  color:
                      widget.isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  size: 24,
                ),
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.fastOutSlowIn,
                  child:
                      widget.isSelected
                          ? Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              widget.label,
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: -0.2,
                              ),
                            ),
                          )
                          : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
