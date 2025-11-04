import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart'; // ten plik wygeneruje FlutterFire CLI

import 'auth/sign_in_page.dart';
import 'users_page.dart';
import 'services/presence_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web i ogólnie “all platforms” – z opcjami:
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await PresenceService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Chat (email based)',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.data == null) return const SignInPage();
          return const UsersPage();
        },
      ),
    );
  }
}
