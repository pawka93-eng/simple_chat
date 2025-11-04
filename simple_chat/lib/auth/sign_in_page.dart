import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;
  String? _err;

  Future<void> _submit() async {
    setState(() { _busy = true; _err = null; });
    try {
      UserCredential cred;
      if (_isRegister) {
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _pass.text,
        );
      } else {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _pass.text,
        );
      }

      final u = cred.user!;
      // załóż/uzupełnij dokument użytkownika
      final users = FirebaseFirestore.instance.collection('users');
      final doc = users.doc(u.uid);
      await doc.set({
        'uid': u.uid,
        'email': u.email,
        'displayName': u.displayName ?? u.email,
        'lastOnline': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      setState(() { _err = e.message; });
    } catch (e) {
      setState(() { _err = e.toString(); });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isRegister ? 'Rejestracja' : 'Logowanie')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail')),
            const SizedBox(height: 8),
            TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Hasło')),
            const SizedBox(height: 16),
            if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const CircularProgressIndicator() : Text(_isRegister ? 'Zarejestruj' : 'Zaloguj'),
            ),
            TextButton(
              onPressed: _busy ? null : () => setState(() => _isRegister = !_isRegister),
              child: Text(_isRegister ? 'Masz konto? Zaloguj się' : 'Nie masz konta? Zarejestruj się'),
            ),
          ],
        ),
      ),
    );
  }
}
