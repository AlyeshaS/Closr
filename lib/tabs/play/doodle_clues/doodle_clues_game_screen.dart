// lib/screens/activities/doodle_clues/doodle_clues_game_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doodle_clues_controller.dart';

class DoodleCluesGameScreen extends StatefulWidget {
  const DoodleCluesGameScreen({super.key});

  @override
  State<DoodleCluesGameScreen> createState() => _DoodleCluesGameScreenState();
}

class _DoodleCluesGameScreenState extends State<DoodleCluesGameScreen> {
  final DoodleCluesController _controller = DoodleCluesController();
  final TextEditingController _guessInputController = TextEditingController();

  // Explicitly isolate the drawing canvas coordinate space
  final GlobalKey _canvasKey = GlobalKey();

  String _myUid = '';
  String _partnerUid = '';
  bool _initializingAuth = true;
  bool _endDialogShown = false;

  // Local point cache for smooth drawing at 60fps
  List<Offset?> _localArtistPoints = [];

  final List<String> _poolOfSecretWords = [
    'SUNSET',
    'AIRPLANE',
    'CAMPFIRE',
    'COFFEE',
    'PIZZA',
    'KEYBOARD',
    'EIFFEL TOWER',
    'BICYCLE',
    'SNOWMAN',
    'CAT',
  ];

  @override
  void initState() {
    super.initState();
    _resolveSessionByEmail();
  }

  @override
  void dispose() {
    _guessInputController.dispose();
    super.dispose();
  }

  void _resolveSessionByEmail() async {
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
          String partnerEmail =
              data['partnerEmailLower'] ?? data['partnerEmail'] ?? '';
          partnerEmail = partnerEmail.trim().toLowerCase();

          if (partnerEmail.isNotEmpty) {
            final partnerQuery = await FirebaseFirestore.instance
                .collection('users')
                .where('emailLower', isEqualTo: partnerEmail)
                .get();

            if (partnerQuery.docs.isNotEmpty) {
              setState(() {
                _partnerUid = partnerQuery.docs.first.id;
              });
            }
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _initializingAuth = false);
    }
  }

  void _handleLeaveOrCancel() async {
    if (_myUid.isNotEmpty) {
      await _controller.triggerForcedCancellation(_myUid, _partnerUid);
    }
    if (mounted) Navigator.pop(context);
  }

  void _showHowToPlay(BuildContext context) {
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
                'How to Play: DoodleClues 🎨',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '• One player claims the Artist role and sketches the secret word.\n'
                '• The drawing is kept hidden until you click "Publish Outline"!\n'
                '• Once revealed, the guesser has exactly 3 guess tokens to type the matching word.\n'
                '• Backing out mid-session safely resets the room back to setup mode.',
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

  void _showGameEndedAlert(bool isWin, BuildContext screenContext) {
    if (_endDialogShown) return;
    _endDialogShown = true;

    final cs = Theme.of(screenContext).colorScheme;
    final Color statusColor = isWin ? cs.primary : cs.error;
    final Color buttonForegroundColor = isWin ? cs.onPrimary : cs.onError;

    showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isWin ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: statusColor,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isWin ? "ROUND WON!" : "ROUND FAILED",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'CormorantGaramond',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isWin
                      ? "Fantastic connection! The word was solved successfully."
                      : "No guess tokens remaining or time ran dry! Better luck next setup loop!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await _controller.purgeMatch(_myUid, _partnerUid);
                      if (screenContext.mounted) Navigator.pop(screenContext);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: statusColor,
                      foregroundColor: buttonForegroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Return to Dashboard',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_initializingAuth || _myUid.isEmpty) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _controller.listenToMyGame(_myUid),
      builder: (context, mySnapshot) {
        String baseArtistUid = '';
        if (mySnapshot.hasData && mySnapshot.data!.exists) {
          baseArtistUid = mySnapshot.data!.data()?['artistUid'] ?? '';
        }

        final String effectiveArtistUid = baseArtistUid.isNotEmpty
            ? baseArtistUid
            : _myUid;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _controller.listenToLiveGame(effectiveArtistUid),
          builder: (context, snapshot) {
            String stage = 'setup';
            String secretWord = '';
            String artistUid = '';
            bool isWin = false;
            int attemptsLeft = 3;

            if (snapshot.hasData &&
                snapshot.data!.exists &&
                snapshot.data!.data() != null) {
              final data = snapshot.data!.data()!;
              stage = data['stage'] ?? 'setup';
              secretWord = data['secretWord'] ?? '';
              artistUid = data['artistUid'] ?? '';
              isWin = data['isWin'] ?? false;
              attemptsLeft = data['attemptsLeft'] ?? 3;

              if (data['status'] == 'cancelled') {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Session cancelled because a player backed out.',
                      ),
                    ),
                  );
                  Navigator.pop(context);
                  await _controller.purgeMatch(_myUid, _partnerUid);
                });
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
            }

            final bool iAmArtist = artistUid == _myUid;

            if (stage == 'results') {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _showGameEndedAlert(isWin, context),
              );
            }

            if (stage == 'setup' && _localArtistPoints.isNotEmpty) {
              _localArtistPoints = [];
            }

            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                _handleLeaveOrCancel();
              },
              child: Scaffold(
                backgroundColor: cs.surface,
                resizeToAvoidBottomInset: false,
                appBar: AppBar(
                  backgroundColor: cs.surface,
                  elevation: 0,
                  title: const Text(
                    'DoodleClues 🎨',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  centerTitle: true,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                    ),
                    onPressed: _handleLeaveOrCancel,
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.help_outline_rounded),
                      onPressed: () => _showHowToPlay(context),
                    ),
                  ],
                ),
                body: SafeArea(
                  child: _buildStageLayout(
                    stage,
                    secretWord,
                    artistUid,
                    iAmArtist,
                    snapshot,
                    attemptsLeft,
                    cs,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStageLayout(
    String stage,
    String secretWord,
    String artistUid,
    bool iAmArtist,
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
    int attemptsLeft,
    ColorScheme cs,
  ) {
    if (stage == 'setup') {
      final bool hasActiveDrawer = artistUid.isNotEmpty && artistUid != _myUid;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ready to Sketch?',
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                hasActiveDrawer
                    ? 'Your partner has claimed the canvas! Prepare to make a guess...'
                    : 'Claim the canvas as the artist! Your partner will receive your sketch once you reveal it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: hasActiveDrawer
                      ? null
                      : () {
                          final randomWord =
                              _poolOfSecretWords[Random().nextInt(
                                _poolOfSecretWords.length,
                              )];
                          _controller.startNewRound(
                            myUid: _myUid,
                            partnerUid: _partnerUid,
                            secretWord: randomWord,
                          );
                        },
                  child: Text(
                    hasActiveDrawer
                        ? 'Partner is drawing...'
                        : 'Become Artist & Generate Word',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (iAmArtist) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            Text(
              'YOUR SECRET TARGET WORD:',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(
              secretWord,
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),

            // 💡 Use Expanded so the canvas dynamically resizes and leaves perfect room for the button
            Expanded(
              child: Container(
                key: _canvasKey,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant, width: 1.5),
                ),
                child: LayoutBuilder(
                  builder: (context, canvasConstraints) {
                    return GestureDetector(
                      onPanStart: (details) {
                        final RenderBox? renderBox =
                            _canvasKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        if (renderBox != null) {
                          final Offset localPos = renderBox.globalToLocal(
                            details.globalPosition,
                          );
                          setState(() {
                            _localArtistPoints.add(localPos);
                          });
                        }
                      },
                      onPanUpdate: (details) {
                        final RenderBox? renderBox =
                            _canvasKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        if (renderBox != null) {
                          final Offset localPos = renderBox.globalToLocal(
                            details.globalPosition,
                          );

                          if (localPos.dx >= 0 &&
                              localPos.dx <= renderBox.size.width &&
                              localPos.dy >= 0 &&
                              localPos.dy <= renderBox.size.height) {
                            setState(() {
                              _localArtistPoints.add(localPos);
                            });
                          }
                        }
                      },
                      onPanEnd: (details) {
                        setState(() {
                          _localArtistPoints.add(null);
                        });
                      },
                      child: CustomPaint(
                        painter: LocalArtistPainter(points: _localArtistPoints),
                        size: Size.infinite,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              stage == 'drawing'
                  ? 'Draw your masterpiece and click publish below!'
                  : 'Live! Partner has $attemptsLeft guess tokens remaining...',
              style: TextStyle(
                fontSize: 13,
                color: cs.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            if (stage == 'drawing')
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    final RenderBox? renderBox =
                        _canvasKey.currentContext?.findRenderObject()
                            as RenderBox?;
                    if (renderBox == null) return;

                    final double canvasWidth = renderBox.size.width;
                    final double canvasHeightActual = renderBox.size.height;
                    List<Map<String, double>> finalizedPayload = [];

                    for (var pt in _localArtistPoints) {
                      if (pt == null) {
                        finalizedPayload.add({'xPct': -1.0, 'yPct': -1.0});
                      } else {
                        finalizedPayload.add({
                          'xPct': pt.dx / canvasWidth,
                          'yPct': pt.dy / canvasHeightActual,
                        });
                      }
                    }
                    _controller.submitDrawing(_myUid, finalizedPayload);
                  },
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text(
                    'Publish Outline & Reveal Clue',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      final bool isGuessingTime = stage == 'guessing';

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isGuessingTime
                      ? 'LIVE CLUE CANVAS'
                      : 'PARTNER SKETCH PHASE...',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (isGuessingTime)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Attempts Left: $attemptsLeft',
                      style: TextStyle(
                        color: cs.onErrorContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant, width: 2),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    List<Offset?> responsivePointsList = [];

                    if (isGuessingTime &&
                        snapshot.hasData &&
                        snapshot.data!.exists &&
                        snapshot.data!.data() != null) {
                      final rawPaths =
                          snapshot.data!.data()!['drawingPaths']
                              as List<dynamic>? ??
                          [];
                      for (var pt in rawPaths) {
                        if (pt != null &&
                            pt['xPct'] != null &&
                            pt['yPct'] != null) {
                          if (pt['xPct'] == -1.0 && pt['yPct'] == -1.0) {
                            responsivePointsList.add(null);
                          } else {
                            responsivePointsList.add(
                              Offset(
                                (pt['xPct'] as num).toDouble() *
                                    constraints.maxWidth,
                                (pt['yPct'] as num).toDouble() *
                                    constraints.maxHeight,
                              ),
                            );
                          }
                        }
                      }
                    }

                    if (!isGuessingTime) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Artist is creating a clue... 🤫',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return CustomPaint(
                      painter: LocalArtistPainter(points: responsivePointsList),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _guessInputController,
                    enabled: isGuessingTime,
                    textCapitalization: TextCapitalization.characters,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: isGuessingTime
                          ? 'Type text guess...'
                          : 'Locked until artist submits canvas',
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
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: !isGuessingTime
                      ? null
                      : () {
                          final cleanGuess = _guessInputController.text
                              .trim()
                              .toUpperCase();
                          if (cleanGuess.isEmpty) return;

                          final bool isCorrect =
                              cleanGuess == secretWord.toUpperCase();
                          _controller.registerGuessAttempt(
                            artistUid: artistUid,
                            isCorrect: isCorrect,
                            currentAttemptsLeft: attemptsLeft,
                          );
                          _guessInputController.clear();
                        },
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }
}

class LocalArtistPainter extends CustomPainter {
  final List<Offset?> points;
  LocalArtistPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LocalArtistPainter oldDelegate) => true;
}
