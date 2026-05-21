import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../partner/partner_service.dart';

class LoginScreen extends StatelessWidget {
  final AuthService _authService = AuthService();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Google'),
          onPressed: () async {
            final user = await _authService.signInWithGoogle();
            if (user != null) {
              // Check if this is a new user (no partnerEmail field exists)
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
              final data = userDoc.data();
              if (data == null ||
                  data['partnerEmail'] == null ||
                  data['partnerEmail'] == '') {
                String? partnerEmail;
                await showDialog(
                  context: context,
                  builder: (context) {
                    final controller = TextEditingController();
                    return AlertDialog(
                      title: const Text('Enter Partner Email (optional)'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'Partner Email',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            partnerEmail = controller.text.trim().toLowerCase();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Continue'),
                        ),
                      ],
                    );
                  },
                );
                if (partnerEmail != null && partnerEmail!.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({
                        'partnerEmail': partnerEmail!.toLowerCase(),
                        'partnerEmailLower': partnerEmail!.toLowerCase(),
                      }, SetOptions(merge: true));
                }
              }
              Navigator.pushReplacementNamed(context, '/preferences');
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Sign in failed')));
            }
          },
        ),
      ),
    );
  }
}
