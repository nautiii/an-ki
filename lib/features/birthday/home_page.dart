import 'package:an_ki/core/common/header.dart';
import 'package:an_ki/core/common/search_bar.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/widgets/next_birthday.dart';
import 'package:an_ki/providers/birthday_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'contact_sections.dart';
import 'create_birthday_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _searchQuery = '';

  List<BirthdayModel> _filterBirthdays(List<BirthdayModel> birthdays) {
    if (_searchQuery.isEmpty) {
      return birthdays;
    }

    final query = _searchQuery.toLowerCase();
    return birthdays
        .where(
          (birthday) =>
              birthday.name.toLowerCase().contains(query) ||
              birthday.surname.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = context.select(
      (BirthdayProvider provider) => provider.isLoading,
    );
    final List<BirthdayModel> birthdays = context.select(
      (BirthdayProvider provider) => provider.birthdays,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final filteredBirthdays = _filterBirthdays(birthdays);

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
              Header(),
              const SizedBox(height: 24),
              const NextBirthdayCard(),
              const SizedBox(height: 20),
              SearchBarWidget(
                onSearchChanged: (query) {
                  setState(() {
                    _searchQuery = query;
                  });
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
