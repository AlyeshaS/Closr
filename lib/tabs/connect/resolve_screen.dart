import 'package:flutter/material.dart';
import '../../services/resolve_service.dart';

class ResolveScreen extends StatefulWidget {
  const ResolveScreen({super.key});

  @override
  State<ResolveScreen> createState() => _ResolveScreenState();
}

class _ResolveScreenState extends State<ResolveScreen> {
  int currentStage = 0;
  int currentPromptIndex = 0;
  bool hasStartedQuestions = false;
  String selectedMode = 'Miscommunication';
  final TextEditingController customModeController = TextEditingController();
  final ResolveService _resolveService = ResolveService();
  String? _activeSessionId;
  bool _isSavingSession = false;

  late List<String> sessionModes;
  int lastCustomIndex = -1;
  late PageController _introPageController;

  final Map<String, List<String>> responses = {
    'Private Reflection': [],
    'Shared Discussion': [],
    'Resolution': [],
  };

  final TextEditingController responseController = TextEditingController();

  static const List<String> modes = [
    'Miscommunication',
    'Jealousy',
    'Feeling disconnected',
    'Stress',
    'Boundaries',
    'Long-distance struggles',
  ];

  static const List<String> stageTitles = [
    'Private Reflection',
    'Shared Discussion',
    'Resolution',
  ];

  static const List<String> reflectionPrompts = [
    'What are you feeling right now?',
    'What part of the situation hurt you the most?',
    'What do you wish your partner understood?',
    'What do you need emotionally right now?',
    'Is there something you have not said yet because you were afraid to?',
    'What do you think your partner may be feeling?',
  ];

  static const List<String> sharedDiscussionPrompts = [
    'What did you learn from your partner’s response?',
    'What surprised you the most?',
    'What part of their response helped you understand them better?',
    'What do you think both of you need moving forward?',
  ];

  static const List<String> resolutionPrompts = [
    'What is one thing each of you can improve going forward?',
    'What reassurance would help rebuild connection?',
    'What small action could help both of you reconnect today?',
    'What can you both agree to work on together?',
  ];

  List<String> get currentPrompts {
    if (currentStage == 0) return reflectionPrompts;
    if (currentStage == 1) return sharedDiscussionPrompts;
    return resolutionPrompts;
  }

  String get currentStageTitle => stageTitles[currentStage];

  bool get isLastStage => currentStage == stageTitles.length - 1;
  bool get isLastPrompt => currentPromptIndex == currentPrompts.length - 1;

  Future<void> _saveProgress({required bool isCompleted}) async {
    if (_isSavingSession) return;

    setState(() {
      _isSavingSession = true;
    });

    try {
      final sessionId = await _resolveService.saveSession(
        sessionId: _activeSessionId,
        selectedMode: selectedMode,
        responses: responses,
        currentStage: currentStage,
        currentPromptIndex: currentPromptIndex,
        isCompleted: isCompleted,
      );
      _activeSessionId = sessionId;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save this response yet: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingSession = false;
        });
      }
    }
  }

  Future<void> nextPrompt() async {
    final text = responseController.text.trim();

    if (text.isNotEmpty) {
      responses[currentStageTitle]!.add(text);
    } else {
      responses[currentStageTitle]!.add('');
    }

    final finishingSession = isLastPrompt && isLastStage;
    await _saveProgress(isCompleted: finishingSession);
    responseController.clear();

    if (!isLastPrompt) {
      setState(() {
        currentPromptIndex++;
      });
    } else if (!isLastStage) {
      setState(() {
        currentStage++;
        currentPromptIndex = 0;
      });
    } else {
      setState(() {
        currentStage = 3;
        currentPromptIndex = 0;
      });
    }
  }

  void goBack() {
    if (currentStage == 3) {
      setState(() {
        currentStage = 2;
        currentPromptIndex = resolutionPrompts.length - 1;
      });
      return;
    }

    if (currentPromptIndex > 0) {
      setState(() {
        currentPromptIndex--;
      });
    } else if (currentStage > 0) {
      setState(() {
        currentStage--;
        currentPromptIndex = currentPrompts.length - 1;
      });
    }
  }

  void restartSession() {
    setState(() {
      currentStage = 0;
      currentPromptIndex = 0;
      hasStartedQuestions = false;
      selectedMode = 'Miscommunication';
      sessionModes = List.from(modes);
      lastCustomIndex = -1;
      _activeSessionId = null;
      responseController.clear();
      responses.updateAll((key, value) => []);
    });
  }

  void startQuestions() {
    setState(() {
      hasStartedQuestions = true;
    });
  }

  Future<void> showCustomModeDialog() async {
    final cs = Theme.of(context).colorScheme;
    final isBuiltIn = modes.contains(selectedMode);
    customModeController.text = isBuiltIn ? '' : selectedMode;

    final customMode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          'Custom situation',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: customModeController,
          autofocus: true,
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: 'What are you working through?',
            hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6)),
            filled: true,
            fillColor: cs.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            onPressed: () {
              final value = customModeController.text.trim();
              Navigator.pop(dialogContext, value.isEmpty ? null : value);
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              elevation: 4,
              shadowColor: cs.shadow.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Use it',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (customMode != null && customMode.isNotEmpty && mounted) {
      setState(() {
        final existingIndex = sessionModes.indexOf(customMode);

        if (existingIndex != -1) {
          selectedMode = customMode;
          if (existingIndex >= modes.length) {
            lastCustomIndex = existingIndex;
          }
        } else {
          final insertAt = lastCustomIndex >= 0
              ? lastCustomIndex + 1
              : modes.length;
          sessionModes.insert(insertAt, customMode);
          lastCustomIndex = insertAt;
          selectedMode = customMode;
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    sessionModes = List.from(modes);
    _introPageController = PageController();
  }

  @override
  void dispose() {
    responseController.dispose();
    customModeController.dispose();
    _introPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (currentStage == 3) {
      return _ResolveBackdrop(child: _EndingScreen(onRestart: restartSession));
    }

    if (!hasStartedQuestions) {
      return _ResolveBackdrop(
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 80,
          child: PageView(
            controller: _introPageController,
            physics: const PageScrollPhysics(),
            children: [
              // Landing intro centered with Get started
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 160,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeroCard(),
                        const SizedBox(height: 32),
                        FilledButton(
                          onPressed: () {
                            _introPageController.animateToPage(
                              1,
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(240, 56),
                            elevation: 6,
                            shadowColor: cs.shadow.withOpacity(0.25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            'Get started',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Mode selector page (swipe-to)
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ModeSelector(
                      modes: sessionModes,
                      selectedMode: selectedMode,
                      onChanged: (mode) {
                        setState(() {
                          selectedMode = mode;
                        });
                      },
                      onCustomPressed: showCustomModeDialog,
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: startQuestions,
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 56),
                        elevation: 6,
                        shadowColor: cs.shadow.withOpacity(0.25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Start Questions',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
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

    return _ResolveBackdrop(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProgressHeader(
              stageTitle: currentStageTitle,
              currentPromptIndex: currentPromptIndex,
              totalPrompts: currentPrompts.length,
              progress: (currentPromptIndex + 1) / currentPrompts.length,
              selectedMode: selectedMode,
            ),
            const SizedBox(height: 20),
            _PromptCard(
              prompt: currentPrompts[currentPromptIndex],
              controller: responseController,
            ),
            const SizedBox(height: 24),
            _NavigationButtons(
              canGoBack: currentStage > 0 || currentPromptIndex > 0,
              isLastPrompt: isLastPrompt,
              isLastStage: isLastStage,
              onBack: goBack,
              onNext: nextPrompt,
              isSavingSession: _isSavingSession,
              showIntroBack: currentStage == 0 && currentPromptIndex == 0,
              onIntroBack: () {
                setState(() {
                  hasStartedQuestions = false;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _introPageController.jumpToPage(1);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

// 1. Moving Background Circles Implementation via stateful loops
class _ResolveBackdrop extends StatefulWidget {
  final Widget child;

  const _ResolveBackdrop({required this.child});

  @override
  State<_ResolveBackdrop> createState() => _ResolveBackdropState();
}

class _ResolveBackdropState extends State<_ResolveBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _movementController;

  @override
  void initState() {
    super.initState();
    _movementController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _movementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surface,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _movementController,
            builder: (context, child) {
              return Positioned(
                top: -40 + (_movementController.value * 15),
                right: -30 - (_movementController.value * 12),
                child: child!,
              );
            },
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _movementController,
            builder: (context, child) {
              return Positioned(
                bottom: -60 - (_movementController.value * 12),
                left: -40 + (_movementController.value * 18),
                child: child!,
              );
            },
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                color: cs.secondary.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

// 2. Beautiful Landing Card Setup with explicitly specified borders and dropshadow structures
class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: cs.primary.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LabelPill(text: 'Resolve'),
            const SizedBox(height: 20),
            Text(
              'Healthy relationships are not built on avoiding conflict, but on learning how to navigate it together.',
              style: textTheme.titleMedium?.copyWith(
                height: 1.5,
                fontWeight: FontWeight.w800,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This space helps both of you slow down, reflect, and communicate with intention. The goal is not to win the conversation, but to understand each other and move forward together.',
              style: textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Take your time. Be honest. Be kind. Remember that you are on the same team.',
              style: textTheme.bodyMedium?.copyWith(
                color: cs.primary,
                height: 1.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final List<String> modes;
  final String selectedMode;
  final ValueChanged<String> onChanged;
  final VoidCallback onCustomPressed;

  const _ModeSelector({
    required this.modes,
    required this.selectedMode,
    required this.onChanged,
    required this.onCustomPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What are you working through?',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a situation so the session feels more focused.',
          style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ...modes.map((mode) {
              final selected = selectedMode == mode;

              return ChoiceChip(
                label: Text(mode),
                selected: selected,
                onSelected: (_) => onChanged(mode),
                selectedColor: cs.secondaryContainer,
                backgroundColor: cs.surfaceContainerLow,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                labelStyle: TextStyle(
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: selected
                        ? cs.primary
                        : cs.outlineVariant.withOpacity(0.6),
                    width: 1.5,
                  ),
                ),
              );
            }),
            ActionChip(
              avatar: Icon(Icons.add_rounded, size: 18, color: cs.primary),
              label: const Text('Custom'),
              onPressed: onCustomPressed,
              backgroundColor: cs.surfaceContainerLow,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              labelStyle: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: cs.outlineVariant.withOpacity(0.6),
                  width: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// 4. Structural Question Segment Customizing Layouts & Color parameters
class _ProgressHeader extends StatelessWidget {
  final String stageTitle;
  final int currentPromptIndex;
  final int totalPrompts;
  final double progress;
  final String selectedMode;

  const _ProgressHeader({
    required this.stageTitle,
    required this.currentPromptIndex,
    required this.totalPrompts,
    required this.progress,
    required this.selectedMode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: cs.primary,
          width: 1.5,
        ), // Primary color border
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Working through: $selectedMode',
              style: textTheme.labelMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            stageTitle,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Question ${currentPromptIndex + 1} of $totalPrompts',
            style: textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: cs.surface,
            color: cs.primary,
          ),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  final String prompt;
  final TextEditingController controller;

  const _PromptCard({required this.prompt, required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final screenHeight = MediaQuery.of(context).size.height;
    late int minLines;
    late int maxLines;

    if (screenHeight > 900) {
      minLines = 10;
      maxLines = 14;
    } else if (screenHeight > 800) {
      minLines = 8;
      maxLines = 11;
    } else if (screenHeight > 700) {
      minLines = 7;
      maxLines = 9;
    } else {
      minLines = 5;
      maxLines = 7;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: cs.primary,
          width: 1.5,
        ), // Primary color border
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SoftMessage(text: 'Read to understand, not to respond.'),
          const SizedBox(height: 20),
          Text(
            prompt,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.5,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Write your thoughts here...',
              hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6)),
              filled: true,
              fillColor: cs.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withOpacity(0.8),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withOpacity(0.8),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: cs.primary, width: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationButtons extends StatelessWidget {
  final bool canGoBack;
  final bool isLastPrompt;
  final bool isLastStage;
  final VoidCallback onBack;
  final Future<void> Function() onNext;
  final bool isSavingSession;
  final bool showIntroBack;
  final VoidCallback? onIntroBack;

  const _NavigationButtons({
    required this.canGoBack,
    required this.isLastPrompt,
    required this.isLastStage,
    required this.onBack,
    required this.onNext,
    required this.isSavingSession,
    this.showIntroBack = false,
    this.onIntroBack,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String buttonText = 'Next';

    if (isLastPrompt && !isLastStage) {
      buttonText = 'Continue';
    } else if (isLastPrompt && isLastStage) {
      buttonText = 'Finish session';
    }

    return Row(
      children: [
        if (canGoBack || showIntroBack)
          Expanded(
            child: OutlinedButton(
              onPressed: canGoBack ? onBack : onIntroBack,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                side: BorderSide(color: cs.outlineVariant, width: 1.5),
              ),
              child: Text(
                'Back',
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (canGoBack || showIntroBack) const SizedBox(width: 14),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: isSavingSession ? null : onNext,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation:
                    0, // Handled by outer container shadow mapping safely
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: isSavingSession
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                      ),
                    )
                  : Text(
                      buttonText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EndingScreen extends StatelessWidget {
  final VoidCallback onRestart;

  const _EndingScreen({required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: cs.primary.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withOpacity(0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _LabelPill(text: 'Session complete'),
                const SizedBox(height: 20),
                Text(
                  'Thank you for taking the time to listen to each other.',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Communication is not always easy, but choosing to understand one another is an important act of care and connection.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                const _SoftMessage(
                  text:
                      'Your relationship character feels proud of you both for trying.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onRestart,
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 56),
              elevation: 4,
              shadowColor: cs.shadow.withOpacity(0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text(
              'Start another session',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelPill extends StatelessWidget {
  final String text;

  const _LabelPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: textTheme.labelLarge?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SoftMessage extends StatelessWidget {
  final String text;

  const _SoftMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: textTheme.bodyMedium?.copyWith(
          color: cs.onSecondaryContainer,
          height: 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
