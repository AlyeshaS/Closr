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
    with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0; // 0: For Us, 1: For Me, 2: Badges

  int userCoins = 240;
  final int nextRewardTarget = 300;

  late AnimationController _celebrationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _showCelebration = false;
  String _celebrationTitle = '';

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
      'points': 50,
      'isCompleted': false,
      'icon': Icons.dinner_dining_rounded,
    },
    {
      'id': '2',
      'title': 'Stargazing picnic in the park',
      'category': 'Adventure',
      'points': 40,
      'isCompleted': true,
      'icon': Icons.nightlight_round,
    },
    {
      'id': '3',
      'title': 'Complete a 1000-piece puzzle',
      'category': 'Cozy',
      'points': 60,
      'isCompleted': false,
      'icon': Icons.extension_rounded,
    },
  ];

  final List<Map<String, dynamic>> personalGoals = [
    {
      'id': 'p1',
      'title': 'Drink 2L of water daily',
      'category': 'Self-Care',
      'points': 15,
      'isCompleted': false,
      'icon': Icons.water_drop_rounded,
    },
    {
      'id': 'p2',
      'title': 'Daily 30 min workout or walk',
      'category': 'Fitness',
      'points': 20,
      'isCompleted': false,
      'icon': Icons.fitness_center_rounded,
    },
    {
      'id': 'p3',
      'title': 'Read 10 pages before bed',
      'category': 'Mindfulness',
      'points': 15,
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
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  void _triggerAddGoalCelebration(String goalTitle) {
    setState(() {
      _celebrationTitle = goalTitle;
      _showCelebration = true;
    });
    _celebrationController.forward(from: 0.0);
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
              duration: const Duration(milliseconds: 300),
              child: _buildActiveTabContent(colorScheme),
            ),
            const SizedBox(height: 40),
          ],
        ),
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
    final progress = (userCoins / nextRewardTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary.withValues(alpha: 0.18),
                  colors.primary.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.pets_rounded, size: 30, color: colors.primary),
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
                      'Mochi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colors.onSurface,
                      ),
                    ),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: userCoins),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.stars_rounded,
                                size: 16,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$val pts',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 7,
                        backgroundColor: colors.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.primary,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  '${(nextRewardTarget - userCoins).clamp(0, nextRewardTarget)} pts to unlock next accessory',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNudgeSection(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Care & Nudges',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
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
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: customNudges.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == customNudges.length) {
                return ActionChip(
                  backgroundColor: colors.surface,
                  side: BorderSide(
                    color: colors.primary.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  avatar: Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: colors.primary,
                  ),
                  label: Text(
                    'New',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                  onPressed: _openAddCustomNudgeDialog,
                );
              }

              final nudge = customNudges[index];
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ActionChip(
                  backgroundColor: colors.surface,
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  avatar: Icon(
                    nudge['icon'] as IconData,
                    size: 16,
                    color: colors.primary,
                  ),
                  label: Text(
                    nudge['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  onPressed: () => _sendNudge(nudge['label'] as String),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedTab(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              title: 'For Us',
              icon: Icons.favorite_rounded,
              isSelected: _selectedTabIndex == 0,
              colors: colors,
              onTap: () => setState(() => _selectedTabIndex = 0),
            ),
          ),
          Expanded(
            child: _buildTabButton(
              title: 'For Me',
              icon: Icons.person_rounded,
              isSelected: _selectedTabIndex == 1,
              colors: colors,
              onTap: () => setState(() => _selectedTabIndex = 1),
            ),
          ),
          Expanded(
            child: _buildTabButton(
              title: 'Badges',
              icon: Icons.military_tech_rounded,
              isSelected: _selectedTabIndex == 2,
              colors: colors,
              onTap: () => setState(() => _selectedTabIndex = 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required ColorScheme colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colors.onSurface : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard({
    required Map<String, dynamic> goal,
    required bool isCoupleGoal,
    required ColorScheme colorScheme,
  }) {
    final isCompleted = goal['isCompleted'] as bool;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(
              alpha: isCompleted ? 0.02 : 0.04,
            ),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
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
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? colorScheme.primary : Colors.transparent,
                border: Border.all(
                  color: isCompleted
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              goal['icon'] as IconData,
              size: 18,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal['title'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
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
              icon: const Icon(Icons.notifications_active_outlined, size: 20),
              color: colorScheme.primary,
              tooltip: 'Remind partner',
              onPressed: () => _sendNudge(goal['title'] as String),
            ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard({
    required Map<String, dynamic> achievement,
    required ColorScheme colorScheme,
  }) {
    final isUnlocked = achievement['isUnlocked'] as bool;
    final progress =
        (achievement['progress'] as int) / (achievement['target'] as int);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnlocked
              ? colorScheme.primary.withValues(alpha: 0.35)
              : colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? colorScheme.primary
                  : colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              achievement['icon'] as IconData,
              size: 24,
              color: isUnlocked ? Colors.white : colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      achievement['title'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
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
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 5,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${achievement['progress']}/${achievement['target']}',
                    style: TextStyle(
                      fontSize: 10,
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
    );
  }

  Widget _buildAddGoalButton({
    required String label,
    required ColorScheme colorScheme,
  }) {
    return OutlinedButton.icon(
      onPressed: () => _openAddGoalModal(context),
      icon: const Icon(Icons.add_rounded),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
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
                          color: colors.primary.withValues(alpha: 0.18),
                          blurRadius: 24,
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

  void _sendNudge(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.send_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('Sent reminder to partner for: "$title"')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
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
    int selectedPoints = 20;
    IconData selectedIcon = _selectedTabIndex == 0
        ? Icons.favorite_rounded
        : Icons.star_rounded;

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
                    decoration: const InputDecoration(
                      labelText: 'Goal Title',
                      hintText: 'e.g. Try a new coffee shop',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category',
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
                  const SizedBox(height: 16),
                  const Text(
                    'Reward Points',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [15, 25, 40, 60, 100].map((pts) {
                      final isChosen = selectedPoints == pts;
                      return ChoiceChip(
                        label: Text('+$pts pts'),
                        selected: isChosen,
                        selectedColor: colors.primary,
                        labelStyle: TextStyle(
                          color: isChosen ? Colors.white : colors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            setModalState(() => selectedPoints = pts),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Goal'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        if (titleController.text.trim().isEmpty) return;

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
