import 'package:flutter/material.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';

class Header extends StatelessWidget {
  Header({super.key});

  final UserRepository repository = UserRepository();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: repository.fetchUser(name: "Maillard", surname: "Quentin"),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Text("Erreur utilisateur");
        }

        final user = snapshot.data;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Bonjour 👋",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  user != null ? "${user.name} ${user.surname}" : "Utilisateur",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const CircleAvatar(radius: 22, child: Icon(Icons.person)),
          ],
        );
      },
    );
  }
}
