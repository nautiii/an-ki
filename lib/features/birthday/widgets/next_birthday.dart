import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/providers/birthday_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NextBirthdayCard extends StatelessWidget {
  const NextBirthdayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLoading = context.select(
      (BirthdayProvider provider) => provider.isLoading,
    );
    final List<BirthdayModel> birthdays = context.select(
      (BirthdayProvider provider) => provider.birthdays,
    );
    final BirthdayModel? nextBirthday = birthdays.nextBirthday;

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
          const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white24,
            child: Icon(Icons.cake_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _BirthdayContent(
              birthday: nextBirthday,
              isLoading: isLoading,
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.cake, color: Colors.white),
        ],
      ),
    );
  }
}

class _BirthdayContent extends StatelessWidget {
  const _BirthdayContent({required this.birthday, required this.isLoading});

  final BirthdayModel? birthday;
  final bool isLoading;

  String _formatDate(DateTime date) => '${date.day} ${months[date.month - 1]}';

  String _daysLabel(int days) {
    if (days == 0) return "Aujourd'hui 🎉";
    if (days == 1) return 'Demain';
    return 'Dans $days jours';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? nextDate = birthday?.nextOccurrence;
    final int? days = birthday?.daysUntilNext;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Prochain anniversaire',
          style: TextStyle(color: Colors.white70),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if (isLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        else if (birthday == null)
          const Text(
            'Aucun anniversaire enregistré',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          )
        else ...[
          Text(
            '${birthday!.surname} ${birthday!.name}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${_daysLabel(days!)} • ${_formatDate(nextDate!)}',
            style: const TextStyle(color: Colors.white70),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
