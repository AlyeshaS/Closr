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
    if (index >= _topics.length) return 'Done';
    final i = index % _depthLabels.length;
    return _depthLabels[i];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final int totalCardCount = _topics.isEmpty ? 0 : _topics.length + 1;
    final bool isAtFinalEndingCard = _currentIndex == _topics.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          // Action Bar Description & Labeled Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Spark real connection — take turns or explore together.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'DMSans',
                    color: cs.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Shadow Container Layer ONLY (No border here)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: !_loading
                      ? [
                          BoxShadow(
                            color: cs.primary.withOpacity(isDark ? 0.06 : 0.12),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: TextButton.icon(
                  onPressed: _loading ? null : _generateMoreTopics,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                  label: const Text(
                    'New Deck',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: cs.primaryContainer.withOpacity(0.9),
                    foregroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                      // Corrected from 'Border.all' to 'BorderSide'
                      side: BorderSide(
                        color: _loading
                            ? cs.outlineVariant.withOpacity(0.1)
                            : cs.primary.withOpacity(isDark ? 0.25 : 0.3),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main Interactive View
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _loading
                  ? Center(
                      key: const ValueKey('loading'),
                      child: CircularProgressIndicator(
                        color: cs.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : _topics.isEmpty
                  ? _buildEmptyState(cs)
                  : Column(
                      key: const ValueKey('content_deck'),
                      children: [
                        // Status Tracking Subheader
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'CARD ${_currentIndex + 1} OF $totalCardCount',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontFamily: 'DMSans',
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: cs.onSurfaceVariant.withOpacity(0.7),
                                  ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _depthLabelFor(_currentIndex).toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontFamily: 'DMSans',
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                          color: cs.primary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Segmented Story-Style Progress Ticks
                        _buildSegmentedProgress(cs, totalCardCount),
                        const SizedBox(height: 24),

                        // Card Stack
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_currentIndex < totalCardCount - 2)
                                _buildCardDeckLayer(
                                  cs,
                                  isDark,
                                  scale: 0.92,
                                  offset: 20,
                                ),
                              if (_currentIndex < totalCardCount - 1)
                                _buildCardDeckLayer(
                                  cs,
                                  isDark,
                                  scale: 0.96,
                                  offset: 10,
                                ),

                              _buildActiveCard(cs, isDark, isAtFinalEndingCard),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Navigation Elements
                        _buildNavigationRow(cs, totalCardCount, isDark),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardDeckLayer(
    ColorScheme cs,
    bool isDark, {
    required double scale,
    required double offset,
  }) {
    return Transform.translate(
      offset: Offset(0, offset),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1215)
                : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: cs.primary.withOpacity(isDark ? 0.1 : 0.15),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCard(
    ColorScheme cs,
    bool isDark,
    bool isAtFinalEndingCard,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF26181C) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: cs.primary.withOpacity(isDark ? 0.25 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(isDark ? 0.04 : 0.06),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned(
              bottom: -30,
              left: -30,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: cs.primary.withOpacity(0.015),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: SingleChildScrollView(
                    key: ValueKey('topic_${_currentIndex}'),
                    physics: const BouncingScrollPhysics(),
                    child: isAtFinalEndingCard
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 36,
                                color: cs.primary.withOpacity(0.8),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Create a new deck by clicking the new deck button.',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontFamily: 'DMSans',
                                      fontSize: 18,
                                      height: 1.5,
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : Text(
                            _topics[_currentIndex]['topic'],
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontFamily: 'CormorantGaramond',
                                  fontSize: 25,
                                  fontStyle: FontStyle.italic,
                                  height: 1.5,
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w400,
                                ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedProgress(ColorScheme cs, int totalCardCount) {
    return Row(
      children: List.generate(totalCardCount, (index) {
        bool isActive = index <= _currentIndex;
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: index == totalCardCount - 1 ? 0 : 4),
            decoration: BoxDecoration(
              color: isActive
                  ? cs.primary
                  : cs.outlineVariant.withOpacity(0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNavigationRow(ColorScheme cs, int totalCardCount, bool isDark) {
    final bool canGoBack = _currentIndex > 0;
    final bool canGoForward = _currentIndex < totalCardCount - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlCircle(
          icon: Icons.chevron_left_rounded,
          onPressed: canGoBack ? () => _goToIndex(_currentIndex - 1) : null,
          cs: cs,
          isDark: isDark,
        ),
        const SizedBox(width: 32),
        _ControlCircle(
          icon: Icons.chevron_right_rounded,
          onPressed: canGoForward ? () => _goToIndex(_currentIndex + 1) : null,
          cs: cs,
          isPrimary: true,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      key: const ValueKey('empty_state'),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_outlined, size: 48, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              'No deck active.',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the "New Deck" button at the top right to generate your questions!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'DMSans',
                color: cs.onSurfaceVariant.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final ColorScheme cs;
  final bool isPrimary;
  final bool isDark;

  const _ControlCircle({
    required this.icon,
    required this.onPressed,
    required this.cs,
    required this.isDark,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;

    Color getBgColor() {
      if (isDisabled) return cs.surfaceContainerHighest.withOpacity(0.15);
      return isPrimary ? cs.primary : cs.primary.withOpacity(0.08);
    }

    Color getIconColor() {
      if (isDisabled) return cs.onSurface.withOpacity(0.2);
      return isPrimary ? cs.onPrimary : cs.primary;
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDisabled
              ? cs.outlineVariant.withOpacity(0.1)
              : cs.primary.withOpacity(isPrimary ? 0.1 : 0.25),
          width: 1,
        ),
        boxShadow: !isDisabled
            ? [
                BoxShadow(
                  color: isPrimary
                      ? cs.primary.withOpacity(isDark ? 0.18 : 0.28)
                      : cs.primary.withOpacity(isDark ? 0.04 : 0.08),
                  blurRadius: isPrimary ? 16 : 10,
                  spreadRadius: 0,
                  offset: isPrimary ? const Offset(0, 6) : const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: getBgColor(),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          splashColor: cs.primary.withOpacity(0.15),
          highlightColor: cs.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(icon, color: getIconColor(), size: 26),
          ),
        ),
      ),
    );
  }
}
