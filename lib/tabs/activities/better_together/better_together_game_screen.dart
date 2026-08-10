// lib/features/better_together/better_together_game_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/better_together_models.dart';
import 'better_together_controller.dart';

class BetterTogetherGameScreen extends StatefulWidget {
  final String myUid;
  final String partnerUid;

  const BetterTogetherGameScreen({
    super.key,
    required this.myUid,
    required this.partnerUid,
  });

  @override
  State<BetterTogetherGameScreen> createState() =>
      _BetterTogetherGameScreenState();
}

class _BetterTogetherGameScreenState extends State<BetterTogetherGameScreen> {
  final BetterTogetherController _controller = BetterTogetherController();
  bool _endDialogShown = false;

  void _showPairReferenceSheet(
    BuildContext context,
    BetterTogetherGame game,
    ColorScheme cs,
  ) {
    final deck = PairDeck.values.firstWhere(
      (d) => d.name == game.deckName,
      orElse: () => PairDeck.food,
    );

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
                'Matching Guide: ${deck.label}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                game.isClassicMode
                    ? 'In Classic Mode, match identical cards.'
                    : 'Find the two complementary items that belong together:',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.8,
                  ),
                  itemCount: deck.pairs.length,
                  itemBuilder: (context, index) {
                    final pair = deck.pairs[index];
                    final String item1 = pair[0];
                    final String item2 = game.isClassicMode ? pair[0] : pair[1];

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cs.outlineVariant.withOpacity(0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item1, style: const TextStyle(fontSize: 22)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.link_rounded,
                              size: 16,
                              color: cs.primary.withOpacity(0.7),
                            ),
                          ),
                          Text(item2, style: const TextStyle(fontSize: 22)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVictoryDialog(BetterTogetherGame game, ColorScheme cs) {
    if (_endDialogShown) return;
    _endDialogShown = true;

    final myScore = game.scores[widget.myUid] ?? 0;
    final partnerScore = game.scores[widget.partnerUid] ?? 0;
    final bool isTie = myScore == partnerScore;
    final bool iWon = myScore > partnerScore;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isTie
                    ? Icons.handshake_rounded
                    : (iWon
                          ? Icons.emoji_events_rounded
                          : Icons.favorite_rounded),
                size: 54,
                color: cs.primary,
              ),
              const SizedBox(height: 16),
              Text(
                isTie ? "PERFECT TIE!" : (iWon ? "YOU WIN!" : "PARTNER WINS!"),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Final Score: $myScore - $partnerScore',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Return to Dashboard',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _controller.listenToGame(widget.myUid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: cs.surface,
            body: Center(child: CircularProgressIndicator(color: cs.primary)),
          );
        }

        final game = BetterTogetherGame.fromFirestore(
          snapshot.data!.data()!,
          snapshot.data!.id,
        );
        final bool isMyTurn = game.turn == widget.myUid;

        final deck = PairDeck.values.firstWhere(
          (d) => d.name == game.deckName,
          orElse: () => PairDeck.food,
        );

        final String titleModeText = game.isClassicMode
            ? 'Classic (${deck.label})'
            : 'Perfect Pair (${deck.label})';

        if (game.status == 'completed') {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _showVictoryDialog(game, cs),
          );
        }

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            backgroundColor: cs.surface,
            elevation: 0,
            centerTitle: true,
            title: Text(
              titleModeText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: () => _showPairReferenceSheet(context, game, cs),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 12.0,
              ),
              child: Column(
                children: [
                  // 🌟 Updated Score Card Widget with Primary Color Border & No Dots
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: cs.primary, // 🌟 Primary color border
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "YOU",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Text(
                                    "${game.scores[widget.myUid] ?? 0}",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: cs.primary.withOpacity(0.3),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "PARTNER",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: cs.tertiary,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Text(
                                    "${game.scores[widget.partnerUid] ?? 0}",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: cs.tertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Centered Turn Badge & Grid Board Area
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Turn Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isMyTurn
                                    ? cs.primaryContainer.withOpacity(0.6)
                                    : cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isMyTurn
                                      ? cs.primary.withOpacity(0.3)
                                      : cs.outlineVariant,
                                ),
                              ),
                              child: Text(
                                isMyTurn
                                    ? "YOUR TURN"
                                    : "WAITING FOR PARTNER...",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isMyTurn
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 3x4 Grid Board
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.85,
                                  ),
                              itemCount: game.board.length,
                              itemBuilder: (context, index) {
                                final card = game.board[index];
                                final bool isFlipped = game.flippedIndices
                                    .contains(index);
                                final String? matchedBy =
                                    game.matchedPairsBy[card.pairId.toString()];
                                final bool isMatched = matchedBy != null;

                                return FlipCardTile(
                                  card: card,
                                  isFlipped: isFlipped || isMatched,
                                  isMatched: isMatched,
                                  matchedByUid: matchedBy,
                                  myUid: widget.myUid,
                                  onTap: isMyTurn && !isFlipped && !isMatched
                                      ? () => _controller.selectCard(
                                          myUid: widget.myUid,
                                          partnerUid: widget.partnerUid,
                                          game: game,
                                          index: index,
                                        )
                                      : null,
                                  cs: cs,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FlipCardTile extends StatelessWidget {
  final CardTile card;
  final bool isFlipped;
  final bool isMatched;
  final String? matchedByUid;
  final String myUid;
  final VoidCallback? onTap;
  final ColorScheme cs;

  const FlipCardTile({
    super.key,
    required this.card,
    required this.isFlipped,
    required this.isMatched,
    required this.matchedByUid,
    required this.myUid,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMyMatch = matchedByUid == myUid;

    Color cardColor;
    Color borderColor;

    if (isMatched) {
      if (isMyMatch) {
        cardColor = cs.primaryContainer.withOpacity(0.5);
        borderColor = cs.primary;
      } else {
        cardColor = cs.tertiaryContainer.withOpacity(0.5);
        borderColor = cs.tertiary;
      }
    } else if (isFlipped) {
      cardColor = cs.surfaceContainerLowest;
      borderColor = cs.primary.withOpacity(0.5);
    } else {
      cardColor = cs.surfaceContainerLow;
      borderColor = cs.outlineVariant;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isMatched ? 2.0 : 1.5),
          boxShadow: [
            BoxShadow(
              color: (isMatched ? borderColor : cs.primary).withOpacity(
                isFlipped ? 0.15 : 0.04,
              ),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isFlipped
              ? Text(card.content, style: const TextStyle(fontSize: 34))
              : Text(
                  "?",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: cs.primary.withOpacity(0.7),
                  ),
                ),
        ),
      ),
    );
  }
}
