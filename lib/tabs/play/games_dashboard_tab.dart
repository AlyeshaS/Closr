// lib/play/games_dashboard_tab.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'trivia/trivia_dashboard_tab.dart';
import 'letter_locked/letter_locked_dashboard.dart';

class GamesDashboardTab extends StatefulWidget {
  const GamesDashboardTab({super.key});

  @override
  State<GamesDashboardTab> createState() => _GamesDashboardTabState();
}

class _GamesDashboardTabState extends State<GamesDashboardTab> {
  String _myUid = '';
  String _coupleId = '';
  String _partnerUid = '';

  @override
  void initState() {
    super.initState();
    _resolveUserSession();
  }

  void _resolveUserSession() async {
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
          if (mounted) {
            setState(() {
              _coupleId = data['coupleId'] ?? data['couple_id'] ?? '';
              _partnerUid = data['partnerUid'] ?? data['partner_uid'] ?? '';
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _coupleId.isEmpty
          ? const Stream.empty()
          : FirebaseFirestore.instance
                .collection('games')
                .doc('letterlocked_$_coupleId')
                .snapshots(),
      builder: (context, snapshot) {
        int myScore = 0;
        int partnerScore = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          final gameData = data?['gameData'] as Map<String, dynamic>?;
          final scores = gameData?['scores'] as Map<String, dynamic>?;

          if (scores != null) {
            myScore = scores[_myUid] as int? ?? 0;
            partnerScore = scores[_partnerUid] as int? ?? 0;
          }
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Premium Match-Score Banner (Matches Quests Styling) ──────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ARCADE PROGRESS',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Scoreboard matching live session',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$myScore - $partnerScore',
                      style: TextStyle(
                        fontFamily: 'CormorantGaramond',
                        fontSize: 36,
                        fontWeight: FontWeight.w500,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'CHOOSE A GAME',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 12),

              // 1. LetterLocked Custom Card
              _buildCleanGameCard(
                context: context,
                title: 'LetterLocked',
                subtitle:
                    'Co-op Vault or Versus Word Trap. Build words, flip turns, and lock rows.',
                emoji: '🔏',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LetterLockedDashboard(),
                    ),
                  );
                },
                cs: cs,
              ),
              const SizedBox(height: 10),

              // 2. Our Trivia Custom Card
              _buildCleanGameCard(
                context: context,
                title: 'Our Trivia',
                subtitle:
                    'Test your compatibility! Sync match responses and test memory.',
                emoji: '🧠',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TriviaDashboardTab(),
                    ),
                  );
                },
                cs: cs,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCleanGameCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String emoji,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF231519) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            // Styled Emoji Square container matching Quest UI items
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: cs.outline.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}
