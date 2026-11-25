// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

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
  String get welcomeTitle => 'Ne ratez plus aucun anniversaire';

  @override
  String get welcomeMessage =>
      'AnKi vous prévient 7 jours avant et le jour J, et prépare votre message.';

  @override
  String get welcomeStart => 'Commencer';

  @override
  String get welcomeHaveAccount => 'J\'ai déjà un compte';

  @override
  String get authTitle => 'Bon retour';

  @override
  String get authMessage => 'Connectez-vous pour retrouver vos anniversaires.';

  @override
  String get authLockedMessage =>
      'Déverrouillez AnKi pour retrouver vos anniversaires.';

  @override
  String get authUnlock => 'Déverrouiller';

  @override
  String get loginWithGoogle => 'Continuer avec Google';

  @override
  String get loginWithEmail => 'Continuer avec un e-mail';

  @override
  String get noAccountYet => 'Pas encore de compte ?';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get signIn => 'Se connecter';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get hidePassword => 'Masquer le mot de passe';

  @override
  String get fullName => 'Prénom et nom';

  @override
  String get fullNameHint => 'Léa Martin, Mamie…';

  @override
  String get birthdayDate => 'Date d\'anniversaire';

  @override
  String birthdayDateHint(String order) {
    String _temp0 = intl.Intl.selectLogic(order, {
      'monthFirst': 'MM/JJ ou MM/JJ/AAAA',
      'other': 'JJ/MM ou JJ/MM/AAAA',
    });
    return '$_temp0';
  }

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
  String get groups => 'Groupes';

  @override
  String groupPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes',
      one: '$count personne',
      zero: 'Aucune personne',
    );
    return '$_temp0';
  }

  @override
  String get groupPreset => 'Proposé à tous';

  @override
  String get groupsErrorTitle => 'Groupes indisponibles';

  @override
  String get editGroup => 'Modifier le groupe';

  @override
  String get deleteGroup => 'Supprimer le groupe';

  @override
  String groupDeleted(String name) {
    return '« $name » est supprimé';
  }

  @override
  String get family => 'Famille';

  @override
  String get friend => 'Amis';

  @override
  String get colleague => 'Travail';

  @override
  String get other => 'Autres';

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
  String get signOut => 'Se déconnecter';

  @override
  String get signOutConfirmation =>
      'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get errorSavingBirthday =>
      'Votre modification n\'a pas pu être enregistrée. Vérifiez votre connexion et réessayez.';

  @override
  String get errorSavingGroup =>
      'Impossible d\'enregistrer le groupe. Vérifiez votre connexion et réessayez.';

  @override
  String get today => 'Aujourd\'hui 🎉';

  @override
  String get tomorrow => 'Demain';

  @override
  String get yesterday => 'Hier';

  @override
  String inDays(int days) {
    return 'Dans $days jours';
  }

  @override
  String get connectionError =>
      'La connexion n\'a pas abouti. Réessayez dans un instant.';

  @override
  String get errorPasswordReset =>
      'Le lien n\'a pas pu partir. Réessayez dans un instant.';

  @override
  String get registrationError =>
      'L\'inscription n\'a pas abouti. Réessayez dans un instant.';

  @override
  String get loginTitle => 'Connexion par e-mail';

  @override
  String get signUpTitle => 'Créer un compte';

  @override
  String get signInButton => 'Se connecter';

  @override
  String get signUpButton => 'S\'inscrire';

  @override
  String get signUpMessage =>
      'Vos anniversaires vous suivront sur tous vos téléphones.';

  @override
  String get loginMessage => 'Vos anniversaires vous attendent.';

  @override
  String get haveAccount => 'Vous avez déjà un compte ?';

  @override
  String get settings => 'Paramètres';

  @override
  String get settingsProfile => 'Profil';

  @override
  String get settingsPreferences => 'Préférences';

  @override
  String get settingsBirthdays => 'Anniversaires';

  @override
  String get settingsSecurity => 'Sécurité';

  @override
  String get settingsAccount => 'Compte';

  @override
  String get language => 'Langue';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get theme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get pseudo => 'Pseudo';

  @override
  String get pseudoHelper => 'Le nom qui vous salue sur l\'accueil';

  @override
  String get savePseudo => 'Enregistrer le pseudo';

  @override
  String get pseudoSaved => 'Pseudo enregistré';

  @override
  String birthdayDeleted(String name) {
    return '$name n\'est plus dans vos anniversaires';
  }

  @override
  String get alreadyWished => 'Déjà souhaité';

  @override
  String get wished => 'Souhaité';

  @override
  String birthdayWished(String name) {
    return '$name a reçu vos vœux';
  }

  @override
  String get wish => 'Souhaiter';

  @override
  String get wishMessageTitle => 'Message de vœux';

  @override
  String get wishMessageEdit => 'Modifier le message de vœux';

  @override
  String get wishMessageField => 'Message';

  @override
  String get wishMessageHelper =>
      'Proposé en premier le jour J et le lendemain. Vous pourrez encore le modifier avant l\'envoi.';

  @override
  String get wishMessageRestored => 'Messages proposés rétablis';

  @override
  String get wishMessageReset => 'Revenir aux messages proposés';

  @override
  String get errorSharing => 'Impossible d\'ouvrir le partage. Réessayez.';

  @override
  String get undo => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get newGroup => 'Nouveau groupe';

  @override
  String get groupName => 'Nom du groupe';

  @override
  String get groupNameHint => 'Voisins, club de lecture…';

  @override
  String get groupNameTaken => 'Ce groupe existe déjà';

  @override
  String get createGroup => 'Créer';

  @override
  String get groupTone => 'Teinte';

  @override
  String get toneBlue => 'Bleu';

  @override
  String get toneGreen => 'Vert';

  @override
  String get toneOrange => 'Orange';

  @override
  String get toneViolet => 'Violet';

  @override
  String get toneCyan => 'Cyan';

  @override
  String get tonePink => 'Rose';

  @override
  String get toneAmber => 'Ambre';

  @override
  String get toneTeal => 'Sarcelle';

  @override
  String get moduleBirthdays => 'Anniversaires';

  @override
  String get moduleBooks => 'Livres';

  @override
  String get moduleBirthdaysDescription =>
      'Qui fête quoi, et quand le souhaiter';

  @override
  String get moduleBooksDescription =>
      'Vos séries : le dernier tome, le prochain et sa date de sortie';

  @override
  String moduleDiscoveryTitle(String name) {
    return 'Nouveau · $name';
  }

  @override
  String get moduleBooksDiscoveryMessage =>
      'Suivez vos séries : le dernier tome acheté, le prochain et sa date de sortie.';

  @override
  String get moduleDiscoveryLater => 'Plus tard';

  @override
  String get moduleDiscoveryTry => 'Essayer';

  @override
  String get modules => 'Modules';

  @override
  String modulesActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actifs',
      one: '1 actif',
    );
    return '$_temp0';
  }

  @override
  String get modulesIntro =>
      'Choisissez ce qu\'AnKi fait pour vous. Un module désactivé garde vos données.';

  @override
  String get modulesLoading => 'Chargement des modules';

  @override
  String get modulesErrorTitle => 'Modules indisponibles';

  @override
  String get moduleAlwaysOn => 'Toujours actif';

  @override
  String moduleEraseData(String module) {
    return 'Effacer les données $module…';
  }

  @override
  String moduleEraseTitle(String module) {
    return 'Effacer les données $module ?';
  }

  @override
  String moduleEraseConfirmation(String module) {
    return 'Tout ce que vous avez enregistré dans $module sera effacé de votre compte, sur tous vos appareils. C\'est définitif.';
  }

  @override
  String get moduleErase => 'Effacer';

  @override
  String get moduleEraseInProgress => 'Effacement en cours…';

  @override
  String moduleErased(String module) {
    return 'Données $module effacées';
  }

  @override
  String moduleEraseError(String module) {
    return 'Les données $module n\'ont pas pu être effacées. Vérifiez votre connexion et réessayez.';
  }

  @override
  String moduleDisabledNotice(String module) {
    return 'Le module $module est désactivé';
  }

  @override
  String get moduleEnable => 'Activer';

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get addBirthday => 'Ajouter un anniversaire';

  @override
  String get agendaSoon => 'Dans les 7 jours';

  @override
  String agendaLine(String date, int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$date · $age ans',
      one: '$date · $age an',
    );
    return '$_temp0';
  }

  @override
  String countdownDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Dans $days jours',
      one: 'Demain',
      zero: 'Aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String orbitDaysUnit(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'jours',
      one: 'jour',
    );
    return '$_temp0';
  }

  @override
  String heroCelebrating(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'fête ses $age ans aujourd\'hui',
      one: 'fête son $age an aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String get heroCelebratingNoAge => 'fête son anniversaire aujourd\'hui';

  @override
  String get searchTooltip => 'Rechercher';

  @override
  String get searchHint => 'Rechercher un nom';

  @override
  String noSearchResults(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get noFilterResults => 'Aucun anniversaire avec ces filtres';

  @override
  String addNamed(String name) {
    return 'Ajouter « $name »';
  }

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get close => 'Fermer';

  @override
  String get choosePhoto => 'Choisir une photo';

  @override
  String get emptyBirthdaysTitle => 'Qui voulez-vous fêter ?';

  @override
  String get emptyBirthdaysMessage =>
      'Retrouvez les anniversaires de vos contacts en une fois, sans rien retaper.';

  @override
  String get chooseFromContacts => 'Choisir dans mes contacts';

  @override
  String get addByHand => 'Ajouter à la main';

  @override
  String get contactsPrivacy =>
      'L\'import ne lit que les noms et les dates d\'anniversaire.';

  @override
  String get bookTitle => 'Titre';

  @override
  String get bookUntitled => 'Titre inconnu';

  @override
  String get deleteAccount => 'Supprimer mon compte';

  @override
  String get deleteAccountTitle => 'Suppression du compte';

  @override
  String get deleteAccountConfirmation =>
      'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible et supprimera toutes vos données.';

  @override
  String get deleteAccountPasswordPrompt =>
      'Pour confirmer, saisissez votre mot de passe.';

  @override
  String get deleteAccountGooglePrompt =>
      'Pour confirmer, Google vous demandera de choisir votre compte.';

  @override
  String get deleteAccountInProgress => 'Suppression en cours…';

  @override
  String get deleteAccountWrongPassword => 'Mot de passe incorrect.';

  @override
  String get importContacts => 'Importer les contacts';

  @override
  String get contactImportTitle => 'Vos contacts';

  @override
  String contactImportFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count anniversaires trouvés. Décochez ceux que vous ne voulez pas suivre.',
      one:
          '1 anniversaire trouvé. Décochez-le si vous ne voulez pas le suivre.',
    );
    return '$_temp0';
  }

  @override
  String get contactImportAllKnown =>
      'Tous les anniversaires de vos contacts sont déjà dans AnKi.';

  @override
  String contactImportSelectAll(int count) {
    return 'Tout cocher ($count)';
  }

  @override
  String get contactImportKnown => 'Déjà dans AnKi';

  @override
  String contactImportDetail(String date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$date · dans $days jours',
      one: '$date · demain',
      zero: '$date · aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String contactImportAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouter $count anniversaires',
      one: 'Ajouter 1 anniversaire',
      zero: 'Ajouter',
    );
    return '$_temp0';
  }

  @override
  String birthdayAdded(String name) {
    return '$name est dans vos anniversaires';
  }

  @override
  String get personView => 'Voir';

  @override
  String personTurning(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'Aura $age ans',
      one: 'Aura $age an',
    );
    return '$_temp0';
  }

  @override
  String get personWishes => 'Vœux';

  @override
  String personWishedIn(int year) {
    return 'Souhaité en $year';
  }

  @override
  String personWishRemoved(int year) {
    return 'Vœu de $year retiré';
  }

  @override
  String get personMissingTitle => 'Anniversaire introuvable';

  @override
  String get personMissingMessage =>
      'Il a sans doute été supprimé. Vos anniversaires vous attendent sur l\'accueil.';

  @override
  String get personErrorTitle => 'Impossible d\'afficher cet anniversaire';

  @override
  String get personBackHome => 'Retour à l\'accueil';

  @override
  String birthdaysAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anniversaires ajoutés',
      one: '1 anniversaire ajouté',
    );
    return '$_temp0';
  }

  @override
  String get contactImportDeniedTitle => 'AnKi n\'a pas accès à vos contacts';

  @override
  String get contactImportDeniedMessage =>
      'Autorisez l\'accès pour choisir qui ajouter, ou ajoutez vos proches à la main.';

  @override
  String get contactImportBlockedMessage =>
      'Autorisez « Contacts » dans les réglages de l\'app, puis revenez ici. Vous pouvez aussi ajouter vos proches à la main.';

  @override
  String get contactImportAllow => 'Autoriser l\'accès';

  @override
  String get openAppSettings => 'Ouvrir les réglages';

  @override
  String get contactImportEmptyTitle => 'Aucun anniversaire dans vos contacts';

  @override
  String get contactImportEmptyMessage =>
      'Ajoutez des dates à vos contacts, ou vos proches ici, à la main.';

  @override
  String get contactImportErrorTitle => 'Impossible de lire vos contacts';

  @override
  String get contactImportErrorMessage => 'Réessayez dans un instant.';

  @override
  String get retry => 'Réessayer';

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
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get resetPasswordNeedsEmail =>
      'Saisissez votre e-mail pour recevoir le lien';

  @override
  String resetPasswordSent(String email) {
    return 'E-mail envoyé à $email';
  }

  @override
  String get resetPasswordSentHint =>
      'Ouvrez son lien pour choisir un nouveau mot de passe. Rien reçu ? Vérifiez l\'adresse et vos courriers indésirables.';

  @override
  String get resetPasswordResend => 'Renvoyer le lien';

  @override
  String get biometricConnexion => 'Connexion biométrique';

  @override
  String get biometricConnexionDescription =>
      'Utiliser votre empreinte digitale pour vous connecter';

  @override
  String get biometricReason =>
      'Veuillez scanner votre empreinte pour vous connecter';

  @override
  String get biometricError =>
      'L\'empreinte n\'a pas pu être vérifiée. Réessayez.';

  @override
  String get biometricRevoked =>
      'La connexion biométrique n\'est plus valide. Reconnectez-vous pour continuer.';

  @override
  String get attention => 'Attention';

  @override
  String get signOutAnonymousWarning =>
      'En vous déconnectant, vous perdrez tous vos anniversaires enregistrés car vous utilisez un compte invité. Voulez-vous continuer ?';

  @override
  String get saveMyData => 'Sauvegarder mes données';

  @override
  String get dataSavedSuccess => 'Compte sauvegardé';

  @override
  String get deleteAndLeave => 'Supprimer et quitter';

  @override
  String guestBackupTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gardez vos $count anniversaires',
      one: 'Gardez votre anniversaire',
    );
    return '$_temp0';
  }

  @override
  String guestBackupMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pour l\'instant, ils ne sont liés qu\'à ce téléphone. Avec votre compte Google, vous les retrouvez partout.',
      one: 'Pour l\'instant, il n\'est lié qu\'à ce téléphone. Avec votre compte Google, vous le retrouvez partout.',
    );
    return '$_temp0';
  }

  @override
  String get guestBackupAction => 'Sauvegarder avec Google';

  @override
  String get guestBackupTakenTitle => 'Ce compte Google a déjà son agenda AnKi';

  @override
  String guestBackupTakenMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Vos $count anniversaires restent sur ce téléphone : rien n\'est perdu. Pour les sauvegarder, choisissez un autre compte Google.',
      one: 'Votre anniversaire reste sur ce téléphone : rien n\'est perdu. Pour le sauvegarder, choisissez un autre compte Google.',
    );
    return '$_temp0';
  }

  @override
  String get guestBackupOtherAccount => 'Choisir un autre compte';

  @override
  String guestBackupDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vos $count anniversaires sont sauvegardés',
      one: 'Votre anniversaire est sauvegardé',
    );
    return '$_temp0';
  }

  @override
  String guestBackupMergeMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ouvrez-le avec vos $count anniversaires : ceux qu\'il a déjà ne seront pas doublés. Vous pouvez aussi choisir un autre compte Google.',
      one: 'Ouvrez-le avec votre anniversaire : s\'il y est déjà, il ne sera pas doublé. Vous pouvez aussi choisir un autre compte Google.',
    );
    return '$_temp0';
  }

  @override
  String guestBackupMergeAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ouvrir ce compte avec mes $count anniversaires',
      one: 'Ouvrir ce compte avec mon anniversaire',
    );
    return '$_temp0';
  }

  @override
  String guestMergeDone(int added, int known) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added anniversaires ajoutés à ce compte',
      one: '1 anniversaire ajouté à ce compte',
      zero: 'Rien à ajouter',
    );
    String _temp1 = intl.Intl.pluralLogic(
      known,
      locale: localeName,
      other: ' · $known y étaient déjà',
      one: ' · 1 y était déjà',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String get guestMergeOffline =>
      'Pas de connexion : vos anniversaires restent sur ce téléphone. Réessayez une fois en ligne.';

  @override
  String get guestMergeFailed =>
      'L\'ouverture du compte n\'a pas abouti : vos anniversaires restent sur ce téléphone. Réessayez.';

  @override
  String get guestMergeIncomplete =>
      'Compte ouvert, mais vos anniversaires n\'ont pas pu y être ajoutés.';

  @override
  String get biometricEnabled => 'Connexion biométrique activée';

  @override
  String get biometricDisabled => 'Connexion biométrique désactivée';

  @override
  String get errorWeakPassword =>
      'Mot de passe trop faible. Choisissez-en un plus long.';

  @override
  String get errorEmailAlreadyInUse =>
      'Cette adresse e-mail a déjà un compte. Connectez-vous plutôt.';

  @override
  String get errorInvalidEmail => 'Cette adresse e-mail n\'est pas valide.';

  @override
  String get errorUserNotFound =>
      'Aucun compte AnKi avec cette adresse. Vérifiez-la, ou créez un compte.';

  @override
  String get errorTooManyRequests =>
      'Trop d\'essais d\'affilée. Patientez quelques minutes, puis réessayez.';

  @override
  String get errorUserDisabled =>
      'Ce compte est désactivé. Connectez-vous avec un autre.';

  @override
  String get errorUserMismatch =>
      'Ce compte Google n\'est pas celui connecté à AnKi. Choisissez le bon et réessayez.';

  @override
  String get errorRequiresRecentLogin =>
      'Pour votre sécurité, reconnectez-vous puis réessayez.';

  @override
  String get errorWrongPassword =>
      'Mot de passe incorrect. Réessayez, ou demandez un nouveau mot de passe.';

  @override
  String get errorInvalidCredentials =>
      'E-mail ou mot de passe incorrect. Vérifiez-les, ou demandez un nouveau mot de passe.';

  @override
  String get errorNetwork =>
      'Pas de connexion. Vérifiez votre réseau et réessayez.';

  @override
  String get errorSignInTimeout =>
      'La connexion prend trop de temps. Vérifiez votre réseau, puis réessayez.';

  @override
  String get errorUnknown =>
      'Quelque chose s\'est mal passé. Réessayez dans un instant.';

  @override
  String get errorGoogleLogin =>
      'La connexion avec Google n\'a pas abouti. Réessayez.';

  @override
  String get errorGoogleAccountInUse =>
      'Ce compte Google a déjà son agenda AnKi. Choisissez-en un autre pour sauvegarder vos anniversaires.';

  @override
  String get errorSignOut => 'La déconnexion n\'a pas abouti. Réessayez.';

  @override
  String get deleteAccountError =>
      'Le compte n\'a pas pu être supprimé. Vérifiez votre connexion et réessayez.';

  @override
  String get notificationChannelName => 'Anniversaires';

  @override
  String get notificationChannelDescription =>
      'Rappels d\'anniversaire du jour';

  @override
  String notificationReminderTitle(String fullName) {
    return '🎉 $fullName';
  }

  @override
  String notificationBirthdayBody(String name) {
    return '$name fête son anniversaire aujourd\'hui !';
  }

  @override
  String notificationReminderBody(String name, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Dans $days jours, $name fête son anniversaire.',
      one: 'Demain, $name fête son anniversaire.',
    );
    return '$_temp0';
  }

  @override
  String notificationBirthdayTitle(String fullName) {
    return '🎂 $fullName';
  }

  @override
  String get reminders => 'Rappels';

  @override
  String get enableReminders => 'Activer les rappels';

  @override
  String get remindersEnabled => 'Rappels activés';

  @override
  String get later => 'Plus tard';

  @override
  String remindersOfferRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anniversaires présents',
      one: '1 anniversaire présent',
    );
    return '$_temp0';
  }

  @override
  String remindersOfferTitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Un rappel $days jours avant, puis le jour J',
      one: 'Un rappel la veille, puis le jour J',
      zero: 'Un rappel le jour J',
    );
    return '$_temp0';
  }

  @override
  String remindersOfferMessage(String time) {
    return 'À $time, même sans connexion.';
  }

  @override
  String remindersExampleIntro(String date, String time) {
    return 'Le $date à $time, vous recevrez :';
  }

  @override
  String get remindersBlockedTitle =>
      'Autorisez les notifications dans les réglages';

  @override
  String get remindersBlockedMessage =>
      'Votre téléphone les bloque pour AnKi. Activez-les dans les réglages, puis revenez ici.';

  @override
  String remindersSchedule(String leads, String time) {
    return '$leads · $time';
  }

  @override
  String get reminderLeadMonthBefore => '30 jours avant';

  @override
  String get reminderLeadWeekBefore => '7 jours avant';

  @override
  String get reminderLeadDayBefore => 'La veille';

  @override
  String get reminderLeadSameDay => 'Le jour J';

  @override
  String get remindersWhen => 'Me prévenir';

  @override
  String get remindersSameDayAlways => 'Le jour J est toujours prévenu.';

  @override
  String get remindersTime => 'Heure des rappels';

  @override
  String get birthdayRemindersDefault => 'Comme d\'habitude';

  @override
  String get birthdayRemindersNone => 'Aucun';

  @override
  String get birthdayRemindersCustom => 'Personnalisés';

  @override
  String get remindersOff => 'Désactivés : AnKi ne peut pas vous prévenir.';

  @override
  String get remindersOffNotice => 'Rappels désactivés';

  @override
  String get remindersOffEnable => 'Activer';

  @override
  String get remindersOffSettings => 'Réglages';

  @override
  String get remindersOffHide => 'Masquer';

  @override
  String get remindersOffHidden =>
      'Vous pourrez toujours les activer dans les paramètres';

  @override
  String get remindersBlocked => 'Bloqués dans les réglages du téléphone.';

  @override
  String get scanBook => 'Scanner un livre';

  @override
  String get shelfSearchHint => 'Rechercher une série';

  @override
  String shelfNoResults(String query) {
    return 'Aucune série pour « $query »';
  }

  @override
  String shelfInbox(int count) {
    return 'À classer ($count)';
  }

  @override
  String get shelfEmptyTitle => 'Votre étagère vous attend';

  @override
  String get shelfEmptyMessage =>
      'Scannez vos livres : AnKi retient le dernier tome de chaque série et ceux qu\'il vous manque.';

  @override
  String get shelfErrorTitle => 'Étagère indisponible';

  @override
  String get shelfLoading => 'Chargement de l\'étagère';

  @override
  String get shelfOffline => 'Hors ligne · dates non actualisées';

  @override
  String get seriesComplete => 'Série terminée';

  @override
  String seriesNextOn(int number, String date) {
    return 'Tome $number · $date';
  }

  @override
  String seriesNextReleased(int number) {
    return 'Tome $number paru';
  }

  @override
  String seriesNextUnknown(int number) {
    return 'Tome $number · date inconnue';
  }

  @override
  String seriesHoles(String numbers) {
    return 'Il vous manque $numbers';
  }

  @override
  String seriesHolesMore(String numbers, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il vous manque $numbers et $count autres',
      one: 'Il vous manque $numbers et 1 autre',
    );
    return '$_temp0';
  }

  @override
  String numberListLast(String head, String last) {
    return '$head et $last';
  }

  @override
  String a11ySeriesLast(int number) {
    return 'dernier tome $number';
  }

  @override
  String get a11ySeriesEmpty => 'aucun tome';

  @override
  String a11yNextAnnounced(int number, String date) {
    return 'prochain tome $number, sortie le $date';
  }

  @override
  String a11yNextAnnouncedMonth(int number, String month) {
    return 'prochain tome $number, sortie en $month';
  }

  @override
  String a11yNextReleased(int number) {
    return 'prochain tome $number, paru';
  }

  @override
  String a11yNextUnknown(int number) {
    return 'prochain tome $number, date inconnue';
  }

  @override
  String get a11yNextComplete => 'série terminée';

  @override
  String a11ySeriesHoles(int count, String numbers) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il vous manque les tomes $numbers',
      one: 'il vous manque le tome $numbers',
    );
    return '$_temp0';
  }

  @override
  String nextCardReleased(int number) {
    return 'Tome $number paru · vous ne l\'avez pas';
  }

  @override
  String nextCardAnnounced(int number, String date) {
    return 'Tome $number · sortie le $date';
  }

  @override
  String nextCardAnnouncedMonth(int number, String month) {
    return 'Tome $number · sortie en $month';
  }

  @override
  String nextCardUnknown(int number) {
    return 'Tome $number · date inconnue';
  }

  @override
  String get nextCardComplete => 'Série terminée : rien à attendre';

  @override
  String get nextSourceBnf => 'selon la BnF';

  @override
  String get nextSourceGoogleBooks => 'selon Google Books';

  @override
  String nextSourceChecked(String source, String date) {
    return '$source · vérifié le $date';
  }

  @override
  String nextSourceEntered(String date) {
    return 'date saisie par vous le $date';
  }

  @override
  String nextSourceNothing(String date) {
    return 'rien à la BnF · vérifié le $date';
  }

  @override
  String get nextDateAdd => 'Ajouter la date';

  @override
  String get nextDateEdit => 'Modifier la date';

  @override
  String get nextRefreshError =>
      'Actualisation impossible pour le moment. Réessayez plus tard.';

  @override
  String releaseSheetTitle(int number) {
    return 'Sortie du tome $number';
  }

  @override
  String get releaseSheetHelper =>
      'Vue sur une affiche ou le site de l\'éditeur, par exemple.';

  @override
  String get releaseSheetPick => 'Choisir une date';

  @override
  String get releaseSheetExactDay => 'Jour précis';

  @override
  String get releaseSheetMonthOnly => 'Mois seulement';

  @override
  String get releaseSheetClear => 'Effacer la date';

  @override
  String seriesHoleChip(int number) {
    return 'Tome $number';
  }

  @override
  String get seriesVolumesTitle => 'Vos tomes';

  @override
  String seriesVolumeOwned(int number) {
    return 'Tome $number, possédé';
  }

  @override
  String seriesVolumeMissing(int number) {
    return 'Tome $number, manquant';
  }

  @override
  String get seriesNoVolume => 'Aucun tome de cette série pour l\'instant.';

  @override
  String get seriesMenu => 'Options de la série';

  @override
  String get seriesRename => 'Renommer';

  @override
  String get seriesMerge => 'Fusionner avec une autre série';

  @override
  String get seriesMarkComplete => 'Marquer comme terminée';

  @override
  String get seriesMarkOngoing => 'Marquer comme en cours';

  @override
  String get seriesDelete => 'Supprimer la série';

  @override
  String get seriesRenameTitle => 'Renommer la série';

  @override
  String get seriesNameLabel => 'Nom de la série';

  @override
  String get seriesNameRequired => 'Donnez un nom à la série';

  @override
  String seriesMergeTitle(String name) {
    return 'Fusionner $name avec…';
  }

  @override
  String get seriesMergeHint =>
      'Ses tomes rejoignent la série choisie, qui garde son nom.';

  @override
  String seriesMerged(String source, String target) {
    return '$source fusionnée dans $target';
  }

  @override
  String seriesMarkedComplete(String name) {
    return '$name marquée terminée';
  }

  @override
  String seriesMarkedOngoing(String name) {
    return '$name de nouveau en cours';
  }

  @override
  String seriesDeleted(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name supprimée, avec ses $count tomes',
      one: '$name supprimée, avec son tome',
      zero: '$name supprimée',
    );
    return '$_temp0';
  }

  @override
  String get seriesMissingTitle => 'Série introuvable';

  @override
  String get seriesMissingMessage =>
      'Elle a peut-être été supprimée ou fusionnée avec une autre.';

  @override
  String get seriesBackToShelf => 'Retour à l\'étagère';

  @override
  String get seriesErrorTitle => 'Série indisponible';

  @override
  String get shelfWriteError =>
      'La modification n\'a pas pu être enregistrée. Vérifiez votre connexion et réessayez.';

  @override
  String volumeIsbn(String isbn) {
    return 'ISBN $isbn';
  }

  @override
  String volumePublished(String date) {
    return 'Paru le $date';
  }

  @override
  String volumePublishedIn(String period) {
    return 'Paru en $period';
  }

  @override
  String volumeInSeries(String series, int number) {
    return '$series · tome $number';
  }

  @override
  String get volumePending => 'Infos à compléter';

  @override
  String get volumeNotFound => 'Inconnu des catalogues';

  @override
  String get volumeClassify => 'Changer de série ou de numéro';

  @override
  String get volumeSort => 'Classer';

  @override
  String get volumeRemove => 'Retirer de la collection';

  @override
  String volumeRemoved(String title) {
    return '$title retiré de la collection';
  }

  @override
  String get classifyTitle => 'Classer ce tome';

  @override
  String get classifySearchLabel => 'Chercher ou créer une série';

  @override
  String get classifyNoSeries =>
      'Aucune série encore : tapez son nom pour la créer.';

  @override
  String classifyCreate(String name) {
    return 'Créer « $name »';
  }

  @override
  String classifySeriesLast(int number) {
    return 'Dernier tome $number';
  }

  @override
  String get classifySeriesEmpty => 'Aucun tome';

  @override
  String get classifyNumberLabel => 'Numéro du tome';

  @override
  String classifyNumberError(int max) {
    return 'Un numéro entre 1 et $max';
  }

  @override
  String get classifySave => 'Ranger';

  @override
  String get inboxEmptyTitle => 'Tout est rangé';

  @override
  String get inboxEmptyMessage => 'Chaque tome a trouvé sa série.';

  @override
  String get scanHint => 'Visez le code-barres au dos du livre';

  @override
  String get cameraDeniedTitle => 'AnKi n\'a pas accès à la caméra';

  @override
  String get cameraDeniedMessage =>
      'Autorisez la caméra pour scanner le code-barres de vos livres. Si elle reste bloquée, ouvrez les réglages de l\'app.';

  @override
  String get cameraAllow => 'Autoriser la caméra';

  @override
  String get cameraUnavailableTitle => 'Caméra indisponible';

  @override
  String get cameraUnavailableMessage =>
      'La caméra n\'a pas pu démarrer. Fermez les autres apps qui l\'utilisent et réessayez.';

  @override
  String seriesVolumeOwnedEditions(int number, int count) {
    return 'Tome $number, possédé en $count éditions';
  }

  @override
  String volumeEditionsTitle(int number) {
    return 'Tome $number : quelle édition ?';
  }

  @override
  String a11ySeriesHolesMore(String numbers, int count) {
    return 'il vous manque les tomes $numbers et $count autres';
  }

  @override
  String burstAdded(String series, int number) {
    return '$series · tome $number';
  }

  @override
  String burstPending(String isbn) {
    return 'ISBN $isbn · infos à compléter';
  }

  @override
  String burstUnclassified(String title) {
    return '$title · à classer';
  }

  @override
  String get burstNotFound => 'Introuvable · Classer';

  @override
  String previousVolumesRange(int first, int last) {
    return 'J\'ai aussi les tomes $first à $last';
  }

  @override
  String previousVolumesMissing(int count, int number) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'J\'ai aussi les $count tomes manquants',
      one: 'J\'ai aussi le tome $number',
    );
    return '$_temp0';
  }

  @override
  String previousVolumesAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tomes ajoutés · infos en cours',
      one: '$count tome ajouté · infos en cours',
    );
    return '$_temp0';
  }

  @override
  String burstAlreadyOwned(String volume) {
    return 'Déjà dans votre collection · $volume';
  }

  @override
  String burstCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tomes ajoutés',
      one: '1 tome ajouté',
    );
    return '$_temp0';
  }

  @override
  String get scanDone => 'Terminé';

  @override
  String get torchOn => 'Allumer la lampe';

  @override
  String get torchOff => 'Éteindre la lampe';

  @override
  String get isbnEntryTitle => 'Saisir un ISBN';

  @override
  String get isbnEntryLabel => 'ISBN';

  @override
  String get isbnEntryHint => '978-2-344-05956-2';

  @override
  String get isbnEntryHelper =>
      '10 ou 13 chiffres, au dos du livre près du code-barres';

  @override
  String get isbnEntryEmpty => 'Saisissez l\'ISBN du livre';

  @override
  String get isbnEntryInvalid =>
      'Cet ISBN n\'existe pas : vérifiez les chiffres';

  @override
  String get addSeriesTitle => 'Ajouter une série';

  @override
  String get addSeriesByHand => 'Ajouter une série à la main';

  @override
  String addSeriesJoins(String name) {
    return 'Ajoutés à votre série « $name »';
  }

  @override
  String get addSeriesVolumesLabel => 'J\'ai les tomes';

  @override
  String get addSeriesVolumesHint => '1-12, 15';

  @override
  String get addSeriesVolumesHelper =>
      'Des numéros et des plages, séparés par des virgules';

  @override
  String addSeriesPreviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tomes',
      one: '1 tome',
    );
    return '$_temp0';
  }

  @override
  String get addSeriesPreviewAllOwned => 'Déjà tous sur votre étagère';

  @override
  String get addSeriesComplete => 'Série terminée';

  @override
  String get addSeriesCompleteHint => 'Plus aucun tome ne paraîtra';

  @override
  String get rangesEmpty => 'Indiquez au moins un tome';

  @override
  String get rangesMalformed => 'Des numéros à partir de 1, comme 1-12, 15';

  @override
  String get rangesInverted =>
      'Une plage va du plus petit au plus grand : 1-12';

  @override
  String rangesTooLarge(int max) {
    return 'Un numéro jusqu\'à $max';
  }

  @override
  String get quickAddLabel => 'Qui, et quand ?';

  @override
  String get quickAddHelper =>
      'Le prénom puis la date, comme « Léa 12 mars ». L\'année est facultative. Collez une liste pour ajouter plusieurs personnes, une par ligne.';

  @override
  String get quickAddNeedsDate => 'Ajoutez la date, comme « 12 mars »';

  @override
  String get quickAddNeedsName => 'Ajoutez le prénom, avant ou après la date';

  @override
  String quickAddKnown(String name) {
    return '$name est déjà dans vos anniversaires à cette date';
  }

  @override
  String get quickAddGroups => 'Groupes · facultatif';

  @override
  String get quickAddContinue => 'Ajouter et continuer';

  @override
  String quickAddAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouter les $count',
      one: 'Ajouter 1 personne',
    );
    return '$_temp0';
  }

  @override
  String quickAddBatchTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes à ajouter',
      one: '1 personne à ajouter',
      zero: 'Personne à ajouter',
    );
    return '$_temp0';
  }

  @override
  String get quickAddBatchKnown => 'déjà dans vos anniversaires';

  @override
  String get quickAddBatchNoDate => 'il manque la date';

  @override
  String get quickAddBatchNoName => 'il manque le prénom';

  @override
  String get quickAddBatchBadDate => 'date impossible';

  @override
  String get addModeForm => 'Formulaire';

  @override
  String get addModeLine => 'En une ligne';

  @override
  String wishSuggestionShort(String name, String variant) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'a': 'Bon anniversaire $name ! 🎂',
      'b': 'Joyeux anniversaire $name ! 🎉',
      'other': 'Très bel anniversaire $name !',
    });
    return '$_temp0';
  }

  @override
  String wishSuggestionWarm(String name, String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'familyA': 'Joyeux anniversaire $name ! Je t\'embrasse très fort',
      'familyB':
          'Bon anniversaire $name ! Plein d\'amour pour cette nouvelle année 🎂',
      'familyC': 'Joyeux anniversaire $name ! Je pense fort à toi aujourd\'hui',
      'friendsA':
          'Bon anniversaire $name ! Que cette année t\'apporte tout ce que tu espères',
      'friendsB': 'Joyeux anniversaire $name ! Profite bien de ta journée 🎉',
      'friendsC':
          'Bon anniversaire $name ! Plein de belles choses pour cette nouvelle année',
      'workA':
          'Joyeux anniversaire $name ! Belle journée et belle année à venir',
      'workB':
          'Bon anniversaire $name ! Tous mes vœux pour cette nouvelle année',
      'workC': 'Très bel anniversaire $name, et une excellente année à venir !',
      'otherA': 'Joyeux anniversaire $name ! Que cette journée te ressemble',
      'otherB': 'Bon anniversaire $name ! Profite bien de ta journée',
      'other':
          'Joyeux anniversaire $name ! Plein de belles choses pour l\'année qui vient',
    });
    return '$_temp0';
  }

  @override
  String wishSuggestionLight(String name, String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'familyA':
          'Joyeux anniversaire $name ! Une bougie de plus, et toujours autant de charme 🎂',
      'familyB': 'Bon anniversaire $name ! Garde-moi une part de gâteau 🎂',
      'familyC': 'Joyeux anniversaire $name ! Que la fête soit belle 🎉',
      'friendsA':
          'Joyeux anniversaire $name ! Une bougie de plus, et toujours autant de style 🎂',
      'friendsB': 'Bon anniversaire $name ! Ce soir, on trinque à toi 🥂',
      'friendsC':
          'Joyeux anniversaire $name ! Un an de plus, mais qui compte ? 🎉',
      'otherA': 'Joyeux anniversaire $name ! Que la fête soit belle 🎉',
      'otherB': 'Bon anniversaire $name ! Garde-moi une part de gâteau 🎂',
      'other':
          'Joyeux anniversaire $name ! Une bougie de plus, et toujours autant de style 🎂',
    });
    return '$_temp0';
  }

  @override
  String wishSuggestionMilestone(String name, String milestone, int age) {
    String _temp0 = intl.Intl.selectLogic(milestone, {
      'first': 'Joyeux premier anniversaire $name ! 🎂',
      'adult': 'Joyeux anniversaire $name ! 18 ans, une belle étape 🎉',
      'other': 'Joyeux anniversaire $name ! $age ans, ça se fête 🎉',
    });
    return '$_temp0';
  }

  @override
  String wishSuggestionMilestoneWork(String name, int age) {
    return 'Joyeux anniversaire $name pour ces $age ans !';
  }

  @override
  String wishSuggestionBelatedShort(String name, String variant) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'a': 'Bon anniversaire $name, avec un peu de retard ! 🎂',
      'b': 'Joyeux anniversaire $name, en léger différé !',
      'other': 'Un peu en retard, mais joyeux anniversaire $name ! 🎉',
    });
    return '$_temp0';
  }

  @override
  String wishSuggestionBelatedWarm(String name, String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'workA':
          'Bon anniversaire $name, avec un jour de retard ! J\'espère que la journée a été belle',
      'workB':
          'Tous mes vœux, avec un jour de retard : joyeux anniversaire $name !',
      'workC':
          'Joyeux anniversaire en différé, $name ! Une excellente année à venir',
      'otherA':
          'Joyeux anniversaire en différé, $name ! J\'espère que ta journée a été belle',
      'otherB':
          'Un jour de retard, mais tous mes vœux quand même : bon anniversaire $name !',
      'other':
          'Bon anniversaire $name ! Je pense à toi, même avec un jour de retard',
    });
    return '$_temp0';
  }

  @override
  String wishSuggestionBelatedLight(String name, String variant) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'a':
          'Je fais durer la fête un jour de plus : joyeux anniversaire $name ! 🎉',
      'b':
          'Le gâteau est encore bon le lendemain : bon anniversaire $name ! 🎂',
      'other': 'Mieux vaut tard que jamais : joyeux anniversaire $name ! 🎉',
    });
    return '$_temp0';
  }

  @override
  String get wishMessageSuggestedCaption =>
      'Proposé par AnKi, change chaque année';

  @override
  String get wishOtherMessages => 'Autres messages';

  @override
  String get wishChooseAnother => 'Choisir un autre message';

  @override
  String wishWriteOwn(String name) {
    return 'Écrire un message pour $name';
  }

  @override
  String belatedHadAge(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'a eu $age ans',
      one: 'a eu $age an',
    );
    return '$_temp0';
  }

  @override
  String get personRemindersNone => 'Aucun rappel';

  @override
  String personWishRemoveYear(int year) {
    return 'Retirer le vœu de $year';
  }

  @override
  String wishMessageOwnCaption(String date) {
    return 'Votre message pour le $date';
  }

  @override
  String shortcutWish(String name) {
    return 'Souhaiter à $name';
  }

  @override
  String get contactLinkAction => 'Relier à un contact';

  @override
  String get contactLinkPrivacy =>
      'Vous choisissez un seul numéro. Il reste sur ce téléphone.';

  @override
  String get contactLinkOnThisPhone => 'Numéro gardé sur ce téléphone';

  @override
  String get contactLinkMenu => 'Options du contact';

  @override
  String get contactLinkChange => 'Changer de contact';

  @override
  String get contactLinkRemove => 'Délier';

  @override
  String get contactLinkRemoved =>
      'Contact délié : numéro effacé de ce téléphone.';

  @override
  String get contactCall => 'Appeler';

  @override
  String get contactMessage => 'Message';

  @override
  String get contactLinkPickerUnavailable =>
      'Impossible d\'ouvrir vos contacts. Réessayez.';

  @override
  String get contactLinkStorageFailed =>
      'La liaison n\'a pas pu être mise à jour sur ce téléphone. Réessayez.';

  @override
  String get contactAppUnavailable =>
      'Aucune app pour appeler ou écrire sur ce téléphone.';

  @override
  String get wishOtherApp => 'Autre app';

  @override
  String get shelfToBuyTitle => 'Paru · pas encore chez vous';

  @override
  String shelfVolumeOf(String series, int number) {
    return '$series · tome $number';
  }

  @override
  String get shelfReleased => 'Paru';

  @override
  String get shelfBought => 'Acheté';

  @override
  String a11yShelfBought(String series, int number) {
    return 'Marquer $series tome $number comme acheté';
  }

  @override
  String get shelfUpcomingTitle => 'Prochaines sorties';

  @override
  String shelfReleaseIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'dans $days jours',
      one: 'demain',
      zero: 'aujourd’hui',
    );
    return '$_temp0';
  }

  @override
  String a11yShelfRelease(String series, int number, String date, String when) {
    return '$series, tome $number, sort le $date, $when';
  }

  @override
  String a11yShelfReleaseMonth(String series, int number, String month) {
    return '$series, tome $number, sort en $month';
  }

  @override
  String shelfSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries, de A à Z',
      one: '1 série, de A à Z',
    );
    return '$_temp0';
  }

  @override
  String a11yShelfInbox(int count, String titles) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tomes',
      one: '1 tome',
    );
    return 'À classer, $_temp0 : $titles';
  }

  @override
  String shelfInboxTitles(String titles, int more) {
    String _temp0 = intl.Intl.pluralLogic(
      more,
      locale: localeName,
      other: '$titles et $more autres',
      one: '$titles et 1 autre',
      zero: '$titles',
    );
    return '$_temp0';
  }

  @override
  String shelfToBuyMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Voir les $count autres tomes',
      one: 'Voir 1 autre tome',
    );
    return '$_temp0';
  }

  @override
  String get seriesLastVolumeCaption => 'dernier tome';

  @override
  String seriesOwnedOf(int owned, int last) {
    String _temp0 = intl.Intl.pluralLogic(
      owned,
      locale: localeName,
      other: '$owned tomes sur $last',
      one: '1 tome sur $last',
    );
    return '$_temp0';
  }

  @override
  String nextCardHeading(int number) {
    return 'Prochain · tome $number';
  }

  @override
  String nextCardOut(int number) {
    return 'Le tome $number est paru';
  }

  @override
  String get seriesBought => 'Je l\'ai acheté';

  @override
  String a11ySeriesBought(int number) {
    return 'J\'ai acheté le tome $number';
  }

  @override
  String seriesHaveHoles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Je les ai',
      one: 'Je l\'ai',
    );
    return '$_temp0';
  }

  @override
  String a11ySeriesHaveHoles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'J\'ai les $count tomes manquants',
      one: 'J\'ai le tome manquant',
    );
    return '$_temp0';
  }

  @override
  String get a11ySpineAddHint => 'marquer comme acheté';

  @override
  String get a11yHolesShowHint => 'afficher dans le rayon';

  @override
  String get burstSessionTitle => 'Cette session';

  @override
  String burstGroupLine(int count, String numbers) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count · tomes $numbers',
      one: '+1 · tome $numbers',
    );
    return '$_temp0';
  }

  @override
  String a11yBurstGroup(String series, int count, String numbers) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tomes ajoutés',
      one: '1 tome ajouté',
    );
    return '$series, $_temp0 : $numbers';
  }

  @override
  String burstRemove(String title) {
    return 'Retirer $title';
  }

  @override
  String get burstEmpty =>
      'Les tomes scannés s\'ajoutent ici, rangés par série.';

  @override
  String burstGroupRemoved(String series, int count, String numbers) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tomes $numbers retirés',
      one: 'tome $numbers retiré',
    );
    return '$series, $_temp0 de la collection';
  }

  @override
  String a11yBurstRemoveGroup(String series, int count, String numbers) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retirer les tomes $numbers de $series',
      one: 'Retirer le tome $numbers de $series',
    );
    return '$_temp0';
  }

  @override
  String get inboxIntro => 'AnKi propose un rangement : un toucher suffit.';

  @override
  String inboxPlaceIn(String series, int number) {
    return 'Ranger dans $series · t. $number';
  }

  @override
  String inboxAlreadyOwned(String series, int number) {
    return 'Tome $number déjà dans $series';
  }

  @override
  String a11yInboxAlreadyOwned(String series, int number) {
    return 'Tome $number déjà dans $series, choisir où ranger ce tome';
  }

  @override
  String get classifyDuplicateHint =>
      'Vous avez déjà ce tome, il comptera comme un deuxième exemplaire.';

  @override
  String a11yInboxPlaceIn(String series, int number) {
    return 'Ranger dans $series, tome $number';
  }

  @override
  String inboxCreateSeries(String series, int number) {
    String _temp0 = intl.Intl.pluralLogic(
      number,
      locale: localeName,
      other: 'Créer « $series » · t. $number',
      one: 'Créer « $series »',
    );
    return '$_temp0';
  }

  @override
  String a11yInboxCreateSeries(String series, int number) {
    return 'Créer la série $series, tome $number';
  }

  @override
  String get inboxOtherSeries => 'Autre série';

  @override
  String inboxPlaced(String series, int number) {
    return 'Rangé dans $series · tome $number';
  }

  @override
  String get inboxSeeSeries => 'Voir';
}
