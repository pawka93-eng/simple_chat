import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../chat_screen.dart';
import '../local_db.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _localChats = [];

  String get myUid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadLocal();

    // opcjonalne: słuchamy Firestore, żeby zaktualizować lokalnie
    FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .listen(_onRemoteChats);
  }

  Future<void> _loadLocal() async {
    final db = LocalDb.instance;
    final chats = await db.getChats(myUid);
    setState(() {
      _localChats = chats;
      _loading = false;
    });
  }

  Future<void> _onRemoteChats(QuerySnapshot snap) async {
    final db = LocalDb.instance;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participants'] ?? []);
      // znajdź rozmówcę
      final peerUid = participants.firstWhere(
        (p) => p != myUid,
        orElse: () => '',
      );

      await db.insertOrUpdateChat(
        chatId: doc.id,
        myUid: myUid,
        peerUid: peerUid,
        peerEmail: data['peerEmails']?[peerUid] ?? '',
        peerNick: data['peerNicks']?[peerUid] ?? '',
        lastMessage: data['lastMessage'] ?? '',
        lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.millisecondsSinceEpoch,
        unreadCount: 0, // tu możesz kiedyś policzyć z Firestore
      );
    }
    // po zapisaniu – odśwież listę
    _loadLocal();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_localChats.isEmpty) {
      return const Center(child: Text('Nie masz jeszcze rozmów.'));
    }

    return ListView.builder(
      itemCount: _localChats.length,
      itemBuilder: (context, i) {
        final c = _localChats[i];
        final unread = c['unread_count'] as int? ?? 0;

        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(
            (c['peer_nick'] as String?)?.isNotEmpty == true
                ? c['peer_nick'] as String
                : (c['peer_email'] as String? ?? 'Użytkownik'),
          ),
          subtitle: Text(c['last_message'] as String? ?? ''),
          trailing: unread > 0
              ? CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.red,
                  child: Text(
                    unread.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                )
              : null,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: c['chat_id'] as String,
                  peerUid: c['peer_uid'] as String? ?? '',
                  peerEmail: c['peer_email'] as String? ?? '',
                  peerNick: c['peer_nick'] as String? ?? '',
                ),
              ),
            ).then((_) {
              // po powrocie – zresetuj i odśwież
              _loadLocal();
            });
          },
        );
      },
    );
  }
}
