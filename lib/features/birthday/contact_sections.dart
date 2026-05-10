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
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        return ContactTile(birthday: birthdays[index]);
      },
    );
  }
}
