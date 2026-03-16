import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/repositories/birthday_repository.dart';
import 'package:an_ki/features/birthday/widgets/custom_bottom_bar.dart';
import 'package:an_ki/features/birthday/widgets/next_birthday.dart';
import 'package:an_ki/features/birthday/widgets/search_bar.dart';
import 'package:an_ki/header.dart';
import 'package:flutter/material.dart';

import 'contact_sections.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final repository = BirthdayRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BirthdayModel>>(
      stream: repository.watchBirthdays(),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
            return Center(child: CircularProgressIndicator());
          case ConnectionState.active:
            {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading data: ${snapshot.error}'),
                );
              }
              return snapshot.hasData
                  ? BirthdayList(birthdays: snapshot.data!)
                  : const Center(child: Text('No birthday data found.'));
            }
          default:
            return const Text(
              "No active connection, please restart the application",
            );
        }
      },
    );
  }
}

class BirthdayList extends StatelessWidget {
  const BirthdayList({super.key, required this.birthdays});

  final List<BirthdayModel> birthdays;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1C2C),
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
              const SearchBarWidget(),
              const SizedBox(height: 20),
              const Expanded(child: ContactSections()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomBar(),
    );
  }
}
