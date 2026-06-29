// lib/tabs/play/letter_locked/letter_locked_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/dictionary_service.dart'; // ✨ IMPORT THE DICTIONARY SERVICE
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
  String _roomId = '';
  String _partnerUid = '';
  String _partnerEmail = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // ✨ FIXED: Pre-loads the full 4-letter dictionary into memory instantly
    DictionaryService.initialize();

    _resolveSession(); // Resolves your dynamic email connections
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
          _partnerEmail =
              data['partnerEmailLower'] ?? data['partnerEmail'] ?? '';
          _partnerEmail = _partnerEmail.trim().toLowerCase();

          if (_partnerEmail.isNotEmpty) {
            var partnerQuery = await FirebaseFirestore.instance
                .collection('users')
                .where('emailLower', isEqualTo: _partnerEmail)
                .get();

            if (partnerQuery.docs.isEmpty) {
              partnerQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: _partnerEmail)
                  .get();
            }

            if (partnerQuery.docs.isNotEmpty) {
              _partnerUid = partnerQuery.docs.first.id;
              List<String> uids = [_myUid, _partnerUid]..sort();
              _roomId = 'letterlocked_${uids[0]}_${uids[1]}';
            }
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _handleGameRouting(String mode) async {
    if (_roomId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final gameDoc = await FirebaseFirestore.instance
          .collection('games')
          .doc(_roomId)
          .get();

      if (mounted) {
        if (gameDoc.exists && gameDoc.data()?['status'] == 'active') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => LetterLockedGameScreen(roomId: _roomId),
            ),
          );
        } else {
          await _controller.startNewGame(
            roomId: _roomId,
            myUid: _myUid,
            partnerUid: _partnerUid,
            mode: mode,
          );

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => LetterLockedGameScreen(roomId: _roomId),
              ),
            );
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_roomId.isEmpty) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              _partnerEmail.isEmpty
                  ? 'Link accounts with your partner in settings to start playing together!'
                  : 'Waiting for your partner to register an account with $_partnerEmail...',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .doc(_roomId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final gameData = snapshot.data!.data();
            if (gameData?['status'] == 'active') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => LetterLockedGameScreen(roomId: _roomId),
                    ),
                  );
                }
              });
            }
          }

          return SingleChildScrollView(
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
                  onTap: () => _handleGameRouting('coop'),
                  cs: cs,
                ),
                const SizedBox(height: 12),
                _buildCleanModeCard(
                  context: context,
                  title: 'Versus Word Trap',
                  subtitle:
                      'Change exactly one letter to morph the word. Trap your partner by locking their choices out.',
                  onTap: () => _handleGameRouting('versus'),
                  cs: cs,
                ),
              ],
            ),
          );
        },
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
