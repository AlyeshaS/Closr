// lib/play/games_dashboard_tab.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'trivia/trivia_game_screen.dart';
import 'letter_locked/letter_locked_dashboard.dart';

class GamesDashboardTab extends StatefulWidget {
  const GamesDashboardTab({super.key});

  @override
  State<GamesDashboardTab> createState() => _GamesDashboardTabState();
}

class _GamesDashboardTabState extends State<GamesDashboardTab> {
  String _myUid = '';
  String _roomId = '';
  String _partnerUid = '';
  bool _isLoading = true;

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

        // 1. Fetch your own user document to read the partner email string link
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_myUid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          String partnerEmail =
              data['partnerEmailLower'] ?? data['partnerEmail'] ?? '';
          partnerEmail = partnerEmail.trim().toLowerCase();

          if (partnerEmail.isNotEmpty) {
            // 2. Search your users collection to resolve your partner's active account UID
            final partnerQuery = await FirebaseFirestore.instance
                .collection('users')
                .where('emailLower', isEqualTo: partnerEmail)
                .get();

            if (partnerQuery.docs.isNotEmpty) {
              _partnerUid = partnerQuery.docs.first.id;

              // 3. Assemble a consistent room string tag by sorting UIDs alphabetically
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _roomId.isEmpty
          ? const Stream.empty()
          : FirebaseFirestore.instance
                .collection('games')
                .doc(_roomId)
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
              // ── Adaptive Premium Split Scoreboard Panel ─────────────────────
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
                      '$myScore',
                      'Your Wins',
                      cs.primary,
                    ),
                    Container(width: 1, height: 40, color: cs.outlineVariant),
                    _buildScoreColumn(
                      context,
                      '$partnerScore',
                      "Partner's Wins",
                      cs.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('GAMES', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 12),

              // 1. LetterLocked Clean Custom Card
              // 1. LetterLocked Clean Custom Card
_buildCleanGameCard(
  context: context,
  title: 'LetterLocked',
  subtitle: 'Co-op Vault or Versus Word Trap. Build words, flip turns, and lock combinations.',
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            title: const Text('LetterLocked'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: const LetterLockedDashboard(), // ✨ FIXED: Removed "coupleId: _coupleId" from here!
        ),
      ),
    );
  },
  cs: cs,
),
              const SizedBox(height: 10),

              // 2. Our Trivia Clean Custom Card
              _buildCleanGameCard(
                context: context,
                title: 'Our Trivia',
                subtitle:
                    'Test your compatibility! Sync matching responses and see who remembers best.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TriviaGameScreen()),
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
