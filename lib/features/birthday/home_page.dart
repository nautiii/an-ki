import 'package:an_ki/core/common/header.dart';
import 'package:an_ki/core/common/search_bar.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/next_birthday.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'contact_sections.dart';
import 'create_birthday_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredBirthdays = ref.watch(filteredBirthdaysProvider);
    final isLoading = ref.watch(birthdayProvider.select((s) => s.isLoading));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        backgroundColor: colorScheme.primary,
        elevation: 0,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CreateBirthdayPage()),
          );
        },
        child: Icon(Icons.add_rounded, color: colorScheme.onPrimary, size: 34),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Header(),
              const SizedBox(height: 24),
              const NextBirthdayCard(),
              const SizedBox(height: 20),
              SearchBarWidget(
                onSearchChanged: (query) {
                  ref.read(birthdaySearchProvider.notifier).state = query;
                },
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _HomeContent(
                  isLoading: isLoading,
                  birthdays: filteredBirthdays,
                ),
              ),
            ],
          ),
        ),
      ),
      // bottomNavigationBar: const BottomBar(),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.isLoading, required this.birthdays});

  final bool isLoading;
  final List<BirthdayModel> birthdays;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (birthdays.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noBirthdaysFound,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ContactSections(birthdays: birthdays);
  }
}
