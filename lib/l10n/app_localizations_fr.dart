// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'An Ki';

  @override
  String greeting(String period) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'day': 'Bonjour',
      'other': 'Bonsoir',
    });
    return '$_temp0';
  }

  @override
  String greetingName(String period, String name) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'day': 'Bonjour, $name',
      'other': 'Bonsoir, $name',
    });
    return '$_temp0';
  }

  @override
  String get manageBirthdays => 'Gérez vos anniversaires';

  @override
  String get loginWithGoogle => 'Connexion Google';

  @override
  String get loginWithEmail => 'Connexion Email';

  @override
  String get continueWithoutAccount => 'Continuer sans compte';

  @override
  String get noAccountYet => 'Pas encore de compte ?';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get signIn => 'Se connecter';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get email => 'Email';

  @override
  String get password => 'Mot de passe';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get fullName => 'Prénom et nom';

  @override
  String get fullNameHint => 'Léa Martin, Mamie…';

  @override
  String get birthdayDate => 'Date d\'anniversaire';

  @override
  String get birthdayDateHint => 'JJ/MM ou JJ/MM/AAAA';

  @override
  String get birthYearOptional => 'L\'année est facultative';

  @override
  String birthDatePreview(String date) {
    return 'Le $date';
  }

  @override
  String birthDatePreviewAge(String date, int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'Le $date · aura $age ans',
      one: 'Le $date · aura $age an',
    );
    return '$_temp0';
  }

  @override
  String get birthDateIncomplete => 'Indiquez le jour et le mois';

  @override
  String get birthYearDigits => 'L\'année s\'écrit avec 4 chiffres';

  @override
  String get birthDateInvalid => 'Cette date n\'existe pas';

  @override
  String get birthDateFuture => 'Cette date est dans le futur';

  @override
  String get categories => 'Catégories';

  @override
  String get family => 'Famille';

  @override
  String get friend => 'Ami';

  @override
  String get colleague => 'Collègue';

  @override
  String get other => 'Autre';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get add => 'Ajouter';

  @override
  String get newBirthday => 'Nouvel anniversaire';

  @override
  String get editBirthday => 'Modifier';

  @override
  String heroAgeUnit(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'ans',
      one: 'an',
    );
    return '$_temp0';
  }

  @override
  String ageInYears(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age ans',
      one: '$age an',
    );
    return '$_temp0';
  }

  @override
  String get requiredField => 'Champ obligatoire';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get signOutConfirmation =>
      'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get errorSavingBirthday =>
      'Erreur lors de l\'enregistrement de l\'anniversaire';

  @override
  String get errorSavingCategory =>
      'Erreur lors de l\'enregistrement de la catégorie';

  @override
  String get nextBirthday => 'Prochain anniversaire';

  @override
  String get today => 'Aujourd\'hui 🎉';

  @override
  String get tomorrow => 'Demain';

  @override
  String inDays(int days) {
    return 'Dans $days jours';
  }

  @override
  String get connectionError => 'Erreur de connexion';

  @override
  String get registrationError => 'Erreur d\'inscription';

  @override
  String get loginTitle => 'An Ki - Connexion';

  @override
  String get signUpTitle => 'An Ki - Inscription';

  @override
  String get signInButton => 'Se connecter';

  @override
  String get signUpButton => 'S\'inscrire';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get signInText => 'Connectez-vous';

  @override
  String get haveAccount => 'Vous avez déjà un compte ? ';

  @override
  String get dontHaveAccount => 'Pas encore de compte ? ';

  @override
  String get settings => 'Paramètres';

  @override
  String get language => 'Langue';

  @override
  String get theme => 'Thème';

  @override
  String get pseudo => 'Pseudo';

  @override
  String get pseudoUpdated => 'Pseudo mis à jour avec succès !';

  @override
  String get updatePseudo => 'Mettre à jour le pseudo';

  @override
  String birthdayDeleted(String name) {
    return 'Anniversaire de $name supprimé';
  }

  @override
  String get alreadyWished => 'Déjà souhaité';

  @override
  String get wished => 'Souhaité';

  @override
  String birthdayWished(String name) {
    return 'Anniversaire de $name souhaité';
  }

  @override
  String get wish => 'Souhaiter';

  @override
  String wishMessage(String name) {
    return 'Joyeux anniversaire $name ! 🎂 Je te souhaite une très belle journée.';
  }

  @override
  String get errorSharing => 'Impossible d\'ouvrir le partage. Réessayez.';

  @override
  String get undo => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get newCategory => 'Nouvelle catégorie';

  @override
  String get categoryName => 'Nom de la catégorie';

  @override
  String get chooseIcon => 'Choisir une icône';

  @override
  String iconOption(int number) {
    return 'Icône $number';
  }

  @override
  String get tabBirthdays => 'Anniversaires';

  @override
  String get tabScanner => 'Scanner';

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get addBirthday => 'Ajouter un anniversaire';

  @override
  String get viewAgenda => 'Agenda';

  @override
  String get viewCalendar => 'Calendrier';

  @override
  String get agendaSoon => 'Dans les 7 jours';

  @override
  String agendaLine(String date, int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$date · aura $age ans',
      one: '$date · aura $age an',
    );
    return '$_temp0';
  }

  @override
  String countdownDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'J-$days',
      one: 'Demain',
      zero: 'Aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String get heroTurning => 'aura';

  @override
  String get searchTooltip => 'Rechercher';

  @override
  String get searchHint => 'Rechercher un nom';

  @override
  String noSearchResults(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get noFilterResults => 'Aucun anniversaire avec ces filtres';

  @override
  String addNamed(String name) {
    return 'Ajouter « $name »';
  }

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get close => 'Fermer';

  @override
  String get choosePhoto => 'Choisir une photo';

  @override
  String get emptyBirthdaysTitle => 'Vos anniversaires vivront ici';

  @override
  String get emptyBirthdaysMessage =>
      'Ajoutez le premier, ou retrouvez ceux de vos contacts : AnKi vous préviendra au bon moment.';

  @override
  String get importMyContacts => 'Importer mes contacts';

  @override
  String get noBooksMessage =>
      'Scannez le code-barres d\'un livre pour garder une idée de cadeau.';

  @override
  String get bookScannerTitle => 'Scanner de livres';

  @override
  String get bookTitle => 'Titre';

  @override
  String isbnLabel(String isbn) {
    return 'ISBN : $isbn';
  }

  @override
  String get bookNotFound => 'Livre non trouvé';

  @override
  String get noBooksFound => 'Aucun livre trouvé.';

  @override
  String get deleteAccount => 'Supprimer mon compte';

  @override
  String get deleteAccountTitle => 'Suppression du compte';

  @override
  String get deleteAccountConfirmation =>
      'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible et supprimera toutes vos données.';

  @override
  String get importContacts => 'Importer les contacts';

  @override
  String contactsImported(int count) {
    return '$count contacts importés avec succès !';
  }

  @override
  String get noContactsWithBirthday =>
      'Aucun contact avec une date de naissance trouvé.';

  @override
  String get permissionDenied => 'Permission refusée.';

  @override
  String get suggestedCategories => 'Catégories suggérées';

  @override
  String get createCustomCategory => 'Ou créer une catégorie personnalisée';

  @override
  String get noMoreSuggestions => 'Aucune autre catégorie suggérée';

  @override
  String get selectOrCreateCategory =>
      'Veuillez sélectionner ou créer une catégorie';

  @override
  String get sport => 'Sport';

  @override
  String get school => 'École';

  @override
  String get ogs => 'OG\'s';

  @override
  String get gaming => 'Gaming';

  @override
  String get goat => 'GOAT';

  @override
  String get doggo => 'Doggo';

  @override
  String get internet => 'Internet';

  @override
  String get bff => 'BFF';

  @override
  String get celebrity => 'Célébrité';

  @override
  String get favorite => 'Favori';

  @override
  String get couple => 'Couple';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get biometricConnexion => 'Connexion biométrique';

  @override
  String get biometricConnexionDescription =>
      'Utiliser votre empreinte digitale pour vous connecter';

  @override
  String get biometricReason =>
      'Veuillez scanner votre empreinte pour vous connecter';

  @override
  String get biometricError => 'Erreur lors de l\'authentification biométrique';

  @override
  String get biometricRevoked =>
      'La connexion biométrique n\'est plus valide. Reconnectez-vous pour continuer.';

  @override
  String get attention => 'Attention';

  @override
  String get signOutAnonymousWarning =>
      'En vous déconnectant, vous perdrez tous vos anniversaires enregistrés car vous utilisez un compte invité. Voulez-vous continuer ?';

  @override
  String get saveMyData => 'Sauvegarder mes données';

  @override
  String get dataSavedSuccess => 'Compte sauvegardé avec succès !';

  @override
  String get deleteAndLeave => 'Supprimer et quitter';

  @override
  String get biometricEnabled => 'Connexion biométrique activée !';

  @override
  String get biometricDisabled => 'Connexion biométrique désactivée.';

  @override
  String get errorWeakPassword => 'Le mot de passe est trop faible.';

  @override
  String get errorEmailAlreadyInUse => 'Cet email est déjà utilisé.';

  @override
  String get errorInvalidEmail => 'L\'email n\'est pas valide.';

  @override
  String get errorUserNotFound => 'Utilisateur non trouvé.';

  @override
  String get errorWrongPassword => 'Mot de passe incorrect.';

  @override
  String get errorInvalidCredentials => 'E‑mail ou mot de passe incorrect.';

  @override
  String get errorNetwork =>
      'Pas de connexion. Vérifiez votre réseau et réessayez.';

  @override
  String get errorUnknown => 'Une erreur est survenue.';

  @override
  String get errorGoogleLogin => 'Erreur lors de la connexion Google';

  @override
  String get errorSignOut => 'Erreur lors de la déconnexion';

  @override
  String get deleteAccountError => 'Erreur lors de la suppression du compte';

  @override
  String get errorQuotaExceeded =>
      'Limite de recherche atteinte. Veuillez réessayer plus tard.';

  @override
  String get bookCategoryNovel => 'Roman';

  @override
  String get bookCategoryComics => 'BD';

  @override
  String get bookCategoryCooking => 'Cuisine';

  @override
  String get bookCategoryTech => 'Tech';

  @override
  String get notificationChannelName => 'Anniversaires';

  @override
  String get notificationChannelDescription =>
      'Rappels d\'anniversaire du jour';

  @override
  String get notificationReminderTitle => '🎉 Anniversaire bientôt';

  @override
  String notificationBirthdayBody(String name) {
    return 'C\'est l\'anniversaire de $name aujourd\'hui !';
  }

  @override
  String notificationReminderBody(String fullName) {
    return '$fullName fête son anniversaire dans 7 jours.';
  }
}
