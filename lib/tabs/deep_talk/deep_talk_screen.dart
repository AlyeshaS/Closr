// deep_talk_screen.dart
import 'package:flutter/material.dart';
import 'deep_talk_service.dart';

class DeepTalkScreen extends StatefulWidget {
  const DeepTalkScreen({super.key});

  @override
  State<DeepTalkScreen> createState() => _DeepTalkScreenState();
}

class _DeepTalkScreenState extends State<DeepTalkScreen> {
  final DeepTalkService _service = DeepTalkService();
  List<Map<String, dynamic>> _topics = [];
  int _currentIndex = 0;
  bool _loading = false;
  bool _loggedCompletedRun = false;

  // Topic depth labels for display
  final List<String> _depthLabels = [
    'Light',
    'Curious',
    'Meaningful',
    'Vulnerable',
    'Deep',
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _generateMoreTopics() async {
    setState(() => _loading = true);
    final topics = await _service.generateAndReplaceTopics();
    setState(() {
      _topics = topics;
      _currentIndex = 0;
      _loggedCompletedRun = false;
      _loading = false;
    });
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final topics = await _service.getOrGenerateTopics();
    setState(() {
      _topics = topics;
      _loggedCompletedRun = false;
      _loading = false;
    });
  }

  Future<void> _goToIndex(int nextIndex) async {
    setState(() => _currentIndex = nextIndex);
    if (_topics.isEmpty) return;
    if (nextIndex == _topics.length - 1 && !_loggedCompletedRun) {
      _loggedCompletedRun = true;
      try {
        await _service.recordCompletedRun();
      } catch (_) {}
    }
  }

  String _depthLabelFor(int index) {
    if (_topics.isEmpty) return '';
    final i = index % _depthLabels.length;
    return _depthLabels[i];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          Text(
            'Questions to spark real conversation — take turns or explore together.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Generate button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _generateMoreTopics,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Generate new cards'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Card area
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: cs.primary,
                      strokeWidth: 2,
                    ),
                  )
                : _topics.isEmpty
                ? Center(
                    child: Text(
                      'No topics yet — tap Generate to start.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    children: [
                      // Progress indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_currentIndex + 1} / ${_topics.length}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              _depthLabelFor(_currentIndex),
                              style: TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Linear progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_currentIndex + 1) / _topics.length,
                          backgroundColor: cs.outlineVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // The card
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF231519)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: cs.primary.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withOpacity(0.06),
                                blurRadius: 24,
                                spreadRadius: 4,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _topics[_currentIndex]['topic'],
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontFamily: 'CormorantGaramond',
                                        fontSize: 22,
                                        fontStyle: FontStyle.italic,
                                        height: 1.45,
                                        color: cs.onSurface,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Navigation row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _NavButton(
                            icon: Icons.arrow_back_rounded,
                            onPressed: _currentIndex > 0
                                ? () {
                                    _goToIndex(_currentIndex - 1);
                                  }
                                : null,
                            cs: cs,
                          ),
                          const SizedBox(width: 48),
                          _NavButton(
                            icon: Icons.arrow_forward_rounded,
                            onPressed: _currentIndex < _topics.length - 1
                                ? () {
                                    _goToIndex(_currentIndex + 1);
                                  }
                                : null,
                            cs: cs,
                            primary: true,
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

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final ColorScheme cs;
  final bool primary;
  const _NavButton({
    required this.icon,
    required this.onPressed,
    required this.cs,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? cs.primary : cs.primaryContainer,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(
            icon,
            color: primary
                ? cs.onPrimary
                : (onPressed == null ? cs.outline : cs.primary),
            size: 22,
          ),
        ),
      ),
    );
  }
}
