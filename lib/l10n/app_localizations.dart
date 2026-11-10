import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Salutation selon l'heure : Bonjour de 6 h 01 à 18 h, Bonsoir sinon
  ///
  /// In fr, this message translates to:
  /// **'{period, select, day{Bonjour} other{Bonsoir}}'**
  String greeting(String period);

  /// Titre de l'accueil : salutation de l'heure et nom de l'utilisateur
  ///
  /// In fr, this message translates to:
  /// **'{period, select, day{Bonjour, {name}} other{Bonsoir, {name}}}'**
  String greetingName(String period, String name);

  /// Bienvenue, hors session : la promesse d'AnKi
  ///
  /// In fr, this message translates to:
  /// **'Ne ratez plus aucun anniversaire'**
  String get welcomeTitle;

  /// No description provided for @welcomeMessage.
  ///
  /// In fr, this message translates to:
  /// **'AnKi vous prévient 7 jours avant et le jour J, et prépare votre message.'**
  String get welcomeMessage;

  /// Bienvenue : ouvre AnKi sans compte (invité), à sauvegarder plus tard
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get welcomeStart;

  /// No description provided for @welcomeHaveAccount.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai déjà un compte'**
  String get welcomeHaveAccount;

  /// Titre de la connexion, ouverte depuis la bienvenue ou quand l'empreinte verrouille AnKi
  ///
  /// In fr, this message translates to:
  /// **'Bon retour'**
  String get authTitle;

  /// No description provided for @authMessage.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour retrouver vos anniversaires.'**
  String get authMessage;

  /// No description provided for @authLockedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Déverrouillez AnKi pour retrouver vos anniversaires.'**
  String get authLockedMessage;

  /// AnKi verrouillé par l'empreinte : relance l'invite d'empreinte
  ///
  /// In fr, this message translates to:
  /// **'Déverrouiller'**
  String get authUnlock;

  /// No description provided for @loginWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get loginWithGoogle;

  /// No description provided for @loginWithEmail.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec un e-mail'**
  String get loginWithEmail;

  /// No description provided for @noAccountYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ?'**
  String get noAccountYet;

  /// No description provided for @signUp.
  ///
  /// In fr, this message translates to:
  /// **'S\'inscrire'**
  String get signUp;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @firstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get lastName;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'E-mail'**
  String get email;

  /// No description provided for @password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get password;

  /// Bulle et libellé TalkBack de l'œil d'un mot de passe masqué
  ///
  /// In fr, this message translates to:
  /// **'Afficher le mot de passe'**
  String get showPassword;

  /// Bulle et libellé TalkBack de l'œil d'un mot de passe affiché
  ///
  /// In fr, this message translates to:
  /// **'Masquer le mot de passe'**
  String get hidePassword;

  /// Champ unique de la feuille d'anniversaire : le premier mot devient le prénom
  ///
  /// In fr, this message translates to:
  /// **'Prénom et nom'**
  String get fullName;

  /// No description provided for @fullNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Léa Martin, Mamie…'**
  String get fullNameHint;

  /// No description provided for @birthdayDate.
  ///
  /// In fr, this message translates to:
  /// **'Date d\'anniversaire'**
  String get birthdayDate;

  /// Ordre de saisie de la date : jour et mois dans l'ordre des dates courtes de la région (dayFirst ou monthFirst), année facultative
  ///
  /// In fr, this message translates to:
  /// **'{order, select, monthFirst{MM/JJ ou MM/JJ/AAAA} other{JJ/MM ou JJ/MM/AAAA}}'**
  String birthdayDateHint(String order);

  /// No description provided for @birthYearOptional.
  ///
  /// In fr, this message translates to:
  /// **'L\'année est facultative'**
  String get birthYearOptional;

  /// Aperçu d'une date tapée sans année : « Le 12 mars »
  ///
  /// In fr, this message translates to:
  /// **'Le {date}'**
  String birthDatePreview(String date);

  /// Aperçu d'une date tapée avec l'année et l'âge atteint au prochain anniversaire
  ///
  /// In fr, this message translates to:
  /// **'{age, plural, one{Le {date} · aura {age} an} other{Le {date} · aura {age} ans}}'**
  String birthDatePreviewAge(String date, int age);

  /// No description provided for @birthDateIncomplete.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez le jour et le mois'**
  String get birthDateIncomplete;

  /// No description provided for @birthYearDigits.
  ///
  /// In fr, this message translates to:
  /// **'L\'année s\'écrit avec 4 chiffres'**
  String get birthYearDigits;

  /// No description provided for @birthDateInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Cette date n\'existe pas'**
  String get birthDateInvalid;

  /// No description provided for @birthDateFuture.
  ///
  /// In fr, this message translates to:
  /// **'Cette date est dans le futur'**
  String get birthDateFuture;

  /// Titre de la ligne des groupes de la feuille d'anniversaire, de la page Groupes et de sa ligne dans les réglages
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get groups;

  /// Page Groupes : nombre d'anniversaires qui portent le groupe
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune personne} one{{count} personne} other{{count} personnes}}'**
  String groupPeople(int count);

  /// Page Groupes : un groupe prédéfini (Famille, Amis, Travail, Autres), ni modifiable ni supprimable
  ///
  /// In fr, this message translates to:
  /// **'Proposé à tous'**
  String get groupPreset;

  /// Page Groupes : titre quand les groupes n'ont pas pu être lus
  ///
  /// In fr, this message translates to:
  /// **'Groupes indisponibles'**
  String get groupsErrorTitle;

  /// Titre de la feuille qui renomme ou recolore un groupe privé
  ///
  /// In fr, this message translates to:
  /// **'Modifier le groupe'**
  String get editGroup;

  /// Feuille d'un groupe privé : le supprimer ; ses anniversaires le perdent, avec « Annuler »
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le groupe'**
  String get deleteGroup;

  /// Snackbar après la suppression d'un groupe privé, avec « Annuler »
  ///
  /// In fr, this message translates to:
  /// **'« {name} » est supprimé'**
  String groupDeleted(String name);

  /// No description provided for @family.
  ///
  /// In fr, this message translates to:
  /// **'Famille'**
  String get family;

  /// No description provided for @friend.
  ///
  /// In fr, this message translates to:
  /// **'Amis'**
  String get friend;

  /// No description provided for @colleague.
  ///
  /// In fr, this message translates to:
  /// **'Travail'**
  String get colleague;

  /// No description provided for @other.
  ///
  /// In fr, this message translates to:
  /// **'Autres'**
  String get other;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @newBirthday.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel anniversaire'**
  String get newBirthday;

  /// No description provided for @editBirthday.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get editBirthday;

  /// Unité sous l'âge en grand, dans l'orbite du héros et de la page personne, accordée (« 1 an », « 34 ans »)
  ///
  /// In fr, this message translates to:
  /// **'{age, plural, one{an} other{ans}}'**
  String heroAgeUnit(int age);

  /// Âge accordé (« 1 an », « 34 ans »)
  ///
  /// In fr, this message translates to:
  /// **'{age, plural, one{{age} an} other{{age} ans}}'**
  String ageInYears(int age);

  /// No description provided for @requiredField.
  ///
  /// In fr, this message translates to:
  /// **'Champ obligatoire'**
  String get requiredField;

  /// No description provided for @signOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get signOut;

  /// No description provided for @signOutConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir vous déconnecter ?'**
  String get signOutConfirmation;

  /// Snackbar de l'accueil : un ajout, une modification, une suppression ou un vœu n'a pas été enregistré
  ///
  /// In fr, this message translates to:
  /// **'Votre modification n\'a pas pu être enregistrée. Vérifiez votre connexion et réessayez.'**
  String get errorSavingBirthday;

  /// Snackbar de l'accueil : la création d'un groupe a échoué
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer le groupe. Vérifiez votre connexion et réessayez.'**
  String get errorSavingGroup;

  /// No description provided for @today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui 🎉'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In fr, this message translates to:
  /// **'Demain'**
  String get tomorrow;

  /// Surtitre du rappel d'un anniversaire d'hier encore à souhaiter (accueil, sous le héros)
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get yesterday;

  /// Number of days until next birthday
  ///
  /// In fr, this message translates to:
  /// **'Dans {days} jours'**
  String inDays(int days);

  /// No description provided for @connectionError.
  ///
  /// In fr, this message translates to:
  /// **'La connexion n\'a pas abouti. Réessayez dans un instant.'**
  String get connectionError;

  /// L'envoi du lien du mot de passe oublié a échoué sans raison connue
  ///
  /// In fr, this message translates to:
  /// **'Le lien n\'a pas pu partir. Réessayez dans un instant.'**
  String get errorPasswordReset;

  /// No description provided for @registrationError.
  ///
  /// In fr, this message translates to:
  /// **'L\'inscription n\'a pas abouti. Réessayez dans un instant.'**
  String get registrationError;

  /// No description provided for @loginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion par e-mail'**
  String get loginTitle;

  /// No description provided for @signUpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get signUpTitle;

  /// No description provided for @signInButton.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signInButton;

  /// No description provided for @signUpButton.
  ///
  /// In fr, this message translates to:
  /// **'S\'inscrire'**
  String get signUpButton;

  /// Sous « Créer un compte » : ce que le compte apporte
  ///
  /// In fr, this message translates to:
  /// **'Vos anniversaires vous suivront sur tous vos téléphones.'**
  String get signUpMessage;

  /// Sous « Connexion par e-mail », après « Bon retour »
  ///
  /// In fr, this message translates to:
  /// **'Vos anniversaires vous attendent.'**
  String get loginMessage;

  /// No description provided for @haveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà un compte ?'**
  String get haveAccount;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settings;

  /// Titre de bloc des réglages : le pseudo
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get settingsProfile;

  /// Titre de bloc des réglages : thème et langue
  ///
  /// In fr, this message translates to:
  /// **'Préférences'**
  String get settingsPreferences;

  /// Titre de bloc des réglages : rappels et import des contacts
  ///
  /// In fr, this message translates to:
  /// **'Anniversaires'**
  String get settingsBirthdays;

  /// Titre de bloc des réglages : connexion par empreinte
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get settingsSecurity;

  /// Titre de bloc des réglages : déconnexion et suppression du compte
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get settingsAccount;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// Nom de la langue, écrit dans cette langue quelle que soit celle de l'app
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// Nom de la langue, écrit dans cette langue quelle que soit celle de l'app
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @theme.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get theme;

  /// Thème des réglages : suit celui du téléphone
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get themeSystem;

  /// Thème des réglages : toujours clair
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// Thème des réglages : toujours sombre
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @pseudo.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo'**
  String get pseudo;

  /// Sous le champ « Pseudo » des réglages : à quoi il sert
  ///
  /// In fr, this message translates to:
  /// **'Le nom qui vous salue sur l\'accueil'**
  String get pseudoHelper;

  /// Infobulle de la coche du champ « Pseudo »
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le pseudo'**
  String get savePseudo;

  /// Snackbar après l'enregistrement du pseudo
  ///
  /// In fr, this message translates to:
  /// **'Pseudo enregistré'**
  String get pseudoSaved;

  /// Snackbar après une suppression, avec « Annuler » ; le nom en tête évite « de Achraf »
  ///
  /// In fr, this message translates to:
  /// **'{name} n\'est plus dans vos anniversaires'**
  String birthdayDeleted(String name);

  /// Bouton du héros le jour J : l'anniversaire a été souhaité hors d'AnKi (de vive voix, par téléphone)
  ///
  /// In fr, this message translates to:
  /// **'Déjà souhaité'**
  String get alreadyWished;

  /// Pastille du héros une fois l'anniversaire du jour souhaité
  ///
  /// In fr, this message translates to:
  /// **'Souhaité'**
  String get wished;

  /// Snackbar après avoir souhaité un anniversaire, avec « Annuler » ; le nom en tête évite « de Achraf »
  ///
  /// In fr, this message translates to:
  /// **'{name} a reçu vos vœux'**
  String birthdayWished(String name);

  /// Bouton du héros le jour J et de la notification : ouvre la feuille de partage avec un message prêt
  ///
  /// In fr, this message translates to:
  /// **'Souhaiter'**
  String get wish;

  /// Message prêt à envoyer, modifiable dans l'app choisie. La voix de l'utilisateur à un proche : tutoiement
  ///
  /// In fr, this message translates to:
  /// **'Bon anniversaire {name} ! 🎂'**
  String wishMessage(String name);

  /// Message prêt à envoyer le lendemain d'un anniversaire oublié, modifiable dans l'app choisie. Chaleureux, sans reproche ; tutoiement
  ///
  /// In fr, this message translates to:
  /// **'Désolé pour le retard, bon anniversaire {name} !😅🎂'**
  String wishMessageBelated(String name);

  /// Titre de la section de la page d'une personne et de la feuille qui personnalise le message envoyé par « Souhaiter »
  ///
  /// In fr, this message translates to:
  /// **'Message de vœux'**
  String get wishMessageTitle;

  /// Sous le message de la page d'une personne, quand aucun message personnalisé n'est enregistré
  ///
  /// In fr, this message translates to:
  /// **'Message par défaut'**
  String get wishMessageDefaultCaption;

  /// Libellé d'accessibilité de la ligne qui ouvre la feuille du message de vœu
  ///
  /// In fr, this message translates to:
  /// **'Modifier le message de vœux'**
  String get wishMessageEdit;

  /// Libellé du champ de la feuille du message de vœu
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get wishMessageField;

  /// Aide sous le champ du message de vœu
  ///
  /// In fr, this message translates to:
  /// **'Envoyé le jour J et le lendemain. Vous pourrez encore le modifier avant l\'envoi.'**
  String get wishMessageHelper;

  /// Snackbar après « Rétablir le message par défaut », avec « Annuler »
  ///
  /// In fr, this message translates to:
  /// **'Message par défaut rétabli'**
  String get wishMessageRestored;

  /// Bouton de la feuille du message de vœu : efface le message personnalisé
  ///
  /// In fr, this message translates to:
  /// **'Rétablir le message par défaut'**
  String get wishMessageReset;

  /// Snackbar quand la feuille de partage du système ne s'ouvre pas
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir le partage. Réessayez.'**
  String get errorSharing;

  /// Action de la snackbar qui rétablit un anniversaire supprimé
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get undo;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// Puce au bout des groupes : ouvre la création d'un groupe sur place
  ///
  /// In fr, this message translates to:
  /// **'Nouveau groupe'**
  String get newGroup;

  /// Champ de la création d'un groupe
  ///
  /// In fr, this message translates to:
  /// **'Nom du groupe'**
  String get groupName;

  /// Exemples dans le champ vide du nom d'un groupe
  ///
  /// In fr, this message translates to:
  /// **'Voisins, club de lecture…'**
  String get groupNameHint;

  /// Sous le nom d'un nouveau groupe : un groupe porte déjà ce nom
  ///
  /// In fr, this message translates to:
  /// **'Ce groupe existe déjà'**
  String get groupNameTaken;

  /// Bouton de la création d'un groupe
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get createGroup;

  /// Teinte d'un groupe, pour TalkBack quand elle n'a pas de nom
  ///
  /// In fr, this message translates to:
  /// **'Teinte'**
  String get groupTone;

  /// Nom d'une teinte de groupe, lu par TalkBack
  ///
  /// In fr, this message translates to:
  /// **'Bleu'**
  String get toneBlue;

  /// Nom d'une teinte de groupe, lu par TalkBack
  ///
  /// In fr, this message translates to:
  /// **'Vert'**
  String get toneGreen;

  /// Nom d'une teinte de groupe, lu par TalkBack
  ///
  /// In fr, this message translates to:
  /// **'Orange'**
  String get toneOrange;

  /// Nom d'une teinte de groupe, lu par TalkBack
  ///
  /// In fr, this message translates to:
  /// **'Violet'**
  String get toneViolet;

  /// Nom d'une teinte de groupe, lu par TalkBack
  ///
  /// In fr, this message translates to:
  /// **'Cyan'**
  String get toneCyan;

  /// Nom d'une teinte de groupe, lu par TalkBack
  ///
  /// In fr, this message translates to:
  /// **'Rose'**
  String get tonePink;

  /// Nom d'une teinte de groupe, lu par TalkBack
  ///
  /// In fr, this message translates to:
  /// **'Ambre'**
  String get toneAmber;

  /// Nom d'une teinte de groupe, lu par TalkBack
  ///
  /// In fr, this message translates to:
  /// **'Sarcelle'**
  String get toneTeal;

  /// Nom du module Anniversaires : son onglet, l'écran des modules
  ///
  /// In fr, this message translates to:
  /// **'Anniversaires'**
  String get moduleBirthdays;

  /// Nom du module Livres : son onglet, l'écran des modules
  ///
  /// In fr, this message translates to:
  /// **'Livres'**
  String get moduleBooks;

  /// Description du module Anniversaires, sous son nom (écran des modules)
  ///
  /// In fr, this message translates to:
  /// **'Qui fête quoi, et quand le souhaiter'**
  String get moduleBirthdaysDescription;

  /// Description du module Livres, sous son nom (écran des modules)
  ///
  /// In fr, this message translates to:
  /// **'Vos séries : le dernier tome, le prochain et sa date de sortie'**
  String get moduleBooksDescription;

  /// Titre de l'écran des modules, et de sa ligne dans les réglages
  ///
  /// In fr, this message translates to:
  /// **'Modules'**
  String get modules;

  /// Sous-titre de la ligne Modules des réglages : combien de modules sont actifs
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 actif} other{{count} actifs}}'**
  String modulesActiveCount(int count);

  /// Phrase d'introduction de l'écran des modules
  ///
  /// In fr, this message translates to:
  /// **'Choisissez ce qu\'AnKi fait pour vous. Un module désactivé garde vos données.'**
  String get modulesIntro;

  /// Lu par TalkBack tant que les modules de l'utilisateur ne sont pas connus
  ///
  /// In fr, this message translates to:
  /// **'Chargement des modules'**
  String get modulesLoading;

  /// Titre de l'écran des modules quand le profil n'a pas pu être lu
  ///
  /// In fr, this message translates to:
  /// **'Modules indisponibles'**
  String get modulesErrorTitle;

  /// À la place de l'interrupteur, pour un module qu'on ne peut pas désactiver
  ///
  /// In fr, this message translates to:
  /// **'Toujours actif'**
  String get moduleAlwaysOn;

  /// Bouton sous un module : ouvre la confirmation de l'effacement de ses données
  ///
  /// In fr, this message translates to:
  /// **'Effacer les données {module}…'**
  String moduleEraseData(String module);

  /// Titre du dialogue d'effacement des données d'un module
  ///
  /// In fr, this message translates to:
  /// **'Effacer les données {module} ?'**
  String moduleEraseTitle(String module);

  /// Texte du dialogue d'effacement des données d'un module : la conséquence
  ///
  /// In fr, this message translates to:
  /// **'Tout ce que vous avez enregistré dans {module} sera effacé de votre compte, sur tous vos appareils. C\'est définitif.'**
  String moduleEraseConfirmation(String module);

  /// Bouton qui confirme l'effacement des données d'un module
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get moduleErase;

  /// Lu par TalkBack pendant l'effacement des données d'un module
  ///
  /// In fr, this message translates to:
  /// **'Effacement en cours…'**
  String get moduleEraseInProgress;

  /// Snackbar : les données d'un module ont été effacées
  ///
  /// In fr, this message translates to:
  /// **'Données {module} effacées'**
  String moduleErased(String module);

  /// Snackbar : l'effacement des données d'un module a échoué (hors ligne)
  ///
  /// In fr, this message translates to:
  /// **'Les données {module} n\'ont pas pu être effacées. Vérifiez votre connexion et réessayez.'**
  String moduleEraseError(String module);

  /// Snackbar : un lien ou une notification menait vers un module désactivé
  ///
  /// In fr, this message translates to:
  /// **'Le module {module} est désactivé'**
  String moduleDisabledNotice(String module);

  /// Action de la snackbar d'un module désactivé : l'active et l'ouvre
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get moduleEnable;

  /// Infobulle du bouton qui vide le champ de recherche
  ///
  /// In fr, this message translates to:
  /// **'Effacer la recherche'**
  String get clearSearch;

  /// Bouton ou infobulle d'ajout d'un anniversaire
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un anniversaire'**
  String get addBirthday;

  /// En-tête de la première section de l'agenda
  ///
  /// In fr, this message translates to:
  /// **'Dans les 7 jours'**
  String get agendaSoon;

  /// Ligne d'agenda : date du prochain anniversaire (« 14 novembre ») et âge atteint, sans « aura » pour tenir sur une ligne
  ///
  /// In fr, this message translates to:
  /// **'{age, plural, one{{date} · {age} an} other{{date} · {age} ans}}'**
  String agendaLine(String date, int age);

  /// Compte à rebours en toutes lettres : surtitre du héros avant le jour J, lecture de l'orbite par TalkBack
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =0{Aujourd\'hui} =1{Demain} other{Dans {days} jours}}'**
  String countdownDays(int days);

  /// Unité sous le nombre de jours, dans l'orbite d'une ligne d'agenda (« 12 jours ») ou du héros sans année de naissance
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, one{jour} other{jours}}'**
  String orbitDaysUnit(int days);

  /// Sous le nom, dans le héros du jour J (« Léa Martin / fête ses 30 ans aujourd'hui »)
  ///
  /// In fr, this message translates to:
  /// **'{age, plural, one{fête son {age} an aujourd\'hui} other{fête ses {age} ans aujourd\'hui}}'**
  String heroCelebrating(int age);

  /// Sous le nom, dans le héros du jour J, sans année de naissance
  ///
  /// In fr, this message translates to:
  /// **'fête son anniversaire aujourd\'hui'**
  String get heroCelebratingNoAge;

  /// Infobulle du bouton qui ouvre la recherche
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get searchTooltip;

  /// Indication du champ de recherche
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un nom'**
  String get searchHint;

  /// Recherche sans résultat
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat pour « {query} »'**
  String noSearchResults(String query);

  /// Filtres de catégories sans résultat
  ///
  /// In fr, this message translates to:
  /// **'Aucun anniversaire avec ces filtres'**
  String get noFilterResults;

  /// Crée un anniversaire à partir du texte recherché
  ///
  /// In fr, this message translates to:
  /// **'Ajouter « {name} »'**
  String addNamed(String name);

  /// Retire les filtres de catégories de la recherche
  ///
  /// In fr, this message translates to:
  /// **'Effacer les filtres'**
  String get clearFilters;

  /// Infobulle du bouton qui ferme une feuille
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// Libellé du sélecteur de photo du formulaire
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo'**
  String get choosePhoto;

  /// Titre de l'accueil sans aucun anniversaire
  ///
  /// In fr, this message translates to:
  /// **'Qui voulez-vous fêter ?'**
  String get emptyBirthdaysTitle;

  /// Message de l'accueil sans aucun anniversaire
  ///
  /// In fr, this message translates to:
  /// **'Retrouvez les anniversaires de vos contacts en une fois, sans rien retaper.'**
  String get emptyBirthdaysMessage;

  /// Action principale de l'accueil vide : ouvre l'import des contacts
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans mes contacts'**
  String get chooseFromContacts;

  /// No description provided for @addByHand.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à la main'**
  String get addByHand;

  /// Sous l'invitation à importer : ce que lit AnKi dans le répertoire
  ///
  /// In fr, this message translates to:
  /// **'AnKi ne lit que les noms et les dates d\'anniversaire.'**
  String get contactsPrivacy;

  /// No description provided for @bookTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get bookTitle;

  /// Titre d'un livre que Google Books connaît sans titre
  ///
  /// In fr, this message translates to:
  /// **'Titre inconnu'**
  String get bookUntitled;

  /// Numéro ISBN d'un livre scanné
  ///
  /// In fr, this message translates to:
  /// **'ISBN : {isbn}'**
  String isbnLabel(String isbn);

  /// No description provided for @bookNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Livre non trouvé'**
  String get bookNotFound;

  /// No description provided for @deleteAccount.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suppression du compte'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible et supprimera toutes vos données.'**
  String get deleteAccountConfirmation;

  /// Dialogue de suppression d'un compte e-mail : au-dessus du champ mot de passe
  ///
  /// In fr, this message translates to:
  /// **'Pour confirmer, saisissez votre mot de passe.'**
  String get deleteAccountPasswordPrompt;

  /// Dialogue de suppression d'un compte Google : le sélecteur Google s'ouvre après « Supprimer »
  ///
  /// In fr, this message translates to:
  /// **'Pour confirmer, Google vous demandera de choisir votre compte.'**
  String get deleteAccountGooglePrompt;

  /// Libellé lu par TalkBack de la barre de progression du dialogue de suppression
  ///
  /// In fr, this message translates to:
  /// **'Suppression en cours…'**
  String get deleteAccountInProgress;

  /// Sous le champ du dialogue de suppression : le mot de passe est refusé
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe incorrect.'**
  String get deleteAccountWrongPassword;

  /// No description provided for @importContacts.
  ///
  /// In fr, this message translates to:
  /// **'Importer les contacts'**
  String get importContacts;

  /// No description provided for @contactImportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vos contacts'**
  String get contactImportTitle;

  /// En tête de l'aperçu d'import : nouveaux anniversaires trouvés
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 anniversaire trouvé. Décochez-le si vous ne voulez pas le suivre.} other{{count} anniversaires trouvés. Décochez ceux que vous ne voulez pas suivre.}}'**
  String contactImportFound(int count);

  /// No description provided for @contactImportAllKnown.
  ///
  /// In fr, this message translates to:
  /// **'Tous les anniversaires de vos contacts sont déjà dans AnKi.'**
  String get contactImportAllKnown;

  /// No description provided for @contactImportSelectAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout cocher ({count})'**
  String contactImportSelectAll(int count);

  /// No description provided for @contactImportKnown.
  ///
  /// In fr, this message translates to:
  /// **'Déjà dans AnKi'**
  String get contactImportKnown;

  /// Ligne d'un contact de l'aperçu : sa date et dans combien de jours
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =0{{date} · aujourd\'hui} =1{{date} · demain} other{{date} · dans {days} jours}}'**
  String contactImportDetail(String date, int days);

  /// No description provided for @contactImportAdd.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Ajouter} =1{Ajouter 1 anniversaire} other{Ajouter {count} anniversaires}}'**
  String contactImportAdd(int count);

  /// Snackbar après une saisie à la main ; le nom en tête évite « de Achraf » et l'accord en genre
  ///
  /// In fr, this message translates to:
  /// **'{name} est dans vos anniversaires'**
  String birthdayAdded(String name);

  /// Action de la snackbar d'ajout : ouvre la page de la personne
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get personView;

  /// Page personne : âge atteint au prochain anniversaire, avant le jour J
  ///
  /// In fr, this message translates to:
  /// **'{age, plural, one{Aura {age} an} other{Aura {age} ans}}'**
  String personTurning(int age);

  /// Page personne : titre de l'historique des vœux
  ///
  /// In fr, this message translates to:
  /// **'Vœux'**
  String get personWishes;

  /// Page personne : une année où l'anniversaire a été souhaité
  ///
  /// In fr, this message translates to:
  /// **'Souhaité en {year}'**
  String personWishedIn(int year);

  /// No description provided for @personNeverWished.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore souhaité avec AnKi'**
  String get personNeverWished;

  /// Snackbar après l'annulation d'un vœu depuis la page personne
  ///
  /// In fr, this message translates to:
  /// **'Vœu de {year} retiré'**
  String personWishRemoved(int year);

  /// No description provided for @personMissingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaire introuvable'**
  String get personMissingTitle;

  /// No description provided for @personMissingMessage.
  ///
  /// In fr, this message translates to:
  /// **'Il a sans doute été supprimé. Vos anniversaires vous attendent sur l\'accueil.'**
  String get personMissingMessage;

  /// No description provided for @personErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'afficher cet anniversaire'**
  String get personErrorTitle;

  /// Page personne : retire le vœu de l'année en cours de l'historique
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get personWishRemove;

  /// No description provided for @personBackHome.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l\'accueil'**
  String get personBackHome;

  /// No description provided for @birthdaysAdded.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 anniversaire ajouté} other{{count} anniversaires ajoutés}}'**
  String birthdaysAdded(int count);

  /// No description provided for @contactImportDeniedTitle.
  ///
  /// In fr, this message translates to:
  /// **'AnKi n\'a pas accès à vos contacts'**
  String get contactImportDeniedTitle;

  /// No description provided for @contactImportDeniedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez l\'accès pour choisir qui ajouter, ou ajoutez vos proches à la main.'**
  String get contactImportDeniedMessage;

  /// No description provided for @contactImportBlockedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez « Contacts » dans les réglages de l\'app, puis revenez ici. Vous pouvez aussi ajouter vos proches à la main.'**
  String get contactImportBlockedMessage;

  /// No description provided for @contactImportAllow.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser l\'accès'**
  String get contactImportAllow;

  /// No description provided for @openAppSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages'**
  String get openAppSettings;

  /// No description provided for @contactImportEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun anniversaire dans vos contacts'**
  String get contactImportEmptyTitle;

  /// No description provided for @contactImportEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des dates à vos contacts, ou vos proches ici, à la main.'**
  String get contactImportEmptyMessage;

  /// No description provided for @contactImportErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire vos contacts'**
  String get contactImportErrorTitle;

  /// No description provided for @contactImportErrorMessage.
  ///
  /// In fr, this message translates to:
  /// **'Réessayez dans un instant.'**
  String get contactImportErrorMessage;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @sport.
  ///
  /// In fr, this message translates to:
  /// **'Sport'**
  String get sport;

  /// No description provided for @school.
  ///
  /// In fr, this message translates to:
  /// **'École'**
  String get school;

  /// No description provided for @ogs.
  ///
  /// In fr, this message translates to:
  /// **'OG\'s'**
  String get ogs;

  /// No description provided for @gaming.
  ///
  /// In fr, this message translates to:
  /// **'Gaming'**
  String get gaming;

  /// No description provided for @goat.
  ///
  /// In fr, this message translates to:
  /// **'GOAT'**
  String get goat;

  /// No description provided for @doggo.
  ///
  /// In fr, this message translates to:
  /// **'Doggo'**
  String get doggo;

  /// No description provided for @internet.
  ///
  /// In fr, this message translates to:
  /// **'Internet'**
  String get internet;

  /// No description provided for @bff.
  ///
  /// In fr, this message translates to:
  /// **'BFF'**
  String get bff;

  /// No description provided for @celebrity.
  ///
  /// In fr, this message translates to:
  /// **'Célébrité'**
  String get celebrity;

  /// No description provided for @favorite.
  ///
  /// In fr, this message translates to:
  /// **'Favori'**
  String get favorite;

  /// No description provided for @couple.
  ///
  /// In fr, this message translates to:
  /// **'Couple'**
  String get couple;

  /// No description provided for @forgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get forgotPassword;

  /// Sous le champ e-mail de la connexion : « Mot de passe oublié ? » touché sans adresse
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre e-mail pour recevoir le lien'**
  String get resetPasswordNeedsEmail;

  /// Connexion par e-mail : le lien du mot de passe oublié est parti
  ///
  /// In fr, this message translates to:
  /// **'E-mail envoyé à {email}'**
  String resetPasswordSent(String email);

  /// Sous « E-mail envoyé à … » ; neutre, car Firebase ne dit pas si l'adresse a un compte
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez son lien pour choisir un nouveau mot de passe. Rien reçu ? Vérifiez l\'adresse et vos courriers indésirables.'**
  String get resetPasswordSentHint;

  /// Renvoie le lien à l'adresse tapée, corrigée au besoin
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le lien'**
  String get resetPasswordResend;

  /// No description provided for @biometricConnexion.
  ///
  /// In fr, this message translates to:
  /// **'Connexion biométrique'**
  String get biometricConnexion;

  /// No description provided for @biometricConnexionDescription.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser votre empreinte digitale pour vous connecter'**
  String get biometricConnexionDescription;

  /// No description provided for @biometricReason.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez scanner votre empreinte pour vous connecter'**
  String get biometricReason;

  /// No description provided for @biometricError.
  ///
  /// In fr, this message translates to:
  /// **'L\'empreinte n\'a pas pu être vérifiée. Réessayez.'**
  String get biometricError;

  /// No description provided for @biometricRevoked.
  ///
  /// In fr, this message translates to:
  /// **'La connexion biométrique n\'est plus valide. Reconnectez-vous pour continuer.'**
  String get biometricRevoked;

  /// No description provided for @attention.
  ///
  /// In fr, this message translates to:
  /// **'Attention'**
  String get attention;

  /// No description provided for @signOutAnonymousWarning.
  ///
  /// In fr, this message translates to:
  /// **'En vous déconnectant, vous perdrez tous vos anniversaires enregistrés car vous utilisez un compte invité. Voulez-vous continuer ?'**
  String get signOutAnonymousWarning;

  /// No description provided for @saveMyData.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder mes données'**
  String get saveMyData;

  /// No description provided for @dataSavedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Compte sauvegardé'**
  String get dataSavedSuccess;

  /// No description provided for @deleteAndLeave.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer et quitter'**
  String get deleteAndLeave;

  /// Carte de sauvegarde d'un invité, en fin d'agenda.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Gardez votre anniversaire} other{Gardez vos {count} anniversaires}}'**
  String guestBackupTitle(int count);

  /// No description provided for @guestBackupMessage.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Pour l\'instant, il n\'est lié qu\'à ce téléphone. Avec votre compte Google, vous le retrouvez partout.} other{Pour l\'instant, ils ne sont liés qu\'à ce téléphone. Avec votre compte Google, vous les retrouvez partout.}}'**
  String guestBackupMessage(int count);

  /// No description provided for @guestBackupAction.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder avec Google'**
  String get guestBackupAction;

  /// No description provided for @guestBackupTakenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte Google a déjà son agenda AnKi'**
  String get guestBackupTakenTitle;

  /// La carte de sauvegarde, quand le compte Google choisi est déjà celui d'un autre agenda AnKi.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Votre anniversaire reste sur ce téléphone : rien n\'est perdu. Pour le sauvegarder, choisissez un autre compte Google.} other{Vos {count} anniversaires restent sur ce téléphone : rien n\'est perdu. Pour les sauvegarder, choisissez un autre compte Google.}}'**
  String guestBackupTakenMessage(int count);

  /// No description provided for @guestBackupOtherAccount.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un autre compte'**
  String get guestBackupOtherAccount;

  /// No description provided for @guestBackupDone.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Votre anniversaire est sauvegardé} other{Vos {count} anniversaires sont sauvegardés}}'**
  String guestBackupDone(int count);

  /// La carte de sauvegarde, quand le compte Google choisi a déjà un agenda AnKi que l'invité peut ouvrir avec ses anniversaires.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Ouvrez-le avec votre anniversaire : s\'il y est déjà, il ne sera pas doublé. Vous pouvez aussi choisir un autre compte Google.} other{Ouvrez-le avec vos {count} anniversaires : ceux qu\'il a déjà ne seront pas doublés. Vous pouvez aussi choisir un autre compte Google.}}'**
  String guestBackupMergeMessage(int count);

  /// No description provided for @guestBackupMergeAction.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Ouvrir ce compte avec mon anniversaire} other{Ouvrir ce compte avec mes {count} anniversaires}}'**
  String guestBackupMergeAction(int count);

  /// Message après l'ouverture d'un compte avec les anniversaires d'un invité : ceux ajoutés, puis ceux que le compte avait déjà.
  ///
  /// In fr, this message translates to:
  /// **'{added, plural, =0{Rien à ajouter} =1{1 anniversaire ajouté à ce compte} other{{added} anniversaires ajoutés à ce compte}}{known, plural, =0{} =1{ · 1 y était déjà} other{ · {known} y étaient déjà}}'**
  String guestMergeDone(int added, int known);

  /// No description provided for @guestMergeOffline.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion : vos anniversaires restent sur ce téléphone. Réessayez une fois en ligne.'**
  String get guestMergeOffline;

  /// No description provided for @guestMergeFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'ouverture du compte n\'a pas abouti : vos anniversaires restent sur ce téléphone. Réessayez.'**
  String get guestMergeFailed;

  /// No description provided for @guestMergeIncomplete.
  ///
  /// In fr, this message translates to:
  /// **'Compte ouvert, mais vos anniversaires n\'ont pas pu y être ajoutés.'**
  String get guestMergeIncomplete;

  /// No description provided for @biometricEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Connexion biométrique activée'**
  String get biometricEnabled;

  /// No description provided for @biometricDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Connexion biométrique désactivée'**
  String get biometricDisabled;

  /// No description provided for @errorWeakPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe trop faible. Choisissez-en un plus long.'**
  String get errorWeakPassword;

  /// No description provided for @errorEmailAlreadyInUse.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse e-mail a déjà un compte. Connectez-vous plutôt.'**
  String get errorEmailAlreadyInUse;

  /// No description provided for @errorInvalidEmail.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse e-mail n\'est pas valide.'**
  String get errorInvalidEmail;

  /// No description provided for @errorUserNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte AnKi avec cette adresse. Vérifiez-la, ou créez un compte.'**
  String get errorUserNotFound;

  /// Firebase bloque un moment après trop d'essais de connexion ou d'envois
  ///
  /// In fr, this message translates to:
  /// **'Trop d\'essais d\'affilée. Patientez quelques minutes, puis réessayez.'**
  String get errorTooManyRequests;

  /// Compte désactivé dans la console Firebase
  ///
  /// In fr, this message translates to:
  /// **'Ce compte est désactivé. Connectez-vous avec un autre.'**
  String get errorUserDisabled;

  /// Confirmation d'identité avec un autre compte Google que celui de la session
  ///
  /// In fr, this message translates to:
  /// **'Ce compte Google n\'est pas celui connecté à AnKi. Choisissez le bon et réessayez.'**
  String get errorUserMismatch;

  /// Opération sensible refusée par Firebase à une connexion trop ancienne
  ///
  /// In fr, this message translates to:
  /// **'Pour votre sécurité, reconnectez-vous puis réessayez.'**
  String get errorRequiresRecentLogin;

  /// No description provided for @errorWrongPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe incorrect. Réessayez, ou demandez un nouveau mot de passe.'**
  String get errorWrongPassword;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In fr, this message translates to:
  /// **'E-mail ou mot de passe incorrect. Vérifiez-les, ou demandez un nouveau mot de passe.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion. Vérifiez votre réseau et réessayez.'**
  String get errorNetwork;

  /// Connexion (e-mail ou Google) restée sans réponse pendant 30 secondes.
  ///
  /// In fr, this message translates to:
  /// **'La connexion prend trop de temps. Vérifiez votre réseau, puis réessayez.'**
  String get errorSignInTimeout;

  /// No description provided for @errorUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Quelque chose s\'est mal passé. Réessayez dans un instant.'**
  String get errorUnknown;

  /// No description provided for @errorGoogleLogin.
  ///
  /// In fr, this message translates to:
  /// **'La connexion avec Google n\'a pas abouti. Réessayez.'**
  String get errorGoogleLogin;

  /// No description provided for @errorGoogleAccountInUse.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte Google a déjà son agenda AnKi. Choisissez-en un autre pour sauvegarder vos anniversaires.'**
  String get errorGoogleAccountInUse;

  /// No description provided for @errorSignOut.
  ///
  /// In fr, this message translates to:
  /// **'La déconnexion n\'a pas abouti. Réessayez.'**
  String get errorSignOut;

  /// No description provided for @deleteAccountError.
  ///
  /// In fr, this message translates to:
  /// **'Le compte n\'a pas pu être supprimé. Vérifiez votre connexion et réessayez.'**
  String get deleteAccountError;

  /// No description provided for @errorQuotaExceeded.
  ///
  /// In fr, this message translates to:
  /// **'Limite de recherche atteinte. Veuillez réessayer plus tard.'**
  String get errorQuotaExceeded;

  /// No description provided for @notificationChannelName.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaires'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In fr, this message translates to:
  /// **'Rappels d\'anniversaire du jour'**
  String get notificationChannelDescription;

  /// Titre d'un rappel avant le jour J.
  ///
  /// In fr, this message translates to:
  /// **'🎉 {fullName}'**
  String notificationReminderTitle(String fullName);

  /// Sans âge : la notification se répète chaque année avec le même texte.
  ///
  /// In fr, this message translates to:
  /// **'{name} fête son anniversaire aujourd\'hui !'**
  String notificationBirthdayBody(String name);

  /// Rappel avant le jour J. Sans âge : la notification se répète chaque année avec le même texte.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =1{Demain, {name} fête son anniversaire.} other{Dans {days} jours, {name} fête son anniversaire.}}'**
  String notificationReminderBody(String name, int days);

  /// Titre de la notification du jour J.
  ///
  /// In fr, this message translates to:
  /// **'🎂 {fullName}'**
  String notificationBirthdayTitle(String fullName);

  /// No description provided for @reminders.
  ///
  /// In fr, this message translates to:
  /// **'Rappels'**
  String get reminders;

  /// No description provided for @enableReminders.
  ///
  /// In fr, this message translates to:
  /// **'Activer les rappels'**
  String get enableReminders;

  /// No description provided for @remindersEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Rappels activés'**
  String get remindersEnabled;

  /// No description provided for @later.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get later;

  /// En tête de la proposition des rappels, quand une connexion retrouve l'agenda sur un appareil : les anniversaires du compte sont là.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 anniversaire présent} other{{count} anniversaires présents}}'**
  String remindersOfferRestored(int count);

  /// No description provided for @remindersOfferTitle.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =0{Un rappel le jour J} =1{Un rappel la veille, puis le jour J} other{Un rappel {days} jours avant, puis le jour J}}'**
  String remindersOfferTitle(int days);

  /// Heure des rappels, formatée dans la langue de l'app.
  ///
  /// In fr, this message translates to:
  /// **'À {time}, même sans connexion.'**
  String remindersOfferMessage(String time);

  /// Au-dessus de l'exemple de notification : jour et heure du prochain vrai rappel du jour J (date « samedi 7 novembre »).
  ///
  /// In fr, this message translates to:
  /// **'Le {date} à {time}, vous recevrez :'**
  String remindersExampleIntro(String date, String time);

  /// No description provided for @remindersBlockedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez les notifications dans les réglages'**
  String get remindersBlockedTitle;

  /// No description provided for @remindersBlockedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Votre téléphone les bloque pour AnKi. Activez-les dans les réglages, puis revenez ici.'**
  String get remindersBlockedMessage;

  /// Rappels choisis (« 7 jours avant · Le jour J ») puis leur heure, sous « Rappels » dans les réglages.
  ///
  /// In fr, this message translates to:
  /// **'{leads} · {time}'**
  String remindersSchedule(String leads, String time);

  /// No description provided for @reminderLeadMonthBefore.
  ///
  /// In fr, this message translates to:
  /// **'30 jours avant'**
  String get reminderLeadMonthBefore;

  /// No description provided for @reminderLeadWeekBefore.
  ///
  /// In fr, this message translates to:
  /// **'7 jours avant'**
  String get reminderLeadWeekBefore;

  /// No description provided for @reminderLeadDayBefore.
  ///
  /// In fr, this message translates to:
  /// **'La veille'**
  String get reminderLeadDayBefore;

  /// No description provided for @reminderLeadSameDay.
  ///
  /// In fr, this message translates to:
  /// **'Le jour J'**
  String get reminderLeadSameDay;

  /// No description provided for @remindersWhen.
  ///
  /// In fr, this message translates to:
  /// **'Me prévenir'**
  String get remindersWhen;

  /// No description provided for @remindersSameDayAlways.
  ///
  /// In fr, this message translates to:
  /// **'Le jour J est toujours prévenu.'**
  String get remindersSameDayAlways;

  /// No description provided for @remindersTime.
  ///
  /// In fr, this message translates to:
  /// **'Heure des rappels'**
  String get remindersTime;

  /// No description provided for @birthdayRemindersDefault.
  ///
  /// In fr, this message translates to:
  /// **'Comme d\'habitude'**
  String get birthdayRemindersDefault;

  /// No description provided for @birthdayRemindersNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get birthdayRemindersNone;

  /// No description provided for @birthdayRemindersCustom.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisés'**
  String get birthdayRemindersCustom;

  /// No description provided for @remindersOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivés : AnKi ne peut pas vous prévenir.'**
  String get remindersOff;

  /// Carte en haut de l'accueil : les notifications sont refusées ou bloquées sur ce téléphone
  ///
  /// In fr, this message translates to:
  /// **'Rappels désactivés'**
  String get remindersOffNotice;

  /// Bouton de la carte « Rappels désactivés » : rouvre la boîte système
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get remindersOffEnable;

  /// Bouton de la carte quand les notifications sont bloquées : ouvre les réglages du téléphone
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get remindersOffSettings;

  /// Infobulle de la croix de la carte « Rappels désactivés »
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get remindersOffHide;

  /// Snackbar après avoir masqué la carte : où retrouver les rappels
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez toujours les activer dans les paramètres'**
  String get remindersOffHidden;

  /// No description provided for @remindersBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Bloqués dans les réglages du téléphone.'**
  String get remindersBlocked;

  /// Action de l'étagère (icône et état vide) et titre du scanner : ouvre la caméra
  ///
  /// In fr, this message translates to:
  /// **'Scanner un livre'**
  String get scanBook;

  /// Indication du champ de recherche de l'étagère
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une série'**
  String get shelfSearchHint;

  /// Étagère : la recherche ne trouve aucune série
  ///
  /// In fr, this message translates to:
  /// **'Aucune série pour « {query} »'**
  String shelfNoResults(String query);

  /// Carte de l'étagère et titre de la page : tomes sans série ni numéro
  ///
  /// In fr, this message translates to:
  /// **'À classer ({count})'**
  String shelfInbox(int count);

  /// Sous-titre de la carte « À classer » de l'étagère
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Un tome attend sa série} other{{count} tomes attendent leur série}}'**
  String shelfInboxHint(int count);

  /// Étagère vide (premier lancement) : titre
  ///
  /// In fr, this message translates to:
  /// **'Votre étagère vous attend'**
  String get shelfEmptyTitle;

  /// Étagère vide (premier lancement) : pourquoi scanner
  ///
  /// In fr, this message translates to:
  /// **'Scannez vos livres : AnKi retient le dernier tome de chaque série et ceux qu\'il vous manque.'**
  String get shelfEmptyMessage;

  /// Étagère : la lecture a échoué (suivi du message réseau et de « Réessayer »)
  ///
  /// In fr, this message translates to:
  /// **'Étagère indisponible'**
  String get shelfErrorTitle;

  /// Lu par TalkBack sur le squelette de l'étagère
  ///
  /// In fr, this message translates to:
  /// **'Chargement de l\'étagère'**
  String get shelfLoading;

  /// Bandeau discret des pages Livres hors ligne
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne · dates non actualisées'**
  String get shelfOffline;

  /// Ligne d'une série close (étagère et page de la série)
  ///
  /// In fr, this message translates to:
  /// **'Série terminée'**
  String get seriesComplete;

  /// Ligne d'une série : prochain tome et sa date de sortie (« 3 décembre », « décembre 2026 »)
  ///
  /// In fr, this message translates to:
  /// **'Prochain : tome {number} · {date}'**
  String seriesNextOn(int number, String date);

  /// Ligne d'une série : le prochain tome est sorti
  ///
  /// In fr, this message translates to:
  /// **'Prochain : tome {number} · paru'**
  String seriesNextReleased(int number);

  /// Ligne d'une série : aucune source ne connaît la date du prochain tome (jamais « non annoncé »)
  ///
  /// In fr, this message translates to:
  /// **'Prochain : tome {number} · date inconnue'**
  String seriesNextUnknown(int number);

  /// Trous d'une série : numéros séparés par des virgules (« 13, 14 »)
  ///
  /// In fr, this message translates to:
  /// **'Il vous manque {numbers}'**
  String seriesHoles(String numbers);

  /// Trous d'une série, au-delà de cinq : les premiers, puis combien d'autres
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Il vous manque {numbers} et 1 autre} other{Il vous manque {numbers} et {count} autres}}'**
  String seriesHolesMore(String numbers, int count);

  /// Fin d'une liste de numéros lue par TalkBack (« 13, 14 et 15 »)
  ///
  /// In fr, this message translates to:
  /// **'{head} et {last}'**
  String numberListLast(String head, String last);

  /// TalkBack, ligne d'une série : le dernier tome possédé
  ///
  /// In fr, this message translates to:
  /// **'dernier tome {number}'**
  String a11ySeriesLast(int number);

  /// TalkBack, ligne d'une série sans tome possédé
  ///
  /// In fr, this message translates to:
  /// **'aucun tome'**
  String get a11ySeriesEmpty;

  /// TalkBack : le prochain tome a une date au jour
  ///
  /// In fr, this message translates to:
  /// **'prochain tome {number}, sortie le {date}'**
  String a11yNextAnnounced(int number, String date);

  /// TalkBack : le prochain tome a une date au mois (« décembre 2026 »)
  ///
  /// In fr, this message translates to:
  /// **'prochain tome {number}, sortie en {month}'**
  String a11yNextAnnouncedMonth(int number, String month);

  /// TalkBack : le prochain tome est sorti
  ///
  /// In fr, this message translates to:
  /// **'prochain tome {number}, paru'**
  String a11yNextReleased(int number);

  /// TalkBack : la date du prochain tome est inconnue
  ///
  /// In fr, this message translates to:
  /// **'prochain tome {number}, date inconnue'**
  String a11yNextUnknown(int number);

  /// TalkBack : la série est close
  ///
  /// In fr, this message translates to:
  /// **'série terminée'**
  String get a11yNextComplete;

  /// TalkBack : les tomes manquants (« 13 et 14 »)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{il vous manque le tome {numbers}} other{il vous manque les tomes {numbers}}}'**
  String a11ySeriesHoles(int count, String numbers);

  /// Page d'une série : titre de la carte du prochain tome
  ///
  /// In fr, this message translates to:
  /// **'Prochain'**
  String get nextCardTitle;

  /// Carte « Prochain » : le tome est sorti
  ///
  /// In fr, this message translates to:
  /// **'Tome {number} paru · vous ne l\'avez pas'**
  String nextCardReleased(int number);

  /// Carte « Prochain » : date au jour
  ///
  /// In fr, this message translates to:
  /// **'Tome {number} · sortie le {date}'**
  String nextCardAnnounced(int number, String date);

  /// Carte « Prochain » : date au mois
  ///
  /// In fr, this message translates to:
  /// **'Tome {number} · sortie en {month}'**
  String nextCardAnnouncedMonth(int number, String month);

  /// Carte « Prochain » : aucune source ne connaît la date
  ///
  /// In fr, this message translates to:
  /// **'Tome {number} · date inconnue'**
  String nextCardUnknown(int number);

  /// Carte « Prochain » d'une série close
  ///
  /// In fr, this message translates to:
  /// **'Série terminée : rien à attendre'**
  String get nextCardComplete;

  /// Carte « Prochain » : la source est la Bibliothèque nationale de France
  ///
  /// In fr, this message translates to:
  /// **'selon la BnF'**
  String get nextSourceBnf;

  /// Carte « Prochain » : la source est Google Books
  ///
  /// In fr, this message translates to:
  /// **'selon Google Books'**
  String get nextSourceGoogleBooks;

  /// Carte « Prochain » : l'utilisateur a saisi la date
  ///
  /// In fr, this message translates to:
  /// **'date saisie par vous'**
  String get nextSourceUser;

  /// Carte « Prochain » : la source et quand elle a été consultée (« 8 nov. »)
  ///
  /// In fr, this message translates to:
  /// **'{source} · vérifié le {date}'**
  String nextSourceChecked(String source, String date);

  /// Page d'une série : titre des tomes manquants (puces)
  ///
  /// In fr, this message translates to:
  /// **'Il vous manque'**
  String get seriesHolesTitle;

  /// Puce d'un tome manquant ; aussi le titre d'un tome sans titre
  ///
  /// In fr, this message translates to:
  /// **'Tome {number}'**
  String seriesHoleChip(int number);

  /// Page d'une série : titre de la grille des numéros
  ///
  /// In fr, this message translates to:
  /// **'Vos tomes'**
  String get seriesVolumesTitle;

  /// TalkBack, case de la grille : tome possédé
  ///
  /// In fr, this message translates to:
  /// **'Tome {number}, possédé'**
  String seriesVolumeOwned(int number);

  /// TalkBack, case de la grille : tome manquant
  ///
  /// In fr, this message translates to:
  /// **'Tome {number}, manquant'**
  String seriesVolumeMissing(int number);

  /// Page d'une série sans tome possédé, à la place de la grille
  ///
  /// In fr, this message translates to:
  /// **'Aucun tome de cette série pour l\'instant.'**
  String get seriesNoVolume;

  /// Infobulle du menu de la page d'une série
  ///
  /// In fr, this message translates to:
  /// **'Options de la série'**
  String get seriesMenu;

  /// Menu d'une série, et bouton du dialogue de renommage
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get seriesRename;

  /// Menu d'une série : ses tomes rejoignent une autre série
  ///
  /// In fr, this message translates to:
  /// **'Fusionner avec une autre série'**
  String get seriesMerge;

  /// Menu d'une série en cours
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme terminée'**
  String get seriesMarkComplete;

  /// Menu d'une série close
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme en cours'**
  String get seriesMarkOngoing;

  /// Menu d'une série : la série et ses tomes, avec Annuler
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la série'**
  String get seriesDelete;

  /// Titre du dialogue de renommage d'une série
  ///
  /// In fr, this message translates to:
  /// **'Renommer la série'**
  String get seriesRenameTitle;

  /// Libellé du champ nom d'une série
  ///
  /// In fr, this message translates to:
  /// **'Nom de la série'**
  String get seriesNameLabel;

  /// Erreur du champ nom d'une série resté vide
  ///
  /// In fr, this message translates to:
  /// **'Donnez un nom à la série'**
  String get seriesNameRequired;

  /// Titre de la feuille de fusion : choisir la série qui reçoit les tomes
  ///
  /// In fr, this message translates to:
  /// **'Fusionner {name} avec…'**
  String seriesMergeTitle(String name);

  /// Feuille de fusion : ce qui va se passer
  ///
  /// In fr, this message translates to:
  /// **'Ses tomes rejoignent la série choisie, qui garde son nom.'**
  String get seriesMergeHint;

  /// Snackbar après une fusion, avec Annuler
  ///
  /// In fr, this message translates to:
  /// **'{source} fusionnée dans {target}'**
  String seriesMerged(String source, String target);

  /// Snackbar après « Marquer comme terminée », avec Annuler
  ///
  /// In fr, this message translates to:
  /// **'{name} marquée terminée'**
  String seriesMarkedComplete(String name);

  /// Snackbar après « Marquer comme en cours », avec Annuler
  ///
  /// In fr, this message translates to:
  /// **'{name} de nouveau en cours'**
  String seriesMarkedOngoing(String name);

  /// Snackbar après la suppression d'une série, avec Annuler
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{{name} supprimée} =1{{name} supprimée, avec son tome} other{{name} supprimée, avec ses {count} tomes}}'**
  String seriesDeleted(String name, int count);

  /// Page d'une série inconnue (supprimée, fusionnée, autre compte) : titre
  ///
  /// In fr, this message translates to:
  /// **'Série introuvable'**
  String get seriesMissingTitle;

  /// Page d'une série inconnue : explication
  ///
  /// In fr, this message translates to:
  /// **'Elle a peut-être été supprimée ou fusionnée avec une autre.'**
  String get seriesMissingMessage;

  /// Page d'une série inconnue : action
  ///
  /// In fr, this message translates to:
  /// **'Retour à l\'étagère'**
  String get seriesBackToShelf;

  /// Page d'une série : la lecture a échoué
  ///
  /// In fr, this message translates to:
  /// **'Série indisponible'**
  String get seriesErrorTitle;

  /// Snackbar : une écriture sur l'étagère a échoué
  ///
  /// In fr, this message translates to:
  /// **'La modification n\'a pas pu être enregistrée. Vérifiez votre connexion et réessayez.'**
  String get shelfWriteError;

  /// Feuille d'un tome, ligne À classer : son ISBN
  ///
  /// In fr, this message translates to:
  /// **'ISBN {isbn}'**
  String volumeIsbn(String isbn);

  /// Feuille d'un tome : date de parution au jour
  ///
  /// In fr, this message translates to:
  /// **'Paru le {date}'**
  String volumePublished(String date);

  /// Feuille d'un tome : date de parution au mois ou à l'année (« juin 2013 », « 2013 »)
  ///
  /// In fr, this message translates to:
  /// **'Paru en {period}'**
  String volumePublishedIn(String period);

  /// Feuille d'un tome rangé : sa série et son numéro
  ///
  /// In fr, this message translates to:
  /// **'{series} · tome {number}'**
  String volumeInSeries(String series, int number);

  /// Tome scanné hors ligne, pas encore cherché dans les catalogues
  ///
  /// In fr, this message translates to:
  /// **'Infos à compléter'**
  String get volumePending;

  /// Tome qu'aucun catalogue ne connaît
  ///
  /// In fr, this message translates to:
  /// **'Inconnu des catalogues'**
  String get volumeNotFound;

  /// Feuille d'un tome rangé : ouvre le classement
  ///
  /// In fr, this message translates to:
  /// **'Changer de série ou de numéro'**
  String get volumeClassify;

  /// Feuille d'un tome à classer : ouvre le classement
  ///
  /// In fr, this message translates to:
  /// **'Classer'**
  String get volumeSort;

  /// Feuille d'un tome : le retire, avec Annuler
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la collection'**
  String get volumeRemove;

  /// Snackbar après le retrait d'un tome, avec Annuler
  ///
  /// In fr, this message translates to:
  /// **'{title} retiré de la collection'**
  String volumeRemoved(String title);

  /// Titre de la feuille de classement d'un tome
  ///
  /// In fr, this message translates to:
  /// **'Classer ce tome'**
  String get classifyTitle;

  /// Feuille de classement : titre de la liste des séries
  ///
  /// In fr, this message translates to:
  /// **'Série'**
  String get classifySeries;

  /// Feuille de classement : choix d'une série à créer
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle série'**
  String get classifyNewSeries;

  /// Feuille de classement : champ du numéro
  ///
  /// In fr, this message translates to:
  /// **'Numéro du tome'**
  String get classifyNumberLabel;

  /// Feuille de classement : numéro invalide
  ///
  /// In fr, this message translates to:
  /// **'Un numéro entre 1 et {max}'**
  String classifyNumberError(int max);

  /// Feuille de classement : enregistre la série et le numéro
  ///
  /// In fr, this message translates to:
  /// **'Ranger'**
  String get classifySave;

  /// Page À classer vide : titre
  ///
  /// In fr, this message translates to:
  /// **'Tout est rangé'**
  String get inboxEmptyTitle;

  /// Page À classer vide : message
  ///
  /// In fr, this message translates to:
  /// **'Chaque tome a trouvé sa série.'**
  String get inboxEmptyMessage;

  /// Scanner : consigne sous le viseur
  ///
  /// In fr, this message translates to:
  /// **'Visez le code-barres au dos du livre'**
  String get scanHint;

  /// Scanner : la permission caméra est refusée (titre)
  ///
  /// In fr, this message translates to:
  /// **'AnKi n\'a pas accès à la caméra'**
  String get cameraDeniedTitle;

  /// Scanner : la permission caméra est refusée (comment faire)
  ///
  /// In fr, this message translates to:
  /// **'Autorisez la caméra pour scanner le code-barres de vos livres. Si elle reste bloquée, ouvrez les réglages de l\'app.'**
  String get cameraDeniedMessage;

  /// Scanner : redemande la permission caméra
  ///
  /// In fr, this message translates to:
  /// **'Autoriser la caméra'**
  String get cameraAllow;

  /// Scanner : la caméra n'a pas démarré (autre erreur que la permission)
  ///
  /// In fr, this message translates to:
  /// **'Caméra indisponible'**
  String get cameraUnavailableTitle;

  /// Scanner : la caméra n'a pas démarré (comment faire)
  ///
  /// In fr, this message translates to:
  /// **'La caméra n\'a pas pu démarrer. Fermez les autres apps qui l\'utilisent et réessayez.'**
  String get cameraUnavailableMessage;

  /// TalkBack, case de la grille : un numéro possédé en plusieurs éditions
  ///
  /// In fr, this message translates to:
  /// **'Tome {number}, possédé en {count} éditions'**
  String seriesVolumeOwnedEditions(int number, int count);

  /// Titre de la feuille qui choisit l'édition d'un numéro possédé plusieurs fois
  ///
  /// In fr, this message translates to:
  /// **'Tome {number} : quelle édition ?'**
  String volumeEditionsTitle(int number);

  /// TalkBack : les cinq premiers tomes manquants, puis combien d'autres
  ///
  /// In fr, this message translates to:
  /// **'il vous manque les tomes {numbers} et {count} autres'**
  String a11ySeriesHolesMore(String numbers, int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
