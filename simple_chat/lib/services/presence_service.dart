import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Bardzo prosty presence oparty o Firestore.
/// Ustawia isOnline=true po starcie, a w onPause/onDetach - false + lastOnline.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  Timer? _heartbeat;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    await _setOnline(true);

    // co 60s odśwież lastOnline (serwerowy timestamp), żeby lista była “żywa”
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 60), (_) => _touch());
  }

  Future<void> _touch() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    await FirebaseFirestore.instance.collection('users').doc(u.uid)
      .set({'lastOnline': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> _setOnline(bool v) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final data = {
      'isOnline': v,
      'lastOnline': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance.collection('users').doc(u.uid).set(data, SetOptions(merge: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnline(true);
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _setOnline(false);
    }
  }
}
