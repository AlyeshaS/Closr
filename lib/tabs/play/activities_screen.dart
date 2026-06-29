// activities_screen.dart
import 'package:flutter/material.dart';
import '../suggestions/suggestions_screen.dart';
import '../../services/streaks_service.dart';
import 'games_dashboard_tab.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                color: Colors.transparent,
                child: TabBar(
                  controller: _tabController,
                  dividerColor: cs.outlineVariant,
                  indicatorColor: cs.primary,
                  indicatorWeight: 2,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  tabs: const [
                    Tab(text: 'Quests'),
                    Tab(text: 'Games'),
                    Tab(text: 'Date Generator'),
                    Tab(text: 'Date Ideas'),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const _QuestsTab(),
                const GamesDashboardTab(), // Styled game hub with functional real-time scores
                _ComingSoonTab(
                  icon: Icons.explore_outlined,
                  title: 'Date Generator',
                  subtitle:
                      'Tell us your mood, time, and budget — we\'ll plan the perfect date.',
                  cs: cs,
                ),
                const SuggestionsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quests Tab ────────────────────────────────────────────────────────────────
class _QuestsTab extends StatefulWidget {
  const _QuestsTab();

  @override
  State<_QuestsTab> createState() => _QuestsTabState();
}

class _QuestsTabState extends State<_QuestsTab> {
  final List<Map<String, dynamic>> _quests = [
    {'title': 'Cook a new recipe together', 'done': true, 'emoji': '🍳'},
    {'title': 'Watch the sunset', 'done': true, 'emoji': '🌅'},
    {'title': 'Write each other a compliment', 'done': false, 'emoji': '💌'},
    {'title': 'Take a photo together today', 'done': false, 'emoji': '📸'},
    {'title': 'Try a new coffee shop', 'done': false, 'emoji': '☕'},
    {'title': 'Play a board game', 'done': false, 'emoji': '🎲'},
  ];

  int get _completedCount => _quests.where((q) => q['done'] == true).length;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This week\'s quest',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$_completedCount / ${_quests.length} completed',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _completedCount / _quests.length,
                          backgroundColor: cs.primary.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${((_completedCount / _quests.length) * 100).round()}%',
                  style: TextStyle(
                    fontFamily: 'CormorantGaramond',
                    fontSize: 36,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('ACTIVITIES', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          ...List.generate(_quests.length, (i) {
            final quest = _quests[i];
            final done = quest['done'] as bool;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () async {
                  setState(() => _quests[i]['done'] = !done);
                  try {
                    if (!done) {
                      await StreaksService().recordActivity('quest_completed');
                    }
                  } catch (_) {}
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: done
                        ? cs.primaryContainer.withOpacity(0.5)
                        : (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF231519)
                              : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: done
                          ? cs.primary.withOpacity(0.3)
                          : cs.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: done
                              ? cs.primaryContainer
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            quest['emoji'],
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          quest['title'],
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: done
                                    ? cs.onSurfaceVariant
                                    : cs.onSurface,
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: done ? cs.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: done ? cs.primary : cs.outline,
                            width: 1.5,
                          ),
                        ),
                        child: done
                            ? Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: cs.onPrimary,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'More quests & bingo challenges coming soon',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Coming Soon widget ─────────────────────────────────────────────────
class _ComingSoonTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme cs;
  const _ComingSoonTab({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primaryContainer,
              ),
              child: Icon(icon, size: 32, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Coming soon',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
