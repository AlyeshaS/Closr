part of 'memories_screen.dart';
// ── Timeline Tab ──────────────────────────────────────────────────────────────

class MemoriesTimelineTab extends StatefulWidget {
  const MemoriesTimelineTab({super.key});

  @override
  State<MemoriesTimelineTab> createState() => _MemoriesTimelineTabState();
}

class _MemoriesTimelineTabState extends State<MemoriesTimelineTab> {
  late final Stream<List<TimelineEntry>> _timelineStream = TimelineService()
      .streamTimelineEntries();
  bool _expanded = false; // when true, show up to 3 weeks; otherwise 1 week

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
        label: 'Activities',
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<TimelineEntry>>(
      stream: _timelineStream,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <TimelineEntry>[];

        // Filter entries by recency: default 1 week, expand to 3 weeks.
        final now = DateTime.now();
        final oneWeekAgo = now.subtract(const Duration(days: 7));
        final threeWeeksAgo = now.subtract(const Duration(days: 21));

        final entriesWithinThreeWeeks = entries
            .where((e) => e.occurredAt.isAfter(threeWeeksAgo))
            .toList();
        final visibleEntries = _expanded
            ? entriesWithinThreeWeeks
            : entriesWhereWithin(entries, oneWeekAgo);

        final removedCount = entries.length - entriesWithinThreeWeeks.length;
        final hasMoreToShow =
            entriesWithinThreeWeeks.length >
            entriesWhereWithin(entries, oneWeekAgo).length;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOUR STORY', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primaryContainer.withValues(alpha: 0.8),
                      cs.secondaryContainer.withValues(alpha: 0.45),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: entries.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your timeline is empty right now.',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Log a scrapbook date, finish a quest, or watch something together to start building it.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entries.length} moments logged',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: cs.onPrimaryContainer),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: _buildStats(entries)
                                .map(
                                  (stat) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.surface.withValues(
                                            alpha: 0.78,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              stat.value.toString(),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              stat.label,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelSmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: CircularProgressIndicator(color: cs.primary),
                  ),
                )
              else if (entries.isEmpty)
                const SizedBox.shrink()
              else ...[
                if (removedCount > 0 && visibleEntries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Some older events (more than 3 weeks) were hidden.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (visibleEntries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.7),
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
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Timeline archived for now',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'There are no timeline items in the last 3 weeks yet. Add a scrapbook moment, watch activity, or new quest to bring it back to life.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ...List.generate(visibleEntries.length, (i) {
                    final entry = visibleEntries[i];
                    final previousVisible = i > 0
                        ? visibleEntries[i - 1]
                        : null;
                    final showDate =
                        previousVisible == null ||
                        previousVisible.occurredAt.year !=
                            entry.occurredAt.year ||
                        previousVisible.occurredAt.month !=
                            entry.occurredAt.month ||
                        previousVisible.occurredAt.day != entry.occurredAt.day;

                    final isLastVisible = i == visibleEntries.length - 1;

                    return Padding(
                      padding: EdgeInsets.only(bottom: isLastVisible ? 0 : 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDate) ...[
                            Text(
                              _dateLabel(entry.occurredAt),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: 8),
                          ],
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 32,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: entry.isMilestone ? 16 : 12,
                                        height: entry.isMilestone ? 16 : 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: entry.isMilestone
                                              ? cs.primary
                                              : cs.primaryContainer,
                                          border: entry.isMilestone
                                              ? null
                                              : Border.all(
                                                  color: cs.primary,
                                                  width: 1.5,
                                                ),
                                        ),
                                      ),
                                      if (!isLastVisible)
                                        Expanded(
                                          child: Container(
                                            width: 1.5,
                                            color: cs.primary.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: entry.isMilestone
                                          ? cs.primaryContainer
                                          : (isDark
                                                ? const Color(0xFF231519)
                                                : Colors.white),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: entry.isMilestone
                                            ? cs.primary.withValues(alpha: 0.3)
                                            : cs.outlineVariant,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          entry.emoji,
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    entry.typeLabel,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.labelSmall,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    _relativeLabel(
                                                      entry.occurredAt,
                                                    ),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: cs
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                entry.title,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                entry.subtitle,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                    ),
                                              ),
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
                    );
                  }),
                ],
                if ((hasMoreToShow && !_expanded) || _expanded)
                  const SizedBox(height: 12),
                if (hasMoreToShow && !_expanded)
                  Align(
                    alignment: Alignment.center,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _expanded = true),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Show more'),
                    ),
                  ),
                if (_expanded)
                  Align(
                    alignment: Alignment.center,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _expanded = false),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Show less'),
                    ),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Timeline syncs scrapbook, watch activity, and streak events.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
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
