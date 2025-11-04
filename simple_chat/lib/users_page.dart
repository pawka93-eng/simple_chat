import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../chat_screen.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  Future<void> _openChat(BuildContext context, String otherUid, String otherEmail) async {
    final my = FirebaseAuth.instance.currentUser!;
    final myUid = my.uid;
    final myEmail = my.email ?? '';

    final chatsCol = FirebaseFirestore.instance.collection('chats');

    // 1. znajdź czy już jest taki direct
    final snap = await chatsCol
        .where('type', isEqualTo: 'direct')
        .where('participants', arrayContains: myUid)
        .get();

    DocumentSnapshot<Map<String, dynamic>>? existing;

    for (final doc in snap.docs) {
      final parts = List<String>.from(doc.data()['participants'] ?? []);
      if (parts.contains(otherUid)) {
        existing = doc;
        break;
      }
    }

    DocumentReference<Map<String, dynamic>> chatDoc;

    if (existing != null) {
      chatDoc = existing.reference;
      // przy wejściu aktualizujmy pole, żeby nie było null
      await chatDoc.set({
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      // 2. nie ma – tworzymy
      chatDoc = await chatsCol.add({
        'type': 'direct',
        'participants': [myUid, otherUid],
        'emails': {
          myUid: myEmail,
          otherUid: otherEmail,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unread': {
          myUid: 0,
          otherUid: 0,
        },
      });
    }

    // przejście do czatu
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatDoc.id,
            peerUid: otherUid,
            peerEmail: otherEmail,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Osoby'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs
              .where((d) => d.id != myUid)
              .toList();

          if (docs.isEmpty) {
            return const Center(child: Text('Brak innych użytkowników'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final u = docs[i].data();
              final email = u['email'] ?? '';
              final uid = docs[i].id;
              final online = u['online'] == true;
              return ListTile(
                leading: Stack(
                  children: [
                    const CircleAvatar(child: Icon(Icons.person)),
                    if (online)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(email),
                onTap: () => _openChat(context, uid, email),
              );
            },
          );
        },
      ),
    );
  }
}
