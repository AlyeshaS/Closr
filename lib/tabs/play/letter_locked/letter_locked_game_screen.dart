// lib/play/letter_locked/letter_locked_game_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/dictionary_service.dart';
import 'letter_locked_controller.dart';
import 'letter_locked_models.dart';

class LetterLockedGameScreen extends StatefulWidget {
  final String roomId;
  const LetterLockedGameScreen({super.key, required this.roomId});

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

  /// ✨ GAME THEORY BOT: Simulates all possible letter modifications to
  /// check if there are zero legal moves left for the current player.
  bool _isUserTrulyTrapped(LetterLockedModel game) {
    if (game.gameMode != 'versus' || game.currentWord.length != 4) return false;

    final currentChars = game.currentWord.split('');
    final validWords = DictionaryService.getValidFourLetterWords();
    final alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');

    // Loop through every letter index slot (0 to 3)
    for (int i = 0; i < 4; i++) {
      // Skip this slot if your partner locked it out!
      if (game.lockedIndices.contains(i)) continue;

      // Try substituting every alphabet letter into the unlocked slot
      for (String letter in alphabet) {
        if (letter == currentChars[i]) continue; // Must change the letter

        List<String> testChars = List.from(currentChars);
        testChars[i] = letter;
        String simulatedWord = testChars.join('');

        // If the simulated word is a real word AND hasn't been used yet, you are NOT trapped!
        if (validWords.contains(simulatedWord) &&
            !game.wordsUsed.contains(simulatedWord)) {
          return false;
        }
      }
    }

    // Checked every option and found nothing? You are genuinely trapped.
    return true;
  }

  void _showRulesOverlay(BuildContext context, String mode, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              mode == 'coop'
                  ? 'How to Play: Co-op Vault'
                  : 'How to Play: Word Trap',
              style: Theme.of(
                ctx,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Divider(color: cs.outlineVariant, height: 1),
            const SizedBox(height: 16),
            if (mode == 'coop') ...[
              _buildRuleRow(
                cs,
                '1',
                'Work together to consume letters displayed on your 3x3 grid.',
              ),
              _buildRuleRow(
                cs,
                '2',
                'Words must start with the last letter of the previous word.',
              ),
              _buildRuleRow(
                cs,
                '3',
                'Illuminate all 9 letters to crack the vault and win!',
              ),
            ] else ...[
              _buildRuleRow(
                cs,
                '1',
                'Mutate exactly one letter per turn to create a new 4-letter word.',
              ),
              _buildRuleRow(
                cs,
                '2',
                'The position you change locks out for your partner\'s turn.',
              ),
              _buildRuleRow(
                cs,
                '3',
                'No repeat words are allowed during the entire match!',
              ),
              _buildRuleRow(
                cs,
                '4',
                'Every submission must be a valid English word from the game dictionary.',
              ),
              _buildRuleRow(
                cs,
                '5',
                'The "I\'m Trapped" button will automatically appear if you run out of legal moves.',
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleRow(ColorScheme cs, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: cs.primaryContainer,
            child: Text(
              number,
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _controller.listenToGame(widget.roomId),
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
        final bool showTrappedButton = isMyTurn && _isUserTrulyTrapped(game);

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            backgroundColor: cs.surface,
            elevation: 0,
            title: Text(
              game.gameMode == 'coop' ? 'Co-op Vault' : 'Word Trap',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, size: 22),
                onPressed: () => _showRulesOverlay(context, game.gameMode, cs),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // ── Intelligent Turn Banner ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isMyTurn
                        ? cs.primaryContainer.withOpacity(0.4)
                        : cs.surfaceContainerLow,
                    border: Border(
                      bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            isMyTurn
                                ? "Your Turn! ⚡"
                                : "Waiting for partner... ⏳",
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isMyTurn
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                      // ✨ SMART CHECK: Only displays if showTrappedButton resolves to TRUE
                      if (showTrappedButton)
                        TextButton(
                          onPressed: () async {
                            final pUids = game.scores.keys.toList();
                            final String partnerUid = pUids.firstWhere(
                              (uid) => uid != _myUid,
                              orElse: () => '',
                            );
                            if (partnerUid.isNotEmpty) {
                              await FirebaseFirestore.instance
                                  .collection('games')
                                  .doc(widget.roomId)
                                  .update({
                                    'status': 'completed',
                                    'gameData.scores.$partnerUid':
                                        FieldValue.increment(1),
                                  });
                              if (mounted) Navigator.pop(context);
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            'I\'m Trapped 🪤',
                            style: TextStyle(
                              color: cs.error,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Main Board Canvas ──
                Expanded(
                  flex: 3,
                  child: game.gameMode == 'coop'
                      ? _buildCoopLayout(game, cs)
                      : _buildVersusLayout(game, cs),
                ),

                // ── Used Words Ledger ──
                if (game.wordsUsed.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'WORDS USED (${game.wordsUsed.length})',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 40,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: game.wordsUsed.length,
                      itemBuilder: (context, idx) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: RawChip(
                            label: Text(game.wordsUsed[idx]),
                            backgroundColor: cs.surfaceContainerHighest
                                .withOpacity(0.5),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: cs.outlineVariant),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // ── Submission Row ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _wordInputController,
                          enabled: isMyTurn,
                          textCapitalization: TextCapitalization.characters,
                          style: Theme.of(context).textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: isMyTurn
                                ? 'Type submission word...'
                                : 'Locked until turn changes',
                            filled: true,
                            fillColor: cs.surfaceContainerLow,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: cs.outlineVariant),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: cs.outlineVariant),
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
                          onPressed: isMyTurn
                              ? () => _handleMoveSubmission(game)
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'LAST SUBMITTED',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(letterSpacing: 1.0),
          ),
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
    final letters = game.currentWord.split('');
    return Center(
      child: Wrap(
        spacing: 10,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: List.generate(letters.length, (index) {
          final bool isLocked = game.lockedIndices.contains(index);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 64,
                decoration: BoxDecoration(
                  color: isLocked
                      ? cs.surfaceContainerHighest.withOpacity(0.5)
                      : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLocked ? cs.outline : cs.primary.withOpacity(0.5),
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
              const SizedBox(height: 6),
              Icon(
                isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 16,
                color: isLocked ? cs.error : cs.outline.withOpacity(0.5),
              ),
            ],
          );
        }),
      ),
    );
  }

  void _handleMoveSubmission(LetterLockedModel game) async {
    final String input = _wordInputController.text.trim().toUpperCase();
    if (input.isEmpty) return;

    if (!DictionaryService.isValidWord(input, game.gameMode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            game.gameMode == 'versus'
                ? '"$input" is not in the game dictionary. Try a real 4-letter word!'
                : '"$input" contains invalid characters or format!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (game.wordsUsed.contains(input)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$input" has already been used this game! Choose a unique word.',
          ),
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
          !input.startsWith(game.currentWord.characters.last)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Word must start with: ${game.currentWord.characters.last}',
            ),
          ),
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

      if (newUsedLetters.length >= game.boardLetters.length) {
        final batch = FirebaseFirestore.instance.batch();
        final roomRef = FirebaseFirestore.instance
            .collection('games')
            .doc(widget.roomId);
        batch.update(roomRef, {
          'status': 'completed',
          'gameData.scores.$_myUid': FieldValue.increment(1),
          'gameData.scores.$partnerUid': FieldValue.increment(1),
        });
        await batch.commit();
        if (mounted) Navigator.pop(context);
        return;
      }

      await _controller.submitMove(
        roomId: widget.roomId,
        partnerUid: partnerUid,
        newWord: input,
        updatedLockedIndices: [],
        updatedUsedLetters: newUsedLetters,
      );
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
        roomId: widget.roomId,
        partnerUid: partnerUid,
        newWord: input,
        updatedLockedIndices: changedIndices,
        updatedUsedLetters: [],
      );
    }

    _wordInputController.clear();
  }
}
