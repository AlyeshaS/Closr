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
            backgroundColor: cs.surface,
            elevation: 0,
            title: Text(
              game.gameMode == 'coop' ? 'Co-op Vault' : 'Word Trap',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Minimalist Turn Banner
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
                const SizedBox(height: 24),

                Expanded(
                  child: game.gameMode == 'coop'
                      ? _buildCoopLayout(game, cs)
                      : _buildVersusLayout(game, cs),
                ),

                // Core Input Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
          const SizedBox(height: 32),
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

      await _controller.submitMove(
        coupleId: widget.coupleId,
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
        coupleId: widget.coupleId,
        partnerUid: partnerUid,
        newWord: input,
        updatedLockedIndices: changedIndices,
        updatedUsedLetters: [],
      );
    }

    _wordInputController.clear();
  }
}
