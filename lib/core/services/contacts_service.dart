import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Plain value object for a contact carrying a birthday.
///
/// Lives in `core` so the service stays decoupled from any feature model;
/// features map it onto their own input model.
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

/// Wraps the `flutter_contacts` plugin (Service layer).
class ContactsService {
  const ContactsService();

  /// Requests read access to the device contacts.
  Future<bool> requestReadPermission() async {
    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    return status == PermissionStatus.granted;
  }

  /// Returns every contact that exposes a birthday event.
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
