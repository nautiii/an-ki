import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Objet de valeur simple pour un contact porteur d'un anniversaire.
///
/// Vit dans `core` pour que le service reste découplé de tout modèle de feature ;
/// les features le mappent vers leur propre modèle d'input.
class ImportedBirthday {
  final String name;
  final String surname;
  final DateTime date;

  const ImportedBirthday({
    required this.name,
    required this.surname,
    required this.date,
  });
}

/// Encapsule le plugin `flutter_contacts` (couche Service).
class ContactsService {
  const ContactsService();

  /// Demande l'accès en lecture aux contacts du device.
  Future<bool> requestReadPermission() async {
    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    return status == PermissionStatus.granted;
  }

  /// Renvoie tous les contacts qui exposent un événement d'anniversaire.
  Future<List<ImportedBirthday>> fetchBirthdays() async {
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.event, ContactProperty.name},
    );

    final result = <ImportedBirthday>[];
    for (final contact in contacts) {
      final birthdayEvent = contact.events.cast<Event?>().firstWhere(
        (e) => e?.label.label == EventLabel.birthday,
        orElse: () => null,
      );
      if (birthdayEvent == null) continue;

      result.add(
        ImportedBirthday(
          name: contact.name?.first ?? "",
          surname: contact.name?.last ?? "",
          date: DateTime(
            birthdayEvent.year ?? 2000,
            birthdayEvent.month,
            birthdayEvent.day,
          ),
        ),
      );
    }
    return result;
  }
}

final contactsServiceProvider = Provider<ContactsService>(
  (ref) => const ContactsService(),
);
