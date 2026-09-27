import 'package:flutter/material.dart';

class WelcomeTransitionScreen extends StatefulWidget {
  final String name;

  const WelcomeTransitionScreen({super.key, required this.name});

  @override
  State<WelcomeTransitionScreen> createState() =>
      _WelcomeTransitionScreenState();
}

class _WelcomeTransitionScreenState extends State<WelcomeTransitionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _floatController;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;
  late final Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
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
    _contentFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.65, curve: Curves.easeOut),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
          ),
        );
    _controller.forward();
    _goHome();
  }

  Future<void> _goHome() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/main');
  }

  @override
  void dispose() {
    _controller.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                      _WelcomeSymbol(
                        icon: Icons.favorite_rounded,
                        size: 28,
                        top: 70,
                        left: 36,
                        color: cs.primary,
                        rotation: -0.15,
                      ),
                      _WelcomeSymbol(
                        icon: Icons.mail_outline_rounded,
                        size: 26,
                        top: 140,
                        right: 42,
                        color: cs.secondary,
                        rotation: 0.18,
                      ),
                      _WelcomeSymbol(
                        icon: Icons.sports_esports_rounded,
                        size: 28,
                        top: 280,
                        left: 28,
                        color: cs.secondary,
                        rotation: -0.1,
                      ),
                      _WelcomeSymbol(
                        icon: Icons.auto_awesome_rounded,
                        size: 22,
                        top: 360,
                        right: 32,
                        color: cs.primary,
                        rotation: 0.2,
                      ),
                      _WelcomeSymbol(
                        icon: Icons.note_alt_outlined,
                        size: 26,
                        bottom: 220,
                        left: 48,
                        color: cs.primary,
                        rotation: 0.12,
                      ),
                      _WelcomeSymbol(
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
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _contentFade,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Welcome,\n${widget.name}',
                        textAlign: TextAlign.center,
                        style: textTheme.displayMedium?.copyWith(
                          fontSize: 34,
                          height: 1.15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Let’s make a little more room for closeness.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 34),
                      SizedBox(
                        width: 42,
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(3),
                          backgroundColor: cs.primary.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      ),
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

class _WelcomeSymbol extends StatelessWidget {
  final IconData icon;
  final double size;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final Color color;
  final double rotation;

  const _WelcomeSymbol({
    required this.icon,
    required this.size,
    required this.color,
    this.top,
    this.right,
    this.bottom,
    this.left,
    required this.rotation,
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
