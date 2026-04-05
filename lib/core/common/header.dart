import 'package:an_ki/data/models/user_model.dart';
import 'package:an_ki/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    final UserModel? user = context.watch<UserProvider>().user;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Bonjour 👋", style: TextStyle(color: Colors.white70)),
            user == null
                ? const Center(child: CircularProgressIndicator())
                : Text(
                  "${user.surname} ${user.name}",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
          ],
        ),
        const CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white10,
          child: Icon(Icons.cake_outlined, color: Colors.white),
        ),
      ],
    );
  }
}
