class BookModel {
  final String title;
  final String isbn;

  BookModel({required this.title, required this.isbn});

  factory BookModel.fromJson(Map<String, dynamic> json, String isbn) {
    final volumeInfo = json['volumeInfo'] as Map<String, dynamic>?;

    return BookModel(
      title: volumeInfo?['title'] ?? 'Unknown Title',
      isbn: isbn,
    );
  }
}
