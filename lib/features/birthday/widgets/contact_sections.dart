import 'package:an_ki/core/common/bottom_bar.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/widgets/contact_tile.dart';
import 'package:flutter/material.dart';

class ContactSections extends StatelessWidget {
  const ContactSections({super.key, required this.birthdays});

  final List<Birthday> birthdays;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: birthdays.length,
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: BottomBar.overlap,
      ),
      physics: const BouncingScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        return ContactTile(birthday: birthdays[index]);
      },
    );
  }
}
