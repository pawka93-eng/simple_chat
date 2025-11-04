import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool isLogin = true;
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _nickC = TextEditingController();

  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailC.text.trim(),
          password: _passC.text.trim(),
        );
      } else {
        // rejestracja
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _emailC.text.trim(),
          password: _passC.text.trim(),
        );

        final uid = cred.user!.uid;
        final nick = _nickC.text.trim();
        await cred.user!.updateDisplayName(nick);

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'email': _emailC.text.trim(),
          'nick': nick,
          'createdAt': FieldValue.serverTimestamp(),
          'online': true,
        }, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _nickC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Zaloguj się' : 'Załóż konto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!isLogin)
              TextField(
                controller: _nickC,
                decoration: const InputDecoration(
                  labelText: 'Nick (widoczny dla innych)',
                ),
              ),
            TextField(
              controller: _emailC,
              decoration: const InputDecoration(labelText: 'E-mail (niewidoczny)'),
            ),
            TextField(
              controller: _passC,
              decoration: const InputDecoration(labelText: 'Hasło'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const CircularProgressIndicator()
                  : Text(isLogin ? 'Zaloguj' : 'Zarejestruj'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  isLogin = !isLogin;
                });
              },
              child: Text(isLogin
                  ? 'Nie masz konta? Zarejestruj się'
                  : 'Masz konto? Zaloguj się'),
            ),
          ],
        ),
      ),
    );
  }
}
