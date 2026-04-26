# Core Architecture Rules

The project follows a strict layered architecture:

```id="arch1"
UI (Widgets)
 ↓
Provider (State)
 ↓
Repository (Data access)
 ↓
Firebase (Firestore)
```

## Hard Rules

* UI must NEVER access Firebase directly
* UI must NEVER contain business logic
* Providers are the ONLY source of state
* Repositories handle ALL external data interactions
* Models must be pure Dart objects

## Models

* Models must be immutable
* Always provide:

    * factory constructor (`fromFirestore`)
    * serialization if needed

## Extensions Usage

Extensions must be used for:

* mapping (String → Enum)
* formatting (DateTime → display)
* UI enrichment (Enum → icon/color)

Avoid utility classes.

## Enums Strategy

Enums are **intelligent objects**, not just values.

Each enum MUST:

* map from Firestore (String → Enum)
* expose UI properties via extensions

Example responsibilities:

* label
* icon
* color
* priority

NO switch/case should exist in UI for enums.

## Forbidden

* business logic in widgets
* data transformation in widgets
