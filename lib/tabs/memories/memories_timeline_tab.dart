// lib/memories/memories_timeline_tab.dart
part of 'memories_screen.dart';

// ── Section Label Helper ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _SectionLabel({required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        ),
        Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.1,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ── Timeline Tab ──────────────────────────────────────────────────────────────

class MemoriesTimelineTab extends StatefulWidget {
  const MemoriesTimelineTab({super.key});

  @override
  State<MemoriesTimelineTab> createState() => _MemoriesTimelineTabState();
}

class _MemoriesTimelineTabState extends State<MemoriesTimelineTab>
    with AutomaticKeepAliveClientMixin {
  late final Stream<List<TimelineEntry>> _timelineStream;
  bool _expanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _timelineStream = TimelineService().streamTimelineEntries();
  }

  String _dateLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final now = DateTime.now();
    final dayStart = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diffDays = today.difference(dayStart).inDays;

    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    if (diffDays < 7) return '$diffDays days ago';
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _relativeLabel(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return '1 day ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return _dateLabel(date);
  }

  List<_TimelineStats> _buildStats(List<TimelineEntry> entries) {
    return [
      _TimelineStats(
        label: 'Dates',
        value: entries
            .where((entry) => entry.type == TimelineEntryType.scrapbook)
            .length,
      ),
      _TimelineStats(
        label: 'Watches',
        value: entries
            .where((entry) => entry.type == TimelineEntryType.watch)
            .length,
      ),
      _TimelineStats(
        label: 'Games',
        value: entries
            .where((entry) => entry.type == TimelineEntryType.activity)
            .length,
      ),
    ];
  }

  List<TimelineEntry> entriesWhereWithin(
    List<TimelineEntry> entries,
    DateTime cutoff,
  ) {
    return entries.where((e) => !e.occurredAt.isBefore(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<TimelineEntry>>(
      stream: _timelineStream,
      builder: (context, snapshot) {
        // Wait for the stream's first (always complete) result. No
        // spinner -- just a blank frame that the AnimatedSwitcher below
        // dissolves into the real content.
        if (!snapshot.hasData) {
          return const AnimatedSwitcher(
            duration: Duration(milliseconds: 320),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: SizedBox.shrink(key: ValueKey('timeline_loading')),
          );
        }

        final entries = snapshot.data ?? const <TimelineEntry>[];

        final now = DateTime.now();
        final oneWeekAgo = now.subtract(const Duration(days: 7));
        final threeWeeksAgo = now.subtract(const Duration(days: 21));

        final entriesWithinThreeWeeks = entries
            .where((e) => e.occurredAt.isAfter(threeWeeksAgo))
            .toList();
        final visibleEntries = _expanded
            ? entriesWithinThreeWeeks
            : entriesWhereWithin(entries, oneWeekAgo);

        final hasMoreToShow =
            entriesWithinThreeWeeks.length >
            entriesWhereWithin(entries, oneWeekAgo).length;

        final stats = _buildStats(entries);

        return SingleChildScrollView(
          key: const PageStorageKey('memories_timeline_scroll'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Stats Card matching Quests Progress Card Styling and Timing
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withOpacity(0.07),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                    BoxShadow(
                      color: cs.primary.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cs.primaryContainer.withOpacity(0.85),
                            cs.secondaryContainer.withOpacity(0.55),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: cs.primary.withOpacity(0.35),
                          width: 1,
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        switchInCurve: Curves.easeInOutCubic,
                        switchOutCurve: Curves.easeInOutCubic,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: entries.isEmpty
                            ? Column(
                                key: const ValueKey('top_empty'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TIMELINE SUMMARY',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          letterSpacing: 1.3,
                                          fontWeight: FontWeight.bold,
                                          color: cs.primary,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Your timeline is empty right now.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: cs.onSurface,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Log a scrapbook date, finish a quest, or watch something together to start building it.',
                                    style: TextStyle(
                                      fontFamily: 'DMSans',
                                      fontSize: 14,
                                      height: 1.45,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                key: const ValueKey('top_stats'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TIMELINE STATS',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          letterSpacing: 1.3,
                                          fontWeight: FontWeight.bold,
                                          color: cs.primary,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  TweenAnimationBuilder<double>(
                                    key: ValueKey(entries.length),
                                    tween: Tween<double>(
                                      begin: 0.0,
                                      end: entries.length.toDouble(),
                                    ),
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, animatedCount, _) {
                                      return Text(
                                        '${animatedCount.round()} Moments Logged',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: cs.onSurface,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: stats.map((stat) {
                                      return Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? cs.surfaceContainerLowest
                                                      .withOpacity(0.5)
                                                : Colors.white.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: cs.primary.withOpacity(
                                                0.2,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              TweenAnimationBuilder<double>(
                                                key: ValueKey(stat.value),
                                                tween: Tween<double>(
                                                  begin: 0.0,
                                                  end: stat.value.toDouble(),
                                                ),
                                                duration: const Duration(
                                                  milliseconds: 350,
                                                ),
                                                curve: Curves.easeOutCubic,
                                                builder:
                                                    (context, animatedVal, _) {
                                                      return Text(
                                                        '${animatedVal.round()}',
                                                        style: TextStyle(
                                                          fontFamily: 'DMSans',
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: cs.primary,
                                                        ),
                                                      );
                                                    },
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                stat.label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily: 'DMSans',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: cs.onSurfaceVariant
                                                      .withOpacity(0.9),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),
              _SectionLabel(text: 'Your story', cs: cs),
              const SizedBox(height: 14),

              if (entries.isEmpty)
                const SizedBox.shrink()
              else if (visibleEntries.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF231519) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.archive_outlined,
                            color: cs.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Timeline archived for now',
                            style: TextStyle(
                              fontFamily: 'CormorantGaramond',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'There are no timeline items in the last 3 weeks yet. Add a scrapbook moment, watch activity, or new quest to bring it back to life.',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 13,
                          height: 1.45,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Pure dissolve matching quests list animation timing (350ms + i * 80ms, Curves.easeInOut)
                ...List.generate(visibleEntries.length, (i) {
                  final entry = visibleEntries[i];
                  final previousVisible = i > 0 ? visibleEntries[i - 1] : null;
                  final showDate =
                      previousVisible == null ||
                      previousVisible.occurredAt.year !=
                          entry.occurredAt.year ||
                      previousVisible.occurredAt.month !=
                          entry.occurredAt.month ||
                      previousVisible.occurredAt.day != entry.occurredAt.day;

                  final isLastVisible = i == visibleEntries.length - 1;

                  return Padding(
                    padding: EdgeInsets.only(bottom: isLastVisible ? 0 : 12),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(entry.id),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 350 + (i * 80)),
                      curve: Curves.easeInOut,
                      builder: (context, opacityValue, child) {
                        return Opacity(opacity: opacityValue, child: child);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDate) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              child: Text(
                                _dateLabel(entry.occurredAt).toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ],
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 18),
                                      Container(
                                        width: entry.isMilestone ? 14 : 10,
                                        height: entry.isMilestone ? 14 : 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: entry.isMilestone
                                              ? cs.primary
                                              : cs.surface,
                                          border: Border.all(
                                            color: cs.primary,
                                            width: entry.isMilestone ? 0 : 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: cs.primary.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isLastVisible)
                                        Expanded(
                                          child: Container(
                                            width: 1.5,
                                            color: cs.primary.withOpacity(0.2),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: entry.isMilestone
                                          ? cs.primaryContainer.withOpacity(0.4)
                                          : (isDark
                                                ? const Color(0xFF231519)
                                                : Colors.white),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: entry.isMilestone
                                            ? cs.primaryContainer.withOpacity(
                                                0.4,
                                              )
                                            : cs.primary.withOpacity(
                                                isDark ? 0.2 : 0.25,
                                              ),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: cs.primary.withOpacity(0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: cs.primaryContainer
                                                .withOpacity(0.5),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            entry.emoji,
                                            style: const TextStyle(
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    entry.typeLabel
                                                        .toUpperCase(),
                                                    style: TextStyle(
                                                      fontFamily: 'DMSans',
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 0.8,
                                                      color: cs.primary,
                                                    ),
                                                  ),
                                                  Text(
                                                    _relativeLabel(
                                                      entry.occurredAt,
                                                    ),
                                                    style: TextStyle(
                                                      fontFamily: 'DMSans',
                                                      fontSize: 11,
                                                      color: cs.onSurfaceVariant
                                                          .withOpacity(0.7),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                entry.title,
                                                style: TextStyle(
                                                  fontFamily:
                                                      'CormorantGaramond',
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: cs.onSurface,
                                                ),
                                              ),
                                              if (entry
                                                  .subtitle
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  entry.subtitle,
                                                  style: TextStyle(
                                                    fontFamily: 'DMSans',
                                                    fontSize: 13,
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              if ((hasMoreToShow && !_expanded) || _expanded)
                const SizedBox(height: 16),

              if (hasMoreToShow && !_expanded)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(isDark ? 0.18 : 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => setState(() => _expanded = true),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: const Text(
                      'Show More',
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

              if (_expanded)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(isDark ? 0.18 : 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => setState(() => _expanded = false),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: const Text(
                      'Show Less',
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Timeline syncs scrapbook, watch activity, and streak events.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    color: cs.onSurfaceVariant.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineStats {
  final String label;
  final int value;

  const _TimelineStats({required this.label, required this.value});
}
