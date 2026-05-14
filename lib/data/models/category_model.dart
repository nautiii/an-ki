import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BirthdayCategory {
  final String id;
  final String name;
  final int icon;

  BirthdayCategory({required this.id, required this.name, required this.icon});

  IconData get iconData => IconData(icon, fontFamily: 'MaterialIcons');

  factory BirthdayCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BirthdayCategory(
      id: doc.id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? Icons.category.codePoint,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'icon': icon};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BirthdayCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
