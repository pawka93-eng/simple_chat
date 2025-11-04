import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String otherEmail;
  const ChatScreen({super.key, required this.otherEmail});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _c = TextEditingController();
  String? _chatId;
  String? _otherUid;
  bool _otherTyping = false;

  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _initChat();
    _c.addListener(_onTypingChanged);
  }

  @override
  void dispose() {
    _c.removeListener(_onTypingChanged);
    _typingDebounce?.cancel();
    _setTyping(false);
    _c.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final my = FirebaseAuth.instance.currentUser!;
    // znajdź UID rozmówcy po e-mailu
    final q = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: widget.otherEmail)
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie znaleziono użytkownika: ${widget.otherEmail}')),
        );
      }
      return;
    }
    _otherUid = q.docs.first.id;

    // chatId deterministycznie z e-maili (lowercase, sort + join)
    final emails = [my.email!.toLowerCase(), widget.otherEmail.toLowerCase()]..sort();
    final chatId = emails.join('__');
    _chatId = chatId;
    if (mounted) setState(() {});

    // słuchaj typing rozmówcy
    FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .doc(_otherUid)
        .snapshots()
        .listen((doc) {
      _otherTyping = (doc.data()?['isTyping'] ?? false) as bool;
      if (mounted) setState(() {});
    });
  }

  void _onTypingChanged() {
    _typingDebounce?.cancel();
    _setTyping(true);
    _typingDebounce = Timer(const Duration(milliseconds: 900), () {
      _setTyping(false);
    });
  }

  Future<void> _setTyping(bool v) async {
    if (_chatId == null) return;
    final my = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('typing')
        .doc(my.uid)
        .set({'isTyping': v}, SetOptions(merge: true));
  }

  Future<void> _send() async {
    final text = _c.text.trim();
    if (text.isEmpty || _chatId == null) return;
    final my = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .add({
      'fromUid': my.uid,
      'fromEmail': my.email,
      'text': text,
      'ts': FieldValue.serverTimestamp(),
    });
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chatId = _chatId;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherEmail),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _otherTyping ? 'pisze…' : '',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(chatId)
                        .collection('messages')
                        .orderBy('ts', descending: true)
                        .limit(100)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final msgs = snap.data!.docs;
                      if (msgs.isEmpty) {
                        return const Center(child: Text('Brak wiadomości. Napisz coś!'));
                      }
                      final myUid = FirebaseAuth.instance.currentUser!.uid;
                      return ListView.builder(
                        reverse: true,
                        itemCount: msgs.length,
                        itemBuilder: (context, i) {
                          final m = msgs[i].data();
                          final me = (m['fromUid'] == myUid);
                          return Align(
                            alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: me
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(m['text'] ?? ''),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      controller: _c,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Napisz wiadomość…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
