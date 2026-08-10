// lib/play/games_dashboard_tab.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'trivia/trivia_game_screen.dart';
import 'letter_locked/letter_locked_dashboard.dart';
import 'doodle_clues/doodle_clues_game_screen.dart';
import 'telepathy/telepathy_dashboard.dart';
import 'better_together/better_together_dashboard.dart';

class GamesDashboardTab extends StatefulWidget {
  const GamesDashboardTab({super.key});

  @override
  State<GamesDashboardTab> createState() => _GamesDashboardTabState();
}

class _GamesDashboardTabState extends State<GamesDashboardTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_myUid.isEmpty) {
      return const Center(child: Text("Please log in."));
    }

    // Stream 1: Listen to the core user profile to extract partner email pairing info
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(_myUid).snapshots(),
      builder: (context, mySnapshot) {
        if (!mySnapshot.hasData || !mySnapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final myData = mySnapshot.data!.data();
        final String partnerEmailLower =
            (myData?['partnerEmailLower'] ?? myData?['partnerEmail'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        // Stream 2: Resolve partner's matching UID string from their registration email
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: partnerEmailLower.isEmpty
              ? const Stream.empty()
              : _firestore
                    .collection('users')
                    .where('emailLower', isEqualTo: partnerEmailLower)
                    .snapshots(),
          builder: (context, partnerLookup) {
            String partnerUid = '';
            if (partnerLookup.hasData && partnerLookup.data!.docs.isNotEmpty) {
              partnerUid = partnerLookup.data!.docs.first.id;
            }

            // Stream 3: Real-time listener targeting your specific subcollection folder logs
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('users')
                  .doc(_myUid)
                  .collection('scores')
                  .snapshots(),
              builder: (context, myScoresSnapshot) {
                // Stream 4: Real-time listener targeting your partner's subcollection folder logs
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: partnerUid.isEmpty
                      ? const Stream.empty()
                      : _firestore
                            .collection('users')
                            .doc(partnerUid)
                            .collection('scores')
                            .snapshots(),
                  builder: (context, partnerScoresSnapshot) {
                    // Aggregate totals by dynamically calculating the sum of matching subcollection document field scores
                    final myTotalWins = _sumScoresFromDocuments(
                      myScoresSnapshot.data?.docs,
                    );
                    final partnerTotalWins = _sumScoresFromDocuments(
                      partnerScoresSnapshot.data?.docs,
                    );

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Frosted Glass Top Score Panel
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.shadow.withOpacity(0.07),
                                  blurRadius: 26,
                                  offset: const Offset(0, 14),
                                ),
                                BoxShadow(
                                  color: cs.primary.withOpacity(0.12),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 18,
                                  sigmaY: 18,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        cs.primaryContainer.withOpacity(0.85),
                                        cs.secondaryContainer.withOpacity(0.55),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: cs.primary.withOpacity(0.35),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildScoreColumn(
                                        context,
                                        '$myTotalWins',
                                        'Your Wins',
                                        cs.primary,
                                      ),
                                      Container(
                                        width: 1.5,
                                        height: 44,
                                        color: cs.primary.withOpacity(0.35),
                                      ),
                                      _buildScoreColumn(
                                        context,
                                        '$partnerTotalWins',
                                        "Partner's Wins",
                                        cs.secondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'AVAILABLE GAMES',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurfaceVariant.withOpacity(0.8),
                                ),
                          ),
                          const SizedBox(height: 14),

                          // Better Together Game Card
                          _buildCleanGameCard(
                            context: context,
                            title: 'Better Together',
                            subtitle:
                                'A memory-card pairing game! Match iconic partners like 🍿 + 🎬 across themed decks.',
                            icon: Icons.style_rounded,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const BetterTogetherDashboard(),
                                ),
                              );
                            },
                            cs: cs,
                          ),
                          const SizedBox(height: 14),

                          // LetterLocked Game Card
                          _buildCleanGameCard(
                            context: context,
                            title: 'LetterLocked',
                            subtitle:
                                'Co-op Vault or Versus Word Trap. Build words, flip turns, and lock combinations.',
                            icon: Icons.lock_open_rounded,
                            onTap: () {
                              if (partnerUid.isEmpty) return;

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LetterLockedDashboard(
                                    myUid: _myUid,
                                    partnerUid: partnerUid,
                                  ),
                                ),
                              );
                            },
                            cs: cs,
                          ),
                          const SizedBox(height: 14),

                          // Our Trivia Game Card
                          _buildCleanGameCard(
                            context: context,
                            title: 'Our Trivia',
                            subtitle:
                                'Test your compatibility! Sync matching responses and see who remembers best.',
                            icon: Icons.quiz_rounded,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TriviaGameScreen(),
                                ),
                              );
                            },
                            cs: cs,
                          ),
                          const SizedBox(height: 14),

                          // DoodleClues Game Card
                          _buildCleanGameCard(
                            context: context,
                            title: 'DoodleClues',
                            subtitle:
                                'An asymmetric sketching showdown! Translate secret items into line art and see if your partner can crack the hint.',
                            icon: Icons.gesture_rounded,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const DoodleCluesGameScreen(),
                                ),
                              );
                            },
                            cs: cs,
                          ),
                          const SizedBox(height: 14),

                          // Telepathy Game Card
                          _buildCleanGameCard(
                            context: context,
                            title: 'Telepathy',
                            subtitle:
                                'Collaborative word chains! Start with a seed phrase and build bridges together until your lines of thinking merge.',
                            icon: Icons.psychology_rounded,
                            onTap: () {
                              if (partnerUid.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Waiting to connect with partner...",
                                    ),
                                  ),
                                );
                                return;
                              }

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TelepathyDashboard(),
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
              },
            );
          },
        );
      },
    );
  }

  /// 🌟 Migrated: Loops through individual document records inside the score subcollection to pull totals
  int _sumScoresFromDocuments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? docs,
  ) {
    if (docs == null || docs.isEmpty) return 0;
    int total = 0;
    for (var doc in docs) {
      // Looks for a field key called 'wins' inside each game's logging document record
      total += (doc.data()['wins'] as int? ?? 0);
    }
    return total;
  }

  Widget _buildScoreColumn(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            fontSize: 38,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCleanGameCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerLow : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(0.9),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Icon(icon, color: cs.primary, size: 22)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
