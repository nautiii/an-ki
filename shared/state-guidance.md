# State Management (Provider)

## Usage rules

* NEVER use `context.watch` inside `initState`
* Avoid `FutureBuilder` when a Provider exists

## Pattern

```id="provider_pattern"
class XProvider extends ChangeNotifier {
  final XRepository repository;

  XProvider(this.repository) {
    _init();
  }

  void _init() {
    repository.stream().listen((data) {
      // update state
      notifyListeners();
    });
  }
}
```
