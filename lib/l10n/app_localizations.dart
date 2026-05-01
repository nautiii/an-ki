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

  /// No description provided for @appName.
  ///
  /// In fr, this message translates to:
  /// **'An Ki'**
  String get appName;

  /// No description provided for @manageBirthdays.
  ///
  /// In fr, this message translates to:
  /// **'Gérez vos anniversaires'**
  String get manageBirthdays;

  /// No description provided for @hello.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get hello;

  /// No description provided for @loginWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion Google'**
  String get loginWithGoogle;

  /// No description provided for @loginWithEmail.
  ///
  /// In fr, this message translates to:
  /// **'Connexion Email'**
  String get loginWithEmail;

  /// No description provided for @continueWithoutAccount.
  ///
  /// In fr, this message translates to:
  /// **'Continuer sans compte'**
  String get continueWithoutAccount;

  /// No description provided for @noAccountYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ?'**
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

  /// No description provided for @birthDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de naissance'**
  String get birthDate;

  /// No description provided for @category.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get category;

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

  /// No description provided for @validate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get validate;

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

  /// No description provided for @noBirthdaysFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun anniversaire trouvé.'**
  String get noBirthdaysFound;

  /// No description provided for @yearsOld.
  ///
  /// In fr, this message translates to:
  /// **'ans'**
  String get yearsOld;

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

  /// No description provided for @login.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get login;

  /// No description provided for @registration.
  ///
  /// In fr, this message translates to:
  /// **'Inscription'**
  String get registration;

  /// No description provided for @january.
  ///
  /// In fr, this message translates to:
  /// **'Janvier'**
  String get january;

  /// No description provided for @february.
  ///
  /// In fr, this message translates to:
  /// **'Février'**
  String get february;

  /// No description provided for @march.
  ///
  /// In fr, this message translates to:
  /// **'Mars'**
  String get march;

  /// No description provided for @april.
  ///
  /// In fr, this message translates to:
  /// **'Avril'**
  String get april;

  /// No description provided for @may.
  ///
  /// In fr, this message translates to:
  /// **'Mai'**
  String get may;

  /// No description provided for @june.
  ///
  /// In fr, this message translates to:
  /// **'Juin'**
  String get june;

  /// No description provided for @july.
  ///
  /// In fr, this message translates to:
  /// **'Juillet'**
  String get july;

  /// No description provided for @august.
  ///
  /// In fr, this message translates to:
  /// **'Août'**
  String get august;

  /// No description provided for @september.
  ///
  /// In fr, this message translates to:
  /// **'Septembre'**
  String get september;

  /// No description provided for @october.
  ///
  /// In fr, this message translates to:
  /// **'Octobre'**
  String get october;

  /// No description provided for @november.
  ///
  /// In fr, this message translates to:
  /// **'Novembre'**
  String get november;

  /// No description provided for @december.
  ///
  /// In fr, this message translates to:
  /// **'Décembre'**
  String get december;

  /// No description provided for @nextBirthday.
  ///
  /// In fr, this message translates to:
  /// **'Prochain anniversaire'**
  String get nextBirthday;

  /// No description provided for @noBirthdayRegistered.
  ///
  /// In fr, this message translates to:
  /// **'Aucun anniversaire enregistré'**
  String get noBirthdayRegistered;

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

  /// No description provided for @viewAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get viewAll;

  /// No description provided for @showLess.
  ///
  /// In fr, this message translates to:
  /// **'Réduire'**
  String get showLess;

  /// No description provided for @search.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher...'**
  String get search;

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

  /// No description provided for @name.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get name;

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
