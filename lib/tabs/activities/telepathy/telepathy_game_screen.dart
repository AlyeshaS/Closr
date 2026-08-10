// lib/features/telepathy/presentation/telepathy_game_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/telepathy_game_model.dart';
import '../../../services/telepathy_service.dart';
import '../../../services/word_generator_service.dart';
import 'emoji_pool.dart';

class TelepathyGameScreen extends StatefulWidget {
  final String myUid;
  final String partnerUid;

  const TelepathyGameScreen({
    Key? key,
    required this.myUid,
    required this.partnerUid,
  }) : super(key: key);

  @override
  State<TelepathyGameScreen> createState() => _TelepathyGameScreenState();
}

class _TelepathyGameScreenState extends State<TelepathyGameScreen> {
  final TelepathyFirebaseService _service = TelepathyFirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _awardedGameId;

  Future<void> _rewardTelepathyMeld(String gameId) async {
    if (_awardedGameId == gameId) return;
    _awardedGameId = gameId;

    WriteBatch scoreBatch = _firestore.batch();

    final myScoreRef = _firestore
        .collection('users')
        .doc(widget.myUid)
        .collection('scores')
        .doc('telepathy');
    final partnerScoreRef = _firestore
        .collection('users')
        .doc(widget.partnerUid)
        .collection('scores')
        .doc('telepathy');

    scoreBatch.set(myScoreRef, {
      'wins': FieldValue.increment(1),
    }, SetOptions(merge: true));
    scoreBatch.set(partnerScoreRef, {
      'wins': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await scoreBatch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Telepathy',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _service.streamGame(widget.myUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: cs.primary));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Session data not found.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            );
          }

          final game = TelepathyGame.fromDocument(snapshot.data!);

          if (game.seedWord == 'PENDING_CHOICE') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop();
            });
            return Center(child: CircularProgressIndicator(color: cs.primary));
          }

          if (game.status == 'completed') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _rewardTelepathyMeld(game.gameId);
            });
            return _buildVictoryScreen(game, cs);
          }

          return TelepathyGameBody(
            key: ValueKey('telepathy_body_${game.gameId}'),
            game: game,
            myUid: widget.myUid,
            service: _service,
          );
        },
      ),
    );
  }

  Widget _buildVictoryScreen(TelepathyGame game, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.psychology_alt_rounded,
                size: 48,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'MIND MELD\nACHIEVED!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: cs.primary,
                letterSpacing: 1.2,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _service.startNewGame(
                  gameId: game.gameId,
                  myUid: game.hostId,
                  partnerUid: game.partnerId,
                  mode: game.gameMode,
                  seedWord: 'PENDING_CHOICE',
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text(
                  'PLAY AGAIN',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CONNECTION HISTORY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: game.rounds.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final rd = game.rounds[index];

                  if (game.gameMode == GameMode.customPrompt && index == 0) {
                    return _buildHistoryCard(
                      cs: cs,
                      indexText: 'SETUP',
                      prompt: 'Baseline Setup',
                      answers:
                          '${rd.player1Input ?? "?"} & ${rd.player2Input ?? "?"}',
                      isMatch: false,
                      isSetup: true,
                    );
                  }

                  return _buildHistoryCard(
                    cs: cs,
                    indexText:
                        '${index + (game.gameMode == GameMode.customPrompt ? 0 : 1)}',
                    prompt: rd.prompt,
                    answers:
                        '${rd.player1Input ?? "?"}   |   ${rd.player2Input ?? "?"}',
                    isMatch: rd.isMatch,
                    isSetup: false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard({
    required ColorScheme cs,
    required String indexText,
    required String prompt,
    required String answers,
    required bool isMatch,
    required bool isSetup,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMatch
            ? cs.primaryContainer.withOpacity(0.4)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMatch
              ? cs.primary.withOpacity(0.5)
              : cs.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isSetup
                  ? cs.secondaryContainer
                  : cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isSetup
                  ? Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: cs.onSecondaryContainer,
                    )
                  : Text(
                      indexText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prompt,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  answers,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: isMatch ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (!isSetup)
            Icon(
              isMatch ? Icons.check_circle_rounded : Icons.close_rounded,
              color: isMatch ? cs.primary : cs.error.withOpacity(0.7),
              size: 20,
            ),
        ],
      ),
    );
  }
}

class TelepathyGameBody extends StatefulWidget {
  final TelepathyGame game;
  final String myUid;
  final TelepathyFirebaseService service;

  const TelepathyGameBody({
    Key? key,
    required this.game,
    required this.myUid,
    required this.service,
  }) : super(key: key);

  @override
  State<TelepathyGameBody> createState() => _TelepathyGameBodyState();
}

class _TelepathyGameBodyState extends State<TelepathyGameBody>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isChangingWord = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.88, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final currentRound = widget.game.rounds[widget.game.currentRoundIndex];
    final bool isHost = widget.myUid == widget.game.hostId;
    final String? myInput = isHost
        ? currentRound.player1Input
        : currentRound.player2Input;
    final bool hasIAnswered = myInput != null;
    final bool isCustomSetup =
        widget.game.gameMode == GameMode.customPrompt &&
        widget.game.currentRoundIndex == 0;
    final bool isEmojiMode = widget.game.gameMode == GameMode.emojisOnly;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const Spacer(),

            // Centered Content Stack
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cs.primary.withOpacity(0.2)),
                  ),
                  child: Text(
                    isCustomSetup
                        ? 'SETUP ROUND'
                        : 'ROUND ${widget.game.currentRoundIndex}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Card Box with Enhanced Glow
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: cs.primary.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      // 🌟 Fix 1: Boosted glow effect
                      BoxShadow(
                        color: cs.primary.withOpacity(0.20),
                        blurRadius: 32,
                        spreadRadius: 4,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCustomSetup
                            ? 'Think of any starting word'
                            : 'Find a connection word for',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isCustomSetup)
                        // 🌟 Fix 2: Clean text-based question marks without circles
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "?",
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: cs.primary.withOpacity(0.7),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                "+",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary.withOpacity(0.4),
                                ),
                              ),
                            ),
                            Text(
                              "?",
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: cs.primary.withOpacity(0.7),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          currentRound.prompt,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isEmojiMode ? 60 : 32,
                            fontWeight: FontWeight.w900,
                            color: cs.primary,
                            height: 1.1,
                          ),
                        ),
                    ],
                  ),
                ),

                if (!isCustomSetup &&
                    widget.game.gameMode != GameMode.customPrompt)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _isChangingWord
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton.icon(
                            onPressed: () async {
                              setState(() => _isChangingWord = true);
                              final String newSeed = isEmojiMode
                                  ? EmojiPool.getRandomEmoji()
                                  : await WordGeneratorService.getRandomSeedWord();

                              await widget.service.changeSeedWord(
                                game: widget.game,
                                newSeed: newSeed,
                              );
                              if (mounted) {
                                setState(() => _isChangingWord = false);
                              }
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(
                              isEmojiMode ? 'Reroll Emoji' : 'Reroll Word',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: cs.onSurfaceVariant,
                            ),
                          ),
                  ),
              ],
            ),

            const Spacer(),

            AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                bottom: bottomInset > 0 ? bottomInset + 12 : 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!hasIAnswered) ...[
                    TextField(
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      textCapitalization: TextCapitalization.characters,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: isCustomSetup
                            ? 'Enter starting word...'
                            : 'Type your link word...',
                        hintStyle: TextStyle(
                          color: cs.onSurfaceVariant.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                        filled: true,
                        fillColor: cs.surfaceContainerLowest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
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
                          borderSide: BorderSide(color: cs.primary, width: 2),
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () async {
                          final String entry = _inputController.text.trim();
                          if (entry.isEmpty) return;

                          try {
                            await widget.service.submitInput(
                              currentUserId: widget.myUid,
                              input: entry,
                              game: widget.game,
                            );
                            _inputController.clear();
                          } catch (e) {
                            if (e is ArgumentError &&
                                e.message == 'EMOJI_ONLY_VIOLATION') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: cs.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  content: const Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Minds must link using Emojis Only! 🔮',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          isCustomSetup
                              ? 'LOCK IN STARTING WORD'
                              : 'LOCK IN GUESS',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: cs.outlineVariant.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withOpacity(0.25),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.hourglass_top_rounded,
                                size: 24,
                                color: cs.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isCustomSetup
                                ? 'Starting word locked!'
                                : 'Guess locked in!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isCustomSetup
                                ? 'Waiting for partner baseline word...'
                                : 'Waiting for partner bridge word...',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
