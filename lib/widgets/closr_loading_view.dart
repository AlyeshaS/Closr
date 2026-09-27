import 'package:flutter/material.dart';

class ClosrLoadingView extends StatefulWidget {
  const ClosrLoadingView({super.key});

  @override
  State<ClosrLoadingView> createState() => _ClosrLoadingViewState();
}

class _ClosrLoadingViewState extends State<ClosrLoadingView>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _floatController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<Offset>(
      begin: const Offset(0, -0.012),
      end: const Offset(0, 0.012),
    ).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
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

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: SlideTransition(
              position: _floatAnimation,
              child: Stack(
                children: [
                  _LoadingSymbol(
                    icon: Icons.favorite_rounded,
                    size: 28,
                    top: 70,
                    left: 36,
                    color: cs.primary,
                    rotation: -0.15,
                  ),
                  _LoadingSymbol(
                    icon: Icons.mail_outline_rounded,
                    size: 26,
                    top: 140,
                    right: 42,
                    color: cs.secondary,
                    rotation: 0.18,
                  ),
                  _LoadingSymbol(
                    icon: Icons.sports_esports_rounded,
                    size: 28,
                    top: 280,
                    left: 28,
                    color: cs.secondary,
                    rotation: -0.1,
                  ),
                  _LoadingSymbol(
                    icon: Icons.auto_awesome_rounded,
                    size: 22,
                    top: 360,
                    right: 32,
                    color: cs.primary,
                    rotation: 0.2,
                  ),
                  _LoadingSymbol(
                    icon: Icons.note_alt_outlined,
                    size: 26,
                    bottom: 220,
                    left: 48,
                    color: cs.primary,
                    rotation: 0.12,
                  ),
                  _LoadingSymbol(
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingSymbol extends StatelessWidget {
  final IconData icon;
  final double size;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final Color color;
  final double rotation;

  const _LoadingSymbol({
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
