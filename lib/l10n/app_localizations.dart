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
  /// **'Continuer avec un e‑mail'**
  String get loginWithEmail;

  /// No description provided for @noAccountYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ?'**
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
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get confirmPassword;

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

  /// Ordre de saisie de la date : jour, mois, année facultative
  ///
  /// In fr, this message translates to:
  /// **'JJ/MM ou JJ/MM/AAAA'**
  String get birthdayDateHint;

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

  /// No description provided for @categories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get categories;

  /// No description provided for @family.
  ///
  /// In fr, this message translates to:
  /// **'Famille'**
  String get family;

  /// No description provided for @friend.
  ///
  /// In fr, this message translates to:
  /// **'Ami'**
  String get friend;

  /// No description provided for @colleague.
  ///
  /// In fr, this message translates to:
  /// **'Collègue'**
  String get colleague;

  /// No description provided for @other.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
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

  /// Unité sous l'âge en grand du héros, accordée (« 1 an », « 34 ans »)
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

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas'**
  String get passwordsDoNotMatch;

  /// No description provided for @signOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get signOut;

  /// No description provided for @signOutConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir vous déconnecter ?'**
  String get signOutConfirmation;

  /// No description provided for @errorSavingBirthday.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'enregistrement de l\'anniversaire'**
  String get errorSavingBirthday;

  /// No description provided for @errorSavingCategory.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'enregistrement de la catégorie'**
  String get errorSavingCategory;

  /// No description provided for @nextBirthday.
  ///
  /// In fr, this message translates to:
  /// **'Prochain anniversaire'**
  String get nextBirthday;

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

  /// Number of days until next birthday
  ///
  /// In fr, this message translates to:
  /// **'Dans {days} jours'**
  String inDays(int days);

  /// No description provided for @connectionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de connexion'**
  String get connectionError;

  /// No description provided for @registrationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur d\'inscription'**
  String get registrationError;

  /// No description provided for @loginTitle.
  ///
  /// In fr, this message translates to:
  /// **'An Ki - Connexion'**
  String get loginTitle;

  /// No description provided for @signUpTitle.
  ///
  /// In fr, this message translates to:
  /// **'An Ki - Inscription'**
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

  /// No description provided for @createAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get createAccount;

  /// No description provided for @signInText.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous'**
  String get signInText;

  /// No description provided for @haveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà un compte ? '**
  String get haveAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ? '**
  String get dontHaveAccount;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get theme;

  /// No description provided for @pseudo.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo'**
  String get pseudo;

  /// No description provided for @pseudoUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo mis à jour avec succès !'**
  String get pseudoUpdated;

  /// No description provided for @updatePseudo.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour le pseudo'**
  String get updatePseudo;

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
  /// **'Joyeux anniversaire {name} ! 🎂 Je te souhaite une très belle journée.'**
  String wishMessage(String name);

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

  /// No description provided for @newCategory.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle catégorie'**
  String get newCategory;

  /// No description provided for @categoryName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la catégorie'**
  String get categoryName;

  /// No description provided for @chooseIcon.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une icône'**
  String get chooseIcon;

  /// Nom lu par les lecteurs d'écran pour une icône de catégorie (numéro dans la grille)
  ///
  /// In fr, this message translates to:
  /// **'Icône {number}'**
  String iconOption(int number);

  /// Libellé de l'onglet des anniversaires (barre du bas)
  ///
  /// In fr, this message translates to:
  /// **'Anniversaires'**
  String get tabBirthdays;

  /// Libellé de l'onglet du scanner de livres (barre du bas)
  ///
  /// In fr, this message translates to:
  /// **'Scanner'**
  String get tabScanner;

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

  /// Segment de l'accueil : liste des anniversaires par période
  ///
  /// In fr, this message translates to:
  /// **'Agenda'**
  String get viewAgenda;

  /// Segment de l'accueil : vue calendrier
  ///
  /// In fr, this message translates to:
  /// **'Calendrier'**
  String get viewCalendar;

  /// En-tête de la première section de l'agenda
  ///
  /// In fr, this message translates to:
  /// **'Dans les 7 jours'**
  String get agendaSoon;

  /// Ligne d'agenda : date du prochain anniversaire et âge atteint
  ///
  /// In fr, this message translates to:
  /// **'{age, plural, one{{date} · aura {age} an} other{{date} · aura {age} ans}}'**
  String agendaLine(String date, int age);

  /// Pastille de compte à rebours d'une ligne d'agenda
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =0{Aujourd\'hui} =1{Demain} other{J-{days}}}'**
  String countdownDays(int days);

  /// Au-dessus de l'âge du héros, avant le jour J (« aura 34 ans »)
  ///
  /// In fr, this message translates to:
  /// **'aura'**
  String get heroTurning;

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
  /// **'Aucun résultat pour « {query} »'**
  String noSearchResults(String query);

  /// Filtres de catégories sans résultat
  ///
  /// In fr, this message translates to:
  /// **'Aucun anniversaire avec ces filtres'**
  String get noFilterResults;

  /// Crée un anniversaire à partir du texte recherché
  ///
  /// In fr, this message translates to:
  /// **'Ajouter « {name} »'**
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
  /// **'Qui voulez-vous fêter ?'**
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

  /// Message de la liste de livres vide
  ///
  /// In fr, this message translates to:
  /// **'Scannez le code-barres d\'un livre pour garder une idée de cadeau.'**
  String get noBooksMessage;

  /// No description provided for @bookScannerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Scanner de livres'**
  String get bookScannerTitle;

  /// No description provided for @bookTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get bookTitle;

  /// Numéro ISBN d'un livre scanné
  ///
  /// In fr, this message translates to:
  /// **'ISBN : {isbn}'**
  String isbnLabel(String isbn);

  /// No description provided for @bookNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Livre non trouvé'**
  String get bookNotFound;

  /// No description provided for @noBooksFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun livre trouvé.'**
  String get noBooksFound;

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
  /// **'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible et supprimera toutes vos données.'**
  String get deleteAccountConfirmation;

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
  /// **'Autorisez « Contacts » dans les réglages de l\'app, puis revenez ici. Vous pouvez aussi ajouter vos proches à la main.'**
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

  /// No description provided for @suggestedCategories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories suggérées'**
  String get suggestedCategories;

  /// No description provided for @createCustomCategory.
  ///
  /// In fr, this message translates to:
  /// **'Ou créer une catégorie personnalisée'**
  String get createCustomCategory;

  /// No description provided for @noMoreSuggestions.
  ///
  /// In fr, this message translates to:
  /// **'Aucune autre catégorie suggérée'**
  String get noMoreSuggestions;

  /// No description provided for @selectOrCreateCategory.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner ou créer une catégorie'**
  String get selectOrCreateCategory;

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
  /// **'Mot de passe oublié ?'**
  String get forgotPassword;

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
  /// **'Erreur lors de l\'authentification biométrique'**
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
  /// **'En vous déconnectant, vous perdrez tous vos anniversaires enregistrés car vous utilisez un compte invité. Voulez-vous continuer ?'**
  String get signOutAnonymousWarning;

  /// No description provided for @saveMyData.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder mes données'**
  String get saveMyData;

  /// No description provided for @dataSavedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Compte sauvegardé avec succès !'**
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
  /// **'{count, plural, =1{Votre anniversaire reste sur ce téléphone : rien n\'est perdu. Pour le sauvegarder, choisissez un autre compte Google.} other{Vos {count} anniversaires restent sur ce téléphone : rien n\'est perdu. Pour les sauvegarder, choisissez un autre compte Google.}}'**
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

  /// No description provided for @biometricEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Connexion biométrique activée !'**
  String get biometricEnabled;

  /// No description provided for @biometricDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Connexion biométrique désactivée.'**
  String get biometricDisabled;

  /// No description provided for @errorWeakPassword.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe est trop faible.'**
  String get errorWeakPassword;

  /// No description provided for @errorEmailAlreadyInUse.
  ///
  /// In fr, this message translates to:
  /// **'Cet email est déjà utilisé.'**
  String get errorEmailAlreadyInUse;

  /// No description provided for @errorInvalidEmail.
  ///
  /// In fr, this message translates to:
  /// **'L\'email n\'est pas valide.'**
  String get errorInvalidEmail;

  /// No description provided for @errorUserNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur non trouvé.'**
  String get errorUserNotFound;

  /// No description provided for @errorWrongPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe incorrect.'**
  String get errorWrongPassword;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In fr, this message translates to:
  /// **'E‑mail ou mot de passe incorrect.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion. Vérifiez votre réseau et réessayez.'**
  String get errorNetwork;

  /// No description provided for @errorUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue.'**
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
  /// **'Erreur lors de la déconnexion'**
  String get errorSignOut;

  /// No description provided for @deleteAccountError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la suppression du compte'**
  String get deleteAccountError;

  /// No description provided for @errorQuotaExceeded.
  ///
  /// In fr, this message translates to:
  /// **'Limite de recherche atteinte. Veuillez réessayer plus tard.'**
  String get errorQuotaExceeded;

  /// No description provided for @bookCategoryNovel.
  ///
  /// In fr, this message translates to:
  /// **'Roman'**
  String get bookCategoryNovel;

  /// No description provided for @bookCategoryComics.
  ///
  /// In fr, this message translates to:
  /// **'BD'**
  String get bookCategoryComics;

  /// No description provided for @bookCategoryCooking.
  ///
  /// In fr, this message translates to:
  /// **'Cuisine'**
  String get bookCategoryCooking;

  /// No description provided for @bookCategoryTech.
  ///
  /// In fr, this message translates to:
  /// **'Tech'**
  String get bookCategoryTech;

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

  /// No description provided for @notificationReminderTitle.
  ///
  /// In fr, this message translates to:
  /// **'🎉 Anniversaire bientôt'**
  String get notificationReminderTitle;

  /// Sans âge : la notification se répète chaque année avec le même texte.
  ///
  /// In fr, this message translates to:
  /// **'{name} fête son anniversaire aujourd\'hui !'**
  String notificationBirthdayBody(String name);

  /// Sans âge : la notification se répète chaque année avec le même texte.
  ///
  /// In fr, this message translates to:
  /// **'{fullName} fête son anniversaire dans 7 jours.'**
  String notificationReminderBody(String fullName);

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

  /// En tête de la proposition des rappels, quand une connexion retrouve l'agenda sur un appareil.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 anniversaire retrouvé} other{{count} anniversaires retrouvés}}'**
  String remindersOfferRestored(int count);

  /// No description provided for @remindersOfferTitle.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =1{Un rappel la veille, puis le jour J} other{Un rappel {days} jours avant, puis le jour J}}'**
  String remindersOfferTitle(int days);

  /// Heure des rappels, formatée dans la langue de l'app.
  ///
  /// In fr, this message translates to:
  /// **'À {time}, même sans connexion.'**
  String remindersOfferMessage(String time);

  /// No description provided for @remindersExample.
  ///
  /// In fr, this message translates to:
  /// **'Exemple de rappel'**
  String get remindersExample;

  /// En-tête de l'exemple de notification : jour et heure du prochain vrai rappel.
  ///
  /// In fr, this message translates to:
  /// **'AnKi · {date} à {time}'**
  String remindersExampleWhen(String date, String time);

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

  /// No description provided for @remindersSchedule.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =1{La veille et le jour J, à {time}} other{{days} jours avant et le jour J, à {time}}}'**
  String remindersSchedule(int days, String time);

  /// No description provided for @remindersOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivés : AnKi ne peut pas vous prévenir.'**
  String get remindersOff;

  /// No description provided for @remindersBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Bloqués dans les réglages du téléphone.'**
  String get remindersBlocked;
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
