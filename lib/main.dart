import 'dart:async';

import 'package:an_ki/app/app.dart';
import 'package:an_ki/app/bootstrap/background_replan.dart';
import 'package:an_ki/app/bootstrap/notification_strings.dart';
import 'package:an_ki/app/modules/module_data_hooks.dart';
import 'package:an_ki/core/firebase_options.dart';
import 'package:an_ki/core/services/device_settings.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/user/providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lu pendant l'initialisation : la première image a déjà le thème du
  // dernier profil, sans passer par celui du système (ux D28). La lecture
  // attend son tour derrière les plugins (1,9 à 6,6 s mesurées à froid sur
  // l'émulateur) mais a fini avant eux à chaque mesure : l'attente n'est
  // bornée qu'après les initialisations, plus bas.
  final rememberedTheme = const DeviceSettings().lastThemeMode();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  await NotificationService.instance.initialize();
  await GoogleSignIn.instance.initialize();
  // Sans attendre : l'ouverture ne paie pas l'enregistrement.
  unawaited(registerBackgroundReplan());

  // Un stockage qui ne répond toujours pas ne retient pas le lancement : le
  // thème système alors.
  final remembered = await rememberedTheme.timeout(
    const Duration(milliseconds: 300),
    onTimeout: () => null,
  );
  runApp(
    ProviderScope(
      overrides: [
        localizedNotificationStrings,
        ...moduleDataHooks,
        rememberedThemeModeProvider.overrideWithValue(remembered),
      ],
      child: const App(),
    ),
  );
}
