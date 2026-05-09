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
  String get manageBirthdays => 'Gérez vos anniversaires';

  @override
  String get hello => 'Bonjour';

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
  String get birthDate => 'Date de naissance';

  @override
  String get category => 'Catégorie';

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
  String get validate => 'Valider';

  @override
  String get newBirthday => 'Nouvel anniversaire';

  @override
  String get editBirthday => 'Modifier';

  @override
  String get noBirthdaysFound => 'Aucun anniversaire trouvé.';

  @override
  String get yearsOld => 'ans';

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
  String get login => 'Connexion';

  @override
  String get registration => 'Inscription';

  @override
  String get january => 'Janvier';

  @override
  String get february => 'Février';

  @override
  String get march => 'Mars';

  @override
  String get april => 'Avril';

  @override
  String get may => 'Mai';

  @override
  String get june => 'Juin';

  @override
  String get july => 'Juillet';

  @override
  String get august => 'Août';

  @override
  String get september => 'Septembre';

  @override
  String get october => 'Octobre';

  @override
  String get november => 'Novembre';

  @override
  String get december => 'Décembre';

  @override
  String get nextBirthday => 'Prochain anniversaire';

  @override
  String get noBirthdayRegistered => 'Aucun anniversaire';

  @override
  String get today => 'Aujourd\'hui 🎉';

  @override
  String get tomorrow => 'Demain';

  @override
  String inDays(int days) {
    return 'Dans $days jours';
  }

  @override
  String get viewAll => 'Voir tout';

  @override
  String get showLess => 'Réduire';

  @override
  String get search => 'Rechercher...';

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
  String get name => 'Nom';

  @override
  String get haveAccount => 'Vous avez déjà un compte ? ';

  @override
  String get dontHaveAccount => 'Pas encore de compte ? ';

  @override
  String get settings => 'Paramètres';

  @override
  String get theme => 'Thème';

  @override
  String get pseudo => 'Pseudo';

  @override
  String get pseudoUpdated => 'Pseudo mis à jour avec succès !';

  @override
  String get updatePseudo => 'Mettre à jour le pseudo';

  @override
  String get deleteBirthdayTitle => 'Supprimer l\'anniversaire';

  @override
  String deleteBirthdayConfirmation(String name) {
    return 'Voulez-vous vraiment supprimer l\'anniversaire de $name ?';
  }

  @override
  String birthdayDeleted(String name) {
    return 'Anniversaire de $name supprimé';
  }

  @override
  String get delete => 'Supprimer';
}
