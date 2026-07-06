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

  // Explicitly isolate the drawing canvas coordinate space
  final GlobalKey _canvasKey = GlobalKey();

  String _myUid = '';
  String _partnerUid = '';
  bool _initializingAuth = true;
  bool _endDialogShown = false;

  // Local point cache for smooth drawing at 60fps
  List<Offset?> _localArtistPoints = [];

  // --- Live-sync + timer state ---------------------------------------
  String _lastKnownStage = 'setup';
  DateTime? _roundStartedAtLocal;
  int _drawDurationSeconds = DoodleCluesController.drawDurationSeconds;
  int _remainingSeconds = DoodleCluesController.drawDurationSeconds;
  bool _timeoutFired = false;
  bool _pathsDirtySinceLastSync = false;
  Timer? _countdownTimer;
  Timer? _liveSyncTimer;
  // ---------------------------------------------------------------------

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

  void _handleLeaveOrCancel() async {
    _stopTimers();
    if (_myUid.isNotEmpty) {
      await _controller.triggerForcedCancellation(_myUid, _partnerUid);
    }
    if (mounted) Navigator.pop(context);
  }

  // --- Timer + live-sync plumbing --------------------------------------

  /// Called on every rebuild with the freshest Firestore data. Detects
  /// stage transitions and starts/stops the local countdown + live-sync
  /// timers accordingly. Safe to call repeatedly - it's a no-op unless
  /// something actually changed.
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

    // Same stage as last build: if we're mid-drawing but never managed to
    // lock in the server timestamp yet (it resolves one snapshot after the
    // optimistic local write), try again once it's actually there.
    if (stage == 'drawing' && _roundStartedAtLocal == null) {
      _startCountdown(data, artistUidForDoc);
    }
  }

  void _startCountdown(Map<String, dynamic> data, String artistUidForDoc) {
    final ts = data['roundStartedAt'];
    if (ts is! Timestamp) return; // server timestamp still pending

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

    // Only the artist actually pushes drawing updates, but it's cheap to
    // arm the flush timer unconditionally - it's a no-op when nothing's
    // dirty or when this device isn't the artist.
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

  /// Converts the artist's local point cache to percentage coordinates and
  /// pushes it to Firestore so the guesser's canvas mirrors it live. Only
  /// fires when something actually changed since the last flush.
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

  // -----------------------------------------------------------------------

  Future<void> _promptStartRound() async {
    final word = await _showChooseWordDialog();
    if (word == null || word.trim().isEmpty) return;
    await _controller.startNewRound(
      myUid: _myUid,
      partnerUid: _partnerUid,
      secretWord: word,
    );
  }

  Future<String?> _showChooseWordDialog() {
    _wordInputController.clear();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Pick your word',
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose any word or phrase for your partner to guess. Keep it secret - you\'ll get 2 minutes to draw it.',
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _wordInputController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                maxLength: 30,
                decoration: InputDecoration(
                  hintText: 'e.g. SUNSET',
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.pop(dialogContext, value);
                  }
                },
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final randomWord =
                        _poolOfSecretWords[Random().nextInt(
                          _poolOfSecretWords.length,
                        )];
                    _wordInputController.text = randomWord;
                  },
                  icon: const Icon(Icons.casino_rounded, size: 18),
                  label: const Text('Surprise me instead'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = _wordInputController.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(dialogContext, value);
              },
              child: const Text(
                'Start Drawing',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
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
                '• One player claims the Artist role and picks their own secret word.\n'
                '• A 2-minute timer starts immediately - your partner watches the sketch appear live, stroke by stroke.\n'
                '• The guesser can send as many guesses as they want - there\'s no limit.\n'
                '• The round ends the moment the word is guessed correctly, or when the timer runs out.\n'
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
                      // Stay on the game screen so a new round can start
                      // straight away, instead of leaving.
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
                    artistUidForDoc,
                    iAmArtist,
                    snapshot,
                    guessCount,
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

  Widget _buildTimerBadge(ColorScheme cs) {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final bool isLow = _remainingSeconds <= 15;
    final Color bg = isLow ? cs.errorContainer : cs.primaryContainer;
    final Color fg = isLow ? cs.onErrorContainer : cs.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            '$minutes:$seconds',
            style: TextStyle(fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildGuessCountBadge(int guessCount, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        guessCount == 0 ? 'Unlimited guesses' : 'Guesses so far: $guessCount',
        style: TextStyle(
          color: cs.onSecondaryContainer,
          fontSize: 11,
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
                    : 'Claim the canvas as the artist, pick your own word, and you\'ll get 2 minutes to draw it - live, as your partner watches.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: hasActiveDrawer ? null : _promptStartRound,
                  child: Text(
                    hasActiveDrawer
                        ? 'Partner is drawing...'
                        : 'Become Artist & Choose Word',
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

            // Use Expanded so the canvas dynamically resizes.
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
                        // Flush immediately at the end of a stroke so the
                        // partner sees each completed line without waiting
                        // for the next throttled tick.
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
            // Background layer: header + canvas. This never resizes for the
            // keyboard (the Scaffold no longer shrinks for it), so the
            // drawing stays exactly the same size whether the keyboard is
            // open or not. A blank strip is reserved at the bottom so the
            // floating guess bar below has room to sit without covering it.
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
                                  'Waiting for the first brush stroke... 🤫',
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

            // Floating layer: guess count + input, pinned to the bottom and
            // shifted up by exactly the keyboard's height, so it's always
            // visible above the keyboard without ever touching the canvas.
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

  /// Pulls the secret word straight from the live snapshot so guess
  /// checking is always against the freshest value, even if this widget's
  /// build hasn't caught up yet.
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
