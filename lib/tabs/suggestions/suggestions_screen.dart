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
  // Controller that lets buttons trigger the real swipe animation
  final CardSwiperController _swiperController = CardSwiperController();

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  // ── Firestore / data helpers (UNCHANGED) ────────────────────────────────────

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
      String cleanTitle = doc['title'];
      String cleanDesc = doc['desc'];
      if (cleanTitle.startsWith('**')) {
        cleanTitle = cleanTitle.replaceFirst(RegExp(r'^\*\*+'), '').trim();
      }
      if (cleanDesc.startsWith('**')) {
        cleanDesc = cleanDesc.replaceFirst(RegExp(r'^\*\*+'), '').trim();
      }
      final suggestion = {
        'id': doc['id'],
        'title': cleanTitle,
        'desc': cleanDesc,
      };
      final action = doc['swipe'];
      if (action == "yes") {
        _yes.add(suggestion);
      } else if (action == "no") {
        _no.add(suggestion);
      } else if (action == "skip") {
        _skip.add(suggestion);
      }
    }
    setState(() {});
  }

  List<Map<String, dynamic>> _matched = [];

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
      setState(() {
        if (!_matched.any((s) => s['id'] == suggestion['id'])) {
          _matched.add(suggestion);
        }
      });
    }
  }

  late final SuggestionService _suggestionService = SuggestionService();
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = false;
  final GeminiService _geminiService = GeminiService();

  Set<String> _tokenSet(String text) {
    final cleaned = text
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s]"), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toSet();
    return cleaned;
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
    String? partnerUid;
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
    if (partnerEmail.isNotEmpty) {
      final partnerQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('emailLower', isEqualTo: partnerEmail)
          .get();
      if (partnerQuery.docs.isNotEmpty) {
        partnerUid = partnerQuery.docs.first.id;
      } else {
        final fallbackQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: partnerEmail)
            .get();
        if (fallbackQuery.docs.isNotEmpty) {
          partnerUid = fallbackQuery.docs.first.id;
        } else {
          final allUsers = await FirebaseFirestore.instance
              .collection('users')
              .limit(250)
              .get();
          for (final doc in allUsers.docs) {
            final data = doc.data();
            final email =
                ((data['emailLower'] as String?) ??
                        (data['email'] as String?) ??
                        '')
                    .trim()
                    .toLowerCase();
            if (email == partnerEmail) {
              partnerUid = doc.id;
              break;
            }
          }
        }
      }
    }
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
    // If refresh requested, remove existing unswiped suggestions so regenerated
    // ideas won't just reuse the previous set.
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
      // Collect user's existing suggestions so we can exclude them from regeneration
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

      // Build exclusions combining user's and partner's suggestions
      final List<Map<String, String>> exclusions = [];
      for (final s in userSuggestions) {
        exclusions.add({
          'title': (s['title'] ?? '').toString(),
          'desc': (s['desc'] ?? '').toString(),
        });
      }
      for (final s in partnerSuggestions) {
        exclusions.add({
          'title': (s['title'] ?? '').toString(),
          'desc': (s['desc'] ?? '').toString(),
        });
      }

      print(
        'SuggestionsScreen: Calling generateDateSuggestions with exclusions count: ${exclusions.length}',
      );
      if (exclusions.isNotEmpty)
        print('SuggestionsScreen: Sample exclusion[0]: ${exclusions[0]}');
      geminiSuggestions = await _geminiService
          .generateDateSuggestions(interests, exclusions: exclusions)
          .timeout(const Duration(seconds: 60));
      print(
        'SuggestionsScreen: Received ${geminiSuggestions.length} geminiSuggestions',
      );
      for (var i = 0; i < geminiSuggestions.length; i++) {
        print(
          'Suggestion[$i]: id=${geminiSuggestions[i]['id']} title=${geminiSuggestions[i]['title']}',
        );
      }

      // Client-side filter: remove suggestions that are similar to existing ones
      final existingSuggestionsList = <Map<String, dynamic>>[];
      existingSuggestionsList.addAll(
        userSuggestions.map((s) => {'title': s['title'], 'desc': s['desc']}),
      );
      existingSuggestionsList.addAll(
        partnerSuggestions.map((s) => {'title': s['title'], 'desc': s['desc']}),
      );

      bool isSimilarToAny(Map<String, dynamic> candidate) {
        final candText = '${candidate['title']} ${candidate['desc']}'
            .toString();
        final candSet = _tokenSet(candText);
        for (final s in existingSuggestionsList) {
          final sText = '${s['title']} ${s['desc']}'.toString();
          final sSet = _tokenSet(sText);
          final intersect = candSet.intersection(sSet).length;
          final smaller = candSet.length < sSet.length
              ? candSet.length
              : sSet.length;
          if (smaller > 0 && intersect / smaller >= 0.75) return true;
        }
        return false;
      }

      final beforeFilter = geminiSuggestions.length;
      geminiSuggestions = geminiSuggestions
          .where((c) => !isSimilarToAny(c))
          .toList();
      print(
        'SuggestionsScreen: Filtered suggestions: before=$beforeFilter after=${geminiSuggestions.length}',
      );
      for (var i = 0; i < geminiSuggestions.length; i++) {
        print(
          'Filtered[$i]: id=${geminiSuggestions[i]['id']} title=${geminiSuggestions[i]['title']}',
        );
      }
      // record streak activity for generating date ideas
      try {
        await StreaksService().recordActivity('date_ideas_view');
      } catch (_) {}
    } on TimeoutException {
      print('SuggestionsScreen: generateDateSuggestions timed out after 60s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI is taking too long. Please try again later.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load Gemini suggestions: $e')),
        );
      }
    }
    final allSuggestionsMap = <String, Map<String, dynamic>>{};
    for (final s in geminiSuggestions) allSuggestionsMap[s['id']] = s;
    for (final s in partnerSuggestions) allSuggestionsMap[s['id']] = s;
    final allSuggestions = allSuggestionsMap.values.toList();
    print(
      'SuggestionsScreen: Saving ${allSuggestions.length} suggestions to Firestore',
    );
    for (final suggestion in allSuggestions) {
      String cleanTitle = suggestion['title'];
      String cleanDesc = suggestion['desc'];
      if (cleanTitle.startsWith('**')) {
        cleanTitle = cleanTitle.replaceFirst(RegExp(r'^\*\*+'), '').trim();
      }
      if (cleanDesc.startsWith('**')) {
        cleanDesc = cleanDesc.replaceFirst(RegExp(r'^\*\*+'), '').trim();
      }
      final id = suggestion['id'];
      print('SuggestionsScreen: Saving suggestion id=$id title=$cleanTitle');
      await _suggestionService.saveSuggestion(id, {
        ...suggestion,
        'title': cleanTitle,
        'desc': cleanDesc,
      });
    }
    setState(() {
      _suggestions = allSuggestions.map((s) {
        String cleanTitle = s['title'];
        String cleanDesc = s['desc'];
        if (cleanTitle.startsWith('**')) {
          cleanTitle = cleanTitle.replaceFirst(RegExp(r'^\*\*+'), '').trim();
        }
        if (cleanDesc.startsWith('**')) {
          cleanDesc = cleanDesc.replaceFirst(RegExp(r'^\*\*+'), '').trim();
        }
        return {...s, 'title': cleanTitle, 'desc': cleanDesc};
      }).toList();
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
    final fallbackQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: partnerEmail)
        .get();
    if (fallbackQuery.docs.isNotEmpty) return fallbackQuery.docs.first.id;

    final allUsers = await FirebaseFirestore.instance
        .collection('users')
        .limit(250)
        .get();
    for (final doc in allUsers.docs) {
      final data = doc.data();
      final email =
          ((data['emailLower'] as String?) ?? (data['email'] as String?) ?? '')
              .trim()
              .toLowerCase();
      if (email == partnerEmail) {
        return doc.id;
      }
    }
    return null;
  }

  final List<Map<String, dynamic>> _yes = [];
  final List<Map<String, dynamic>> _no = [];
  final List<Map<String, dynamic>> _skip = [];

  void _showSwipedCards() async {
    await fetchSwipedSuggestionsForPanel();
    await _loadMatchedSuggestions();
    showModalBottomSheet(
      context: context,
      builder: (context) => DefaultTabController(
        length: 3,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: [
                Tab(text: 'Yes'),
                Tab(text: 'No'),
                Tab(text: 'Matched'),
              ],
            ),
            SizedBox(
              height: 300,
              child: TabBarView(
                children: [
                  _buildCardList(_yes),
                  _buildCardList(_no),
                  _buildCardList(_matched),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMatchedSuggestions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final matchSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('matched_suggestions')
        .get();
    setState(() {
      _matched = matchSnap.docs
          .map(
            (doc) => {
              'id': doc['id'],
              'title': doc['title'],
              'desc': doc['desc'],
            },
          )
          .toList();
    });
  }

  Widget _buildCardList(List<Map<String, dynamic>> cards) {
    if (cards.isEmpty) return const Center(child: Text('No cards'));
    return ListView(
      children: cards
          .map(
            (card) => ListTile(
              title: Text(card['title']),
              subtitle: Text(card['desc']),
            ),
          )
          .toList(),
    );
  }

  // ── onSwipe callback — called by BOTH gesture swipes AND programmatic swipes ─
  // This is the single source of truth for recording swipe results.

  Future<bool> _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) async {
    if (previousIndex < 0 || previousIndex >= _suggestions.length) return false;
    final suggestion = _suggestions[previousIndex];

    if (direction == CardSwiperDirection.right) {
      // Right = Yes (Love it)
      _yes.add(suggestion);
      await _suggestionService.swipeSuggestion(suggestion['id'], 'yes');
      await _checkAndStoreMatch(suggestion);
    } else if (direction == CardSwiperDirection.left) {
      // Left = No (Pass)
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

    return false; // returning false keeps the card stack intact (original behaviour)
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                  // ── Top bar ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Date Ideas',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: cs.onSurface),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.list_alt_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                          tooltip: 'View swiped cards',
                          onPressed: _showSwipedCards,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                          tooltip: 'Generate more',
                          onPressed: _loading
                              ? null
                              : () => _loadSuggestions(refresh: true),
                        ),
                      ],
                    ),
                  ),

                  // ── Hint ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Text(
                      'Tap the buttons below to decide',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // ── Card swiper ───────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: CardSwiper(
                        controller: _swiperController,
                        cardsCount: _suggestions.length,
                        numberOfCardsDisplayed: _suggestions.length < 3
                            ? _suggestions.length
                            : 3,
                        cardBuilder: (context, index, _, __) {
                          if (index < 0 || index >= _suggestions.length) {
                            return null;
                          }
                          return _SuggestionCard(
                            suggestion: _suggestions[index],
                            cs: cs,
                          );
                        },
                        // Single onSwipe handles both gesture & programmatic
                        onSwipe: _onSwipe,
                      ),
                    ),
                  ),

                  // ── Buttons ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
                    child: Row(
                      children: [
                        // Pass — triggers swipe RIGHT animation
                        Expanded(
                          child: OutlinedButton.icon(
                            style:
                                OutlinedButton.styleFrom(
                                  backgroundColor: cs.surface,
                                  foregroundColor: cs.error,
                                  side: BorderSide(color: cs.error, width: 1.5),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  elevation: 4,
                                  shadowColor: cs.error.withOpacity(0.22),
                                  surfaceTintColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ).copyWith(
                                  overlayColor:
                                      MaterialStateProperty.resolveWith(
                                        (states) =>
                                            states.contains(
                                              MaterialState.pressed,
                                            )
                                            ? cs.error.withOpacity(0.12)
                                            : null,
                                      ),
                                ),
                            onPressed: _suggestions.isEmpty
                                ? null
                                : () => _swiperController.swipe(
                                    CardSwiperDirection.left,
                                  ),
                            icon: const Icon(Icons.close_rounded, size: 20),
                            label: const Text(
                              'Pass',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Love it — triggers swipe RIGHT animation
                        Expanded(
                          child: ElevatedButton.icon(
                            style:
                                ElevatedButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  foregroundColor: cs.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  elevation: 4,
                                  shadowColor: cs.primary.withOpacity(0.26),
                                  surfaceTintColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ).copyWith(
                                  overlayColor:
                                      MaterialStateProperty.resolveWith(
                                        (states) =>
                                            states.contains(
                                              MaterialState.pressed,
                                            )
                                            ? cs.onPrimary.withOpacity(0.14)
                                            : null,
                                      ),
                                ),
                            onPressed: _suggestions.isEmpty
                                ? null
                                : () => _swiperController.swipe(
                                    CardSwiperDirection.right,
                                  ),
                            icon: const Icon(Icons.favorite_rounded, size: 20),
                            label: const Text(
                              'Love it',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
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
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate some date ideas to get started.',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadSuggestions(refresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Generate ideas'),
              style:
                  ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    elevation: 4,
                    shadowColor: cs.primary.withOpacity(0.26),
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ).copyWith(
                    overlayColor: MaterialStateProperty.resolveWith(
                      (states) => states.contains(MaterialState.pressed)
                          ? cs.onPrimary.withOpacity(0.14)
                          : null,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card widget ───────────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final ColorScheme cs;
  const _SuggestionCard({required this.suggestion, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primaryContainer,
              ),
              child: Icon(Icons.favorite_rounded, color: cs.primary, size: 24),
            ),
            const SizedBox(height: 20),
            Text(
              suggestion['title'] ?? '',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Divider(color: cs.outline.withOpacity(0.4), height: 1),
            const SizedBox(height: 12),
            Flexible(
              child: Text(
                suggestion['desc'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.fade,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
