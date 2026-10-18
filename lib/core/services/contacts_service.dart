import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Objet de valeur simple pour un contact porteur d'un anniversaire.
///
/// Vit dans `core` pour que le service reste découplé de tout modèle de feature ;
/// les features le mappent vers leur propre modèle d'input.
class ImportedBirthday {
  final String name;
  final String surname;
  final int month;
  final int day;

  /// Année de naissance ; null quand le contact ne la donne pas.
  final int? year;

  const ImportedBirthday({
    required this.name,
    required this.surname,
    required this.month,
    required this.day,
    this.year,
  });
}

/// Accès en lecture au répertoire du téléphone.
enum ContactsAccess {
  /// Accordé (ou limité aux contacts choisis, iOS 18).
  granted,

  /// Refusé, mais la boîte système peut encore être proposée.
  denied,

  /// Refusé pour de bon (deux refus sur Android, un sur iOS) ou bloqué par
  /// une règle de l'appareil : seuls les réglages de l'app peuvent l'accorder.
  blocked,
}

/// Encapsule le plugin `flutter_contacts` (couche Service).
class ContactsService {
  const ContactsService();

  /// Demande l'accès en lecture : la boîte système quand elle peut encore
  /// s'afficher, sinon l'accès tel qu'il est.
  Future<ContactsAccess> requestReadAccess() async =>
      _access(await FlutterContacts.permissions.request(PermissionType.read));

  /// Accès en lecture actuel, sans rien demander.
  Future<ContactsAccess> readAccess() async =>
      _access(await FlutterContacts.permissions.check(PermissionType.read));

  /// Ouvre la page de l'app dans les réglages du téléphone, où se trouvent
  /// ses autorisations.
  Future<void> openAppSettings() => FlutterContacts.permissions.openSettings();

  static ContactsAccess _access(PermissionStatus status) => switch (status) {
    PermissionStatus.granted ||
    PermissionStatus.limited => ContactsAccess.granted,
    PermissionStatus.denied ||
    PermissionStatus.notDetermined => ContactsAccess.denied,
    PermissionStatus.permanentlyDenied ||
    PermissionStatus.restricted => ContactsAccess.blocked,
  };

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
          month: birthdayEvent.month,
          day: birthdayEvent.day,
          year: birthdayEvent.year,
        ),
      );
    }
    return result;
  }
}

final contactsServiceProvider = Provider<ContactsService>(
  (ref) => const ContactsService(),
);
