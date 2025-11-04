import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'auth/sign_in_page.dart';
import 'home_shell.dart';
import 'services/notifications.dart';
import 'services/presence_service.dart';
import 'theme_controller.dart';

final ThemeController themeController = ThemeController(); // global

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await themeController.load(); // wczytaj tryb
  await NotificationsService.instance.init(); // FCM + local notif
  await PresenceService.instance.init(); // online / lastSeen

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Simple Chat',
          debugShowCheckedModeBanner: false,
          themeMode: themeController.mode,
          theme: ThemeData(
            colorSchemeSeed: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.data == null) return const SignInPage();
              return const HomeShell();
            },
          ),
        );
      },
    );
  }
}
