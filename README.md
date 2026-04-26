# An Ki 🎂

**An Ki** est une application Flutter moderne conçue pour vous aider à ne plus jamais oublier un
anniversaire. Simple, élégante et efficace.

## 🚀 Fonctionnalités

- 🔐 **Authentification Multi-plateforme** : Connectez-vous via Google, Email ou restez anonyme (avec
  option de sauvegarde ultérieure).
- 📅 **Gestion des Anniversaires** : Ajoutez, modifiez et organisez les anniversaires de vos proches.
- 📂 **Catégorisation** : Classez vos contacts par catégories (Famille, Amis, Collègues, Autre).
- 🔔 **Notifications** : Recevez des rappels pour ne rien manquer.
- 🌓 **Mode Sombre/Clair** : Interface adaptative selon vos préférences.
- 🌍 **Multi-langue** : Support complet du Français (par défaut) et de l'Anglais.

## 🛠️ Stack Technique

- **Framework** : [Flutter](https://flutter.dev/)
- **Backend** : [Firebase](https://firebase.google.com/) (Auth, Firestore, Storage)
- **Gestion d'état** : [Provider](https://pub.dev/packages/provider)
- **Notifications
  ** : [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- **Localisation** : `flutter_localizations` (ARB files)

## 📦 Installation

1. **Cloner le projet** :
   ```bash
   git clone https://github.com/votre-username/kairos.git
   cd kairos
   ```

2. **Installer les dépendances** :
   ```bash
   flutter pub get
   ```

3. **Configuration Firebase** :
    - Créez un projet sur la [Console Firebase](https://console.firebase.google.com/).
    - Ajoutez les applications Android et iOS.
    - Téléchargez et placez les fichiers `google-services.json` et `GoogleService-Info.plist` dans
      les dossiers respectifs.
    - Activez l'Authentification (Email, Google, Anonyme) et Firestore.

4. **Lancer l'application** :
   ```bash
   flutter run
   ```
5. **Déploiement** :

   Si vous désirez déployer l'application sur votre téléphone, utilisez le script de déploiement :
    ```powerShell
    .\build_and_deploy.ps1
    ```

## 📂 Structure du projet

- `lib/core/` : Éléments partagés (thèmes, extensions, services).
- `lib/data/` : Modèles de données et dépôts (Firestore).
- `lib/features/` : Fonctionnalités de l'application (Auth, Birthday).
- `lib/providers/` : Gestion de l'état global.
- `lib/l10n/` : Fichiers de traduction.

---
**Développeur:** Quentin Maillard
