import 'package:flutter/material.dart';
import 'auth/auth_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _floatController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // Smooth dissolve / fade-in animation controller
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
        );

    // Continuous up-and-down floating animation controller for background icons
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _floatAnimation =
        Tween<Offset>(
          begin: const Offset(0, -0.012),
          end: const Offset(0, 0.012),
        ).animate(
          CurvedAnimation(
            parent: _floatController,
            curve: Curves.easeInOutSine,
          ),
        );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final AuthService authService = AuthService();

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: SlideTransition(
                  position: _floatAnimation,
                  child: Stack(
                    children: [
                      _BackgroundSymbol(
                        icon: Icons.favorite_rounded,
                        size: 28,
                        top: 70,
                        left: 36,
                        color: cs.primary,
                        rotation: -0.15,
                      ),
                      _BackgroundSymbol(
                        icon: Icons.mail_outline_rounded,
                        size: 26,
                        top: 140,
                        right: 42,
                        color: cs.secondary,
                        rotation: 0.18,
                      ),
                      _BackgroundSymbol(
                        icon: Icons.sports_esports_rounded,
                        size: 28,
                        top: 280,
                        left: 28,
                        color: cs.secondary,
                        rotation: -0.1,
                      ),
                      _BackgroundSymbol(
                        icon: Icons.auto_awesome_rounded,
                        size: 22,
                        top: 360,
                        right: 32,
                        color: cs.primary,
                        rotation: 0.2,
                      ),
                      _BackgroundSymbol(
                        icon: Icons.note_alt_outlined,
                        size: 26,
                        bottom: 220,
                        left: 48,
                        color: cs.primary,
                        rotation: 0.12,
                      ),
                      _BackgroundSymbol(
                        icon: Icons.favorite_border_rounded,
                        size: 24,
                        bottom: 140,
                        right: 50,
                        color: cs.secondary,
                        rotation: -0.2,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Main content with fade/slide entrance
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      // Top App Title in All Caps
                      Text(
                        'CLOSR',
                        style: textTheme.labelLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4.0,
                          color: cs.primary,
                        ),
                      ),

                      const Spacer(flex: 1),

                      // Logo area with pure glow shadow (no filled circular background)
                      Center(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.35),
                                blurRadius: 36,
                                spreadRadius: 4,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
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

                      // Centered Headline
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'A little '),
                            TextSpan(
                              text: 'CLOSR',
                              style: TextStyle(color: cs.primary),
                            ),
                            const TextSpan(text: ',\nevery day.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: textTheme.displayMedium?.copyWith(
                          fontSize: 36,
                          height: 1.12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Centered Subtitle
                      Text(
                        'A thoughtful space for the conversations, rituals, and small moments that make your relationship yours.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.6,
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Sign-in Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                          shadowColor: cs.primary.withValues(alpha: 0.3),
                        ),
                        onPressed: () async {
                          await authService.signOut();

                          final user = await authService.signInWithGoogle();

                          if (context.mounted) {
                            if (user != null) {
                              Navigator.pushReplacementNamed(
                                context,
                                authService.lastProfileExisted
                                    ? '/main'
                                    : '/preferences',
                              );
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
                      const SizedBox(height: 14),

                      // Terms & Privacy Policy Footer
                      Center(
                        child: Text(
                          'By continuing you agree to our Terms & Privacy Policy.',
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 11,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.68),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundSymbol extends StatelessWidget {
  final IconData icon;
  final double size;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final Color color;
  final double rotation;

  const _BackgroundSymbol({
    required this.icon,
    required this.size,
    required this.color,
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.rotation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Transform.rotate(
        angle: rotation,
        child: Icon(icon, size: size, color: color.withValues(alpha: 0.22)),
      ),
    );
  }
}
