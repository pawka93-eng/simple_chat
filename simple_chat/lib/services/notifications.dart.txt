import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  final _fcm = FirebaseMessaging.instance;
  final _fln = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) {
      // na webie odpuśćmy
      return;
    }

    // android init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidInit,
    );
    await _fln.initialize(initSettings);

    // pozwolenia
    if (Platform.isAndroid || Platform.isIOS) {
      await _fcm.requestPermission();
    }

    // token
    final token = await _fcm.getToken();
    await _saveToken(token);

    // listen na foregound
    FirebaseMessaging.onMessage.listen((msg) {
      final notif = msg.notification;
      if (notif != null) {
        _showLocal(notif.title ?? 'Nowa wiadomość', notif.body ?? '');
      }
    });
  }

  Future<void> _saveToken(String? token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || token == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmTokens': {token: true},
    }, SetOptions(merge: true));
  }

  Future<void> _showLocal(String title, String body) async {
    const android = AndroidNotificationDetails(
      'chat_messages',
      'Wiadomości',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _fln.show(
      0,
      title,
      body,
      const NotificationDetails(android: android),
    );
  }
}
