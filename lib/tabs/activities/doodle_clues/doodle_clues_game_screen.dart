// lib/screens/activities/doodle_clues/doodle_clues_game_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doodle_clues_controller.dart';
import '../../../services/streaks_service.dart';

class DoodleCluesGameScreen extends StatefulWidget {
  const DoodleCluesGameScreen({super.key});

  @override
  State<DoodleCluesGameScreen> createState() => _DoodleCluesGameScreenState();
}

class _DoodleCluesGameScreenState extends State<DoodleCluesGameScreen> {
  final DoodleCluesController _controller = DoodleCluesController();
  final StreaksService _streaksService = StreaksService();
  final TextEditingController _guessInputController = TextEditingController();
  final TextEditingController _wordInputController = TextEditingController();
  bool _isExiting = false;

  final GlobalKey _canvasKey = GlobalKey();

  String _myUid = '';
  String _partnerUid = '';
  bool _initializingAuth = true;
  bool _endDialogShown = false;

  List<Offset?> _localArtistPoints = [];

  String _lastKnownStage = 'setup';
  DateTime? _roundStartedAtLocal;
  int _drawDurationSeconds = DoodleCluesController.drawDurationSeconds;
  int _remainingSeconds = DoodleCluesController.drawDurationSeconds;
  bool _timeoutFired = false;
  bool _pathsDirtySinceLastSync = false;
  Timer? _countdownTimer;
  Timer? _liveSyncTimer;

  Future<void> _logGameCompleted() async {
    try {
      await _streaksService.recordActivity('game_completed');
    } catch (_) {}
  }

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
    _wordInputController.dispose();
    _countdownTimer?.cancel();
    _liveSyncTimer?.cancel();
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

  void _ensureTimerForStage(
    String stage,
    Map<String, dynamic> data,
    String artistUidForDoc,
  ) {
    if (stage != _lastKnownStage) {
      _lastKnownStage = stage;
      if (stage == 'drawing') {
        _timeoutFired = false;
        _startCountdown(data, artistUidForDoc);
      } else {
        _stopTimers();
      }
      return;
    }

    if (stage == 'drawing' && _roundStartedAtLocal == null) {
      _startCountdown(data, artistUidForDoc);
    }
  }

  void _startCountdown(Map<String, dynamic> data, String artistUidForDoc) {
    final ts = data['roundStartedAt'];
    if (ts is! Timestamp) return;

    _roundStartedAtLocal = ts.toDate();
    _drawDurationSeconds =
        (data['drawDurationSeconds'] as int?) ??
        DoodleCluesController.drawDurationSeconds;

    _countdownTimer?.cancel();
    _tickCountdown(artistUidForDoc);
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickCountdown(artistUidForDoc),
    );

    _liveSyncTimer?.cancel();
    _liveSyncTimer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => _flushLiveDrawingIfDirty(artistUidForDoc),
    );
  }

  void _tickCountdown(String artistUidForDoc) {
    if (!mounted || _roundStartedAtLocal == null) return;
    final elapsed = DateTime.now().difference(_roundStartedAtLocal!).inSeconds;
    final remaining = (_drawDurationSeconds - elapsed).clamp(
      0,
      _drawDurationSeconds,
    );

    setState(() => _remainingSeconds = remaining);

    if (remaining <= 0 && !_timeoutFired) {
      _timeoutFired = true;
      _controller.endRoundTimeout(artistUidForDoc);
    }
  }

  void _stopTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _liveSyncTimer?.cancel();
    _liveSyncTimer = null;
    _roundStartedAtLocal = null;
    _remainingSeconds = _drawDurationSeconds;
  }

  void _flushLiveDrawingIfDirty(String artistUidForDoc) {
    if (!_pathsDirtySinceLastSync) return;
    if (_myUid != artistUidForDoc) return;

    final RenderBox? renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final double width = renderBox.size.width;
    final double height = renderBox.size.height;
    if (width <= 0 || height <= 0) return;

    final List<Map<String, double>> payload = _localArtistPoints.map((pt) {
      if (pt == null) return {'xPct': -1.0, 'yPct': -1.0};
      return {'xPct': pt.dx / width, 'yPct': pt.dy / height};
    }).toList();

    _pathsDirtySinceLastSync = false;
    _controller.updateLiveDrawing(artistUidForDoc, payload);
  }

  Future<void> _handleStartRoundFromInput() async {
    final word = _wordInputController.text.trim();
    if (word.isEmpty) return;
    await _controller.startNewRound(
      myUid: _myUid,
      partnerUid: _partnerUid,
      secretWord: word,
    );
    _wordInputController.clear();
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
                'How to Play: DoodleClues',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildInstructionStep(
                context: context,
                stepNumber: '1',
                text:
                    'One player claims the Artist role and picks a secret word.',
                cs: cs,
              ),
              _buildInstructionStep(
                context: context,
                stepNumber: '2',
                text:
                    'A 2-minute timer starts - your partner watches your sketch appear live, stroke by stroke.',
                cs: cs,
              ),
              _buildInstructionStep(
                context: context,
                stepNumber: '3',
                text:
                    'The guesser can send unlimited guesses until the word is solved or time runs out.',
                cs: cs,
              ),
              _buildInstructionStep(
                context: context,
                stepNumber: '4',
                text:
                    'Backing out mid-session safely resets the room back to setup mode.',
                cs: cs,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructionStep({
    required BuildContext context,
    required String stepNumber,
    required String text,
    required ColorScheme cs,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGameEndedAlert(bool isWin, BuildContext screenContext) {
    if (_endDialogShown) return;
    _endDialogShown = true;
    unawaited(_logGameCompleted());

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
                  isWin ? "ROUND WON!" : "TIME'S UP",
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
                      : "The 2-minute timer ran out before the word was guessed. Better luck next round!",
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
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: statusColor,
                      foregroundColor: buttonForegroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Play Again',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await _controller.purgeMatch(_myUid, _partnerUid);
                      if (screenContext.mounted) Navigator.pop(screenContext);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant,
                      side: BorderSide(color: cs.outlineVariant),
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

  Future<void> _requestExitConfirmation(String stage) async {
    if (stage == 'setup' || stage == 'results') {
      _stopTimers();
      if (mounted) Navigator.pop(context);
      return;
    }

    final cs = Theme.of(context).colorScheme;
    final bool? dynamicConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.primary, width: 1.5),
          ),
          title: const Text(
            'End Game?',
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          content: Text(
            'Are you sure you want to end the game? This will abandon the match for both you and your partner.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Resume Play'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
              child: const Text(
                'Yes, End Game',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (dynamicConfirm == true) {
      setState(() => _isExiting = true);
      _stopTimers();

      if (mounted) Navigator.pop(context);

      if (_myUid.isNotEmpty) {
        await _controller.triggerForcedCancellation(_myUid, _partnerUid);
        await _controller.purgeMatch(_myUid, _partnerUid);
      }
    }
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
            int guessCount = 0;
            Map<String, dynamic> rawData = {};

            if (snapshot.hasData &&
                snapshot.data!.exists &&
                snapshot.data!.data() != null) {
              rawData = snapshot.data!.data()!;
              stage = rawData['stage'] ?? 'setup';
              secretWord = rawData['secretWord'] ?? '';
              artistUid = rawData['artistUid'] ?? '';
              isWin = rawData['isWin'] ?? false;
              guessCount = rawData['guessCount'] ?? 0;

              if (rawData['status'] == 'cancelled') {
                if (!_isExiting) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Session cancelled because a player backed out.',
                        ),
                      ),
                    );
                    if (mounted) Navigator.pop(context);
                    await _controller.purgeMatch(_myUid, _partnerUid);
                  });
                }
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
            }

            final bool iAmArtist = artistUid == _myUid;
            final String artistUidForDoc = artistUid.isNotEmpty
                ? artistUid
                : effectiveArtistUid;

            if (stage == 'results') {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _showGameEndedAlert(isWin, context),
              );
            }

            if (stage == 'setup' && _localArtistPoints.isNotEmpty) {
              _localArtistPoints = [];
            }

            if (stage == 'setup') {
              _endDialogShown = false;
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _ensureTimerForStage(stage, rawData, artistUidForDoc);
            });

            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                _requestExitConfirmation(stage);
              },
              child: Scaffold(
                backgroundColor: cs.surface,
                resizeToAvoidBottomInset: false,
                appBar: stage == 'setup'
                    ? null
                    : AppBar(
                        backgroundColor: cs.surface,
                        elevation: 0,
                        title: const Text(
                          'DoodleClues',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        centerTitle: true,
                        leading: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                          ),
                          onPressed: () => _requestExitConfirmation(stage),
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.help_outline_rounded),
                            onPressed: () => _showHowToPlay(context),
                          ),
                        ],
                      ),
                body: SafeArea(
                  // 🌟 SWIPE RIGHT TRANSITION: Smoothly slides in from the right when moving to drawing mode
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final isIncoming =
                          child.key ==
                          ValueKey('stage_$stage\_artist_$iAmArtist');

                      // Incoming widget slides in from right (1.0 -> 0.0), outgoing slides left (-1.0 <- 0.0)
                      final offsetAnimation = Tween<Offset>(
                        begin: isIncoming
                            ? const Offset(1.0, 0.0)
                            : const Offset(-1.0, 0.0),
                        end: Offset.zero,
                      ).animate(animation);

                      return SlideTransition(
                        position: offsetAnimation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey('stage_$stage\_artist_$iAmArtist'),
                      child: _buildStageLayout(
                        stage,
                        secretWord,
                        artistUidForDoc,
                        iAmArtist,
                        snapshot,
                        guessCount,
                        cs,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimerBadge(ColorScheme cs) {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.28),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 16, color: cs.onPrimary),
          const SizedBox(width: 6),
          Text(
            '$minutes:$seconds',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cs.onPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuessCountBadge(int guessCount, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.3), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.12),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        guessCount == 0 ? 'Unlimited guesses' : 'Guesses so far: $guessCount',
        style: TextStyle(
          color: cs.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStageLayout(
    String stage,
    String secretWord,
    String artistUid,
    bool iAmArtist,
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
    int guessCount,
    ColorScheme cs,
  ) {
    if (stage == 'setup') {
      final bool hasActiveDrawer = artistUid.isNotEmpty && artistUid != _myUid;

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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

            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withOpacity(0.6),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withOpacity(0.18),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.palette_rounded,
                          size: 32,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'READY TO SKETCH',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        hasActiveDrawer
                            ? 'Your partner has claimed the canvas! Prepare to make a guess...'
                            : 'Enter your secret word or phrase below. You\'ll get 2 minutes to draw it live for your partner.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (!hasActiveDrawer) ...[
                        TextField(
                          controller: _wordInputController,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 30,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'e.g. SUNSET',
                            hintStyle: TextStyle(
                              color: cs.onSurfaceVariant.withOpacity(0.5),
                              fontSize: 15,
                              fontWeight: FontWeight.normal,
                            ),
                            filled: true,
                            fillColor: cs.surfaceContainerLowest,
                            counterText: '',
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
                              borderSide: BorderSide(
                                color: cs.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          textAlign: TextAlign.center,
                          onSubmitted: (_) => _handleStartRoundFromInput(),
                        ),
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: () {
                            final randomWord =
                                _poolOfSecretWords[Random().nextInt(
                                  _poolOfSecretWords.length,
                                )];
                            _wordInputController.text = randomWord;
                          },
                          icon: const Icon(Icons.casino_rounded, size: 18),
                          label: const Text('Surprise me instead'),
                          style: TextButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: hasActiveDrawer
                              ? null
                              : _handleStartRoundFromInput,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            hasActiveDrawer
                                ? 'PARTNER IS DRAWING...'
                                : 'START DRAWING',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (iAmArtist) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR SECRET TARGET WORD:',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        secretWord,
                        style: TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildTimerBadge(cs),
              ],
            ),
            const SizedBox(height: 12),

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
                          _pathsDirtySinceLastSync = true;
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
                            _pathsDirtySinceLastSync = true;
                          }
                        }
                      },
                      onPanEnd: (details) {
                        setState(() {
                          _localArtistPoints.add(null);
                        });
                        _pathsDirtySinceLastSync = true;
                        _flushLiveDrawingIfDirty(artistUid);
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Live - partner is watching',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildGuessCountBadge(guessCount, cs),
              ],
            ),
          ],
        ),
      );
    } else {
      final bool isRoundActive = stage == 'drawing';
      final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
      const double footerReserve = 108.0;

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Stack(
          children: [
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LIVE CLUE CANVAS',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    _buildTimerBadge(cs),
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

                        if (snapshot.hasData &&
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

                        if (responsivePointsList.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  'Waiting for the first brush stroke...',
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
                          painter: LocalArtistPainter(
                            points: responsivePointsList,
                          ),
                          size: Size.infinite,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: footerReserve),
              ],
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: keyboardInset,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildGuessCountBadge(guessCount, cs),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _guessInputController,
                          enabled: isRoundActive,
                          textCapitalization: TextCapitalization.characters,
                          style: Theme.of(context).textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: isRoundActive
                                ? 'Type as many guesses as you like...'
                                : 'Round has ended',
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
                          onSubmitted: !isRoundActive
                              ? null
                              : (_) => _submitGuess(
                                  artistUid,
                                  secretWord: secretWordArg(snapshot),
                                  guessCount: guessCount,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: !isRoundActive
                            ? null
                            : () => _submitGuess(
                                artistUid,
                                secretWord: secretWordArg(snapshot),
                                guessCount: guessCount,
                              ),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  String secretWordArg(
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.hasData &&
        snapshot.data!.exists &&
        snapshot.data!.data() != null) {
      return snapshot.data!.data()!['secretWord'] ?? '';
    }
    return '';
  }

  void _submitGuess(
    String artistUid, {
    required String secretWord,
    required int guessCount,
  }) {
    final cleanGuess = _guessInputController.text.trim().toUpperCase();
    if (cleanGuess.isEmpty) return;

    final bool isCorrect = cleanGuess == secretWord.toUpperCase();
    _controller.registerGuessAttempt(
      artistUid: artistUid,
      guesserUid: _myUid,
      isCorrect: isCorrect,
      currentGuessCount: guessCount,
    );
    _guessInputController.clear();
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
