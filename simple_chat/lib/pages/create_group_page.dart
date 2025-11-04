import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../chat_screen.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _nameCtrl = TextEditingController();
  bool _isChannel = false;
  final Set<String> _selected = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj nazwę')),
      );
      return;
    }
    // Upewnij się, że ja też jestem w uczestnikach
    final participants = {..._selected, myUid}.toList();

    if (participants.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dodaj co najmniej jedną osobę')),
      );
      return;
    }

    final chatRef = FirebaseFirestore.instance.collection('chats').doc();
    await chatRef.set({
      'type': _isChannel ? 'channel' : 'group',
      'name': name,
      'ownerUid': myUid,
      'admins': [myUid],
      'participants': participants,
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unread': { for (final uid in participants) uid: 0 },
      'typing': { for (final uid in participants) uid: false },
    });

    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ChatScreen(
        chatId: chatRef.id,
        // dla group/channel nie potrzebujemy peer danych:
        peerUid: '',
        peerEmail: '',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final usersQuery = FirebaseFirestore.instance
        .collection('users')
        .orderBy('email');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isChannel ? 'Nowy kanał' : 'Nowa grupa'),
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Kanał (tylko właściciel/admin może pisać)'),
            value: _isChannel,
            onChanged: (v) => setState(() => _isChannel = v),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nazwa',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Wybierz uczestników', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: usersQuery.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = (snap.data?.docs ?? [])
                    .where((d) => d.id != myUid)
                    .toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('Brak innych użytkowników.'));
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data();
                    final email = (data['email'] as String?) ?? '(bez e-maila)';
                    final selected = _selected.contains(d.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(d.id);
                          } else {
                            _selected.remove(d.id);
                          }
                        });
                      },
                      title: Text(email),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _create,
                  child: Text(_isChannel ? 'Utwórz kanał' : 'Utwórz grupę'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
