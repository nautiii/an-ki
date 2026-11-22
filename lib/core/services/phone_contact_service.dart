import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Numéro choisi dans le sélecteur du système, avec le nom de son contact.
///
/// Vit dans `core` pour que le service reste découplé de tout modèle de
/// feature ; les features le mappent vers le leur.
class const PickedPhone({
  required final String number,

  /// Nom du contact tel que le répertoire l'affiche ; vide s'il n'en a pas.
  required final String contactName,
}) {
  @override
  bool operator ==(Object other) =>
      other is PickedPhone &&
      other.number == number &&
      other.contactName == contactName;

  @override
  int get hashCode => Object.hash(number, contactName);
}

/// Le sélecteur du système n'a pas pu s'ouvrir ou rendre le numéro choisi.
class PhoneContactUnavailable implements Exception {
  const PhoneContactUnavailable();
}

/// Numéro d'une personne et ses deux usages, appel et SMS, par le canal
/// `an_ki/phone_contact` de `MainActivity` (couche Service).
///
/// Aucune permission : le sélecteur du système montre le répertoire, AnKi ne
/// reçoit que la ligne choisie ; le composeur et l'app de SMS s'ouvrent sans
/// rien envoyer d'eux-mêmes. Android seulement : ailleurs, [isSupported] est
/// faux et rien ne s'ouvre.
class PhoneContactService {
  const PhoneContactService();

  static const _channel = MethodChannel('an_ki/phone_contact');

  /// Vrai là où le canal existe (Android).
  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  /// Ouvre le sélecteur de numéros du système. Renvoie le numéro choisi, ou
  /// null si la personne a fermé le sélecteur (ou s'il est déjà ouvert). Lève
  /// [PhoneContactUnavailable] quand il ne s'ouvre pas ou ne rend rien de
  /// lisible.
  Future<PickedPhone?> pickPhone() async {
    final Map<Object?, Object?>? picked;
    try {
      picked = await _channel.invokeMapMethod<Object?, Object?>('pickPhone');
    } on PlatformException catch (error) {
      // Un second toucher pendant que le sélecteur s'ouvre : déjà ouvert.
      if (error.code == 'busy') return null;
      throw const PhoneContactUnavailable();
    } on MissingPluginException {
      throw const PhoneContactUnavailable();
    }
    if (picked == null) return null;
    final number = picked['number'];
    if (number is! String || number.trim().isEmpty) {
      throw const PhoneContactUnavailable();
    }
    final name = picked['name'];
    return PickedPhone(
      number: number.trim(),
      contactName: name is String ? name.trim() : '',
    );
  }

  /// Ouvre le composeur avec [number], sans appeler. Faux quand aucune app
  /// ne le prend en charge.
  Future<bool> dial(String number) => _open('dial', {'number': number});

  /// Ouvre la conversation SMS avec [number], [body] déjà écrit. Faux quand
  /// aucune app ne la prend en charge.
  Future<bool> sendSms(String number, String body) =>
      _open('sendSms', {'number': number, 'body': body});

  Future<bool> _open(String method, Map<String, String> arguments) async {
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Numéro d'une personne, appel et SMS ; les tests le remplacent.
final phoneContactServiceProvider = Provider<PhoneContactService>(
  (ref) => const PhoneContactService(),
);
