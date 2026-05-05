# State Management (Riverpod 3)

## Usage rules

* Use `Notifier` (or `AsyncNotifier`) for complex state and `Provider` for read-only repositories/services.
* Use `ref.watch` in `build` methods and `ref.read` in callbacks.
* Always check `if (ref.mounted)` before updating `state` after an `await` or inside a listener.
* `StateNotifier` is deprecated; prefer `Notifier`.

## Pattern

```id="provider_pattern"
class XState {
  final List<Data> items;
  final bool isLoading;
  // ...
  XState({this.items = const [], this.isLoading = true});
  XState copyWith({List<Data>? items, bool? isLoading}) => ...
}

class XNotifier extends Notifier<XState> {
  StreamSubscription? _subscription;

  @override
  XState build() {
    _init();
    ref.onDispose(() => _subscription?.cancel());
    return XState();
  }

  void _init() {
    final repository = ref.watch(xRepositoryProvider);
    _subscription = repository.stream().listen((data) {
      if (ref.mounted) {
        state = state.copyWith(items: data, isLoading: false);
      }
    });
  }
}

final xProvider = NotifierProvider<XNotifier, XState>(XNotifier.new);
```
