import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/widgets/contact_tile.dart';
import 'package:an_ki/features/birthday/widgets/section_widget.dart';
import 'package:flutter/material.dart';

class ContactSections extends StatefulWidget {
  const ContactSections({super.key, required this.birthdays});

  final List<BirthdayModel> birthdays;

  @override
  State<ContactSections> createState() => _ContactSectionsState();
}

class _ContactSectionsState extends State<ContactSections> {
  final Set<String> _expandedSections = {};

  @override
  Widget build(BuildContext context) {
    final sections = widget.birthdays.toSections(context);

    return ListView(
      children:
          sections.entries.map((MapEntry<String, List<BirthdayModel>> entry) {
            final String category = entry.key;
            final List<BirthdayModel> allBirthdays = entry.value;
            final bool isExpanded = _expandedSections.contains(category);

            // Afficher seulement les 3 premiers anniversaires si non étendu
            final displayedBirthdays =
                isExpanded ? allBirthdays : allBirthdays.take(3).toList();

            return SectionWidget(
              title: category,
              isExpanded: isExpanded,
              showViewAll: allBirthdays.length > 3,
              onViewAllPressed: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSections.remove(category);
                  } else {
                    _expandedSections.add(category);
                  }
                });
              },
              children:
                  displayedBirthdays
                      .map((birthday) => ContactTile(birthday: birthday))
                      .toList(),
            );
          }).toList(),
    );
  }
}
