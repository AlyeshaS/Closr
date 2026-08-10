// lib/suggestions/suggestions_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'suggestion_service.dart';
import '../../gemini_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/streaks_service.dart';

class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen>
    with TickerProviderStateMixin {
  final CardSwiperController _swiperController = CardSwiperController();

  // Filter State
  String _selectedBudget = 'Any';
  String _selectedLocation = 'Any';
  String _selectedActivity = 'Any';

  final List<String> _budgetOptions = ['Any', 'Free', '\$', '\$\$', '\$\$\$'];
  final List<String> _locationOptions = [
    'Any',
    'At Home',
    'Outdoors',
    'In the City',
    'Nearby Trip',
  ];
  final List<String> _activityOptions = [
    'Any',
    'Food & Drinks',
    'Active / Sporty',
    'Cozy / Relaxed',
    'Arts & Culture',
  ];

  late final SuggestionService _suggestionService = SuggestionService();
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = false;
  final GeminiService _geminiService = GeminiService();

  final List<Map<String, dynamic>> _yes = [];
  final List<Map<String, dynamic>> _no = [];
  final List<Map<String, dynamic>> _skip = [];
  List<Map<String, dynamic>> _matched = [];

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading && _suggestions.isEmpty) {
      _loadSuggestions(refresh: true);
    }
  }

  Future<List<String>> _getUserInterests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final doc = await FirebaseFirestore.instance
        .collection('preferences')
        .doc(user.uid)
        .get();
    final data = doc.data();
    if (data == null || data['interests'] == null) return [];
    return List<String>.from(data['interests']);
  }

  Future<void> _loadSuggestions({bool refresh = false}) async {
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    String? partnerUid = await _getPartnerUid();
    List<Map<String, dynamic>> partnerSuggestions = [];
    if (partnerUid != null) {
      final partnerSuggestionsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(partnerUid)
          .collection('suggestions')
          .get();
      partnerSuggestions = partnerSuggestionsSnap.docs
          .map(
            (doc) => {
              'id': doc['id'],
              'title': doc['title'],
              'desc': doc['desc'],
            },
          )
          .toList();
    }

    if (refresh) {
      final mySuggestionsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('suggestions')
          .get();
      for (final doc in mySuggestionsSnap.docs) {
        final swipe = doc.data()?['swipe'];
        if (swipe == null) {
          await doc.reference.delete();
        }
      }
    }

    final interests = await _getUserInterests();
    List<Map<String, dynamic>> geminiSuggestions = [];

    try {
      final userSuggestionsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('suggestions')
          .get();
      final userSuggestions = userSuggestionsSnap.docs
          .map(
            (doc) => {'title': doc['title'] ?? '', 'desc': doc['desc'] ?? ''},
          )
          .toList();

      final List<Map<String, String>> exclusions = [];
      for (final s in userSuggestions) {
        exclusions.add({
          'title': (s['title'] ?? '').toString(),
          'desc': (s['desc'] ?? '').toString(),
        });
      }

      geminiSuggestions = await _geminiService
          .generateDateSuggestions(
            interests,
            exclusions: exclusions,
            budget: _selectedBudget,
            location: _selectedLocation,
            activityType: _selectedActivity,
          )
          .timeout(const Duration(seconds: 60));

      try {
        await StreaksService().recordActivity('date_ideas_view');
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load suggestions: $e')),
        );
      }
    }

    final allSuggestionsMap = <String, Map<String, dynamic>>{};
    for (final s in geminiSuggestions) allSuggestionsMap[s['id']] = s;
    final allSuggestions = allSuggestionsMap.values.toList();

    for (final suggestion in allSuggestions) {
      String cleanTitle = suggestion['title'] ?? '';
      String cleanDesc = suggestion['desc'] ?? '';
      if (cleanTitle.startsWith('**')) {
        cleanTitle = cleanTitle.replaceFirst(RegExp(r'^\*\*+'), '').trim();
      }
      if (cleanDesc.startsWith('**')) {
        cleanDesc = cleanDesc.replaceFirst(RegExp(r'^\*\*+'), '').trim();
      }
      await _suggestionService.saveSuggestion(suggestion['id'], {
        ...suggestion,
        'title': cleanTitle,
        'desc': cleanDesc,
      });
    }

    setState(() {
      _suggestions = allSuggestions;
      _loading = false;
    });
  }

  Future<String?> _getPartnerUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data();
    final partnerEmail =
        ((userData?['partnerEmailLower'] as String?) ??
                (userData?['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();
    if (partnerEmail.isEmpty) return null;
    final partnerQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('emailLower', isEqualTo: partnerEmail)
        .get();
    if (partnerQuery.docs.isNotEmpty) return partnerQuery.docs.first.id;
    return null;
  }

  Future<void> fetchSwipedSuggestionsForPanel() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final allSuggestionsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('suggestions')
        .get();

    _yes.clear();
    _no.clear();
    _skip.clear();

    for (final doc in allSuggestionsSnapshot.docs) {
      final data = doc.data();
      String cleanTitle = data['title'] ?? '';
      String cleanDesc = data['desc'] ?? '';

      if (cleanTitle.startsWith('**')) {
        cleanTitle = cleanTitle.replaceFirst(RegExp(r'^\*\*+'), '').trim();
      }
      if (cleanDesc.startsWith('**')) {
        cleanDesc = cleanDesc.replaceFirst(RegExp(r'^\*\*+'), '').trim();
      }

      final suggestion = {'id': doc.id, 'title': cleanTitle, 'desc': cleanDesc};

      final action = data['swipe'];
      if (action == "yes") {
        _yes.add(suggestion);
      } else if (action == "no") {
        _no.add(suggestion);
      } else if (action == "skip") {
        _skip.add(suggestion);
      }
    }
  }

  Future<void> _loadMatchedSuggestions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final matchSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('matched_suggestions')
        .get();

    _matched = matchSnap.docs
        .map(
          (doc) => {
            'id': doc.id,
            'title': doc.data()['title'] ?? '',
            'desc': doc.data()['desc'] ?? '',
          },
        )
        .toList();
  }

  void _showSwipedCards() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    await fetchSwipedSuggestionsForPanel();
    await _loadMatchedSuggestions();

    if (!mounted) return;
    Navigator.of(context).pop();

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => DefaultTabController(
        length: 3,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Saved Date Ideas',
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.3),
                    ),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: cs.onPrimary,
                    unselectedLabelColor: cs.onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: [
                      Tab(text: 'Yes (${_yes.length})'),
                      Tab(text: 'No (${_no.length})'),
                      Tab(text: 'Matched (${_matched.length})'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildCardList(
                      _yes,
                      cs,
                      isDark,
                      statusColor: cs.primary,
                      statusLabel: 'Liked',
                      icon: Icons.favorite_rounded,
                    ),
                    _buildCardList(
                      _no,
                      cs,
                      isDark,
                      statusColor: cs.error,
                      statusLabel: 'Passed',
                      icon: Icons.close_rounded,
                    ),
                    _buildCardList(
                      _matched,
                      cs,
                      isDark,
                      statusColor: cs.primary,
                      statusLabel: 'Matched!',
                      icon: Icons.auto_awesome_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardList(
    List<Map<String, dynamic>> cards,
    ColorScheme cs,
    bool isDark, {
    required Color statusColor,
    required String statusLabel,
    required IconData icon,
  }) {
    if (cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 40,
              color: cs.outline.withOpacity(0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'No cards in this category yet',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: cs.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final card = cards[index];
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF26181C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: statusColor.withOpacity(isDark ? 0.35 : 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  card['title'] ?? '',
                  style: TextStyle(
                    fontFamily: 'CormorantGaramond',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                if ((card['desc'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    card['desc'] ?? '',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 13,
                      height: 1.4,
                      color: cs.onSurfaceVariant.withOpacity(0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _checkAndStoreMatch(Map<String, dynamic> suggestion) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final partnerUid = await _getPartnerUid();
    if (partnerUid == null) return;

    final partnerSuggestionDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(partnerUid)
        .collection('suggestions')
        .doc(suggestion['id'])
        .get();

    final partnerSwipe = partnerSuggestionDoc.data()?['swipe'];
    if (partnerSuggestionDoc.exists && partnerSwipe == 'yes') {
      await _suggestionService.saveMatchedSuggestion(
        suggestion['id'],
        suggestion,
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(partnerUid)
          .collection('matched_suggestions')
          .doc(suggestion['id'])
          .set(suggestion);
    }
  }

  Future<bool> _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) async {
    if (previousIndex < 0 || previousIndex >= _suggestions.length) return false;
    final suggestion = _suggestions[previousIndex];

    if (direction == CardSwiperDirection.right) {
      _yes.add(suggestion);
      await _suggestionService.swipeSuggestion(suggestion['id'], 'yes');
      await _checkAndStoreMatch(suggestion);
    } else if (direction == CardSwiperDirection.left) {
      _no.add(suggestion);
      await _suggestionService.swipeSuggestion(suggestion['id'], 'no');
    } else {
      _skip.add(suggestion);
      await _suggestionService.swipeSuggestion(suggestion['id'], 'skip');
    }

    setState(() {
      if (_suggestions.isNotEmpty) _suggestions.removeAt(0);
    });

    if (_suggestions.isEmpty && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No more suggestions!')));
    }

    return false;
  }

  void _showFilterSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Suggestions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFilterDropdown(
                    'Budget',
                    _selectedBudget,
                    _budgetOptions,
                    (val) {
                      setModalState(() => _selectedBudget = val!);
                    },
                    cs,
                  ),
                  const SizedBox(height: 12),
                  _buildFilterDropdown(
                    'Location',
                    _selectedLocation,
                    _locationOptions,
                    (val) {
                      setModalState(() => _selectedLocation = val!);
                    },
                    cs,
                  ),
                  const SizedBox(height: 12),
                  _buildFilterDropdown(
                    'Activity Type',
                    _selectedActivity,
                    _activityOptions,
                    (val) {
                      setModalState(() => _selectedActivity = val!);
                    },
                    cs,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _loadSuggestions(refresh: true);
                      },
                      child: const Text(
                        'Apply & Generate',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String currentValue,
    List<String> options,
    ValueChanged<String?> onChanged,
    ColorScheme cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              dropdownColor: cs.surfaceContainerHighest,
              items: options.map((opt) {
                return DropdownMenuItem(
                  value: opt,
                  child: Text(opt, style: TextStyle(color: cs.onSurface)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasActiveFilter =
        _selectedBudget != 'Any' ||
        _selectedLocation != 'Any' ||
        _selectedActivity != 'Any';

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: cs.primary,
                  strokeWidth: 2,
                ),
              )
            : _suggestions.isEmpty
            ? _buildEmptyState(cs)
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            hasActiveFilter
                                ? Icons.filter_alt_rounded
                                : Icons.filter_alt_outlined,
                            color: hasActiveFilter
                                ? cs.primary
                                : cs.onSurfaceVariant,
                            size: 22,
                          ),
                          tooltip: 'Filter options',
                          onPressed: _showFilterSheet,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.checklist_rounded,
                            color: cs.onSurfaceVariant,
                            size: 22,
                          ),
                          tooltip: 'View swiped cards',
                          onPressed: _showSwipedCards,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: cs.onSurfaceVariant,
                            size: 22,
                          ),
                          tooltip: 'Generate more',
                          onPressed: _loading
                              ? null
                              : () => _loadSuggestions(refresh: true),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 8),
                    child: Text(
                      'Tap the buttons below or swipe to decide',
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 13,
                        color: cs.onSurfaceVariant.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Swiper Cards Area with tighter stack spacing
                  // Swiper Cards Area with tighter stack spacing
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: CardSwiper(
                        controller: _swiperController,
                        cardsCount: _suggestions.length,
                        numberOfCardsDisplayed: _suggestions.length < 3
                            ? _suggestions.length
                            : 3,
                        maxAngle: 30,
                        scale:
                            0.85, // Brings stacked cards closer by keeping their scale almost full size
                        threshold: 50,
                        cardBuilder: (context, index, _, __) {
                          if (index < 0 || index >= _suggestions.length) {
                            return null;
                          }
                          return _SuggestionCard(
                            suggestion: _suggestions[index],
                            cs: cs,
                            isDark: isDark,
                          );
                        },
                        onSwipe: _onSwipe,
                      ),
                    ),
                  ),
                  // Circular Control Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ControlCircle(
                          icon: Icons.close_rounded,
                          onPressed: _suggestions.isEmpty
                              ? null
                              : () => _swiperController.swipe(
                                  CardSwiperDirection.left,
                                ),
                          cs: cs,
                          isDark: isDark,
                          color: cs.error,
                        ),
                        const SizedBox(width: 32),
                        _ControlCircle(
                          icon: Icons.favorite_rounded,
                          onPressed: _suggestions.isEmpty
                              ? null
                              : () => _swiperController.swipe(
                                  CardSwiperDirection.right,
                                ),
                          cs: cs,
                          isPrimary: true,
                          isDark: isDark,
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_outlined, size: 56, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              'No suggestions yet',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate some date ideas to get started.',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadSuggestions(refresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Generate ideas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                elevation: 4,
                shadowColor: cs.primary.withOpacity(0.26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subtle Deep Talk Style Card ───────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final ColorScheme cs;
  final bool isDark;

  const _SuggestionCard({
    required this.suggestion,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        suggestion['title'] ?? '',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontFamily: 'CormorantGaramond',
                              fontSize: 25,
                              fontStyle: FontStyle.italic,
                              height: 1.25,
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Divider(
                        color: cs.primary.withOpacity(0.15),
                        height: 1,
                        indent: 40,
                        endIndent: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        suggestion['desc'] ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'DMSans',
                          fontSize: 14,
                          height: 1.45,
                          color: cs.onSurfaceVariant.withOpacity(0.85),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Circle Controls Matching DeepTalk Screen ───────────────────────────────

class _ControlCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final ColorScheme cs;
  final bool isPrimary;
  final bool isDark;
  final Color color;

  const _ControlCircle({
    required this.icon,
    required this.onPressed,
    required this.cs,
    required this.isDark,
    required this.color,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;

    Color getBgColor() {
      if (isDisabled) return cs.surfaceContainerHighest.withOpacity(0.15);
      return isPrimary ? color : color.withOpacity(0.08);
    }

    Color getIconColor() {
      if (isDisabled) return cs.onSurface.withOpacity(0.2);
      return isPrimary ? cs.onPrimary : color;
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDisabled
              ? cs.outlineVariant.withOpacity(0.1)
              : color.withOpacity(isPrimary ? 0.1 : 0.25),
          width: 1,
        ),
        boxShadow: !isDisabled
            ? [
                BoxShadow(
                  color: isPrimary
                      ? color.withOpacity(isDark ? 0.18 : 0.28)
                      : color.withOpacity(isDark ? 0.04 : 0.08),
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
          splashColor: color.withOpacity(0.15),
          highlightColor: color.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Icon(icon, color: getIconColor(), size: 26),
          ),
        ),
      ),
    );
  }
}
