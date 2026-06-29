// lib/play/letter_locked/letter_locked_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'letter_locked_controller.dart';
import 'letter_locked_game_screen.dart';

class LetterLockedDashboard extends StatefulWidget {
  const LetterLockedDashboard({super.key});

  @override
  State<LetterLockedDashboard> createState() => _LetterLockedDashboardState();
}

class _LetterLockedDashboardState extends State<LetterLockedDashboard> {
  final LetterLockedController _controller = LetterLockedController();
  String _myUid = '';
  String _coupleId = '';
  String _partnerUid = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _resolveSession();
  }

  void _resolveSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _myUid = user.uid;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_myUid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          _coupleId = data['coupleId'] ?? data['couple_id'] ?? '';
          _partnerUid = data['partnerUid'] ?? data['partner_uid'] ?? '';
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _setupAndLaunchGame(String mode) async {
    setState(() => _isLoading = true);
    await _controller.startNewGame(
      coupleId: _coupleId,
      myUid: _myUid,
      partnerUid: _partnerUid,
      mode: mode,
    );
    if (mounted) {
      // Replace layout so the back button on game screen routes smoothly back to the core hub
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LetterLockedGameScreen(coupleId: _coupleId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CHOOSE YOUR MODE',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
            ),
            const SizedBox(height: 16),
            _buildCleanModeCard(
              context: context,
              title: 'Co-op Vault Mode',
              subtitle:
                  'Work together using a shared letter dial to unlock the safe vault. Cozy and collaborative.',
              onTap: () => _setupAndLaunchGame('coop'),
              cs: cs,
            ),
            const SizedBox(height: 12),
            _buildCleanModeCard(
              context: context,
              title: 'Versus Word Trap',
              subtitle:
                  'Change exactly one letter to morph the word. Trap your partner by locking their choices out.',
              onTap: () => _setupAndLaunchGame('versus'),
              cs: cs,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanModeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF231519) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.primary.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.layers_rounded, color: cs.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
