import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../chat_screen.dart';
import '../local_db.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final _searchC = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _myLocalPeople = [];
  bool _searching = false;

  String get myUid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadLocalPeople();
  }

  Future<void> _loadLocalPeople() async {
    final db = LocalDb.instance;
    final list = await db.getFriends(myUid);
    setState(() {
      _myLocalPeople = list;
    });
  }

  Future<void> _doSearch(String text) async {
    final q = text.trim();
    if (q.length < 2) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _searching = true;
    });

    // zakładam, że w users masz pola: uid, email, nick
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('nick', isGreaterThanOrEqualTo: q)
        .where('nick', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(20)
        .get();

    setState(() {
      _searchResults = snap.docs
          .map((d) => {
                'uid': d.id,
                'email': d['email'] ?? '',
                'nick': d['nick'] ?? '',
              })
          .where((u) => u['uid'] != myUid)
          .toList();
      _searching = false;
    });
  }

  Future<void> _addPerson(Map<String, dynamic> user) async {
    final db = LocalDb.instance;
    await db.insertFriend(
      ownerUid: myUid,
      userUid: user['uid'] as String,
      email: user['email'] as String,
      nick: user['nick'] as String,
    );
    _loadLocalPeople();
  }

  Future<void> _openChatFromLocal(Map<String, dynamic> p) async {
    // kiedy klikam w osobę, chcę mieć rekord w chats
    final db = LocalDb.instance;

    // tworzymy ID czatu deterministycznie:
    final chatId = _composeChatId(myUid, p['user_uid'] as String);

    await db.insertOrUpdateChat(
      chatId: chatId,
      myUid: myUid,
      peerUid: p['user_uid'] as String,
      peerEmail: p['email'] as String? ?? '',
      peerNick: p['nick'] as String? ?? '',
      lastMessage: '',
      lastMessageAt: DateTime.now().millisecondsSinceEpoch,
      unreadCount: 0,
    );

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          peerUid: p['user_uid'] as String,
          peerEmail: p['email'] as String? ?? '',
          peerNick: p['nick'] as String? ?? '',
        ),
      ),
    );

    _loadLocalPeople();
  }

  String _composeChatId(String a, String b) {
    // to samo co w innych miejscach
    return (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // SEARCH
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchC,
            decoration: InputDecoration(
              hintText: 'Szukaj po nicku…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: _doSearch,
          ),
        ),
        if (_searching) const LinearProgressIndicator(),

        // wyniki wyszukiwania z Firestore
        if (_searchResults.isNotEmpty)
          Expanded(
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Wyniki z Firestore',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ..._searchResults.map((u) {
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(u['nick'] as String? ?? u['email'] as String? ?? ''),
                    subtitle: Text(u['email'] as String? ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_add),
                      onPressed: () => _addPerson(u),
                    ),
                  );
                }).toList(),
              ],
            ),
          )
        else
          Expanded(
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Twoje osoby (lokalnie)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_myLocalPeople.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Brak dodanych osób. Użyj wyszukiwarki.'),
                  ),
                ..._myLocalPeople.map((p) {
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(p['nick'] as String? ?? p['email'] as String? ?? ''),
                    subtitle: Text(p['email'] as String? ?? ''),
                    onTap: () => _openChatFromLocal(p),
                  );
                }).toList(),
              ],
            ),
          ),
      ],
    );
  }
}
