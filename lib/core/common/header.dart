import 'package:an_ki/data/models/user_model.dart';
import 'package:an_ki/providers/theme_provider.dart';
import 'package:an_ki/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    final UserModel? user = context.watch<UserProvider>().user;
    final colorScheme = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDark = themeProvider.isDark ||
        (themeProvider.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Bonjour 👋", style: TextStyle(color: colorScheme.onSurfaceVariant)),
            user == null
                ? const Center(child: CircularProgressIndicator())
                : Text(
                  "${user.surname} ${user.name}",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
          ],
        ),
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(10),
          ),
          onPressed: () => context.read<ThemeProvider>().toggle(context),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                RotationTransition(turns: animation, child: child),
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(isDark),
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
