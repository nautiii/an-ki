import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/domain/contact_import_failure.dart';
import 'package:an_ki/features/birthday/widgets/contact_import_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  testWidgets('words every outcome of a contacts import', (tester) async {
    final l10n = (await tester.pumpLocalizedContext()).l10n;

    expect(
      contactImportMessage(l10n, const AsyncData(3)),
      '3 contacts importés avec succès !',
    );
    expect(
      contactImportMessage(l10n, const AsyncData(0)),
      'Aucun contact avec une date de naissance trouvé.',
    );
    expect(
      contactImportMessage(
        l10n,
        const AsyncError(
          ContactImportFailure.permissionDenied,
          StackTrace.empty,
        ),
      ),
      'Permission refusée.',
    );
    expect(
      contactImportMessage(l10n, AsyncError(Exception('x'), StackTrace.empty)),
      'Une erreur est survenue.',
    );
  });

  testWidgets('says nothing before or during an import', (tester) async {
    final l10n = (await tester.pumpLocalizedContext()).l10n;

    expect(contactImportMessage(l10n, const AsyncData(null)), isNull);
    expect(contactImportMessage(l10n, const AsyncLoading()), isNull);
  });
}
