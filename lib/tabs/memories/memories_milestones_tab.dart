// lib/memories/memories_milestones_tab.dart
part of 'memories_screen.dart';

class MemoriesMilestonesTab extends StatelessWidget {
  const MemoriesMilestonesTab({super.key});

  @override
  Widget build(BuildContext context) => const _MilestonesGoalsContentTab();
}

class _MilestonesGoalsContentTab extends StatefulWidget {
  const _MilestonesGoalsContentTab();

  @override
  State<_MilestonesGoalsContentTab> createState() =>
      _MilestonesGoalsContentTabState();
}

class _MilestonesGoalsContentTabState extends State<_MilestonesGoalsContentTab>
    with TickerProviderStateMixin {
  int _selectedTabIndex = 0; // 0: For Us, 1: For Me, 2: Badges

  int userCoins = 140;
  final int nextRewardTarget = 300;
  final String nextAccessoryName = 'Party Hat';

  late AnimationController _celebrationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _showCelebration = false;
  String _celebrationTitle = '';

  // Burst animation controllers & particles
  late AnimationController _burstAnimController;
  bool _showNudgeBurst = false;
  IconData? _burstIcon;
  final List<_ParticleTrajectory> _particles = [];

  List<Map<String, dynamic>> customNudges = [
    {'icon': Icons.water_drop_rounded, 'label': 'Water'},
    {'icon': Icons.medication_rounded, 'label': 'Vitamins'},
    {'icon': Icons.restaurant_rounded, 'label': 'Snack'},
    {'icon': Icons.volunteer_activism_rounded, 'label': 'Hug'},
    {'icon': Icons.bedtime_rounded, 'label': 'Sleep'},
  ];

  final List<Map<String, dynamic>> coupleGoals = [
    {
      'id': '1',
      'title': 'Cook a homemade pasta dinner',
      'category': 'Date Night',
      'points': 10,
      'isCompleted': false,
      'icon': Icons.dinner_dining_rounded,
    },
    {
      'id': '2',
      'title': 'Stargazing picnic in the park',
      'category': 'Adventure',
      'points': 8,
      'isCompleted': true,
      'icon': Icons.nightlight_round,
    },
    {
      'id': '3',
      'title': 'Complete a 1000-piece puzzle',
      'category': 'Cozy',
      'points': 10,
      'isCompleted': false,
      'icon': Icons.extension_rounded,
    },
  ];

  final List<Map<String, dynamic>> personalGoals = [
    {
      'id': 'p1',
      'title': 'Drink 2L of water daily',
      'category': 'Self-Care',
      'points': 3,
      'isCompleted': false,
      'icon': Icons.water_drop_rounded,
    },
    {
      'id': 'p2',
      'title': 'Daily 30 min workout or walk',
      'category': 'Fitness',
      'points': 5,
      'isCompleted': false,
      'icon': Icons.fitness_center_rounded,
    },
    {
      'id': 'p3',
      'title': 'Read 10 pages before bed',
      'category': 'Mindfulness',
      'points': 5,
      'isCompleted': true,
      'icon': Icons.auto_stories_rounded,
    },
  ];

  final List<Map<String, dynamic>> achievements = [
    {
      'id': 'a1',
      'title': 'Memory Keeper',
      'description': 'Add 5 entries to your shared scrapbook',
      'progress': 3,
      'target': 5,
      'points': 100,
      'isUnlocked': false,
      'icon': Icons.photo_library_rounded,
    },
    {
      'id': 'a2',
      'title': 'Love Notes',
      'description': 'Send 10 love letters or notes',
      'progress': 10,
      'target': 10,
      'points': 150,
      'isUnlocked': true,
      'icon': Icons.mark_email_read_rounded,
    },
    {
      'id': 'a3',
      'title': 'Week of Harmony',
      'description': 'Maintain a 7-day active goal streak',
      'progress': 4,
      'target': 7,
      'points': 120,
      'isUnlocked': false,
      'icon': Icons.local_fire_department_rounded,
    },
    {
      'id': 'a4',
      'title': 'Duo Explorers',
      'description': 'Complete 5 shared couple bucket list items',
      'progress': 5,
      'target': 5,
      'points': 200,
      'isUnlocked': true,
      'icon': Icons.explore_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();

    // Goal set celebration
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.25,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.25,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_celebrationController);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_celebrationController);

    _celebrationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showCelebration = false);
      }
    });

    // Icon Burst Animation Setup
    _burstAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _burstAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showNudgeBurst = false);
      }
    });
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _burstAnimController.dispose();
    super.dispose();
  }

  void _triggerAddGoalCelebration(String goalTitle) {
    setState(() {
      _celebrationTitle = goalTitle;
      _showCelebration = true;
    });
    _celebrationController.forward(from: 0.0);
  }

  void _sendNudge(
    String title, {
    IconData icon = Icons.volunteer_activism_rounded,
  }) {
    HapticFeedback.lightImpact();

    final random = math.Random();
    _particles.clear();

    for (int i = 0; i < 10; i++) {
      final angle =
          (i * (2 * math.pi / 10)) + (random.nextDouble() * 0.4 - 0.2);
      final distance = 90.0 + random.nextDouble() * 110.0;
      final targetOffset = Offset(
        math.cos(angle) * distance,
        math.sin(angle) * distance - 30.0,
      );
      _particles.add(
        _ParticleTrajectory(
          targetOffset: targetOffset,
          size: 26.0 + random.nextDouble() * 18.0,
          rotation: (random.nextDouble() - 0.5) * 1.2,
        ),
      );
    }

    setState(() {
      _burstIcon = icon;
      _showNudgeBurst = true;
    });
    _burstAnimController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _buildPetHeroCard(colorScheme),
            const SizedBox(height: 18),
            _buildQuickNudgeSection(colorScheme),
            const SizedBox(height: 20),
            _buildSegmentedTab(colorScheme),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _buildActiveTabContent(colorScheme),
            ),
            const SizedBox(height: 40),
          ],
        ),
        if (_showNudgeBurst) _buildIconBurstOverlay(colorScheme),
        if (_showCelebration) _buildCelebrationOverlay(colorScheme),
      ],
    );
  }

  Widget _buildActiveTabContent(ColorScheme colorScheme) {
    if (_selectedTabIndex == 0) {
      return Column(
        key: const ValueKey('couple_tab'),
        children: [
          ...coupleGoals.map(
            (g) => _buildGoalCard(
              goal: g,
              isCoupleGoal: true,
              colorScheme: colorScheme,
            ),
          ),
          const SizedBox(height: 8),
          _buildAddGoalButton(
            label: 'Add Couple Goal',
            colorScheme: colorScheme,
          ),
        ],
      );
    } else if (_selectedTabIndex == 1) {
      return Column(
        key: const ValueKey('personal_tab'),
        children: [
          ...personalGoals.map(
            (g) => _buildGoalCard(
              goal: g,
              isCoupleGoal: false,
              colorScheme: colorScheme,
            ),
          ),
          const SizedBox(height: 8),
          _buildAddGoalButton(
            label: 'Add Personal Goal',
            colorScheme: colorScheme,
          ),
        ],
      );
    } else {
      return Column(
        key: const ValueKey('badges_tab'),
        children: achievements
            .map(
              (a) => _buildAchievementCard(
                achievement: a,
                colorScheme: colorScheme,
              ),
            )
            .toList(),
      );
    }
  }

  Widget _buildPetHeroCard(ColorScheme colors) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = (userCoins / nextRewardTarget).clamp(0.0, 1.0);
    final pointsRemaining = (nextRewardTarget - userCoins).clamp(
      0,
      nextRewardTarget,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: colors.primary.withValues(alpha: isDark ? 0.18 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
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
                  colors.primaryContainer.withValues(alpha: 0.85),
                  colors.secondaryContainer.withValues(alpha: 0.55),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.pets_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "MOCHI'S ACCESSORY",
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.3,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Unlock $nextAccessoryName',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return Container(
                            height: 10,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: value,
                                backgroundColor: isDark
                                    ? colors.surfaceContainerHighest
                                    : colors.primary.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colors.primary,
                                ),
                                minHeight: 10,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$pointsRemaining pts until $nextAccessoryName is unlocked',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: userCoins),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$val',
                          style: TextStyle(
                            fontFamily: 'CormorantGaramond',
                            fontSize: 34,
                            height: 1.0,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        Text(
                          'points',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.primary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickNudgeSection(ColorScheme colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                Text(
                  'CARE & NUDGES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _openManageNudgesModal,
              icon: Icon(Icons.tune_rounded, size: 14, color: colors.primary),
              label: Text(
                'Customize',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 56,
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            itemCount: customNudges.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == customNudges.length) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? colors.surfaceContainerLow : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.35)
                            : colors.primary.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openAddCustomNudgeDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'New',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              final nudge = customNudges[index];
              final iconData = nudge['icon'] as IconData;
              final label = nudge['label'] as String;

              return Container(
                decoration: BoxDecoration(
                  color: isDark ? colors.surfaceContainerLow : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.9),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _sendNudge(label, icon: iconData),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconData, size: 16, color: colors.primary),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedTab(ColorScheme colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = [
      ('For Us', Icons.favorite_rounded),
      ('For Me', Icons.person_rounded),
      ('Badges', Icons.military_tech_rounded),
    ];

    final alignment = _selectedTabIndex == 0
        ? Alignment.centerLeft
        : _selectedTabIndex == 1
        ? Alignment.center
        : Alignment.centerRight;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: alignment,
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(tabs.length, (index) {
              final isSelected = _selectedTabIndex == index;
              final tab = tabs[index];

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selectedTabIndex = index),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.$2,
                          size: 15,
                          color: isSelected
                              ? colors.onPrimary
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? colors.onPrimary
                                : colors.onSurfaceVariant,
                          ),
                          child: Text(tab.$1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard({
    required Map<String, dynamic> goal,
    required bool isCoupleGoal,
    required ColorScheme colorScheme,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = goal['isCompleted'] as bool;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            goal['isCompleted'] = !isCompleted;
            if (goal['isCompleted']) {
              userCoins += (goal['points'] as int);
            } else {
              userCoins -= (goal['points'] as int);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCompleted
                ? (isDark
                      ? const Color(0xFF1E2B24)
                      : colorScheme.primaryContainer.withValues(alpha: 0.35))
                : (isDark ? colorScheme.surfaceContainerLow : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCompleted
                  ? colorScheme.primary.withValues(alpha: 0.6)
                  : colorScheme.outlineVariant.withValues(alpha: 0.9),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isCompleted
                    ? colorScheme.primary.withValues(alpha: 0.05)
                    : (isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.06)),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? colorScheme.primaryContainer.withValues(alpha: 0.85)
                      : colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    goal['icon'] as IconData,
                    size: 22,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal['title'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: isCompleted
                            ? FontWeight.normal
                            : FontWeight.w600,
                        color: isCompleted
                            ? colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              )
                            : colorScheme.onSurface,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          goal['category'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+${goal['points']} pts',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isCoupleGoal && !isCompleted)
                IconButton(
                  icon: const Icon(
                    Icons.notifications_active_outlined,
                    size: 20,
                  ),
                  color: colorScheme.primary,
                  tooltip: 'Remind partner',
                  onPressed: () => _sendNudge(
                    goal['title'] as String,
                    icon: goal['icon'] as IconData,
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCompleted
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  boxShadow: isCompleted
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: isCompleted
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: colorScheme.onPrimary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard({
    required Map<String, dynamic> achievement,
    required ColorScheme colorScheme,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnlocked = achievement['isUnlocked'] as bool;
    final progress =
        (achievement['progress'] as int) / (achievement['target'] as int);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnlocked
              ? (isDark
                    ? const Color(0xFF1E2B24)
                    : colorScheme.primaryContainer.withValues(alpha: 0.35))
              : (isDark ? colorScheme.surfaceContainerLow : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isUnlocked
                ? colorScheme.primary.withValues(alpha: 0.6)
                : colorScheme.outlineVariant.withValues(alpha: 0.9),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isUnlocked
                  ? colorScheme.primary.withValues(alpha: 0.05)
                  : (isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.06)),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? colorScheme.primaryContainer.withValues(alpha: 0.85)
                    : colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  achievement['icon'] as IconData,
                  size: 22,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        achievement['title'] as String,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.6,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${achievement['points']} pts',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement['description'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: progress.clamp(0.0, 1.0),
                    ),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: isDark
                              ? colorScheme.surfaceContainerHighest
                              : colorScheme.primary.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${achievement['progress']}/${achievement['target']}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
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
  }

  Widget _buildAddGoalButton({
    required String label,
    required ColorScheme colorScheme,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: () => _openAddGoalModal(context),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildIconBurstOverlay(ColorScheme colors) {
    if (_burstIcon == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _burstAnimController,
          builder: (context, child) {
            final t = _burstAnimController.value;
            final curvedT = Curves.easeOutCubic.transform(t);
            final fadeOut = (1.0 - t).clamp(0.0, 1.0);

            return Center(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Transform.scale(
                    scale: 1.0 + (curvedT * 0.8),
                    child: Opacity(
                      opacity: fadeOut,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary.withValues(alpha: 0.15),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(
                                alpha: 0.35 * fadeOut,
                              ),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          _burstIcon,
                          size: 52,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                  ..._particles.map((p) {
                    final particleOffset = Offset(
                      p.targetOffset.dx * curvedT,
                      p.targetOffset.dy * curvedT,
                    );
                    final particleScale = (1.0 - (t * 0.4)).clamp(0.0, 1.0);

                    return Transform.translate(
                      offset: particleOffset,
                      child: Transform.rotate(
                        angle: p.rotation * curvedT,
                        child: Transform.scale(
                          scale: particleScale,
                          child: Opacity(
                            opacity: fadeOut,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withValues(
                                      alpha: 0.25 * fadeOut,
                                    ),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _burstIcon,
                                size: p.size,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCelebrationOverlay(ColorScheme colors) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _celebrationController,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.25),
                          blurRadius: 28,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 36,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Goal Set!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _celebrationTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openAddCustomNudgeDialog() {
    final labelCtrl = TextEditingController();
    IconData selectedIcon = Icons.notifications_active_rounded;

    final expandedNudgeIcons = [
      Icons.water_drop_rounded,
      Icons.restaurant_rounded,
      Icons.medication_rounded,
      Icons.bedtime_rounded,
      Icons.volunteer_activism_rounded,
      Icons.favorite_rounded,
      Icons.fitness_center_rounded,
      Icons.directions_walk_rounded,
      Icons.spa_rounded,
      Icons.self_improvement_rounded,
      Icons.wb_sunny_rounded,
      Icons.battery_charging_full_rounded,
      Icons.coffee_rounded,
      Icons.menu_book_rounded,
      Icons.music_note_rounded,
      Icons.pets_rounded,
      Icons.cleaning_services_rounded,
      Icons.call_rounded,
      Icons.chat_bubble_rounded,
      Icons.celebration_rounded,
      Icons.psychology_rounded,
      Icons.brush_rounded,
      Icons.notifications_active_rounded,
    ];

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final colors = Theme.of(context).colorScheme;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'New Care Nudge',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: labelCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nudge Label',
                        hintText: 'e.g. Stretch, Call Me, Unclench Jaw',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Pick an Icon',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: expandedNudgeIcons.map((icon) {
                        final isSel = selectedIcon == icon;
                        return InkWell(
                          onTap: () => setDlgState(() => selectedIcon = icon),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? colors.primary
                                  : colors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              size: 20,
                              color: isSel ? Colors.white : colors.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (labelCtrl.text.trim().isEmpty) return;
                  setState(() {
                    customNudges.add({
                      'icon': selectedIcon,
                      'label': labelCtrl.text.trim(),
                    });
                  });
                  Navigator.pop(dlgCtx);
                },
                child: const Text('Save Nudge'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddGoalModal(BuildContext context) {
    final titleController = TextEditingController();
    final categoryController = TextEditingController(
      text: _selectedTabIndex == 0 ? 'Date Night' : 'Self-Care',
    );
    int selectedPoints = 5;
    IconData selectedIcon = _selectedTabIndex == 0
        ? Icons.favorite_rounded
        : Icons.star_rounded;
    String? titleError;

    final selectableGoalIcons = [
      Icons.favorite_rounded,
      Icons.star_rounded,
      Icons.water_drop_rounded,
      Icons.fitness_center_rounded,
      Icons.auto_stories_rounded,
      Icons.restaurant_rounded,
      Icons.flight_takeoff_rounded,
      Icons.movie_rounded,
      Icons.park_rounded,
      Icons.music_note_rounded,
      Icons.spa_rounded,
      Icons.brush_rounded,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final colors = Theme.of(modalCtx).colorScheme;
          final isDark = Theme.of(modalCtx).brightness == Brightness.dark;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedTabIndex == 0
                        ? 'Create Couple Goal'
                        : 'Create Personal Goal',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    onChanged: (val) {
                      if (titleError != null && val.trim().isNotEmpty) {
                        setModalState(() => titleError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Goal Title',
                      hintText: 'e.g. Try a new coffee shop',
                      errorText: titleError,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category (Optional)',
                      hintText: 'e.g. Adventure, Wellness',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Icon',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectableGoalIcons.map((iconData) {
                      final isChosen = selectedIcon == iconData;
                      return ChoiceChip(
                        selected: isChosen,
                        showCheckmark: false,
                        label: Icon(
                          iconData,
                          size: 18,
                          color: isChosen ? Colors.white : colors.primary,
                        ),
                        selectedColor: colors.primary,
                        backgroundColor: colors.primary.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onSelected: (_) =>
                            setModalState(() => selectedIcon = iconData),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reward Points',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Max 10 pts',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [2, 3, 5, 8, 10].map((pts) {
                      final isChosen = selectedPoints == pts;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () =>
                                setModalState(() => selectedPoints = pts),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isChosen
                                    ? colors.primary
                                    : (isDark
                                          ? colors.surfaceContainerHighest
                                          : colors.surface),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isChosen
                                      ? colors.primary
                                      : colors.outlineVariant.withValues(
                                          alpha: 0.7,
                                        ),
                                  width: isChosen ? 1.5 : 1.0,
                                ),
                                boxShadow: isChosen
                                    ? [
                                        BoxShadow(
                                          color: colors.primary.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.03,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '+$pts',
                                    style: TextStyle(
                                      color: isChosen
                                          ? Colors.white
                                          : colors.onSurface,
                                      fontWeight: isChosen
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'pts',
                                    style: TextStyle(
                                      color: isChosen
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: const Text(
                        'Add Goal',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        if (titleController.text.trim().isEmpty) {
                          setModalState(() {
                            titleError = 'Please enter a goal title';
                          });
                          return;
                        }

                        final newGoal = {
                          'id': DateTime.now().millisecondsSinceEpoch
                              .toString(),
                          'title': titleController.text.trim(),
                          'category': categoryController.text.trim().isEmpty
                              ? 'General'
                              : categoryController.text.trim(),
                          'points': selectedPoints,
                          'isCompleted': false,
                          'icon': selectedIcon,
                        };

                        setState(() {
                          if (_selectedTabIndex == 0) {
                            coupleGoals.add(newGoal);
                          } else {
                            personalGoals.add(newGoal);
                          }
                        });

                        Navigator.pop(modalCtx);
                        _triggerAddGoalCelebration(newGoal['title'] as String);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openManageNudgesModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final colors = Theme.of(context).colorScheme;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Manage Care Nudges',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      color: colors.primary,
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openAddCustomNudgeDialog();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...customNudges.map((nudge) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        nudge['icon'] as IconData,
                        size: 18,
                        color: colors.primary,
                      ),
                    ),
                    title: Text(
                      nudge['label'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      onPressed: () {
                        setState(() {
                          customNudges.remove(nudge);
                        });
                        setModalState(() {});
                      },
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ParticleTrajectory {
  final Offset targetOffset;
  final double size;
  final double rotation;

  _ParticleTrajectory({
    required this.targetOffset,
    required this.size,
    required this.rotation,
  });
}
