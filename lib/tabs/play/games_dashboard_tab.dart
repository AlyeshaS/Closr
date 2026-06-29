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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Solid Rich Score Split Banner (Matches Quests Theme) ────────
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  // Uses the solid primary container color matching your weekly quest design
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: cs.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // My Score Segment
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'MY SCORE',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  letterSpacing: 2.0,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onPrimaryContainer.withOpacity(0.8),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$myScore',
                            style: TextStyle(
                              fontFamily: 'CormorantGaramond',
                              fontSize: 44,
                              fontWeight: FontWeight.w500,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Elegant split line that matches the content contrast
                    Container(
                      width: 1,
                      height: 50,
                      color: cs.onPrimaryContainer.withOpacity(0.15),
                    ),

                    // Partner Score Segment
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'PARTNER',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  letterSpacing: 2.0,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onPrimaryContainer.withOpacity(0.8),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$partnerScore',
                            style: TextStyle(
                              fontFamily: 'CormorantGaramond',
                              fontSize: 44,
                              fontWeight: FontWeight.w500,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 16),
                child: Text(
                  'CHOOSE A GAME',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurfaceVariant.withOpacity(0.9),
                  ),
                ),
              ),

              // 1. LetterLocked Editorial Card
              _buildCleanGameCard(
                context: context,
                title: 'LetterLocked',
                subtitle:
                    'Co-op Vault or Versus Word Trap. Build words, flip turns, and lock combinations.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LetterLockedDashboard(),
                    ),
                  );
                },
                cs: cs,
              ),
              const SizedBox(height: 12),

              // 2. Our Trivia Editorial Card
              _buildCleanGameCard(
                context: context,
                title: 'Our Trivia',
                subtitle:
                    'Test your compatibility! Sync matching responses and see who remembers best.',
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
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1D1214) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? cs.outlineVariant.withOpacity(0.15)
                : cs.outlineVariant.withOpacity(0.7),
            width: 1,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withOpacity(0.75),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: cs.outline.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
