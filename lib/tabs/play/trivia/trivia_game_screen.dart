import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'trivia_controller.dart';

class TriviaGameScreen extends StatefulWidget {
  const TriviaGameScreen({super.key});

  @override
  State<TriviaGameScreen> createState() => _TriviaGameScreenState();
}

class _TriviaGameScreenState extends State<TriviaGameScreen> {
  final TriviaController _controller = TriviaController();
  int? _selectedAnswerIndex;
  int _currentQuestionIndex = 0;

  // Resolved Firebase Auth credentials
  String _myUid = '';
  bool _initializingAuth = true;

  final List<Map<String, dynamic>> _tenQuestions = [
    {
      "q": "What is my absolute favorite way to spend a rainy Sunday morning?",
      "options": [
        "Sleeping in & ordering takeout 🥞",
        "Curling up with a book & coffee ☕",
        "Playing video/card games 🎮",
        "Going for a drive 🚗",
      ],
    },
    {
      "q": "If I could win a lifetime supply of one drink, what is it?",
      "options": [
        "Iced Coffee / Matcha 🍵",
        "Boba 🧋",
        "Craft Beer / Wine 🍷",
        "Energy Drinks ⚡",
      ],
    },
    {
      "q": "What is my biggest minor pet peeve?",
      "options": [
        "Slow walkers 🚶",
        "People chewing loudly 🔊",
        "Unread notification badges 📱",
        "Texting 'K.' 💬",
      ],
    },
    {
      "q": "Choose my dream travel destination category:",
      "options": [
        "Relaxing beach resort 🏝️",
        "Exploring historic European streets 🏰",
        "Hiking mountains & camping 🏔️",
        "Bright neon Tokyo nightlife 🍣",
      ],
    },
    {
      "q": "What's my go-to movie genre when I can't decide?",
      "options": [
        "Comfort Comedy 🍿",
        "Psychological Thriller 🧠",
        "Cheesy Romance 💖",
        "Sci-Fi / Fantasy 🧙‍♂️",
      ],
    },
    {
      "q": "Which superpower would I actually pick?",
      "options": [
        "Teleportation instantly 🌎",
        "Time travel ⏳",
        "Mind reading 🔮",
        "Invisibility 👻",
      ],
    },
    {
      "q": "What's my love language style?",
      "options": [
        "Words of Affirmation 💬",
        "Quality Time ⏰",
        "Physical Touch 🤝",
        "Acts of Service / Gifts 🎁",
      ],
    },
    {
      "q": "How do I handle a high-stress day?",
      "options": [
        "Vent out loud completely 🗣️",
        "Retreat into total quiet space 🤫",
        "Distract myself with tasks 🧹",
        "Workout / Sleep it off 🏋️",
      ],
    },
    {
      "q": "What song track vibe am I turning on in a road trip car session?",
      "options": [
        "Early 2000s throwbacks 🎸",
        "Chill Indie Pop 🎧",
        "Hype Rap / R&B 🔥",
        "Modern Top 40 Radio 📻",
      ],
    },
    {
      "q": "What's my favorite season of the year?",
      "options": [
        "Blooming Spring 🌸",
        "Hot Summer Beach Days ☀️",
        "Cozy Autumn Leaves 🍁",
        "Snowy Winter Nights ❄️",
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _resolveCurrentUser();
  }

  void _resolveCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _myUid = user.uid;
    }
    setState(() {
      _initializingAuth = false;
    });
  }

  void _handleNextStep() async {
    if (_selectedAnswerIndex == null || _myUid.isEmpty) return;

    final int databaseValue = _selectedAnswerIndex! + 1; // 1 to 4 scaling

    if (_controller.myStage == 'setup') {
      List<int> updatedAnswers = List<int>.from(_controller.mySelfAnswers)
        ..add(databaseValue);

      await _controller.submitSelfAnswer(_myUid, updatedAnswers);

      if (_currentQuestionIndex < _tenQuestions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _selectedAnswerIndex = null;
        });
      } else {
        await _controller.updateUserStage(_myUid, 'waiting');
        setState(() => _selectedAnswerIndex = null);
      }
    } else if (_controller.myStage == 'guessing') {
      List<int> updatedGuesses = List<int>.from(_controller.myGuessesForPartner)
        ..add(databaseValue);
      await _controller.submitGuessAnswer(_myUid, updatedGuesses);

      if (_currentQuestionIndex < _tenQuestions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _selectedAnswerIndex = null;
        });
      } else {
        setState(() => _selectedAnswerIndex = null);
        await _controller.updateUserStage(_myUid, 'results');
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
      stream: _controller.listenToMyTrivia(_myUid),
      builder: (context, mySnapshot) {
        if (mySnapshot.hasData && mySnapshot.data!.exists) {
          _controller.updateMyData(mySnapshot.data!);
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _controller.listenToPartnerTrivia(_myUid),
          builder: (context, partnerSnapshot) {
            if (partnerSnapshot.hasData && partnerSnapshot.data!.exists) {
              _controller.updatePartnerData(partnerSnapshot.data!);

              // Calculate index values dynamically matching lengths inside Firestore database arrays
              _currentQuestionIndex = _controller.myStage == 'guessing'
                  ? _controller.myGuessesForPartner.length
                  : _controller.mySelfAnswers.length;

              if (_currentQuestionIndex >= 10) _currentQuestionIndex = 9;

              // AUTOMATIC STATE TRANSITION BLOCK
              // If I am waiting, and my partner's answers are fully locked in, push me directly to guessing!
              if (_controller.myStage == 'waiting' &&
                  _controller.isPartnerSetupComplete) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _controller.updateUserStage(_myUid, 'guessing');
                });
              }
            }

            return Scaffold(
              backgroundColor: cs.surface,
              appBar: AppBar(
                backgroundColor: cs.surface,
                elevation: 0,
                title: Text(
                  _controller.myStage == 'setup' ||
                          _controller.myStage == 'guessing'
                      ? 'Question ${_currentQuestionIndex + 1} of 10'
                      : 'Our Trivia',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: SafeArea(child: _buildCurrentStateLayout(cs)),
            );
          },
        );
      },
    );
  }

  Widget _buildCurrentStateLayout(ColorScheme cs) {
    if (_controller.myStage == 'waiting') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  size: 36,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Answers locked in! 🔒',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Your profile answers are safely saved. Once your partner finishes locking in their setup choices, this screen will instantly change so you can start guessing!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller.myStage == 'results') {
      int myScore = 0;
      for (int i = 0; i < _controller.myGuessesForPartner.length; i++) {
        if (i < _controller.partnerSelfAnswers.length &&
            _controller.myGuessesForPartner[i] ==
                _controller.partnerSelfAnswers[i]) {
          myScore++;
        }
      }

      int partnerScore = 0;
      for (int i = 0; i < _controller.partnerGuessesForMe.length; i++) {
        if (i < _controller.mySelfAnswers.length &&
            _controller.partnerGuessesForMe[i] ==
                _controller.mySelfAnswers[i]) {
          partnerScore++;
        }
      }

      String matchOutcomeTitle = "It's a Tie! 🤝";
      if (myScore > partnerScore) matchOutcomeTitle = "You Won This Round! 🎉";
      if (partnerScore > myScore) matchOutcomeTitle = "Your Partner Won! 👑";

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              matchOutcomeTitle,
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your Score',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$myScore/10',
                          style: TextStyle(
                            fontFamily: 'CormorantGaramond',
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Partner Score',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$partnerScore/10',
                          style: TextStyle(
                            fontFamily: 'CormorantGaramond',
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: cs.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () async {
                  await _controller.evaluateAndPurgeMatch(_myUid);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text(
                  'Complete Round & Purge Answers',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final currentQuestion = _tenQuestions[_currentQuestionIndex];
    final List<String> options = currentQuestion["options"];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _tenQuestions.length,
            minHeight: 4,
          ),
          const SizedBox(height: 28),
          Text(
            _controller.myStage == 'setup'
                ? "STEP 1: ANSWER FOR YOURSELF"
                : "STEP 3: GUESS THEIR ANSWER",
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: cs.primary),
          ),
          const SizedBox(height: 12),
          Text(
            currentQuestion["q"],
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedAnswerIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => setState(() => _selectedAnswerIndex = index),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primaryContainer
                            : cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? cs.primary : cs.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              options[index],
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Radio<int>(
                            value: index,
                            groupValue: _selectedAnswerIndex,
                            onChanged: (val) =>
                                setState(() => _selectedAnswerIndex = val),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _selectedAnswerIndex == null ? null : _handleNextStep,
              child: Text(
                _currentQuestionIndex == _tenQuestions.length - 1 &&
                        _controller.myStage == 'guessing'
                    ? 'Show Results'
                    : 'Next Question',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
