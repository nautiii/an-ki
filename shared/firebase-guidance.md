# Firebase & Persistence

## Firestore
* **Mapping**: Use `factory Model.fromFirestore` and `toJson()`. Manual mapping in repositories.
* **Queries**: Always filter by `uid` for data isolation.
* **Offline**: Firestore persistence is enabled by default.

## Auth
* **Methods**: Support for Email, Google, and Anonymous.
* **Link Account**: Support for migrating anonymous users to permanent accounts.
* **Biometrics**: Local biometric lock (`local_auth`) coupled with secure token storage.

## Storage
* **Optimization**: Compress images/convert to base64 before upload (current implementation uses base64 in Firestore for small images).
* **Structure**: `/users/{uid}/{category}/{filename}`.

## Atomicity
* Use `WriteBatch` for multi-document operations (e.g., deleting all user data).
