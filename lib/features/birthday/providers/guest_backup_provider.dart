import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/domain/guest_backup.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nombre d'anniversaires que la carte de sauvegarde annonce à un invité, en
/// fin d'agenda ; null quand elle ne s'affiche pas ([guestBackupOffer]).
final guestBackupOfferProvider = Provider<int?>(
  (ref) => guestBackupOffer(
    guest: ref.watch(isGuestProvider),
    birthdays: ref.watch(
      birthdaysListProvider.select((birthdays) => birthdays.length),
    ),
  ),
);
