import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'local_db.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String peerUid;
  final String peerEmail;
  final String peerNick;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.peerUid,
    required this.peerEmail,
    required this.peerNick,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<Map<String, dynamic>> _messages = [];

  String get myUid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadLocalMessages();
    _listenRemote();
  }

  Future<void> _loadLocalMessages() async {
    final db = await LocalDb.instance;
    final msgs = await db.getMessages(widget.chatId);
    if (!mounted) return;
    setState(() {
      _messages = msgs;
    });
    _scrollToEndSoon();
  }

  void _listenRemote() {
    // jeśli w Firestore coś się zmieni – pobierz z lokalnej bazy jeszcze raz
    _sub = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((_) {
      // nie bawimy się w porównywanie – po prostu wczytujemy z lokalnej,
      // bo nasz Cloud Function / inne urządzenia też mogą dopisać
      _loadLocalMessages();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _c.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. zapisz do Firestore (żeby drugi telefon dostał)
    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    await chatRef.collection('messages').add({
      'fromUid': myUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. zapisz lokalnie
    final db = await LocalDb.instance;
    await db.insertMessage(
      chatId: widget.chatId,
      fromUid: myUid,
      text: text,
      createdAt: now,
    );
    await db.insertOrUpdateChat(
      chatId: widget.chatId,
      myUid: myUid,
      peerUid: widget.peerUid,
      peerEmail: widget.peerEmail,
      peerNick: widget.peerNick,
      lastMessage: text,
      lastMessageAt: now,
      unreadCount: 0,
    );

    // 3. wyczyść pole i odśwież listę
    _c.clear();
    await _loadLocalMessages();
  }

  void _scrollToEndSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.peerNick.isNotEmpty
        ? widget.peerNick
        : (widget.peerEmail.isNotEmpty ? widget.peerEmail : 'Czat');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final fromMe = m['from_uid'] == myUid;

                return Align(
                  alignment:
                      fromMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: fromMe
                          ? Colors.blue.shade100
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m['text'] ?? ''),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _c,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Napisz wiadomość…',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
