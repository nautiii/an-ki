import 'package:flutter/material.dart';

class NextBirthdayCard extends StatelessWidget {
  const NextBirthdayCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF7B5E57), Color(0xFFD6A48F)],
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 24),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Prochain anniversaire",
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 4),
              Text(
                "Sophie Martin",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Dans 2 jours • 24 Avril",
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const Spacer(),
          const Icon(Icons.cake, color: Colors.white),
        ],
      ),
    );
  }
}
