// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'An Ki';

  @override
  String get manageBirthdays => 'Manage your birthdays';

  @override
  String get hello => 'Hello';

  @override
  String get loginWithGoogle => 'Login with Google';

  @override
  String get loginWithEmail => 'Login with Email';

  @override
  String get continueWithoutAccount => 'Continue without account';

  @override
  String get noAccountYet => 'No account yet?';

  @override
  String get signUp => 'Sign up';

  @override
  String get signIn => 'Sign in';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get birthDate => 'Birth date';

  @override
  String get category => 'Category';

  @override
  String get family => 'Family';

  @override
  String get friend => 'Friend';

  @override
  String get colleague => 'Colleague';

  @override
  String get other => 'Other';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get newBirthday => 'New birthday';

  @override
  String get editBirthday => 'Edit';

  @override
  String get noBirthdaysFound => 'No birthdays found.';

  @override
  String get yearsOld => 'years old';

  @override
  String get requiredField => 'Required field';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirmation => 'Are you sure you want to sign out?';

  @override
  String get errorSavingBirthday => 'Error saving birthday';

  @override
  String get login => 'Login';

  @override
  String get registration => 'Registration';

  @override
  String get january => 'January';

  @override
  String get february => 'February';

  @override
  String get march => 'March';

  @override
  String get april => 'April';

  @override
  String get may => 'May';

  @override
  String get june => 'June';

  @override
  String get july => 'July';

  @override
  String get august => 'August';

  @override
  String get september => 'September';

  @override
  String get october => 'October';

  @override
  String get november => 'November';

  @override
  String get december => 'December';

  @override
  String get nextBirthday => 'Next birthday';

  @override
  String get noBirthdayRegistered => 'No birthday';

  @override
  String get today => 'Today 🎉';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String inDays(int days) {
    return 'In $days days';
  }

  @override
  String get viewAll => 'View all';

  @override
  String get showLess => 'Show less';

  @override
  String get search => 'Search...';

  @override
  String get connectionError => 'Login error';

  @override
  String get registrationError => 'Registration error';

  @override
  String get loginTitle => 'An Ki - Login';

  @override
  String get signUpTitle => 'An Ki - Registration';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signUpButton => 'Sign up';

  @override
  String get createAccount => 'Create account';

  @override
  String get signInText => 'Sign in';

  @override
  String get name => 'Name';

  @override
  String get haveAccount => 'Already have an account? ';

  @override
  String get dontHaveAccount => 'No account yet? ';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get pseudo => 'Nickname';

  @override
  String get pseudoUpdated => 'Nickname updated successfully!';

  @override
  String get updatePseudo => 'Update Nickname';

  @override
  String get deleteBirthdayTitle => 'Delete Birthday';

  @override
  String deleteBirthdayConfirmation(String name) {
    return 'Are you sure you want to delete $name\'s birthday?';
  }

  @override
  String birthdayDeleted(String name) {
    return '$name\'s birthday deleted';
  }

  @override
  String get delete => 'Delete';

  @override
  String get newCategory => 'New category';

  @override
  String get categoryName => 'Category\'s name';

  @override
  String get chooseIcon => 'Choose an icon';

  @override
  String get bookScanner => 'Scan a book';

  @override
  String get bookScannerTitle => 'Book Scanner';

  @override
  String get bookTitle => 'Title';

  @override
  String get bookPrice => 'Price';

  @override
  String get bookNotFound => 'Book not found';

  @override
  String get scanning => 'Scanning...';

  @override
  String get noInfoFound => 'No information found';

  @override
  String get deleteAccount => 'Delete my account';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountConfirmation =>
      'Are you sure you want to delete your account? This action is irreversible and will delete all your data.';

  @override
  String get importContacts => 'Import contacts';

  @override
  String contactsImported(int count) {
    return '$count contacts imported successfully!';
  }

  @override
  String get noContactsWithBirthday => 'No contacts with a birthday found.';

  @override
  String get permissionDenied => 'Permission denied.';

  @override
  String get suggestedCategories => 'Suggested categories';

  @override
  String get createCustomCategory => 'Or create a custom category';

  @override
  String get noMoreSuggestions => 'No more suggested categories';

  @override
  String get selectOrCreateCategory => 'Please select or create a category';

  @override
  String get sport => 'Sport';

  @override
  String get school => 'School';

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
  String get celebrity => 'Celebrity';

  @override
  String get favorite => 'Favorite';

  @override
  String get couple => 'Couple';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get biometricConnexion => 'Biometric connexion';

  @override
  String get biometricConnexionDescription => 'Use your fingerprint to sign in';

  @override
  String get reconnectToEnableBiometrics =>
      'Please sign in again once to enable biometrics';

  @override
  String get biometricReason => 'Please use your fingerprint to authenticate';

  @override
  String get noBiometricCredentials => 'No credentials saved for biometrics';

  @override
  String get biometricError => 'Error during biometric authentication';

  @override
  String get attention => 'Attention';

  @override
  String get signOutAnonymousWarning =>
      'By signing out, you will lose all your saved birthdays because you are using a guest account. Do you want to continue?';

  @override
  String get saveMyData => 'Save my data';

  @override
  String get dataSavedSuccess => 'Account saved successfully!';

  @override
  String get deleteAndLeave => 'Delete and leave';

  @override
  String get biometricEnabled => 'Biometric login enabled!';

  @override
  String get biometricDisabled => 'Biometric login disabled.';

  @override
  String get errorWeakPassword => 'The password is too weak.';

  @override
  String get errorEmailAlreadyInUse => 'This email is already in use.';

  @override
  String get errorInvalidEmail => 'The email is not valid.';

  @override
  String get errorUserNotFound => 'User not found.';

  @override
  String get errorWrongPassword => 'Incorrect password.';

  @override
  String get errorUnknown => 'An error occurred.';

  @override
  String get errorGoogleLogin => 'Google login error';

  @override
  String get deleteAccountError => 'Error during account deletion';

  @override
  String get errorQuotaExceeded =>
      'Search limit reached. Please try again later.';
}
