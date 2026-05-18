import 'dart:math';

import 'package:an_ki/core/animations/anki_fade_in.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/widgets/contact_tile.dart';
import 'package:flutter/material.dart';

class ContactSections extends StatelessWidget {
  const ContactSections({super.key, required this.birthdays});

  final List<BirthdayModel> birthdays;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: birthdays.length,
      padding: const EdgeInsets.only(bottom: 110, top: 12),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        // Staggered entrance animation
        // Limit the delay to the first few items for better performance
        final delay = Duration(milliseconds: min(index * 60, 400));

        return AnKiFadeIn(
          delay: delay,
          offset: const Offset(0, 0.05),
          child: ContactTile(birthday: birthdays[index]),
        );
      },
    );
  }
}
