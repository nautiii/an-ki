# Style Guidance

## Expected Code Style

You should generate code that is:

* modular
* strongly typed
* null-safe
* easily testable

## UI Rules

* Use Material 3 (`useMaterial3: true`)
* Use `ColorScheme` (no hardcoded colors)
* UI must be dumb (render-only)
* Prefer `const` constructors where possible

## Naming Conventions

* Models: `XModel`
* Repositories: `XRepository`
* Providers: `XProvider`
* Widgets: descriptive and UI-focused

## Import files

* Always use absolute imports (`package:an_ki/**.dart`).
* Never use relative imports for files within the same package.

## Code Structure Example

```dart
// lib/features/feature_name/providers/feature_provider.dart
class FeatureState {
  final List<ItemModel> items;
  final bool isLoading;

  FeatureState({required this.items, this.isLoading = false});

  FeatureState copyWith({List<ItemModel>? items, bool? isLoading}) =>
      FeatureState(items: items ?? this.items, isLoading: isLoading ?? this.isLoading);
}

class FeatureNotifier extends Notifier<FeatureState> {
  @override
  FeatureState build() => FeatureState(items: []);

// Logic here
}
```
