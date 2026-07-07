// lib/features/telepathy/presentation/telepathy_game_screen.dart
import 'package:flutter/material.dart';
import '../../../models/telepathy_game_model.dart';
import '../../../services/telepathy_service.dart';
import '../../../services/word_generator_service.dart';
import 'telepathy_controller.dart';

class TelepathyGameScreen extends StatefulWidget {
  final String gameId;
  final String hostId;
  final String currentUserId;

  const TelepathyGameScreen({
    Key? key,
    required this.gameId,
    required this.hostId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<TelepathyGameScreen> createState() => _TelepathyGameScreenState();
}

class _TelepathyGameScreenState extends State<TelepathyGameScreen> {
  final TelepathyController _controller = TelepathyController();
  final TelepathyFirebaseService _service = TelepathyFirebaseService();
  final TextEditingController _inputController = TextEditingController();
  bool _isChangingWord = false;

  @override
  void initState() {
    super.initState();
    _enterRoomLifecycle();
  }

  // Runs on widget entry: Increments presence tracking, rolling fresh if room was abandoned (0 players)
  Future<void> _enterRoomLifecycle() async {
    final String initialSeed = await WordGeneratorService.getRandomSeedWord();
    await _service.updatePresence(
      hostId: widget.hostId,
      gameId: widget.gameId,
      countChange: 1,
      fallbackSeed: initialSeed,
    );
  }

  @override
  void dispose() {
    // Runs on exit: Decrements presence tracking safely
    _service.updatePresence(
      hostId: widget.hostId,
      gameId: widget.gameId,
      countChange: -1,
      fallbackSeed: 'Camping',
    );
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mind Meld Telepathy')),
      body: StreamBuilder<TelepathyGame>(
        stream: _controller.watchGame(widget.hostId, widget.gameId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.hasError) {
            return _buildInitScreen();
          }

          final game = snapshot.data!;
          final currentRound = game.rounds[game.currentRoundIndex];

          final bool isHost = widget.currentUserId == game.hostId;
          final String? myInput = isHost
              ? currentRound.player1Input
              : currentRound.player2Input;
          final bool hasIAnswered = myInput != null;

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
                    'ROUND ${game.currentRoundIndex + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Find a connection word for:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),

                  // Wrap prompt in a row containing the new Shuffle Change Action Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 40), // This can stay const
                      Expanded(
                        child: Text(
                          currentRound.prompt,
                          textAlign: TextAlign.center,
                          // Make sure there is NO 'const' here!
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      _isChangingWord
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
                              ), // Dynamic theme color here too!
                              tooltip: 'Change Word',
                              onPressed: () async {
                                setState(() => _isChangingWord = true);
                                final String newSeed =
                                    await WordGeneratorService.getRandomSeedWord();
                                await _service.changeSeedWord(
                                  hostId: widget.hostId,
                                  gameId: widget.gameId,
                                  newSeed: newSeed,
                                );
                                if (mounted)
                                  setState(() => _isChangingWord = false);
                              },
                            ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  if (!hasIAnswered) ...[
                    TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: game.gameMode == GameMode.emojisOnly
                            ? 'Enter an Emoji...'
                            : 'Type your single link word...',
                        border: const OutlineInputBorder(),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (_inputController.text.trim().isEmpty) return;
                        _controller.submitGuess(
                          hostId: game.hostId,
                          gameId: game.gameId,
                          userId: widget.currentUserId,
                          input: _inputController.text,
                          game: game,
                        );
                        _inputController.clear();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Lock It In'),
                    ),
                  ] else ...[
                    const Card(
                      color: Colors.amberAccent,
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.hourglass_bottom,
                              size: 48,
                              color: Colors.amber,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Answer locked in!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Waiting for your partner to pick their bridge word...',
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

  Widget _buildInitScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.psychology_outlined,
              size: 72,
              color: Colors.indigo,
            ),
            const SizedBox(height: 16),
            const Text(
              'Initializing Mind Meld...',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const CircularProgressIndicator(),
          ],
        ),
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
            const SizedBox(height: 8),
            Text(
              'You synchronized in ${game.rounds.length} rounds!',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final String dynamicSeed =
                    await WordGeneratorService.getRandomSeedWord();
                await _service.startNewGame(
                  gameId: widget.gameId,
                  hostId: widget.hostId,
                  partnerId: game.partnerId,
                  mode: game.gameMode,
                  seedWord: dynamicSeed,
                );
                if (mounted) setState(() {});
              },
              child: const Text('Play Again'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Chain Path:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: game.rounds.length,
                itemBuilder: (context, index) {
                  final rd = game.rounds[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
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
