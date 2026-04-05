import 'package:an_ki/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppInitializer extends StatefulWidget {
  final StatelessWidget child;

  const AppInitializer({super.key, required this.child});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UserProvider>().loadUser(
          name: "Maillard",
          surname: "Quentin",
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final UserProvider userProvider = context.watch<UserProvider>();

    if (userProvider.isLoading) {
      return const Material(child: Center(child: CircularProgressIndicator()));
    }
    return widget.child;
  }
}
