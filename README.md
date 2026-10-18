# AnKi 🎂

**AnKi** est une application Flutter moderne conçue pour vous aider à ne plus jamais oublier un
anniversaire. Simple, élégante et efficace.

## 🚀 Fonctionnalités

- 🔐 **Authentification Multi-plateforme** : Connectez-vous via Google, Email ou restez anonyme (avec
  option de sauvegarde ultérieure).
- 📅 **Gestion des Anniversaires** : Ajoutez, modifiez et organisez les anniversaires de vos proches.
- 📂 **Catégorisation** : Classez vos proches par catégories prédéfinies (Famille, Ami, Sport…) ou
  par les vôtres.
- 🔔 **Rappels** : Notifications le jour J et 7 jours avant, programmées sur l'appareil (même
  hors ligne).
- 🌓 **Mode Sombre/Clair** : Interface adaptative selon vos préférences.
- 🌍 **Multi-langue** : Support complet du Français (par défaut) et de l'Anglais.

## 🛠️ Stack Technique

- **Framework** : [Flutter](https://flutter.dev/) 3.47.6 · Dart 3.13.5 · Material 3
- **Plateformes** : Android (testé sur appareil), iOS (non testé) ; la cible web a été retirée
- **Backend** : [Firebase](https://firebase.google.com/) (Auth, Firestore avec persistance hors ligne)
- **Gestion d'état** : [Riverpod](https://riverpod.dev/) 3, sans génération de code
- **Navigation** : [go_router](https://pub.dev/packages/go_router)
- **Notifications** : [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- **Localisation** : `flutter_localizations` (ARB files)
- Toutes les dépendances sont épinglées à une version exacte (`pubspec.lock` versionné).

## 📦 Installation

1. **Cloner le projet** :
   ```bash
   git clone https://github.com/nautiii/kairos.git
   cd kairos
   ```

2. **Installer les dépendances** :
   ```bash
   flutter pub get
   ```

3. **Configuration Firebase** : la configuration client du projet (`android/app/google-services.json`,
   `lib/core/firebase_options.dart`) est versionnée. Pour utiliser votre propre projet Firebase :
    - activez l'authentification (e-mail, Google, anonyme) et Firestore dans la
      [console Firebase](https://console.firebase.google.com/) ;
    - lancez `flutterfire configure --platforms=android,ios`, puis déplacez le
      `lib/firebase_options.dart` généré dans `lib/core/` ;
    - pour la connexion Google, enregistrez l'empreinte SHA-1 de votre clé de signature.

4. **Configurer les secrets** : copiez `secrets.example.json` en `secrets.json` (ignoré par git)
   et renseignez la clé `GOOGLE_BOOKS_API_KEY` (clé Google Books, restreinte à l'app Android).
   ```bash
   cp secrets.example.json secrets.json
   ```

5. **Lancer l'application** :
   ```bash
   flutter run --dart-define-from-file=secrets.json
   ```

6. **Génération d'assets (Icônes & Splash)** :

   Après avoir modifié les configurations dans `pubspec.yaml` :
   - **Icônes d'application** :
     ```bash
     dart run flutter_launcher_icons
     ```
   - **Splash Screen** :
     ```bash
     dart run flutter_native_splash:create
     ```

## 🛠️ Scripts & Déploiement

Les scripts PowerShell sont dans `scripts/` et lisent `secrets.json` :
```powershell
.\scripts\run.ps1                                 # flutter run avec les secrets
.\scripts\build_and_deploy.ps1 [-Release] [-Clean] # build l'APK et l'installe via adb
```

## ✅ Qualité

```bash
flutter analyze        # doit être propre
dart analyze           # seul à exécuter le plugin riverpod_lint
flutter test           # dont test/architecture/ qui vérifie les dépendances entre couches
flutter gen-l10n       # après toute modification d'un fichier .arb
```

## 📂 Structure du projet

Architecture MVVM en couches, organisée par fonctionnalité :

- `lib/app/` : Racine de composition (MaterialApp, routes, shell à onglets, démarrage).
- `lib/core/` : Éléments partagés indépendants des fonctionnalités (thème, widgets communs,
  services, routage, extensions).
- `lib/features/<feature>/` : `auth`, `user`, `birthday`, `book_scanner`, `reminders`, `settings`,
  chacune découpée en `domain/`, `data/`, `providers/`, `screens/`, `widgets/`.
- `lib/l10n/` : Fichiers de traduction (`intl_fr.arb` comme modèle, `intl_en.arb`).
- `test/` : Miroir de `lib/`.

Les conventions de code et d'architecture sont détaillées dans [`AGENTS.md`](AGENTS.md).

---
**Développeur:** Quentin Maillard
