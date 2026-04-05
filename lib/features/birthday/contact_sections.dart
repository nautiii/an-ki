import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/widgets/contact_tile.dart';
import 'package:an_ki/features/birthday/widgets/section_widget.dart';
import 'package:flutter/material.dart';

class ContactSections extends StatelessWidget {
  const ContactSections({super.key, required this.birthdays});

  final List<BirthdayModel> birthdays;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children:
          birthdays.toSections().entries.map((
            MapEntry<String, List<BirthdayModel>> entry,
          ) {
            return SectionWidget(
              title: entry.key,
              children:
                  entry.value
                      .map((birthday) => ContactTile(birthday: birthday))
                      .toList(),
            );
          }).toList(),
    );
  }
}
