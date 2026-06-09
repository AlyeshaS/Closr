// lib/screens/activities/trivia/trivia_game_screen.dart
import 'package:flutter/material.dart';
import 'trivia_controller.dart';

class TriviaGameScreen extends StatefulWidget {
  const TriviaGameScreen({super.key});

  @override
  State<TriviaGameScreen> createState() => _TriviaGameScreenState();
}

class _TriviaGameScreenState extends State<TriviaGameScreen> {
  final TriviaController _controller = TriviaController();
  int? _selectedAnswerIndex;

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

  void _handleNextStep() {
    if (_selectedAnswerIndex == null) return;

    setState(() {
      if (_controller.localUserStage == 'setup') {
        _controller.mySelfAnswers.add(_selectedAnswerIndex!);
        if (_controller.currentQuestionIndex < _tenQuestions.length - 1) {
          _controller.currentQuestionIndex++;
          _selectedAnswerIndex = null;
        } else {
          _controller.localUserStage = 'waiting';
          _controller.currentQuestionIndex = 0;
          _selectedAnswerIndex = null;
        }
      } else if (_controller.localUserStage == 'guessing') {
        _controller.myGuessesForPartner.add(_selectedAnswerIndex!);
        if (_controller.currentQuestionIndex < _tenQuestions.length - 1) {
          _controller.currentQuestionIndex++;
          _selectedAnswerIndex = null;
        } else {
          // If partner is already done guessing too, calculate the game score instantly
          if (_controller.partnerGuessesForMe.length == 10) {
            _controller.evaluateWinnerAndIncrementGlobalScore();
            _controller.localUserStage = 'results';
          } else {
            _controller.localUserStage =
                'waiting'; // Wait for partner's final guesses
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          _controller.localUserStage == 'setup' ||
                  _controller.localUserStage == 'guessing'
              ? 'Question ${_controller.currentQuestionIndex + 1} of 10'
              : 'Our Trivia',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentStateLayout(cs),
        ),
      ),
    );
  }

  Widget _buildCurrentStateLayout(ColorScheme cs) {
    // ── STEP 2: DYNAMIC WAITING & CUTE TRANSITION VIEW ───────────────────────
    if (_controller.localUserStage == 'waiting') {
      final bool isReadyToGuess =
          _controller.isPartnerSetupComplete &&
          _controller.myGuessesForPartner.length < 10;
      final bool isWaitingForPartnerFinalGuesses =
          _controller.myGuessesForPartner.length == 10 &&
          _controller.partnerGuessesForMe.length < 10;

      return Center(
        key: const ValueKey('waiting_stage'),
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
                  isReadyToGuess
                      ? Icons.favorite_rounded
                      : Icons.hourglass_top_rounded,
                  size: 36,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isReadyToGuess
                    ? 'Your turn to guess! ✨'
                    : 'Answers locked in! 🔒',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                isReadyToGuess
                    ? 'Your partner has submitted their choices! Tap below to read their mind.'
                    : isWaitingForPartnerFinalGuesses
                    ? 'You completed your guesses! Hanging tight until your partner answers your challenge pool to reveal the final winner.'
                    : 'Your profile answers are saved. We are waiting for your partner to create their challenge pool!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 40),

              // Cute Action Button appeared if data criteria is fulfilled
              if (isReadyToGuess)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: () =>
                        setState(() => _controller.localUserStage = 'guessing'),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text(
                      'Let\'s Guess Their Answers! 🧸',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: FilledButton.styleFrom(backgroundColor: cs.primary),
                  ),
                ),

              // Simulation Dev Dashboard Controllers
              const SizedBox(height: 32),
              const Divider(),
              Text(
                'PROTOTYPING TOOLS',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: cs.outline),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => setState(
                      () => _controller.simulatePartnerFinishedSetup(),
                    ),
                    child: const Text('1. Mock Partner Setup Done'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _controller.simulatePartnerFinishedGuessing();
                        if (_controller.myGuessesForPartner.length == 10) {
                          _controller.evaluateWinnerAndIncrementGlobalScore();
                          _controller.localUserStage = 'results';
                        }
                      });
                    },
                    child: const Text('2. Mock Partner Guesses Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // ── STEP 4: HEAD-TO-HEAD FINAL SUMMARY SPLIT VIEW ────────────────────────
    if (_controller.localUserStage == 'results') {
      final myScore = _controller.myScoreOutof10;
      final partnerScore = _controller.partnerScoreOutof10;

      String matchOutcomeTitle = "It's a Tie! 🤝";
      if (myScore > partnerScore) matchOutcomeTitle = "You Won This Round! 🎉";
      if (partnerScore > myScore) matchOutcomeTitle = "Your Partner Won! 👑";

      return SingleChildScrollView(
        key: const ValueKey('results_stage'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              matchOutcomeTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 28),

            // Scoreboard Comparer Blocks
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
                onPressed: () {
                  _controller.resetGame();
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Complete Challenge',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── QUESTION SUB-VIEW (SETUP & GUESSING) ──────────────────────────────────
    final currentQuestion = _tenQuestions[_controller.currentQuestionIndex];
    final List<String> options = currentQuestion["options"];

    return Padding(
      key: ValueKey(
        'question_${_controller.localUserStage}_${_controller.currentQuestionIndex}',
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:
                  (_controller.currentQuestionIndex + 1) / _tenQuestions.length,
              backgroundColor: cs.primary.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _controller.localUserStage == 'setup'
                ? "STEP 1: ANSWER FOR YOURSELF"
                : "STEP 3: GUESS THEIR ANSWER",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            currentQuestion["q"],
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
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
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primaryContainer
                            : cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? cs.primary : cs.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              options[index],
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: isSelected
                                        ? cs.onPrimaryContainer
                                        : cs.onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                            ),
                          ),
                          Radio<int>(
                            value: index,
                            groupValue: _selectedAnswerIndex,
                            activeColor: cs.primary,
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
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _controller.currentQuestionIndex == _tenQuestions.length - 1 &&
                        _controller.localUserStage == 'guessing'
                    ? 'Show Results'
                    : 'Next Question',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
