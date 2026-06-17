import 'package:cloud_firestore/cloud_firestore.dart';

class BookModel {
  final String id;
  final String uid;
  final String title;
  final List<String> authors;
  final String isbn;
  final String? imageUrl;
  final String? publishedDate;
  final String? description;
  final int? pageCount;
  final DateTime? scannedAt;

  BookModel({
    required this.id,
    required this.uid,
    required this.title,
    required this.authors,
    required this.isbn,
    this.imageUrl,
    this.publishedDate,
    this.description,
    this.pageCount,
    this.scannedAt,
  });

  factory BookModel.fromJson(Map<String, dynamic> json, String isbn) {
    final volumeInfo = json['volumeInfo'] as Map<String, dynamic>?;
    final imageLinks = volumeInfo?['imageLinks'] as Map<String, dynamic>?;

    return BookModel(
      id: '',
      // Set by repository or Firestore
      uid: '',
      // Set by repository
      title: volumeInfo?['title'] ?? 'Unknown Title',
      authors: List<String>.from(volumeInfo?['authors'] ?? []),
      isbn: isbn,
      imageUrl: imageLinks?['thumbnail']?.replaceFirst('http:', 'https:'),
      publishedDate: volumeInfo?['publishedDate'],
      description: volumeInfo?['description'],
      pageCount: volumeInfo?['pageCount'],
      scannedAt: DateTime.now(),
    );
  }

  factory BookModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return BookModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      title: data['title'] ?? '',
      authors: List<String>.from(data['authors'] ?? []),
      isbn: data['isbn'] ?? '',
      imageUrl: data['imageUrl'],
      publishedDate: data['publishedDate'],
      description: data['description'],
      pageCount: data['pageCount'],
      scannedAt: (data['scannedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'title': title,
      'authors': authors,
      'isbn': isbn,
      'imageUrl': imageUrl,
      'publishedDate': publishedDate,
      'description': description,
      'pageCount': pageCount,
      'scannedAt':
          scannedAt != null
              ? Timestamp.fromDate(scannedAt!)
              : FieldValue.serverTimestamp(),
    };
  }

  BookModel copyWith({
    String? id,
    String? uid,
    String? title,
    List<String>? authors,
    String? isbn,
    String? imageUrl,
    String? publishedDate,
    String? description,
    int? pageCount,
    DateTime? scannedAt,
  }) {
    return BookModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      isbn: isbn ?? this.isbn,
      imageUrl: imageUrl ?? this.imageUrl,
      publishedDate: publishedDate ?? this.publishedDate,
      description: description ?? this.description,
      pageCount: pageCount ?? this.pageCount,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }
}
