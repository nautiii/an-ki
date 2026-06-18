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
      title: volumeInfo?['title'] as String? ?? 'Unknown Title',
      authors: List<String>.from(
        volumeInfo?['authors'] as List<dynamic>? ?? const [],
      ),
      isbn: isbn,
      imageUrl: (imageLinks?['thumbnail'] as String?)?.replaceFirst(
        'http:',
        'https:',
      ),
      publishedDate: volumeInfo?['publishedDate'] as String?,
      description: volumeInfo?['description'] as String?,
      pageCount: volumeInfo?['pageCount'] as int?,
      scannedAt: DateTime.now(),
    );
  }

  factory BookModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return BookModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      title: data['title'] as String? ?? '',
      authors: List<String>.from(data['authors'] as List<dynamic>? ?? const []),
      isbn: data['isbn'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      publishedDate: data['publishedDate'] as String?,
      description: data['description'] as String?,
      pageCount: data['pageCount'] as int?,
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
