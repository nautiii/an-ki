import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String surname;
  final String? pseudo;
  final List<String> categories;
  final bool isDark;
  final String locale;
  final String? biometricToken;

  const UserModel({
    required this.id,
    required this.name,
    required this.surname,
    this.pseudo,
    this.categories = const [],
    required this.isDark,
    required this.locale,
    this.biometricToken,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data()!;

    return UserModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      surname: data['surname'] as String? ?? '',
      pseudo: data['pseudo'] as String?,
      categories: List<String>.from(
        data['categories'] as List<dynamic>? ?? const [],
      ),
      isDark: data['isDark'] as bool? ?? false,
      locale: data['locale'] as String? ?? 'fr',
      biometricToken: data['biometricToken'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'surname': surname,
      if (pseudo != null) 'pseudo': pseudo,
      'categories': categories,
      'isDark': isDark,
      'locale': locale,
      if (biometricToken != null) 'biometricToken': biometricToken,
    };
  }

  /// Nom affiché dans l'UI : le pseudo s'il est défini, sinon « nom prénom ».
  String get displayName {
    if (pseudo != null && pseudo!.isNotEmpty) return pseudo!;
    return '$surname $name';
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? surname,
    String? pseudo,
    List<String>? categories,
    bool? isDark,
    String? locale,
    String? biometricToken,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      pseudo: pseudo ?? this.pseudo,
      categories: categories ?? this.categories,
      isDark: isDark ?? this.isDark,
      locale: locale ?? this.locale,
      biometricToken: biometricToken ?? this.biometricToken,
    );
  }
}
