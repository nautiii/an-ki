import 'package:an_ki/core/providers/pending_ids.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Session extends Notifier<String?> {
  @override
  String? build() => 'user';

  void change(String? next) => state = next;
}

void main() {
  late NotifierProvider<PendingIds, Set<String>> pending;
  late NotifierProvider<_Session, String?> session;

  setUp(() {
    session = NotifierProvider<_Session, String?>(_Session.new);
    pending = NotifierProvider<PendingIds, Set<String>>(
      () => PendingIds(session),
    );
  });

  test('starts empty', () {
    final container = ProviderContainer.test();

    expect(container.read(pending), isEmpty);
  });

  test('hides then restores an id', () {
    final container = ProviderContainer.test();
    final notifier = container.read(pending.notifier);

    notifier
      ..hide('a')
      ..hide('b');
    expect(container.read(pending), {'a', 'b'});

    notifier.restore('a');
    expect(container.read(pending), {'b'});

    // Rattraper un id inconnu ne change rien.
    notifier.restore('zzz');
    expect(container.read(pending), {'b'});
  });

  test('resets when the watched provider changes', () {
    final container = ProviderContainer.test();
    container.read(pending.notifier).hide('a');
    expect(container.read(pending), {'a'});

    container.read(session.notifier).change('other-user');

    expect(container.read(pending), isEmpty);
  });
}
