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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _myUid = user.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_myUid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _coupleId = data['coupleId'] ?? 'fallback_couple_id';
        _partnerUid = data['partnerUid'] ?? 'fallback_partner_id';
      }
    }
    setState(() => _isLoading = false);
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LetterLockedGameScreen(coupleId: _coupleId),
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('LetterLocked'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
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
            _buildModeCard(
              context: context,
              title: 'Co-op Vault Mode',
              subtitle:
                  'Work together using a shared letter dial to unlock the safe vault. Cozy and collaborative!',
              icon: Icons.gpp_good_outlined,
              color: cs.primaryContainer,
              onTap: () => _setupAndLaunchGame('coop'),
              cs: cs,
            ),
            const SizedBox(height: 16),
            _buildModeCard(
              context: context,
              title: 'Versus Word Trap',
              subtitle:
                  'Change exactly one letter to morph the word. Trap your partner by locking their choices out!',
              icon: Icons.local_fire_department_outlined,
              color: cs.secondaryContainer,
              onTap: () => _setupAndLaunchGame('versus'),
              cs: cs,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: cs.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: cs.outline),
          ],
        ),
      ),
    );
  }
}
