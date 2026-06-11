# Project Context: AnKi (Kairos)

## Product Vision

AnKi is a production-ready birthday management app: modern, minimalist, and reliable.

* **Goal**: Centralize contacts' birthdays with intelligent, local-first notifications.
* **Target**: Users seeking a "Pixel Perfect" experience without technical friction.

## Application Overview

AnKi (Kairos) is designed to solve the "forgotten birthday" problem with a focus on high-quality
UI/UX. It leverages a local-first notification system while keeping data synced across devices via
Firebase.

## Current Features

* **Authentication**: Multi-method (Google, Email/Password, Anonymous) with biometric lock support.
* **Birthday Management**: Full CRUD, categories, search, proximity-based sorting, and calendar
  view.
* **Smart Notifications**: Scheduled via `flutter_local_notifications` with timezone awareness (
  Day-of and J-7 reminders).
* **Contact Integration**: Import birthdays directly from phone contacts.
* **Book Scanning**: ISBN scanner using `mobile_scanner` and Google Books API for gift ideas.

## Technical Decisions

* **Architecture**: Strict layered approach (UI > Provider > Repository > Service).
* **State**: Riverpod 3 (Notifier API) for testability and performance.
* **Persistence**: Firebase (Firestore, Auth, Storage) with offline capabilities.
* **L10n**: `flutter_gen` (intl) via `.arb` files for 100% translatable UI.
* **Reliability**: Timezone-aware local notifications; strict typing.
* **Security**: Biometric authentication (`local_auth`) and secure token storage.
* **Localization**: 100% translatable via `.arb` files and `flutter_gen`.

## User Experience Principles

* **Pixel Perfect**: Strict adherence to Material 3 and 8dp grid.
* **Zero Empty States**: Always provide visual feedback or CTA.
* **Fluidity**: Native-feel transitions and haptic responses.
* **Zero Empty States**: Informative placeholders when lists are empty.

## Domain Model

* **Birthday**: Core entity. Notifications are calculated/scheduled based on this.
* **Category**: User-defined labels for grouping birthdays.
* **User**: Profile-linked Firestore document.
