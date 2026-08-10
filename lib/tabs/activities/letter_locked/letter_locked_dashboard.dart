import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/dictionary_service.dart';
import 'letter_locked_controller.dart';
import 'letter_locked_game_screen.dart';

class LetterLockedDashboard extends StatefulWidget {
  final String myUid;
  final String partnerUid;

  const LetterLockedDashboard({
    super.key,
    required this.myUid,
    required this.partnerUid,
  });

  @override
  State<LetterLockedDashboard> createState() => _LetterLockedDashboardState();
}

class _LetterLockedDashboardState extends State<LetterLockedDashboard> {
  final LetterLockedController _controller = LetterLockedController();
  String _myUid = '';
  String _partnerUid = '';
  String _partnerEmail = '';
  String _legacyRoomId = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    DictionaryService.initialize();
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
              _legacyRoomId = 'letterlocked_${uids[0]}_${uids[1]}';

              await _controller.migrateLegacyRoomIfNeeded(
                myUid: _myUid,
                partnerUid: _partnerUid,
                legacyRoomId: _legacyRoomId,
              );
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
    if (_partnerUid.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final gameDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_myUid)
          .collection('games')
          .doc('letterlocked')
          .get();

      if (!mounted) return;

      final isGameActive =
          gameDoc.exists && gameDoc.data()?['status'] == 'active';
      final currentMode = gameDoc.data()?['gameMode'];

      // If an active game exists in the selected mode, resume it directly
      if (isGameActive && currentMode == mode) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LetterLockedGameScreen(
              myUid: _myUid,
              partnerUid: _partnerUid,
              legacyRoomId: _legacyRoomId,
            ),
          ),
        );
      } else {
        // Start new game if no game active or mode changed
        Map<String, int> existingScores = {_myUid: 0, _partnerUid: 0};
        if (gameDoc.exists && gameDoc.data()?['gameData']?['scores'] != null) {
          final oldScores =
              gameDoc.data()?['gameData']['scores'] as Map<String, dynamic>;
          existingScores[_myUid] = oldScores[_myUid] ?? 0;
          existingScores[_partnerUid] = oldScores[_partnerUid] ?? 0;
        }

        await _controller.startNewGame(
          myUid: _myUid,
          partnerUid: _partnerUid,
          mode: mode,
          existingScores: existingScores,
        );

        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LetterLockedGameScreen(
                myUid: _myUid,
                partnerUid: _partnerUid,
                legacyRoomId: _legacyRoomId,
              ),
            ),
          );
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
      return Scaffold(
        backgroundColor: cs.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_partnerUid.isEmpty) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Center(
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
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_myUid)
              .collection('games')
              .doc('letterlocked')
              .snapshots(),
          builder: (context, snapshot) {
            final gameData = snapshot.data?.data();
            final bool hasActiveGame = gameData?['status'] == 'active';
            final String activeMode = gameData?['gameMode'] ?? '';

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 15,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Return to game options',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (hasActiveGame) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cs.primary.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.play_circle_fill_rounded,
                            color: cs.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Game In Progress',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface,
                                  ),
                                ),
                                Text(
                                  activeMode == 'coop'
                                      ? 'Co-op Vault match active'
                                      : 'Versus Word Trap match active',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LetterLockedGameScreen(
                                    myUid: _myUid,
                                    partnerUid: _partnerUid,
                                    legacyRoomId: _legacyRoomId,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Resume'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  Text(
                    'CHOOSE YOUR MODE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCleanModeCard(
                    context: context,
                    title: 'Co-op Vault Mode',
                    subtitle:
                        'Work together using a shared letter dial to unlock the safe vault. Cozy and collaborative.',
                    icon: Icons.lock_reset_rounded,
                    onTap: () => _handleGameRouting('coop'),
                    cs: cs,
                  ),
                  const SizedBox(height: 14),
                  _buildCleanModeCard(
                    context: context,
                    title: 'Versus Word Trap',
                    subtitle:
                        'Change exactly one letter to morph the word. Trap your partner by locking their choices out.',
                    icon: Icons.published_with_changes_rounded,
                    onTap: () => _handleGameRouting('versus'),
                    cs: cs,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCleanModeCard({
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
