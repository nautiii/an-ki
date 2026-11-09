import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:an_ki/features/books/widgets/book_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

/// ISBN-13 valide (clé de contrôle juste).
const _isbn = '9780451524935';

void main() {
  IdentifiedVolume identified({
    String? imageUrl,
    List<String> authors = const ['Orwell'],
    String title = '1984',
    String? subtitle,
  }) => IdentifiedVolume(
    isbn: _isbn,
    metadata: BookMetadata(
      title: title,
      subtitle: subtitle,
      authors: authors,
      publishedDate: '1949',
      imageUrl: imageUrl,
    ),
  );

  List<Object> overridesFor(RecordingBookshelfRepository repository) => [
    bookshelfRepositoryProvider.overrideWithValue(repository),
    currentUidProvider.overrideWithValue('fake-uid'),
  ];

  group('BookInfoSheet', () {
    testWidgets('renders details with a cover image, saves and closes', (
      tester,
    ) async {
      final repository = RecordingBookshelfRepository();
      await mockNetworkImages(() async {
        await tester.pumpHarness(
          BookInfoSheet(
            volume: identified(imageUrl: 'https://example.com/cover.jpg'),
          ),
          overrides: overridesFor(repository),
        );
        await tester.pumpAndSettle();

        expect(find.text('1984'), findsOneWidget);
        expect(find.text('Orwell'), findsOneWidget);
        expect(find.text('1949'), findsOneWidget);
        // L'étiquette met une espace insécable avant les deux-points.
        expect(find.textContaining(_isbn), findsOneWidget);

        // La feuille se ferme à l'ajout : l'écran garde l'éditeur en vie le
        // temps de l'écriture complète, ici le test.
        ProviderScope.containerOf(tester.element(find.byType(BookInfoSheet)))
            .listen(shelfEditorProvider, (_, _) {});

        await tester.tap(find.text('Ajouter'));
        await tester.pumpAndSettle();

        expect(find.byType(BookInfoSheet), findsNothing);
        expect(repository.savedVolumes.last.title, '1984');
        expect(repository.savedVolumes.last.lookup, LookupState.found);
        expect(repository.volumes.single.id, _isbn);
      });
    });

    testWidgets('shows the subtitle after the title', (tester) async {
      await mockNetworkImages(() async {
        await tester.pumpHarness(
          BookInfoSheet(
            volume: identified(
              title: 'Blacksad',
              subtitle: 'Alors, tout tombe',
            ),
          ),
          overrides: overridesFor(RecordingBookshelfRepository()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Blacksad : Alors, tout tombe'), findsOneWidget);
      });
    });

    testWidgets('renders a placeholder icon without authors or image', (
      tester,
    ) async {
      await mockNetworkImages(() async {
        await tester.pumpHarness(
          BookInfoSheet(volume: identified(authors: const [])),
          overrides: overridesFor(RecordingBookshelfRepository()),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.book_rounded), findsOneWidget);
        expect(find.text('Orwell'), findsNothing);
      });
    });

    testWidgets('names a book without title', (tester) async {
      await mockNetworkImages(() async {
        await tester.pumpHarness(
          BookInfoSheet(volume: identified(title: '')),
          overrides: overridesFor(RecordingBookshelfRepository()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Titre inconnu'), findsOneWidget);
      });
    });
  });
}
