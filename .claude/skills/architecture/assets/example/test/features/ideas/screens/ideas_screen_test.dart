import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/ideas/data/idea_repository.dart';
import 'package:an_ki/features/ideas/domain/idea.dart';
import 'package:an_ki/features/ideas/domain/idea_failure.dart';
import 'package:an_ki/features/ideas/providers/ideas_providers.dart';
import 'package:an_ki/features/ideas/screens/ideas_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

/// Dépôt factice : on simule la source de données, pas les Notifiers.
class _FakeIdeaRepository extends Fake implements IdeaRepository {
  final added = <IdeaDraft>[];
  IdeaFailure? failure;

  @override
  Future<String> addIdea(
    String uid,
    IdeaDraft draft, {
    required DateTime now,
  }) async {
    if (failure case final failure?) throw failure;
    added.add(draft);
    return 'new-id';
  }
}

void main() {
  late _FakeIdeaRepository repository;
  final idea = Idea(id: 'i1', title: 'Livre', createdAt: DateTime(2026));

  Future<void> pumpScreen(
    WidgetTester tester, {
    required AsyncValue<List<Idea>> ideas,
  }) => tester.pumpHarness(
    const IdeasScreen(),
    overrides: [
      // L'état d'un StreamProvider se fixe directement : pas de flux à simuler.
      ideasProvider.overrideWithValue(ideas),
      ideaRepositoryProvider.overrideWithValue(repository),
      currentUidProvider.overrideWithValue('u1'),
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 7)),
    ],
  );

  setUp(() => repository = _FakeIdeaRepository());

  testWidgets('renders loading, empty, data and error states', (tester) async {
    await pumpScreen(tester, ideas: const AsyncLoading());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await pumpScreen(tester, ideas: const AsyncData([]));
    expect(find.text("Aucune idée pour l'instant."), findsOneWidget);

    await pumpScreen(tester, ideas: AsyncData([idea]));
    expect(find.text('Livre'), findsOneWidget);

    await pumpScreen(
      tester,
      ideas: AsyncError(Exception('offline'), StackTrace.empty),
    );
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('adds an idea and closes the sheet at once', (tester) async {
    await pumpScreen(tester, ideas: const AsyncData([]));

    await tester.tap(find.byTooltip('Ajouter une idée'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Vinyle');
    await tester.pump();
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(repository.added.single.normalizedTitle, 'Vinyle');
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('announces a failed write after the sheet closed', (
    tester,
  ) async {
    repository.failure = IdeaFailure.storage;
    await pumpScreen(tester, ideas: const AsyncData([]));

    await tester.tap(find.byTooltip('Ajouter une idée'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Vinyle');
    await tester.pump();
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(find.text('Enregistrement impossible. Réessayez.'), findsOneWidget);
  });
}
