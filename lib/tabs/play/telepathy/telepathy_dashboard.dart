// lib/features/telepathy/presentation/telepathy_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/telepathy_game_model.dart';
import '../../../services/telepathy_service.dart';
import '../../../services/word_generator_service.dart';
import 'telepathy_game_screen.dart';

class TelepathyDashboard extends StatefulWidget {
  const TelepathyDashboard({super.key});

  @override
  State<TelepathyDashboard> createState() => _TelepathyDashboardState();
}

class _TelepathyDashboardState extends State<TelepathyDashboard> {
  final TelepathyFirebaseService _service = TelepathyFirebaseService();
  String _myUid = '';
  String _partnerUid = '';
  String _partnerEmail = '';
  String _gameId = '';
  bool _isLoading = true;

  // 🎯 FIX 1: Track if we are already showing the game screen to prevent loop navigation stacking
  bool _isScreenPushed = false;

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
              _gameId = 'telepathy_${uids[0]}_${uids[1]}';
            }
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _handleGameRouting(GameMode mode) async {
    if (_partnerUid.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      String initialSeed = "Custom Session";
      if (mode == GameMode.wordsOnly) {
        initialSeed = await WordGeneratorService.getRandomSeedWord();
      } else if (mode == GameMode.emojisOnly) {
        initialSeed = "🔮";
      }

      // Simply write the selection data update directly to the shared document trace
      await _service.startNewGame(
        gameId: _gameId,
        myUid: _myUid,
        partnerUid: _partnerUid,
        mode: mode,
        seedWord: initialSeed,
      );
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

    if (_partnerUid.isEmpty) {
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
      appBar: AppBar(title: const Text('Mind Meld Telepathy')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_myUid)
            .collection('games')
            .doc('telepathy')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final gameData = snapshot.data!.data();

            // 🎯 FIX 1 Cont.: Check state flag to ensure auto-navigation only fires
            // if the user is not already actively viewing the gameplay screen.
            if (gameData?['status'] == 'active' &&
                gameData?['seedWord'] != 'PENDING_CHOICE' &&
                !_isScreenPushed) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (mounted) {
                  _isScreenPushed = true;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TelepathyGameScreen(
                        myUid: _myUid,
                        partnerUid: _partnerUid,
                      ),
                    ),
                  );
                  _isScreenPushed = false;
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
                  title: 'Random AI Word',
                  subtitle:
                      'The system generates a random seed word to kickstart your matching pool.',
                  icon: Icons.casino_outlined,
                  iconColor: cs.primary,
                  onTap: () => _handleGameRouting(GameMode.wordsOnly),
                  cs: cs,
                ),
                const SizedBox(height: 12),
                _buildCleanModeCard(
                  context: context,
                  title: 'Emojis Only',
                  subtitle:
                      'Link minds and predict connection points strictly using symbols.',
                  icon: Icons.emoji_emotions_outlined,
                  iconColor: Colors.purple,
                  onTap: () => _handleGameRouting(GameMode.emojisOnly),
                  cs: cs,
                ),
                const SizedBox(height: 12),
                _buildCleanModeCard(
                  context: context,
                  title: 'Create Your Own',
                  subtitle:
                      'Both enter a hidden baseline word. They merge to build your initial prompt challenge.',
                  icon: Icons.tune_rounded,
                  iconColor: Colors.orange[700]!,
                  onTap: () => _handleGameRouting(GameMode.customPrompt),
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
    required IconData icon,
    required Color iconColor,
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
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
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
