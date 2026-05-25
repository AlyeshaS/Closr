import 'package:flutter/material.dart';
import 'auth/auth_service.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final AuthService authService = AuthService();

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top accent removed for a cleaner welcome screen
              const Spacer(flex: 2),

              // Logo / illustration area — no filled circle behind the logo,
              // only a primary-colored shadow (glow) to give depth.
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  // transparent background, with a primary-colored shadow
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.32),
                        blurRadius: 28,
                        spreadRadius: 4,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/closr_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.favorite_rounded,
                          size: 56,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Headline
              Text(
                'Making together\nfeel easier.',
                style: Theme.of(
                  context,
                ).textTheme.displayMedium?.copyWith(fontSize: 36, height: 1.15),
              ),
              const SizedBox(height: 16),
              Text(
                'Deepen your connection through intentional conversations, shared experiences, and meaningful moments.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.65,
                ),
              ),

              const Spacer(flex: 3),

              // Sign in button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  await authService.signOut();

                  String? partnerEmail;
                  await showDialog(
                    context: context,
                    builder: (context) {
                      final controller = TextEditingController();
                      return AlertDialog(
                        title: const Text('Your partner\'s email'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Optional — add this to link your accounts.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: controller,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'partner@email.com',
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Skip'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                            onPressed: () {
                              partnerEmail = controller.text
                                  .trim()
                                  .toLowerCase();
                              Navigator.of(context).pop();
                            },
                            child: const Text('Continue'),
                          ),
                        ],
                      );
                    },
                  );

                  final user = await authService.signInWithGoogle(
                    partnerEmail: partnerEmail,
                  );

                  if (context.mounted) {
                    if (user != null) {
                      Navigator.pushReplacementNamed(context, '/main');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sign in failed')),
                      );
                    }
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/google_logo.png',
                      height: 20,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.login_rounded, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Continue with Google'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Center(
                child: Text(
                  'By continuing you agree to our Terms & Privacy Policy.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
