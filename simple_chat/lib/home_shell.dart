import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'pages/chats_page.dart';
import 'pages/people_page.dart';
import 'services/presence_service.dart';
import 'main.dart'; // dla themeController

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Future<void> _logout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await PresenceService.instance.setOfflineNow(uid);
    }
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ChatsPage(),
      const PeoplePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'Czaty' : 'Osoby'),
        actions: [
          IconButton(
            tooltip: 'Zmień motyw',
            onPressed: () => themeController.toggle(),
            icon: const Icon(Icons.brightness_6),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Czaty',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            label: 'Osoby',
          ),
        ],
      ),
    );
  }
}
