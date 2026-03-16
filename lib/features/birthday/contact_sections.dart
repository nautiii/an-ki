import 'package:an_ki/features/birthday/widgets/section_widget.dart';
import 'package:flutter/material.dart';

class ContactSections extends StatelessWidget {
  const ContactSections({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SectionWidget(title: "Famille"),
        SectionWidget(title: "Amis"),
        SectionWidget(title: "Collègues"),
      ],
    );
  }
}
