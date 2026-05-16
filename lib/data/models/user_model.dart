import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String surname;
  final String? pseudo;
  final List<String> categories;
  final bool isDark;
  final String locale;

  const UserModel({
    required this.id,
    required this.name,
    required this.surname,
    this.pseudo,
    this.categories = const [],
    required this.isDark,
    required this.locale,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data()!;

    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      surname: data['surname'] ?? '',
      pseudo: data['pseudo'],
      categories: List<String>.from(data['categories'] ?? []),
      isDark: data['isDark'],
      locale: data['locale'],
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
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? surname,
    String? pseudo,
    List<String>? categories,
    bool? isDark,
    String? locale,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      pseudo: pseudo ?? this.pseudo,
      categories: categories ?? this.categories,
      isDark: isDark ?? this.isDark,
      locale: locale ?? this.locale,
    );
  }
}
