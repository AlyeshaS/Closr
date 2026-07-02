// lib/play/letter_locked/letter_locked_game_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/dictionary_service.dart';
import 'letter_locked_controller.dart';
import 'letter_locked_models.dart';

class LetterLockedGameScreen extends StatefulWidget {
  final String myUid;
  final String partnerUid;
  final String? legacyRoomId;
  const LetterLockedGameScreen({
    super.key,
    required this.myUid,
    required this.partnerUid,
    this.legacyRoomId,
  });

  @override
  State<LetterLockedGameScreen> createState() => _LetterLockedGameScreenState();
}

class _LetterLockedGameScreenState extends State<LetterLockedGameScreen> {
  final LetterLockedController _controller = LetterLockedController();
  final TextEditingController _wordInputController = TextEditingController();
  bool _endDialogShown = false;

  @override
  void dispose() {
    _wordInputController.dispose();
    super.dispose();
  }

  String get _myUid => widget.myUid;

  DocumentReference<Map<String, dynamic>> _gameDoc(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('games')
        .doc('letterlocked');
  }

  Future<void> _updateMirroredGameDocs(Map<String, dynamic> updates) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_gameDoc(widget.myUid), updates, SetOptions(merge: true));
    batch.set(_gameDoc(widget.partnerUid), updates, SetOptions(merge: true));
    await batch.commit();
  }

  void _showHowToPlayCoop(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'How to Play: Co-op Vault 🔐',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '• Work as a team to light up all 9 letters on the grid dial.\n'
                '• You take turns submitting valid 4-letter words.\n'
                '• Every word MUST start with the last letter of the previous word.\n'
                '• Using a letter on the grid lights it up. Turn the whole board primary colored to win!\n'
                '• If either player gets stuck with no moves left, the team loses together.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHowToPlayVersus(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'How to Play: Word Trap ⚔️',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '• Change exactly ONE letter of the current word to submit a new turn.\n'
                '• The single index position you changed becomes locked for your partner.\n'
                '• You earn +1 Point for every successful word placement calculation.\n'
                '• Trap your opponent into a dead-end with no valid dictionary words to win the match!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGameEndedAlert(LetterLockedModel game, BuildContext screenContext) {
    if (_endDialogShown) return;
    _endDialogShown = true;

    final bool isCoop = game.gameMode == 'coop';
    final String calculatedWinner = game.scores.keys.firstWhere(
      (uid) => uid != game.turn,
      orElse: () => '',
    );

    final bool iWon =
        game.winnerUid == _myUid ||
        (game.winnerUid.isEmpty && calculatedWinner == _myUid);

    String title = "";
    String message = "";
    IconData icon;
    Color iconColor;

    if (isCoop) {
      if (game.winnerUid == 'TEAM_WIN') {
        title = "🎉 VAULT CRACKED!";
        icon = Icons.emoji_events_rounded;
        iconColor = Colors.amber;
        message =
            "Brilliant teamwork! You and your partner successfully illuminated the entire letter dial! +1 Point added to both scores.";
      } else {
        title = "💥 VAULT LOCKED OUT";
        icon = Icons.disabled_by_default_rounded;
        iconColor = Colors.redAccent;
        message =
            "The vault locked down because your team ran out of combinations or surrendered. Better luck next time!";
      }
    } else {
      String reason = game.lockedIndices.isNotEmpty ? 'trapped' : 'surrendered';
      if (game.wordsUsed.length <= 1) reason = 'surrendered';

      if (iWon) {
        title = "🎉 CONGRATULATIONS!";
        icon = Icons.emoji_events_rounded;
        iconColor = Colors.amber;
        message = reason == 'trapped'
            ? "Incredible tactical work! You completely trapped your partner with no moves remaining! 🧠"
            : "You won by surrender! Your partner left the match frame. 🏳️";
      } else {
        title = "💥 GAME OVER";
        icon = Icons.disabled_by_default_rounded;
        iconColor = Colors.redAccent;
        message = reason == 'trapped'
            ? "Ah, you got caught in a corner! Your partner trapped your word positions with zero moves left."
            : "You forfeited the match by backing out.";
      }
    }

    showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final cs = Theme.of(screenContext).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _updateMirroredGameDocs({'status': 'archived'});

                if (screenContext.mounted) {
                  Navigator.of(
                    screenContext,
                  ).popUntil((route) => route.isFirst);
                }
              },
              child: Text(
                'Return to Main Menu',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _controller.listenToGame(
        widget.myUid,
        legacyRoomId: widget.legacyRoomId,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: cs.surface,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data()!;
        final game = LetterLockedModel.fromFirestore(data, snapshot.data!.id);

        final finalGameModel = LetterLockedModel(
          gameId: game.gameId,
          gameType: game.gameType,
          gameMode: game.gameMode,
          status: game.status,
          turn: game.turn,
          winnerUid: game.winnerUid,
          currentWord: game.currentWord,
          lockedIndices: game.lockedIndices,
          boardLetters: game.boardLetters,
          usedLetters: game.usedLetters,
          wordsUsed: game.wordsUsed,
          scores: game.scores,
        );

        final bool isMyTurn = finalGameModel.turn == _myUid;

        if (finalGameModel.status == 'completed') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showGameEndedAlert(finalGameModel, context);
          });
        }

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            backgroundColor: cs.surface,
            elevation: 0,
            title: Text(
              finalGameModel.gameMode == 'coop' ? 'Co-op Vault' : 'Word Trap',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => _handleManualSurrender(finalGameModel),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline_rounded),
                onPressed: () {
                  if (finalGameModel.gameMode == 'coop') {
                    _showHowToPlayCoop(context);
                  } else {
                    _showHowToPlayVersus(context);
                  }
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isMyTurn
                        ? cs.primaryContainer.withOpacity(0.4)
                        : cs.surfaceContainerLow,
                    border: Border(
                      bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isMyTurn ? "Your Turn! ⚡" : "Waiting for partner... ⏳",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isMyTurn ? cs.primary : cs.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: Center(
                    child: finalGameModel.gameMode == 'coop'
                        ? _buildCoopLayout(finalGameModel, cs)
                        : _buildVersusLayout(finalGameModel, cs),
                  ),
                ),

                if (finalGameModel.wordsUsed.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'WORDS USED (${finalGameModel.wordsUsed.length})',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 38,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: finalGameModel.wordsUsed.length,
                      itemBuilder: (context, idx) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: RawChip(
                            label: Text(finalGameModel.wordsUsed[idx]),
                            backgroundColor: cs.surfaceContainerHighest
                                .withOpacity(0.4),
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(
                              color: cs.outlineVariant.withOpacity(0.5),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isMyTurn &&
                          finalGameModel.currentWord.isNotEmpty &&
                          finalGameModel.status == 'active') ...[
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final bool movesExist =
                                  DictionaryService.hasValidMovesLeft(
                                    currentWord: finalGameModel.currentWord,
                                    lockedIndices: finalGameModel.lockedIndices,
                                    wordsUsed: finalGameModel.wordsUsed,
                                    gameMode: finalGameModel.gameMode,
                                  );

                              if (movesExist) {
                                _showForfeitConfirmation(
                                  context,
                                  finalGameModel,
                                );
                              } else {
                                _handleTrappedForfeit(finalGameModel);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cs.error,
                              side: BorderSide(color: cs.error, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.flag_rounded, size: 18),
                            label: Text(
                              finalGameModel.gameMode == 'coop'
                                  ? "WE ARE TRAPPED! (GIVE UP)"
                                  : "I'M TRAPPED! (TESTING FORFEIT)",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _wordInputController,
                              enabled:
                                  isMyTurn && finalGameModel.status == 'active',
                              textCapitalization: TextCapitalization.characters,
                              style: Theme.of(context).textTheme.bodyLarge,
                              decoration: InputDecoration(
                                hintText: isMyTurn
                                    ? 'Type submission word...'
                                    : 'Locked until turn changes',
                                hintStyle: TextStyle(
                                  color: cs.onSurfaceVariant.withOpacity(0.6),
                                ),
                                filled: true,
                                fillColor: cs.surfaceContainerLow,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: cs.outlineVariant,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: cs.outlineVariant,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: cs.primary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 54,
                            width: 54,
                            child: FilledButton(
                              onPressed:
                                  isMyTurn && finalGameModel.status == 'active'
                                  ? () => _handleMoveSubmission(finalGameModel)
                                  : null,
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Icon(Icons.send_rounded, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoopLayout(LetterLockedModel game, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            'LAST SUBMITTED',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(letterSpacing: 1.0),
          ),
          const SizedBox(height: 4),
          Text(
            game.currentWord.isEmpty ? "NONE" : game.currentWord,
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: game.boardLetters.length,
            itemBuilder: (context, i) {
              final letter = game.boardLetters[i];
              final bool isUsed = game.usedLetters.contains(letter);
              return Container(
                decoration: BoxDecoration(
                  color: isUsed ? cs.primaryContainer : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUsed ? cs.primary : cs.outlineVariant,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isUsed ? cs.onPrimaryContainer : cs.onSurface,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVersusLayout(LetterLockedModel game, ColorScheme cs) {
    final String displayWord = game.currentWord.isEmpty
        ? "    "
        : game.currentWord;
    final letters = displayWord.split('');

    if (game.currentWord.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: 16),
            Text(
              "Generating word trap puzzle...",
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Wrap(
          spacing: 12,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: List.generate(letters.length, (index) {
            final bool isLocked = game.lockedIndices.contains(index);
            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 66,
                  decoration: BoxDecoration(
                    color: isLocked
                        ? cs.surfaceContainerHighest.withOpacity(0.5)
                        : cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isLocked
                          ? cs.outline
                          : cs.primary.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      letters[index],
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isLocked ? cs.onSurfaceVariant : cs.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 16,
                  color: isLocked ? cs.error : cs.outline.withOpacity(0.4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  void _showForfeitConfirmation(BuildContext context, LetterLockedModel game) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            game.gameMode == 'coop' ? 'Surrender Team Match?' : 'Are you sure?',
          ),
          content: Text(
            game.gameMode == 'coop'
                ? 'Giving up will log a game loss for both you and your partner. No score points will be added.'
                : 'Our solver detects that there are still valid words available to play! Do you want to surrender?',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _handleTrappedForfeit(game);
              },
              child: Text(
                'Surrender',
                style: TextStyle(color: cs.error, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleTrappedForfeit(LetterLockedModel game) async {
    final pUids = game.scores.keys.toList();
    final String partnerUid = pUids.firstWhere(
      (uid) => uid != _myUid,
      orElse: () => '',
    );
    if (partnerUid.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    if (game.gameMode == 'coop') {
      batch.set(_gameDoc(_myUid), {
        'status': 'completed',
        'winnerUid': 'TEAM_LOSS',
        'endReason': 'trapped',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(_gameDoc(partnerUid), {
        'status': 'completed',
        'winnerUid': 'TEAM_LOSS',
        'endReason': 'trapped',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      batch.set(_gameDoc(_myUid), {
        'status': 'completed',
        'winnerUid': partnerUid,
        'endReason': 'trapped',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(_gameDoc(partnerUid), {
        'status': 'completed',
        'winnerUid': partnerUid,
        'endReason': 'trapped',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 🏆 CENTRALIZED SCORE ROUTING: Reward partner profile on root folder
      final partnerUserDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(partnerUid);
      batch.set(partnerUserDoc, {
        'scores': {'letterlocked': FieldValue.increment(1)},
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  void _handleManualSurrender(LetterLockedModel game) async {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Quit Game?'),
          content: Text(
            game.gameMode == 'coop'
                ? 'Exiting midway fails the vault raid challenge completely. No scores will increment.'
                : 'Leaving mid-match counts as a total forfeit. Your partner will receive the win points!',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Stay', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final pUids = game.scores.keys.toList();
                final String partnerUid = pUids.firstWhere(
                  (uid) => uid != _myUid,
                  orElse: () => '',
                );

                final batch = FirebaseFirestore.instance.batch();

                if (game.gameMode == 'coop') {
                  batch.set(_gameDoc(_myUid), {
                    'status': 'completed',
                    'winnerUid': 'TEAM_LOSS',
                    'endReason': 'surrendered',
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                  batch.set(_gameDoc(partnerUid), {
                    'status': 'completed',
                    'winnerUid': 'TEAM_LOSS',
                    'endReason': 'surrendered',
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                } else {
                  if (partnerUid.isNotEmpty) {
                    batch.set(_gameDoc(_myUid), {
                      'status': 'completed',
                      'winnerUid': partnerUid,
                      'endReason': 'surrendered',
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                    batch.set(_gameDoc(partnerUid), {
                      'status': 'completed',
                      'winnerUid': partnerUid,
                      'endReason': 'surrendered',
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    // 🏆 CENTRALIZED SCORE ROUTING: Reward partner profile on root folder
                    final partnerUserDoc = FirebaseFirestore.instance
                        .collection('users')
                        .doc(partnerUid);
                    batch.set(partnerUserDoc, {
                      'scores': {'letterlocked': FieldValue.increment(1)},
                    }, SetOptions(merge: true));
                  }
                }

                await batch.commit();
              },
              child: Text(
                'Forfeit',
                style: TextStyle(color: cs.error, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleMoveSubmission(LetterLockedModel game) async {
    final String input = _wordInputController.text.trim().toUpperCase();
    if (input.isEmpty) return;

    if (game.wordsUsed.contains(input)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$input" has already been used this game!')),
      );
      return;
    }

    if (!DictionaryService.isValidWord(input, game.gameMode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$input" is not a valid word!'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final pUids = game.scores.keys.toList();
    final String partnerUid = pUids.firstWhere(
      (uid) => uid != _myUid,
      orElse: () => '',
    );

    if (game.gameMode == 'coop') {
      if (game.currentWord.isNotEmpty &&
          !input.startsWith(game.currentWord[game.currentWord.length - 1])) {
        final String lastLetter = game.currentWord[game.currentWord.length - 1];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Word must start with: $lastLetter')),
        );
        return;
      }

      List<String> newUsedLetters = List<String>.from(game.usedLetters);
      for (var char in input.split('')) {
        if (game.boardLetters.contains(char) &&
            !newUsedLetters.contains(char)) {
          newUsedLetters.add(char);
        }
      }

      final boardSet = game.boardLetters
          .map((e) => e.trim().toUpperCase())
          .toSet();
      final usedSet = newUsedLetters.map((e) => e.trim().toUpperCase()).toSet();
      bool allLettersUsed = boardSet.every(
        (letter) => usedSet.contains(letter),
      );

      if (allLettersUsed) {
        final batch = FirebaseFirestore.instance.batch();
        final Map<String, dynamic> endPayload = {
          'status': 'completed',
          'winnerUid': 'TEAM_WIN',
          'endReason': 'completed',
          'gameData.currentWord': input,
          'gameData.usedLetters': newUsedLetters,
          'gameData.wordsUsed': FieldValue.arrayUnion([input]),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        batch.set(_gameDoc(_myUid), endPayload, SetOptions(merge: true));
        batch.set(_gameDoc(partnerUid), endPayload, SetOptions(merge: true));

        // 🏆 CENTRALIZED SCORE ROUTING: Reward both user roots on Co-op Victory
        batch.set(
          FirebaseFirestore.instance.collection('users').doc(_myUid),
          {
            'scores': {'letterlocked': FieldValue.increment(1)},
          },
          SetOptions(merge: true),
        );
        batch.set(
          FirebaseFirestore.instance.collection('users').doc(partnerUid),
          {
            'scores': {'letterlocked': FieldValue.increment(1)},
          },
          SetOptions(merge: true),
        );

        await batch.commit();
      } else {
        await _controller.submitMove(
          myUid: _myUid,
          partnerUid: partnerUid,
          newWord: input,
          updatedLockedIndices: [],
          updatedUsedLetters: newUsedLetters,
          isCoopTurn: true,
        );
      }
    } else {
      if (input.length != game.currentWord.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Word length must remain exactly identical'),
          ),
        );
        return;
      }

      List<int> changedIndices = [];
      for (int i = 0; i < input.length; i++) {
        if (input[i] != game.currentWord[i]) changedIndices.add(i);
      }

      if (changedIndices.length != 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must change exactly one letter')),
        );
        return;
      }

      if (game.lockedIndices.contains(changedIndices.first)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That position is locked by your partner'),
          ),
        );
        return;
      }

      await _controller.submitMove(
        myUid: _myUid,
        partnerUid: partnerUid,
        newWord: input,
        updatedLockedIndices: changedIndices,
        updatedUsedLetters: [],
        isCoopTurn: false,
      );
    }

    _wordInputController.clear();
  }
}
