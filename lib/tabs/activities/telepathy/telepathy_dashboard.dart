// lib/features/telepathy/presentation/telepathy_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/telepathy_game_model.dart';
import '../../../services/telepathy_service.dart';
import '../../../services/word_generator_service.dart';
import 'telepathy_game_screen.dart';
import "emoji_pool.dart";

class TelepathyDashboard extends StatefulWidget {
  const TelepathyDashboard({super.key});

  @override
  State<TelepathyDashboard> createState() => _TelepathyDashboardState();
}

Widget _buildInstructionStep({
  required BuildContext context,
  required String stepNumber,
  required String text,
  required ColorScheme cs,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14.0, left: 4.0, right: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
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
        // ✅ FIX: Grab a fully randomized emoji for the starting seed
        initialSeed = EmojiPool.getRandomEmoji();
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
                  title: 'Random Word',
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

                // 💡 NEW: HOW TO PLAY SECTION
                const SizedBox(height: 36),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Divider(color: cs.outlineVariant, thickness: 1),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: cs.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'HOW TO PLAY',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.5,
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInstructionStep(
                  context: context,
                  stepNumber: '1',
                  text:
                      'Start with a core prompt word displayed at the top of your gameplay screen.',
                  cs: cs,
                ),
                _buildInstructionStep(
                  context: context,
                  stepNumber: '2',
                  text:
                      'Both you and your partner independently type a single word associated with that prompt.',
                  cs: cs,
                ),
                _buildInstructionStep(
                  context: context,
                  stepNumber: '3',
                  text:
                      'If your entries do not match, your words fuse into a new double-word prompt challenge!',
                  cs: cs,
                ),
                _buildInstructionStep(
                  context: context,
                  stepNumber: '4',
                  text:
                      'Keep building creative connection bridges until you both submit the exact same matching word to achieve a Mind Meld!',
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
