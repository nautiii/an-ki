// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String greeting(String period) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'day': 'Hello',
      'other': 'Good evening',
    });
    return '$_temp0';
  }

  @override
  String greetingName(String period, String name) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'day': 'Hello, $name',
      'other': 'Good evening, $name',
    });
    return '$_temp0';
  }

  @override
  String get welcomeTitle => 'Never miss a birthday again';

  @override
  String get welcomeMessage =>
      'AnKi reminds you 7 days before and on the day, and gets your message ready.';

  @override
  String get welcomeStart => 'Get started';

  @override
  String get welcomeHaveAccount => 'I already have an account';

  @override
  String get authTitle => 'Welcome back';

  @override
  String get authMessage => 'Sign in to get back to your birthdays.';

  @override
  String get authLockedMessage => 'Unlock AnKi to get back to your birthdays.';

  @override
  String get authUnlock => 'Unlock';

  @override
  String get loginWithGoogle => 'Continue with Google';

  @override
  String get loginWithEmail => 'Continue with email';

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
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get fullName => 'Full name';

  @override
  String get fullNameHint => 'Lea Martin, Grandma…';

  @override
  String get birthdayDate => 'Birthday';

  @override
  String birthdayDateHint(String order) {
    String _temp0 = intl.Intl.selectLogic(order, {
      'monthFirst': 'MM/DD or MM/DD/YYYY',
      'other': 'DD/MM or DD/MM/YYYY',
    });
    return '$_temp0';
  }

  @override
  String get birthYearOptional => 'The year is optional';

  @override
  String birthDatePreview(String date) {
    return '$date';
  }

  @override
  String birthDatePreviewAge(String date, int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$date · turns $age',
    );
    return '$_temp0';
  }

  @override
  String get birthDateIncomplete => 'Enter the day and month';

  @override
  String get birthYearDigits => 'Write the year with 4 digits';

  @override
  String get birthDateInvalid => 'This date doesn\'t exist';

  @override
  String get birthDateFuture => 'This date is in the future';

  @override
  String get groups => 'Groups';

  @override
  String groupPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
      zero: 'Nobody',
    );
    return '$_temp0';
  }

  @override
  String get groupPreset => 'Offered to everyone';

  @override
  String get groupsErrorTitle => 'Groups unavailable';

  @override
  String get editGroup => 'Edit group';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String groupDeleted(String name) {
    return '“$name” deleted';
  }

  @override
  String get leaveGroup => 'Remove from my groups';

  @override
  String groupLeft(String name) {
    return '“$name” is no longer in your groups';
  }

  @override
  String get sharedGroupNote =>
      'This group is shared: it can\'t be renamed, but you can remove it from your groups and birthdays.';

  @override
  String get family => 'Family';

  @override
  String get friend => 'Friends';

  @override
  String get colleague => 'Work';

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
  String heroAgeUnit(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'years old',
      one: 'year old',
    );
    return '$_temp0';
  }

  @override
  String ageInYears(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age years old',
      one: '$age year old',
    );
    return '$_temp0';
  }

  @override
  String get requiredField => 'Required field';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirmation => 'Are you sure you want to sign out?';

  @override
  String get errorSavingBirthday =>
      'Your change couldn\'t be saved. Check your connection and try again.';

  @override
  String get errorSavingGroup =>
      'Couldn\'t save the group. Check your connection and try again.';

  @override
  String get nextBirthday => 'Next birthday';

  @override
  String get today => 'Today 🎉';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get yesterday => 'Yesterday';

  @override
  String inDays(int days) {
    return 'In $days days';
  }

  @override
  String get connectionError => 'Couldn\'t sign you in. Try again in a moment.';

  @override
  String get errorPasswordReset =>
      'The link couldn\'t be sent. Try again in a moment.';

  @override
  String get registrationError =>
      'Couldn\'t create your account. Try again in a moment.';

  @override
  String get loginTitle => 'Sign in with email';

  @override
  String get signUpTitle => 'Create an account';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signUpButton => 'Sign up';

  @override
  String get signUpMessage => 'Your birthdays will follow you to every phone.';

  @override
  String get loginMessage => 'Your birthdays are waiting for you.';

  @override
  String get haveAccount => 'Already have an account?';

  @override
  String get settings => 'Settings';

  @override
  String get settingsProfile => 'Profile';

  @override
  String get settingsPreferences => 'Preferences';

  @override
  String get settingsBirthdays => 'Birthdays';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsAccount => 'Account';

  @override
  String get language => 'Language';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get pseudo => 'Nickname';

  @override
  String get pseudoHelper => 'The name AnKi greets you with';

  @override
  String get savePseudo => 'Save nickname';

  @override
  String get pseudoSaved => 'Nickname saved';

  @override
  String birthdayDeleted(String name) {
    return '$name removed from your birthdays';
  }

  @override
  String get alreadyWished => 'Already wished';

  @override
  String get wished => 'Wished';

  @override
  String birthdayWished(String name) {
    return '$name got your wishes';
  }

  @override
  String get wish => 'Send wishes';

  @override
  String wishMessage(String name) {
    return 'Happy birthday $name! 🎂 Have a wonderful day.';
  }

  @override
  String wishMessageBelated(String name) {
    return 'Happy belated birthday $name! 🎂 I hope you had a wonderful day.';
  }

  @override
  String get errorSharing => 'Couldn\'t open sharing. Please try again.';

  @override
  String get undo => 'Undo';

  @override
  String get delete => 'Delete';

  @override
  String get newGroup => 'New group';

  @override
  String get groupName => 'Group name';

  @override
  String get groupNameHint => 'Neighbours, book club…';

  @override
  String get groupNameTaken => 'This group already exists';

  @override
  String get createGroup => 'Create';

  @override
  String get groupTone => 'Colour';

  @override
  String get toneBlue => 'Blue';

  @override
  String get toneGreen => 'Green';

  @override
  String get toneOrange => 'Orange';

  @override
  String get toneViolet => 'Violet';

  @override
  String get toneCyan => 'Cyan';

  @override
  String get tonePink => 'Pink';

  @override
  String get toneAmber => 'Amber';

  @override
  String get toneTeal => 'Teal';

  @override
  String get tabBirthdays => 'Birthdays';

  @override
  String get tabScanner => 'Scanner';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get addBirthday => 'Add a birthday';

  @override
  String get viewAgenda => 'Agenda';

  @override
  String get viewCalendar => 'Calendar';

  @override
  String get agendaSoon => 'Next 7 days';

  @override
  String agendaLine(String date, int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$date · turns $age',
    );
    return '$_temp0';
  }

  @override
  String countdownDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: 'Tomorrow',
      zero: 'Today',
    );
    return '$_temp0';
  }

  @override
  String get heroTurning => 'turns';

  @override
  String get searchTooltip => 'Search';

  @override
  String get searchHint => 'Search a name';

  @override
  String noSearchResults(String query) {
    return 'No results for “$query”';
  }

  @override
  String get noFilterResults => 'No birthdays with these filters';

  @override
  String addNamed(String name) {
    return 'Add “$name”';
  }

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get close => 'Close';

  @override
  String get choosePhoto => 'Choose a photo';

  @override
  String get emptyBirthdaysTitle => 'Who do you want to celebrate?';

  @override
  String get emptyBirthdaysMessage =>
      'Bring in your contacts\' birthdays all at once, no typing.';

  @override
  String get chooseFromContacts => 'Choose from my contacts';

  @override
  String get addByHand => 'Add by hand';

  @override
  String get contactsPrivacy => 'AnKi only reads names and birthdays.';

  @override
  String get noBooksMessage => 'Scan a book\'s barcode to keep a gift idea.';

  @override
  String get bookScannerTitle => 'Book Scanner';

  @override
  String get bookTitle => 'Title';

  @override
  String isbnLabel(String isbn) {
    return 'ISBN: $isbn';
  }

  @override
  String get bookNotFound => 'Book not found';

  @override
  String get noBooksYet => 'No books yet';

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
  String get contactImportTitle => 'Your contacts';

  @override
  String contactImportFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count birthdays found. Untick the ones you don\'t want to follow.',
      one: '1 birthday found. Untick it if you don\'t want to follow it.',
    );
    return '$_temp0';
  }

  @override
  String get contactImportAllKnown =>
      'All your contacts\' birthdays are already in AnKi.';

  @override
  String contactImportSelectAll(int count) {
    return 'Select all ($count)';
  }

  @override
  String get contactImportKnown => 'Already in AnKi';

  @override
  String contactImportDetail(String date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$date · in $days days',
      one: '$date · tomorrow',
      zero: '$date · today',
    );
    return '$_temp0';
  }

  @override
  String contactImportAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count birthdays',
      one: 'Add 1 birthday',
      zero: 'Add',
    );
    return '$_temp0';
  }

  @override
  String birthdayAdded(String name) {
    return '$name added to your birthdays';
  }

  @override
  String birthdaysAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count birthdays added',
      one: '1 birthday added',
    );
    return '$_temp0';
  }

  @override
  String get contactImportDeniedTitle => 'AnKi can\'t see your contacts';

  @override
  String get contactImportDeniedMessage =>
      'Allow access to choose who to add, or add your people by hand.';

  @override
  String get contactImportBlockedMessage =>
      'Allow Contacts in the app\'s settings, then come back here. You can also add your people by hand.';

  @override
  String get contactImportAllow => 'Allow access';

  @override
  String get openAppSettings => 'Open settings';

  @override
  String get contactImportEmptyTitle => 'No birthdays in your contacts';

  @override
  String get contactImportEmptyMessage =>
      'Add dates to your contacts, or add your people here by hand.';

  @override
  String get contactImportErrorTitle => 'Couldn\'t read your contacts';

  @override
  String get contactImportErrorMessage => 'Try again in a moment.';

  @override
  String get retry => 'Try again';

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
  String get resetPasswordNeedsEmail => 'Enter your e-mail to get the link';

  @override
  String resetPasswordSent(String email) {
    return 'E-mail sent to $email';
  }

  @override
  String get resetPasswordSentHint =>
      'Open its link to choose a new password. Nothing yet? Check the address and your spam folder.';

  @override
  String get resetPasswordResend => 'Send the link again';

  @override
  String get biometricConnexion => 'Biometric connexion';

  @override
  String get biometricConnexionDescription => 'Use your fingerprint to sign in';

  @override
  String get biometricReason => 'Scan your fingerprint to sign in';

  @override
  String get biometricError => 'Couldn\'t check your fingerprint. Try again.';

  @override
  String get biometricRevoked =>
      'Biometric login is no longer valid. Sign in again to continue.';

  @override
  String get attention => 'Attention';

  @override
  String get signOutAnonymousWarning =>
      'By signing out, you will lose all your saved birthdays because you are using a guest account. Do you want to continue?';

  @override
  String get saveMyData => 'Save my data';

  @override
  String get dataSavedSuccess => 'Account saved';

  @override
  String get deleteAndLeave => 'Delete and leave';

  @override
  String guestBackupTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Keep your $count birthdays',
      one: 'Keep your birthday',
    );
    return '$_temp0';
  }

  @override
  String guestBackupMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'For now, they only live on this phone. With your Google account, you\'ll find them everywhere.',
      one: 'For now, it only lives on this phone. With your Google account, you\'ll find it everywhere.',
    );
    return '$_temp0';
  }

  @override
  String get guestBackupAction => 'Save with Google';

  @override
  String get guestBackupTakenTitle =>
      'This Google account is already used by AnKi';

  @override
  String guestBackupTakenMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Your $count birthdays stay on this phone: nothing is lost. To save them, choose another Google account.',
      one: 'Your birthday stays on this phone: nothing is lost. To save it, choose another Google account.',
    );
    return '$_temp0';
  }

  @override
  String get guestBackupOtherAccount => 'Choose another account';

  @override
  String guestBackupDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your $count birthdays are saved',
      one: 'Your birthday is saved',
    );
    return '$_temp0';
  }

  @override
  String get biometricEnabled => 'Biometric login enabled';

  @override
  String get biometricDisabled => 'Biometric login disabled';

  @override
  String get errorWeakPassword => 'Password too weak. Choose a longer one.';

  @override
  String get errorEmailAlreadyInUse =>
      'This email already has an account. Sign in instead.';

  @override
  String get errorInvalidEmail => 'This email address isn\'t valid.';

  @override
  String get errorUserNotFound =>
      'No AnKi account uses this address. Check it, or create an account.';

  @override
  String get errorTooManyRequests =>
      'Too many tries in a row. Wait a few minutes, then try again.';

  @override
  String get errorUserDisabled =>
      'This account is disabled. Sign in with another one.';

  @override
  String get errorWrongPassword =>
      'Wrong password. Try again, or ask for a new one.';

  @override
  String get errorInvalidCredentials =>
      'Wrong e-mail or password. Check them, or ask for a new password.';

  @override
  String get errorNetwork =>
      'You\'re offline. Check your connection and try again.';

  @override
  String get errorUnknown => 'Something went wrong. Try again in a moment.';

  @override
  String get errorGoogleLogin => 'Couldn\'t connect with Google. Try again.';

  @override
  String get errorGoogleAccountInUse =>
      'This Google account is already used by AnKi. Choose another one to save your birthdays.';

  @override
  String get errorSignOut => 'Couldn\'t sign you out. Try again.';

  @override
  String get deleteAccountError =>
      'Couldn\'t delete the account. Check your connection and try again.';

  @override
  String get errorQuotaExceeded =>
      'Search limit reached. Please try again later.';

  @override
  String get notificationChannelName => 'Birthdays';

  @override
  String get notificationChannelDescription => 'Daily birthday reminders';

  @override
  String notificationReminderTitle(String fullName) {
    return '🎉 $fullName';
  }

  @override
  String notificationBirthdayBody(String name) {
    return 'It\'s $name\'s birthday today!';
  }

  @override
  String notificationReminderBody(String name, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$name\'s birthday is in $days days.',
      one: '$name\'s birthday is tomorrow.',
    );
    return '$_temp0';
  }

  @override
  String notificationBirthdayTitle(String fullName) {
    return '🎂 $fullName';
  }

  @override
  String get reminders => 'Reminders';

  @override
  String get enableReminders => 'Turn on reminders';

  @override
  String get remindersEnabled => 'Reminders on';

  @override
  String get later => 'Not now';

  @override
  String remindersOfferRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count birthdays restored',
      one: '1 birthday restored',
    );
    return '$_temp0';
  }

  @override
  String remindersOfferTitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'A reminder $days days before, then on the day',
      one: 'A reminder the day before, then on the day',
      zero: 'A reminder on the day',
    );
    return '$_temp0';
  }

  @override
  String remindersOfferMessage(String time) {
    return 'At $time, even offline.';
  }

  @override
  String get remindersExample => 'Example reminder';

  @override
  String remindersExampleWhen(String date, String time) {
    return 'AnKi · $date at $time';
  }

  @override
  String get remindersBlockedTitle => 'Allow notifications in settings';

  @override
  String get remindersBlockedMessage =>
      'Your phone blocks them for AnKi. Turn them on in settings, then come back here.';

  @override
  String remindersSchedule(String leads, String time) {
    return '$leads · $time';
  }

  @override
  String get reminderLeadMonthBefore => '30 days before';

  @override
  String get reminderLeadWeekBefore => '7 days before';

  @override
  String get reminderLeadDayBefore => 'The day before';

  @override
  String get reminderLeadSameDay => 'On the day';

  @override
  String get remindersWhen => 'Remind me';

  @override
  String get remindersSameDayAlways => 'You\'re always reminded on the day.';

  @override
  String get remindersTime => 'Reminder time';

  @override
  String get birthdayRemindersDefault => 'As usual';

  @override
  String get birthdayRemindersNone => 'None';

  @override
  String get birthdayRemindersCustom => 'Custom';

  @override
  String get remindersOff => 'Off: AnKi can\'t remind you.';

  @override
  String get remindersOffNotice => 'Reminders are off';

  @override
  String get remindersOffEnable => 'Turn on';

  @override
  String get remindersOffSettings => 'Settings';

  @override
  String get remindersOffHide => 'Hide';

  @override
  String get remindersOffHidden => 'You can still turn them on in Settings';

  @override
  String get remindersBlocked => 'Blocked in your phone\'s settings.';
}
