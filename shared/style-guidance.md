# Style & Conventions

* **Modularity**: extract sub-widgets into private `_MyWidget` classes; max ~200–300 lines per widget.
* **Typing**: strong typing everywhere, no `dynamic`.
* **Const**: `const` constructors wherever possible.
* **Imports**: absolute only. Order: Dart/Flutter → packages → internal.
* **Naming**: `snake_case.dart` files, `PascalCase` classes, `XModel`, `XRepository`, `xProvider`, `XScreen`/`XPage`.
* **Immutability**: `final` fields, `copyWith`, JSON mapping in every model. No logic in constructors.
