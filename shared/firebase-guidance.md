# Firebase & Persistence

## Firestore

* Map via `factory Model.fromFirestore` + `toJson()`, manually in repositories.
* Filter every query by `uid` for data isolation. Offline persistence is on by default.
* Use `WriteBatch` for multi-document operations (e.g. deleting all user data).

## Auth

* Methods: Email, Google, Anonymous; support linking anonymous → permanent accounts.
* Biometric lock (`local_auth`) + secure token storage.

## Storage

* Small images: compress/convert to base64 in Firestore (current approach).
* Path structure: `/users/{uid}/{category}/{filename}`.
