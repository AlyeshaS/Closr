// lib/screens/activities/trivia/trivia_controller.dart
import 'package:flutter/material.dart';

class TriviaController extends ChangeNotifier {
  static final TriviaController _instance = TriviaController._internal();
  factory TriviaController() => _instance;
  TriviaController._internal();

  // ── INDEPENDENT PLAYER TRACKING ────────────────────────────────────────────
  // Track what step the local user is currently on: 'setup' | 'waiting' | 'guessing' | 'results'
  String localUserStage = 'setup';
  int currentQuestionIndex = 0;

  // Answer Storage
  List<int> mySelfAnswers = []; // What I chose for myself
  List<int> myGuessesForPartner = []; // My guesses for what my partner likes

  // Partner Answer Storage (Simulating the partner's device updates)
  List<int> partnerSelfAnswers = []; // Empty until partner finishes their setup
  List<int> partnerGuessesForMe = []; // Empty until partner guesses my answers

  // ── GLOBAL SCOREBOARD METRICS ──────────────────────────────────────────────
  int userGlobalWins = 0;
  int partnerGlobalWins = 0;

  // Check if the partner has completed their initial setup round
  bool get isPartnerSetupComplete => partnerSelfAnswers.isNotEmpty;

  // Check if both users have finished both phases entirely
  bool get isEntireGameFinished =>
      myGuessesForPartner.length == 10 && partnerGuessesForMe.length == 10;

  // ── SIMULATION TOGGLES FOR INDEPENDENT TESTING ──────────────────────────────
  // Call this to mock your partner finishing their setup phase asynchronously
  void simulatePartnerFinishedSetup() {
    partnerSelfAnswers = [
      1,
      0,
      2,
      0,
      1,
      1,
      0,
      2,
      0,
      3,
    ]; // Partner's choices saved
    notifyListeners();
  }

  // Call this to mock your partner finishing their guessing phase asynchronously
  void simulatePartnerFinishedGuessing() {
    partnerGuessesForMe = [
      0,
      0,
      2,
      3,
      1,
      1,
      0,
      0,
      0,
      2,
    ]; // Partner's guesses for you
    notifyListeners();
  }

  // Calculate scores
  int get myScoreOutof10 {
    int score = 0;
    for (int i = 0; i < myGuessesForPartner.length; i++) {
      if (myGuessesForPartner[i] == partnerSelfAnswers[i]) score++;
    }
    return score;
  }

  int get partnerScoreOutof10 {
    int score = 0;
    for (int i = 0; i < partnerGuessesForMe.length; i++) {
      if (partnerGuessesForMe[i] == mySelfAnswers[i]) score++;
    }
    return score;
  }

  void evaluateWinnerAndIncrementGlobalScore() {
    int me = myScoreOutof10;
    int them = partnerScoreOutof10;
    if (me > them) {
      userGlobalWins++;
    } else if (them > me) {
      partnerGlobalWins++;
    }
    notifyListeners();
  }

  void resetGame() {
    localUserStage = 'setup';
    currentQuestionIndex = 0;
    mySelfAnswers.clear();
    myGuessesForPartner.clear();
    partnerSelfAnswers.clear();
    partnerGuessesForMe.clear();
    notifyListeners();
  }
}
