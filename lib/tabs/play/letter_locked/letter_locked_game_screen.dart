// lib/play/letter_locked/letter_locked_game_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'letter_locked_controller.dart';
import 'letter_locked_models.dart';

class LetterLockedGameScreen extends StatefulWidget {
  final String coupleId;
  const LetterLockedGameScreen({super.key, required this.coupleId});

  @override
  State<LetterLockedGameScreen> createState() => _LetterLockedGameScreenState();
}

class _LetterLockedGameScreenState extends State<LetterLockedGameScreen> {
  final LetterLockedController _controller = LetterLockedController();
  final TextEditingController _wordInputController = TextEditingController();
  String _myUid = '';

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  void dispose() {
    _wordInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _controller.listenToGame(widget.coupleId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: cs.surface,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final game = LetterLockedModel.fromFirestore(
          snapshot.data!.data()!,
          snapshot.data!.id,
        );
        final bool isMyTurn = game.turn == _myUid;

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            title: Text(
              game.gameMode == 'coop'
                  ? 'LetterLocked: Co-op Vault'
                  : 'LetterLocked: Word Trap',
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Turn Indicator Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: isMyTurn
                      ? cs.primaryContainer
                      : cs.surfaceContainerLow,
                  child: Center(
                    child: Text(
                      isMyTurn ? "Your Turn! ⚡" : "Waiting for partner... ⏳",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMyTurn
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Main Dynamic Layout Router
                Expanded(
                  child: game.gameMode == 'coop'
                      ? _buildCoopLayout(game, cs)
                      : _buildVersusLayout(game, cs),
                ),

                // Input Actions Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _wordInputController,
                          enabled: isMyTurn,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: isMyTurn
                                ? 'Type submission word...'
                                : 'Locked until turn changes',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: isMyTurn
                              ? () => _handleMoveSubmission(game)
                              : null,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Icon(Icons.send_rounded),
                        ),
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

  // ── Co-op Mode UI Builder (3x3 Safe Dial) ──────────────────────────────────
  Widget _buildCoopLayout(LetterLockedModel game, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'LAST SUBMITTED: ${game.currentWord.isEmpty ? "NONE" : game.currentWord}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: game.boardLetters.length,
            itemBuilder: (context, i) {
              final letter = game.boardLetters[i];
              final bool isUsed = game.usedLetters.contains(letter);
              return Container(
                decoration: BoxDecoration(
                  color: isUsed ? cs.primaryContainer : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUsed ? cs.primary : cs.outlineVariant,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 28,
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

  // ── Versus Mode UI Builder (Padlocked Word Chain Row) ──────────────────────
  Widget _buildVersusLayout(LetterLockedModel game, ColorScheme cs) {
    final letters = game.currentWord.split('');
    return Center(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: List.generate(letters.length, (index) {
          final bool isLocked = game.lockedIndices.contains(index);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 72,
                decoration: BoxDecoration(
                  color: isLocked ? cs.surfaceContainerHighest : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isLocked ? cs.outline : cs.primary,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    letters[index],
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? cs.onSurfaceVariant : cs.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 18,
                color: isLocked ? cs.error : cs.outline,
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Game Logic Processor ───────────────────────────────────────────────────
  void _handleMoveSubmission(LetterLockedModel game) async {
    final String input = _wordInputController.text.trim().toUpperCase();
    if (input.isEmpty) return;

    final pUids = game.scores.keys.toList();
    final String partnerUid = pUids.firstWhere(
      (uid) => uid != _myUid,
      orElse: () => '',
    );

    if (game.gameMode == 'coop') {
      // Co-op Logic Check: Must match the last character of the previous input word
      if (game.currentWord.isNotEmpty &&
          !input.startsWith(game.currentWord.characters.last)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Word must start with letter: ${game.currentWord.characters.last}',
            ),
          ),
        );
        return;
      }

      // Track newly illuminated characters
      List<String> newUsedLetters = List<String>.from(game.usedLetters);
      for (var char in input.split('')) {
        if (game.boardLetters.contains(char) &&
            !newUsedLetters.contains(char)) {
          newUsedLetters.add(char);
        }
      }

      await _controller.submitMove(
        coupleId: widget.coupleId,
        partnerUid: partnerUid,
        newWord: input,
        updatedLockedIndices: [],
        updatedUsedLetters: newUsedLetters,
      );
    } else {
      // Versus Logic Check: Must be exactly equal in length
      if (input.length != game.currentWord.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Word must keep the exact same character length'),
          ),
        );
        return;
      }

      // Extract variations
      List<int> changedIndices = [];
      for (int i = 0; i < input.length; i++) {
        if (input[i] != game.currentWord[i]) {
          changedIndices.add(i);
        }
      }

      if (changedIndices.length != 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must change EXACTLY one letter!')),
        );
        return;
      }

      if (game.lockedIndices.contains(changedIndices.first)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That letter position is locked by your partner!'),
          ),
        );
        return;
      }

      await _controller.submitMove(
        coupleId: widget.coupleId,
        partnerUid: partnerUid,
        newWord: input,
        updatedLockedIndices:
            changedIndices, // This slot is now locked for the partner
        updatedUsedLetters: [],
      );
    }

    _wordInputController.clear();
  }
}
