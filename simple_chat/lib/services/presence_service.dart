import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Klasa zarządzająca statusem online/offline użytkownika.
/// Aktualizuje `users/{uid}` w Firestore:
///  - online: true/false
///  - lastSeen: FieldValue.serverTimestamp()
///  - nick, email (jeśli są znane)
class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  StreamSubscription? _sub;
  final _firestore = FirebaseFirestore.instance;

  Future<void> init() async {
    // słuchaj zmian w stanie aplikacji (foreground / background)
    WidgetsBinding.instance.addObserver(
      LifecycleEventHandler(
        resumeCallBack: () async => _setOnline(true),
        suspendingCallBack: () async => _setOnline(false),
      ),
    );

    // jeśli zalogowany użytkownik — oznacz online
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _setOnline(true);
    }

    // obserwuj zmiany zalogowanego użytkownika
    _sub = FirebaseAuth.instance.authStateChanges().listen((u) async {
      if (u == null) {
        await _setOnline(false);
      } else {
        await _setOnline(true);
      }
    });
  }

  /// Ustawia użytkownika offline z aktualizacją lastSeen
  Future<void> setOfflineNow(String uid) async {
    await _firestore.collection('users').doc(uid).set({
      'online': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _setOnline(bool online) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = _firestore.collection('users').doc(user.uid);

    final nick = user.displayName ?? '';
    final email = user.email ?? '';

    await doc.set({
      'uid': user.uid,
      'nick': nick,
      'email': email,
      'online': online,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }
}

/// Pomocnik reagujący na stan aplikacji (życie cyklu Fluttera)
class LifecycleEventHandler extends WidgetsBindingObserver {
  final Future<void> Function()? resumeCallBack;
  final Future<void> Function()? suspendingCallBack;

  LifecycleEventHandler({this.resumeCallBack, this.suspendingCallBack});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (resumeCallBack != null) {
          resumeCallBack!();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (suspendingCallBack != null) {
          suspendingCallBack!();
        }
        break;
    }
  }
}
