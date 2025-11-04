import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Użytkownicy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('email')
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs.where((d) => d.id != myUid).toList();

          if (docs.isEmpty) {
            return const Center(child: Text('Brak innych użytkowników.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = docs[i].data();
              final email = (u['email'] ?? '') as String;
              final dn = (u['displayName'] ?? email) as String;
              final isOnline = (u['isOnline'] ?? false) as bool;
              final lastOnline = (u['lastOnline'] as Timestamp?)?.toDate();

              String subtitle = isOnline
                  ? 'online'
                  : (lastOnline != null ? 'ostatnio: $lastOnline' : 'offline');

              return ListTile(
                leading: CircleAvatar(
                  child: Text((dn.isNotEmpty ? dn[0] : '?').toUpperCase()),
                ),
                title: Text(dn),
                subtitle: Text('$email • $subtitle'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatScreen(otherEmail: email),
                  ));
                },
              );
            },
          );
        },
      ),
    );
  }
}
