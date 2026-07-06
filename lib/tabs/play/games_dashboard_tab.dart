// lib/play/games_dashboard_tab.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'trivia/trivia_game_screen.dart';
import 'letter_locked/letter_locked_dashboard.dart';
import 'doodle_clues/doodle_clues_game_screen.dart';
import 'telepathy/telepathy_game_screen.dart'; // Import your new telepathy screen

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

    // ⚡ INSTANT ROOT PROFILE STREAM: No async initState delays, maps live data directly
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_myUid)
          .snapshots(),
      builder: (context, mySnapshot) {
        if (!mySnapshot.hasData || !mySnapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final myData = mySnapshot.data!.data();
        final myTotalWins = _scoreTotalFromUserData(myData);
        final String partnerEmailLower =
            (myData?['partnerEmailLower'] ?? myData?['partnerEmail'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

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

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: partnerUid.isEmpty
                  ? const Stream.empty()
                  : _firestore.collection('users').doc(partnerUid).snapshots(),
              builder: (context, partnerSnapshot) {
                int partnerTotalWins = 0;

                if (partnerSnapshot.hasData && partnerSnapshot.data!.exists) {
                  partnerTotalWins = _scoreTotalFromUserData(
                    partnerSnapshot.data!.data(),
                  );
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildScoreColumn(
                              context,
                              '$myTotalWins',
                              'Your Wins',
                              cs.primary,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: cs.outlineVariant,
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
                      const SizedBox(height: 24),
                      Text(
                        'GAMES',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 12),
                      _buildCleanGameCard(
                        context: context,
                        title: 'LetterLocked',
                        subtitle:
                            'Co-op Vault or Versus Word Trap. Build words, flip turns, and lock combinations.',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                backgroundColor: cs.surface,
                                appBar: AppBar(
                                  title: const Text('LetterLocked'),
                                  centerTitle: true,
                                  leading: IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ),
                                body: const LetterLockedDashboard(),
                              ),
                            ),
                          );
                        },
                        cs: cs,
                      ),
                      const SizedBox(height: 10),
                      _buildCleanGameCard(
                        context: context,
                        title: 'Our Trivia',
                        subtitle:
                            'Test your compatibility! Sync matching responses and see who remembers best.',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TriviaGameScreen(),
                            ),
                          );
                        },
                        cs: cs,
                      ),
                      const SizedBox(height: 10),
                      _buildCleanGameCard(
                        context: context,
                        title: 'DoodleClues',
                        subtitle:
                            'An asymmetric sketching showdown! Translate secret items into line art and see if your partner can crack the hint.',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DoodleCluesGameScreen(),
                            ),
                          );
                        },
                        cs: cs,
                      ),
                      const SizedBox(height: 10),
                      // 🧠 Telepathy Mind Meld Co-op Custom Card
                      _buildCleanGameCard(
                        context: context,
                        title: 'Telepathy',
                        subtitle:
                            'Collaborative word chains! Start with a seed phrase and build bridges together until your lines of thinking merge.',
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

                          // Establish a predictable host room document key
                          // by sorting alphanumeric user tokens
                          final List<String> pairIds = [_myUid, partnerUid]
                            ..sort();
                          final String functionalHostId = pairIds.first;
                          const String activeGameSessionId =
                              "daily_telepathy_session";

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TelepathyGameScreen(
                                gameId: activeGameSessionId,
                                hostId: functionalHostId,
                                currentUserId: _myUid,
                              ),
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
  }

  int _scoreTotalFromUserData(Map<String, dynamic>? data) {
    final scores = data?['scores'] as Map<String, dynamic>?;
    if (scores == null) return 0;

    final int llWins = scores['letterlocked'] as int? ?? 0;
    final int triviaWins = scores['trivia'] as int? ?? 0;
    final int doodleWins = scores['doodleclues'] as int? ?? 0;
    // Telepathy is purely cooperative, so it doesn't modify individual win sums
    return llWins + triviaWins + doodleWins;
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
            fontSize: 36,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
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
              child: Icon(Icons.star_rounded, color: cs.primary),
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
