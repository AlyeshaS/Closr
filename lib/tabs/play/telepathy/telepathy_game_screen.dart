// lib/features/telepathy/presentation/telepathy_game_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/telepathy_game_model.dart';
import '../../../services/telepathy_service.dart';
import '../../../services/word_generator_service.dart';

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
  final TextEditingController _inputController = TextEditingController();
  bool _isChangingWord = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mind Meld Session'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _service.streamGame(widget.myUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Session data not found.'));
          }

          final game = TelepathyGame.fromDocument(snapshot.data!);

          if (game.seedWord == 'PENDING_CHOICE') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop();
            });
            return const Center(child: CircularProgressIndicator());
          }

          final currentRound = game.rounds[game.currentRoundIndex];
          final bool isHost = widget.myUid == game.hostId;
          final String? myInput = isHost
              ? currentRound.player1Input
              : currentRound.player2Input;
          final bool hasIAnswered = myInput != null;
          final bool isCustomSetup =
              game.gameMode == GameMode.customPrompt &&
              game.currentRoundIndex == 0;

          if (game.status == 'completed') {
            return _buildVictoryScreen(game);
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              24.0,
              24.0,
              24.0,
              MediaQuery.of(context).viewInsets.bottom + 24.0,
            ),
            child: SizedBox(
              height:
                  MediaQuery.of(context).size.height -
                  AppBar().preferredSize.height -
                  MediaQuery.of(context).padding.top -
                  48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isCustomSetup
                        ? 'SETUP ROUND'
                        : 'ROUND ${game.currentRoundIndex}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isCustomSetup
                        ? 'Think of any random starting word!'
                        : 'Find a connection word for:',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  if (!isCustomSetup)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 40),
                        Expanded(
                          child: Text(
                            currentRound.prompt,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        game.gameMode != GameMode.wordsOnly
                            ? const SizedBox(width: 40)
                            : _isChangingWord
                            ? const SizedBox(
                                width: 40,
                                height: 40,
                                child: Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  Icons.refresh_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                tooltip: 'Change Word',
                                onPressed: () async {
                                  setState(() => _isChangingWord = true);
                                  final String newSeed =
                                      await WordGeneratorService.getRandomSeedWord();
                                  await _service.changeSeedWord(
                                    game: game,
                                    newSeed: newSeed,
                                  );
                                  if (mounted)
                                    setState(() => _isChangingWord = false);
                                },
                              ),
                      ],
                    )
                  else
                    Text(
                      "❓ + ❓",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.4),
                      ),
                    ),

                  const SizedBox(height: 48),

                  if (!hasIAnswered) ...[
                    TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: isCustomSetup
                            ? 'Enter starting word...'
                            : 'Type your single link word...',
                        border: const OutlineInputBorder(),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final String entry = _inputController.text.trim();
                        if (entry.isEmpty) return;

                        try {
                          await _service.submitInput(
                            currentUserId: widget.myUid,
                            input: entry,
                            game: game,
                          );
                          _inputController.clear();
                        } catch (e) {
                          // Catch our explicit emoji rule violation
                          if (e is ArgumentError &&
                              e.message == 'EMOJI_ONLY_VIOLATION') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                content: const Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Minds must link using Emojis Only! 🔮',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isCustomSetup ? 'Submit Starting Word' : 'Lock It In',
                      ),
                    ),
                  ] else ...[
                    Card(
                      color: Colors.amberAccent[100],
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.hourglass_bottom,
                              size: 48,
                              color: Colors.amber,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isCustomSetup
                                  ? 'Starting word locked!'
                                  : 'Answer locked in!',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isCustomSetup
                                  ? 'Waiting for partner baseline word...'
                                  : 'Waiting for partner bridge word...',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVictoryScreen(TelepathyGame game) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt, size: 100, color: Colors.orangeAccent),
            const SizedBox(height: 16),
            const Text(
              'MIND MELD\nACHIEVED!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _service.startNewGame(
                gameId: game.gameId,
                myUid: game.hostId,
                partnerUid: game.partnerId,
                mode: game.gameMode,
                seedWord: 'PENDING_CHOICE',
              ),
              child: const Text('Play Again'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: game.rounds.length,
                itemBuilder: (context, index) {
                  final rd = game.rounds[index];
                  if (game.gameMode == GameMode.customPrompt && index == 0) {
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.tune, size: 16),
                      ),
                      title: const Text('Baseline Custom Setup'),
                      subtitle: Text(
                        'Base Words: ${rd.player1Input ?? "?"} + ${rd.player2Input ?? "?"}',
                      ),
                    );
                  }
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        game.gameMode == GameMode.customPrompt
                            ? '$index'
                            : '${index + 1}',
                      ),
                    ),
                    title: Text('Prompt: ${rd.prompt}'),
                    subtitle: Text(
                      'Answers: ${rd.player1Input ?? "?"} | ${rd.player2Input ?? "?"}',
                    ),
                    trailing: rd.isMatch
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.close, color: Colors.red),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
