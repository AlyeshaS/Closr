import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WatchTab extends StatefulWidget {
  const WatchTab({super.key});

  @override
  State<WatchTab> createState() => _WatchTabState();
}

class _WatchTabState extends State<WatchTab> {
  final _repository = _WatchRepository();

  late Future<List<_WatchItem>> _recommendationsFuture;

  _WatchFeedFilter _filter = _WatchFeedFilter.all;
  _TopView _topView = _TopView.suggestions;
  int _currentRecommendationIndex = 0;

  // Filter State
  final Set<String> _selectedRegions = <String>{};
  final Set<String> _selectedGenres = <String>{};
  double _minRating = 0;
  double _maxRuntime = 240;
  RangeValues _yearRange = const RangeValues(1980, 2026);

  @override
  void initState() {
    super.initState();
    _recommendationsFuture = _repository.fetchRecommendations();
  }

  Future<void> _refreshRecommendations() async {
    setState(() {
      _recommendationsFuture = _repository.fetchRecommendations();
      _currentRecommendationIndex = 0;
    });
  }

  Future<void> _openFilterSheet({
    required ColorScheme cs,
    required List<String> genres,
  }) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  border: Border.all(color: cs.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: cs.onSurfaceVariant,
                            ),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Filter Watch Picks',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _filter = _WatchFeedFilter.all;
                                _currentRecommendationIndex = 0;
                                _selectedRegions.clear();
                                _selectedGenres.clear();
                                _minRating = 0;
                                _maxRuntime = 240;
                                _yearRange = const RangeValues(1980, 2026);
                              });
                              Navigator.of(sheetContext).pop();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: cs.primary,
                            ),
                            child: const Text(
                              'Reset',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _FilterPanel(
                        cs: cs,
                        theme: theme,
                        filter: _filter,
                        selectedRegions: _selectedRegions,
                        selectedGenres: _selectedGenres,
                        genres: genres,
                        minRating: _minRating,
                        maxRuntime: _maxRuntime,
                        yearRange: _yearRange,
                        onFilterChanged: (value) {
                          setSheetState(() {});
                          setState(() {
                            _filter = value;
                            _currentRecommendationIndex = 0;
                          });
                        },
                        onRegionToggled: (region) {
                          setSheetState(() {});
                          setState(() {
                            if (_selectedRegions.contains(region)) {
                              _selectedRegions.remove(region);
                            } else {
                              _selectedRegions.add(region);
                            }
                            _currentRecommendationIndex = 0;
                          });
                        },
                        onGenreToggled: (genre) {
                          setSheetState(() {});
                          setState(() {
                            if (genre == null) {
                              _selectedGenres.clear();
                            } else {
                              if (_selectedGenres.contains(genre)) {
                                _selectedGenres.remove(genre);
                              } else {
                                _selectedGenres.add(genre);
                              }
                            }
                            _currentRecommendationIndex = 0;
                          });
                        },
                        onRatingChanged: (value) {
                          setSheetState(() {});
                          setState(() {
                            _minRating = value;
                            _currentRecommendationIndex = 0;
                          });
                        },
                        onRuntimeChanged: (value) {
                          setSheetState(() {});
                          setState(() {
                            _maxRuntime = value;
                            _currentRecommendationIndex = 0;
                          });
                        },
                        onYearRangeChanged: (value) {
                          setSheetState(() {});
                          setState(() {
                            _yearRange = value;
                            _currentRecommendationIndex = 0;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<String> _collectGenres(
    List<_WatchItem> items,
    List<_WatchRecord> records,
  ) {
    final genres = <String>{};
    for (final item in items) {
      genres.addAll(_normalizeGenres(item.genres));
    }
    for (final record in records) {
      genres.addAll(_normalizeGenres(record.matchedGenres));
    }

    // Keep US / CAD, Anime, and Asian categories exclusively in "Region & Type"
    genres.remove('US / CAD');
    genres.remove('US/CAD');
    genres.remove('Anime');
    genres.remove('J-Drama');
    genres.remove('Japanese');
    genres.remove('Korean');
    genres.remove('K-Drama');

    final list = genres.toList();
    list.sort();
    return list;
  }

  _WatchRecord? _recordFor(_WatchItem item, List<_WatchRecord> records) {
    for (final record in records) {
      if (record.id == item.tmdbKey) {
        return record;
      }
    }
    return null;
  }

  bool _matchesFilter(
    _WatchItem item,
    _WatchRecord? record,
    String currentUid,
    String? partnerUid,
  ) {
    switch (_filter) {
      case _WatchFeedFilter.all:
        break;
      case _WatchFeedFilter.movies:
        if (item.mediaType != _WatchMediaType.movie) return false;
        break;
      case _WatchFeedFilter.tv:
        if (item.mediaType != _WatchMediaType.tv) return false;
        break;
    }

    final normalizedItemGenres = _normalizeGenres(item.genres);

    // Multi-select Region / Category Filtering
    if (_selectedRegions.isNotEmpty) {
      bool regionMatches = false;
      for (final region in _selectedRegions) {
        if (region == 'Anime' && normalizedItemGenres.contains('Anime')) {
          regionMatches = true;
          break;
        }
        if (region == 'Japanese' &&
            (normalizedItemGenres.contains('Japanese') ||
                normalizedItemGenres.contains('J-Drama'))) {
          regionMatches = true;
          break;
        }
        if (region == 'Korean' &&
            (normalizedItemGenres.contains('Korean') ||
                normalizedItemGenres.contains('K-Drama'))) {
          regionMatches = true;
          break;
        }
        if (region == 'US / CAD' &&
            !normalizedItemGenres.contains('Anime') &&
            !normalizedItemGenres.contains('Japanese') &&
            !normalizedItemGenres.contains('J-Drama') &&
            !normalizedItemGenres.contains('Korean') &&
            !normalizedItemGenres.contains('K-Drama')) {
          regionMatches = true;
          break;
        }
      }
      if (!regionMatches) return false;
    }

    // Multi-select Genre Filtering
    if (_selectedGenres.isNotEmpty) {
      bool genreMatches = false;
      for (final selectedGenre in _selectedGenres) {
        if (normalizedItemGenres.contains(selectedGenre)) {
          genreMatches = true;
          break;
        }
      }
      if (!genreMatches) return false;
    }

    if (item.rating < _minRating) {
      return false;
    }

    if (item.runtimeMinutes > 0 && item.runtimeMinutes > _maxRuntime) {
      return false;
    }

    if (item.releaseDate != null) {
      final year = item.releaseDate!.year;
      if (year < _yearRange.start || year > _yearRange.end) {
        return false;
      }
    }

    return true;
  }

  double _displayScore(
    _WatchItem item,
    _WatchRecord? record,
    String currentUid,
    String? partnerUid,
  ) {
    if (record == null) {
      return item.matchPercentage;
    }

    final currentLiked = record.isLikedBy(currentUid);
    final currentDisliked = record.isDislikedBy(currentUid);
    final partnerLiked = partnerUid != null
        ? record.isLikedBy(partnerUid)
        : false;
    final partnerDisliked = partnerUid != null
        ? record.isDislikedBy(partnerUid)
        : false;

    if (currentLiked && partnerLiked) return 96;
    if (currentDisliked && partnerDisliked) return 12;
    if ((currentLiked && partnerDisliked) ||
        (currentDisliked && partnerLiked)) {
      return 34;
    }
    if (currentLiked || partnerLiked) return 78;
    if (currentDisliked || partnerDisliked) return 24;
    return record.coupleMatchScore > 0
        ? record.coupleMatchScore
        : item.matchPercentage;
  }

  Future<void> _toggleAction({
    required _WatchItem item,
    bool? liked,
    bool? disliked,
    bool? favorited,
    bool? watched,
  }) async {
    await _repository.updateInteraction(
      item: item,
      liked: liked,
      disliked: disliked,
      favorited: favorited,
      watched: watched,
    );
  }

  Future<void> _voteAndAdvance({
    required _WatchItem item,
    required int currentListCount,
    bool? liked,
    bool? disliked,
  }) async {
    await _toggleAction(item: item, liked: liked, disliked: disliked);
  }

  Future<void> _openDetails(_WatchItem item) async {
    final details = await _repository.fetchDetails(item);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.9,
            minChildSize: 0.7,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (details.item.backdropUrl.isNotEmpty)
                              Image.network(
                                details.item.backdropUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _BackdropFallback(cs: cs),
                              )
                            else
                              _BackdropFallback(cs: cs),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.65),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      width: 96,
                                      height: 144,
                                      child: details.item.posterUrl.isNotEmpty
                                          ? Image.network(
                                              details.item.posterUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _PosterFallback(cs: cs),
                                            )
                                          : _PosterFallback(cs: cs),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          details.item.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          details.item.mediaLabel,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(color: Colors.white70),
                                        ),
                                        if (details.tagline != null) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            details.tagline!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.9),
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _DetailStat(
                          label: 'Rating',
                          value: details.item.rating > 0
                              ? details.item.rating.toStringAsFixed(1)
                              : 'N/A',
                        ),
                        const SizedBox(width: 10),
                        if (details.item.mediaType == _WatchMediaType.tv)
                          _DetailStat(
                            label: 'Seasons',
                            value: details.seasons != null
                                ? '${details.seasons} seasons'
                                : 'Seasons unavailable',
                          )
                        else
                          _DetailStat(
                            label: 'Runtime',
                            value: details.item.runtimeLabel,
                          ),
                        const SizedBox(width: 10),
                        _DetailStat(
                          label: 'Year',
                          value: details.item.releaseYear,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      details.item.genreLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (details.item.overview.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        details.item.overview,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    const SizedBox(height: 18),
                    const _SectionLabel(text: 'Streaming providers'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: details.providers
                          .map((provider) => Chip(label: Text(provider)))
                          .toList(),
                    ),
                    if (details.item.matchReason.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const _SectionLabel(text: 'Couple match reason'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          details.item.matchReason,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _EmptyWatchState(
        cs: cs,
        title: 'Sign in to build your shared watchlist.',
        subtitle: 'Link your account, then save movies and shows together.',
      );
    }

    return FutureBuilder<List<_WatchItem>>(
      future: _recommendationsFuture,
      builder: (context, recommendationsSnapshot) {
        final recommendations =
            recommendationsSnapshot.data ?? const <_WatchItem>[];

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            final userData = userSnapshot.data?.data();
            final partnerEmail =
                ((userData?['partnerEmailLower'] as String?) ??
                        (userData?['partnerEmail'] as String?) ??
                        '')
                    .trim()
                    .toLowerCase();

            return FutureBuilder<String?>(
              future: _repository.resolvePartnerUid(partnerEmail),
              builder: (context, partnerSnapshot) {
                final partnerUid = partnerSnapshot.data;

                return StreamBuilder<List<_WatchRecord>>(
                  stream: _repository.streamWatchRecords(),
                  builder: (context, recordsSnapshot) {
                    final records =
                        recordsSnapshot.data ?? const <_WatchRecord>[];

                    return StreamBuilder<List<_WatchRecord>>(
                      stream: _repository.streamSharedWatchMatches(),
                      builder: (context, sharedMatchesSnapshot) {
                        final matchedRecords =
                            sharedMatchesSnapshot.data ??
                            const <_WatchRecord>[];
                        final recommendationsLoading =
                            recommendationsSnapshot.connectionState ==
                            ConnectionState.waiting;
                        final genres = _collectGenres(recommendations, records);
                        final filteredItems = recommendations.where((item) {
                          final record = _recordFor(item, records);

                          final currentUserInteracted =
                              record?.isLikedBy(user.uid) == true ||
                              record?.isDislikedBy(user.uid) == true;

                          if (_topView == _TopView.suggestions &&
                              currentUserInteracted) {
                            return false;
                          }

                          return _matchesFilter(
                            item,
                            record,
                            user.uid,
                            partnerUid,
                          );
                        }).toList();

                        final activeFilterCount =
                            (_filter != _WatchFeedFilter.all ? 1 : 0) +
                            _selectedRegions.length +
                            _selectedGenres.length +
                            (_minRating > 0 ? 1 : 0) +
                            (_maxRuntime < 240 ? 1 : 0) +
                            (_yearRange.start > 1980 || _yearRange.end < 2026
                                ? 1
                                : 0);

                        return RefreshIndicator(
                          onRefresh: _refreshRecommendations,
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  18,
                                  20,
                                  14,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _TopViewDropdown(
                                            value: _topView,
                                            cs: cs,
                                            onChanged: (value) {
                                              setState(() {
                                                _topView = value;
                                                _currentRecommendationIndex = 0;
                                                if (value ==
                                                    _TopView.suggestions) {
                                                  _filter =
                                                      _WatchFeedFilter.all;
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _openFilterSheet(
                                              cs: cs,
                                              genres: genres,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: activeFilterCount > 0
                                                    ? cs.primaryContainer
                                                    : cs.surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: activeFilterCount > 0
                                                      ? cs.primary
                                                      : cs.outlineVariant,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: cs.primary
                                                        .withValues(
                                                          alpha: 0.12,
                                                        ),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.05,
                                                        ),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.tune_rounded,
                                                    size: 18,
                                                    color: activeFilterCount > 0
                                                        ? cs.onPrimaryContainer
                                                        : cs.onSurfaceVariant,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Filter',
                                                    style: TextStyle(
                                                      color:
                                                          activeFilterCount > 0
                                                          ? cs.onPrimaryContainer
                                                          : cs.onSurface,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  if (activeFilterCount >
                                                      0) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: cs.primary,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Text(
                                                        '$activeFilterCount',
                                                        style: TextStyle(
                                                          color: cs.onPrimary,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (recommendationsLoading &&
                                  _topView == _TopView.suggestions)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: cs.primary,
                                    ),
                                  ),
                                )
                              else ...[
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    16,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      switchInCurve: Curves.easeOut,
                                      switchOutCurve: Curves.easeIn,
                                      child: _topView == _TopView.history
                                          ? _PersonalHistoryPanel(
                                              key: const ValueKey('history'),
                                              cs: cs,
                                              currentUserId: user.uid,
                                              records: records,
                                            )
                                          : const SizedBox.shrink(
                                              key: ValueKey('empty'),
                                            ),
                                    ),
                                  ),
                                ),
                                if (_topView == _TopView.matched)
                                  if (matchedRecords.isEmpty)
                                    SliverFillRemaining(
                                      hasScrollBody: false,
                                      child: _MatchedTimelineState(
                                        cs: cs,
                                        icon: Icons.favorite_border_rounded,
                                        title: 'No shared matches yet',
                                        subtitle:
                                            'Once you both like the same picks, they will show up here as a shared timeline.',
                                        milestones: const [
                                          'Pick a few recommendations together',
                                          'Save items you both say yes to',
                                          'Watch the matched timeline grow',
                                        ],
                                      ),
                                    )
                                  else
                                    SliverPadding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        32,
                                      ),
                                      sliver: SliverToBoxAdapter(
                                        child: _MatchedTimelineFeed(
                                          cs: cs,
                                          currentUserId: user.uid,
                                          partnerUid: partnerUid,
                                          onMarkWatchedTogether:
                                              (record) async {
                                                await _repository
                                                    .markWatchedTogether(
                                                      record: record,
                                                    );
                                              },
                                          onOpenDetails: (record) async {
                                            final docKey =
                                                '${record.mediaType}_${record.tmdbId}';
                                            final docSnap =
                                                await FirebaseFirestore.instance
                                                    .collection('watch_options')
                                                    .doc(docKey)
                                                    .get();

                                            if (docSnap.exists) {
                                              final data = docSnap.data()!;
                                              final mediaType =
                                                  record.mediaType == 'tv'
                                                  ? _WatchMediaType.tv
                                                  : _WatchMediaType.movie;

                                              final fullItem = _WatchItem(
                                                tmdbId: record.tmdbId,
                                                mediaType: mediaType,
                                                title: record.title,
                                                overview:
                                                    (data['overview']
                                                        as String?) ??
                                                    '',
                                                posterPath: record.posterPath,
                                                backdropPath:
                                                    (data['backdropPath']
                                                        as String?) ??
                                                    record.backdropPath,
                                                rating:
                                                    (data['rating'] as num?)
                                                        ?.toDouble() ??
                                                    0.0,
                                                runtimeMinutes:
                                                    (data['runtimeMinutes']
                                                            as num?)
                                                        ?.toInt() ??
                                                    0,
                                                releaseDate: _parseReleaseDate(
                                                  data['releaseDate'],
                                                ),
                                                seasons:
                                                    (data['seasons'] as num?)
                                                        ?.toInt(),
                                                genres: List<String>.from(
                                                  (data['genres'] as List?) ??
                                                      record.matchedGenres,
                                                ),
                                                matchPercentage:
                                                    record.coupleMatchScore,
                                                matchReason:
                                                    (data['matchReason']
                                                        as String?) ??
                                                    '',
                                              );
                                              _openDetails(fullItem);
                                            } else {
                                              _openDetails(
                                                _WatchItem(
                                                  tmdbId: record.tmdbId,
                                                  mediaType:
                                                      record.mediaType == 'tv'
                                                      ? _WatchMediaType.tv
                                                      : _WatchMediaType.movie,
                                                  title: record.title,
                                                  overview: '',
                                                  posterPath: record.posterPath,
                                                  backdropPath:
                                                      record.backdropPath,
                                                  rating: 0,
                                                  runtimeMinutes: 0,
                                                  releaseDate: null,
                                                  seasons: null,
                                                  genres: record.matchedGenres,
                                                  matchPercentage:
                                                      record.coupleMatchScore,
                                                  matchReason: '',
                                                ),
                                              );
                                            }
                                          },
                                          entries: matchedRecords
                                              .map(
                                                (record) =>
                                                    _MatchedTimelineEntry(
                                                      record: record,
                                                    ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    )
                                else if (_topView == _TopView.history)
                                  const SliverToBoxAdapter(
                                    child: SizedBox.shrink(),
                                  )
                                else if (filteredItems.isEmpty)
                                  SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: _EmptyWatchState(
                                      cs: cs,
                                      title: 'No new picks right now',
                                      subtitle:
                                          'You may have interacted with all current suggestions or active filters.',
                                    ),
                                  )
                                else
                                  SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        14,
                                      ),
                                      child: Builder(
                                        builder: (context) {
                                          final activeIndex =
                                              _currentRecommendationIndex %
                                              filteredItems.length;
                                          final item =
                                              filteredItems[activeIndex];
                                          final record = _recordFor(
                                            item,
                                            records,
                                          );
                                          final score = _displayScore(
                                            item,
                                            record,
                                            user.uid,
                                            partnerUid,
                                          );

                                          return Center(
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 360,
                                              ),
                                              child: _RecommendationCard(
                                                cs: cs,
                                                item: item,
                                                score: score,
                                                record: record,
                                                currentUserId: user.uid,
                                                partnerUid: partnerUid,
                                                onOpenDetails: () =>
                                                    _openDetails(item),
                                                onYes: () => _voteAndAdvance(
                                                  item: item,
                                                  liked: true,
                                                  currentListCount:
                                                      filteredItems.length,
                                                ),
                                                onNo: () => _voteAndAdvance(
                                                  item: item,
                                                  disliked: true,
                                                  currentListCount:
                                                      filteredItems.length,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

enum _WatchFeedFilter { all, movies, tv }

enum _WatchMediaType { movie, tv }

enum _TopView { suggestions, matched, history }

DateTime? _parseReleaseDate(dynamic rawRelease) {
  if (rawRelease == null) return null;
  if (rawRelease is Timestamp) return rawRelease.toDate();
  if (rawRelease is String && rawRelease.isNotEmpty) {
    final parsed = DateTime.tryParse(rawRelease);
    if (parsed != null) return parsed;

    final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(rawRelease);
    if (match != null) {
      final year = int.tryParse(match.group(0)!);
      if (year != null) {
        return DateTime(year);
      }
    }
  }
  return null;
}

List<String> _normalizeGenres(Iterable<dynamic> genres) {
  const excludedGenres = {
    'Ecchi',
    'Hentai',
    'Erotica',
    'Talk-Show',
    'Reality-TV',
    'News',
    'Game-Show',
    'Short',
    'Adult',
    'Mecha',
    'Mahou Shoujo',
    'Card Battle',
  };

  final normalized = <String>[];
  final seen = <String>{};

  for (final value in genres) {
    final genre = value.toString().trim();
    if (genre.isEmpty || excludedGenres.contains(genre)) continue;

    final expanded = switch (genre) {
      'Action & Adventure' => const ['Action', 'Adventure'],
      'Sci-Fi & Fantasy' => const ['Sci-Fi', 'Fantasy'],
      'Science Fiction' => const ['Sci-Fi'],
      'Romance Comedy' => const ['Romance', 'Comedy'],
      _ => [genre],
    };

    for (final tag in expanded) {
      if (!excludedGenres.contains(tag) && seen.add(tag)) {
        normalized.add(tag);
      }
    }
  }

  return normalized;
}

class _WatchItem {
  final int tmdbId;
  final _WatchMediaType mediaType;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final double rating;
  final int runtimeMinutes;
  final DateTime? releaseDate;
  final int? seasons;
  final List<String> genres;
  final double matchPercentage;
  final String matchReason;

  const _WatchItem({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.rating,
    required this.runtimeMinutes,
    required this.releaseDate,
    required this.seasons,
    required this.genres,
    required this.matchPercentage,
    required this.matchReason,
  });

  String get tmdbKey => '${mediaType.name}_$tmdbId';
  String get posterUrl => posterPath.isEmpty
      ? ''
      : (posterPath.startsWith('http')
            ? posterPath
            : 'https://image.tmdb.org/t/p/w500$posterPath');
  String get backdropUrl => backdropPath.isEmpty
      ? ''
      : (backdropPath.startsWith('http')
            ? backdropPath
            : 'https://image.tmdb.org/t/p/w780$backdropPath');
  String get releaseYear =>
      releaseDate == null ? 'Unknown' : '${releaseDate!.year}';
  String get runtimeLabel =>
      runtimeMinutes > 0 ? '$runtimeMinutes min' : 'Runtime unavailable';
  String get genreLabel =>
      genres.isEmpty ? 'Genre mix' : _normalizeGenres(genres).join(' • ');
  String get mediaLabel =>
      mediaType == _WatchMediaType.movie ? 'Movie' : 'TV show';
  String? get seasonsLabel {
    if (mediaType != _WatchMediaType.tv || seasons == null) {
      return null;
    }
    return seasons == 1 ? '1 season' : '$seasons seasons';
  }
}

class _WatchDetails {
  final _WatchItem item;
  final List<String> cast;
  final List<String> providers;
  final String? tagline;
  final int? seasons;

  const _WatchDetails({
    required this.item,
    required this.cast,
    required this.providers,
    required this.tagline,
    required this.seasons,
  });
}

class _WatchRecord {
  final String id;
  final int tmdbId;
  final String mediaType;
  final String title;
  final String posterPath;
  final String backdropPath;
  final List<String> likedBy;
  final List<String> dislikedBy;
  final List<String> favoritedBy;
  final List<String> watchedBy;
  final double coupleMatchScore;
  final List<String> matchedGenres;
  final DateTime createdAt;
  final DateTime updatedAt;

  const _WatchRecord({
    required this.id,
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    required this.posterPath,
    required this.backdropPath,
    required this.likedBy,
    required this.dislikedBy,
    required this.favoritedBy,
    required this.watchedBy,
    required this.coupleMatchScore,
    required this.matchedGenres,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _WatchRecord.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    final createdTs = data['createdAt'] as Timestamp?;
    final updatedTs = data['updatedAt'] as Timestamp?;
    return _WatchRecord(
      id: doc.id,
      tmdbId: (data['tmdbId'] as num?)?.toInt() ?? 0,
      mediaType: (data['mediaType'] as String?) ?? 'movie',
      title: (data['title'] as String?) ?? 'Untitled',
      posterPath: (data['posterPath'] as String?) ?? '',
      backdropPath: (data['backdropPath'] as String?) ?? '',
      likedBy: List<String>.from((data['likedBy'] as List?) ?? const []),
      dislikedBy: List<String>.from((data['dislikedBy'] as List?) ?? const []),
      favoritedBy: List<String>.from(
        (data['favoritedBy'] as List?) ?? const [],
      ),
      watchedBy: List<String>.from((data['watchedBy'] as List?) ?? const []),
      coupleMatchScore: (data['coupleMatchScore'] as num?)?.toDouble() ?? 0,
      matchedGenres: _normalizeGenres(
        (data['matchedGenres'] as List?) ?? const [],
      ),
      createdAt: createdTs?.toDate() ?? DateTime.now(),
      updatedAt: updatedTs?.toDate() ?? DateTime.now(),
    );
  }

  bool isLikedBy(String uid) => likedBy.contains(uid);
  bool isDislikedBy(String uid) => dislikedBy.contains(uid);
  bool isFavoritedBy(String uid) => favoritedBy.contains(uid);
  bool isWatchedBy(String uid) => watchedBy.contains(uid);
}

class _WatchRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String?> resolvePartnerUid(String partnerEmail) async {
    final normalizedEmail = partnerEmail.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return null;
    }

    final partnerQuery = await _db
        .collection('users')
        .where('emailLower', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (partnerQuery.docs.isNotEmpty) {
      return partnerQuery.docs.first.id;
    }

    final fallbackQuery = await _db
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (fallbackQuery.docs.isNotEmpty) {
      return fallbackQuery.docs.first.id;
    }

    final allUsers = await _db.collection('users').limit(250).get();
    for (final doc in allUsers.docs) {
      final data = doc.data();
      final email =
          ((data['emailLower'] as String?) ?? (data['email'] as String?) ?? '')
              .trim()
              .toLowerCase();
      if (email == normalizedEmail) {
        return doc.id;
      }
    }

    return null;
  }

  Stream<List<_WatchRecord>> streamWatchRecords() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('watchItems')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_WatchRecord.fromDoc).toList());
  }

  Stream<List<_WatchRecord>> streamSharedWatchMatches() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('watchMatches')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_WatchRecord.fromDoc).toList());
  }

  Future<String?> fetchPartnerUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData == null) {
      return null;
    }

    final partnerEmail =
        ((userData['partnerEmailLower'] as String?) ??
                (userData['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();
    if (partnerEmail.isEmpty) {
      return null;
    }

    final partnerQuery = await _db
        .collection('users')
        .where('emailLower', isEqualTo: partnerEmail)
        .limit(1)
        .get();

    if (partnerQuery.docs.isNotEmpty) {
      return partnerQuery.docs.first.id;
    }

    final fallbackQuery = await _db
        .collection('users')
        .where('email', isEqualTo: partnerEmail)
        .limit(1)
        .get();

    if (fallbackQuery.docs.isEmpty) {
      final allUsers = await _db.collection('users').limit(250).get();
      for (final doc in allUsers.docs) {
        final data = doc.data();
        final email =
            ((data['emailLower'] as String?) ??
                    (data['email'] as String?) ??
                    '')
                .trim()
                .toLowerCase();
        if (email == partnerEmail) {
          return doc.id;
        }
      }
      return null;
    }

    return fallbackQuery.docs.first.id;
  }

  Future<List<_WatchItem>> fetchRecommendations() async {
    try {
      final querySnapshot = await _db
          .collection('watch_options')
          .limit(1500)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return _sampleRecommendations();
      }

      final items = querySnapshot.docs.map((doc) {
        final data = doc.data();
        final mediaTypeStr = (data['mediaType'] as String?) ?? 'movie';
        final mediaType = mediaTypeStr == 'tv'
            ? _WatchMediaType.tv
            : _WatchMediaType.movie;
        final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
        final rawGenres = List<dynamic>.from(
          (data['genres'] as List?) ?? const [],
        );
        final normalizedGenres = _normalizeGenres(rawGenres);

        final releaseDate = _parseReleaseDate(data['releaseDate']);

        return _WatchItem(
          tmdbId: (data['tmdbId'] as num?)?.toInt() ?? 0,
          mediaType: mediaType,
          title: (data['title'] as String?) ?? 'Untitled',
          overview: (data['overview'] as String?) ?? '',
          posterPath: (data['posterPath'] as String?) ?? '',
          backdropPath: (data['backdropPath'] as String?) ?? '',
          rating: rating,
          runtimeMinutes: (data['runtimeMinutes'] as num?)?.toInt() ?? 0,
          releaseDate: releaseDate,
          seasons: (data['seasons'] as num?)?.toInt(),
          genres: normalizedGenres.isEmpty
              ? _defaultGenresFor(mediaType)
              : normalizedGenres,
          matchPercentage: _predictMatchScore(rating, normalizedGenres),
          matchReason: _buildMatchReason(normalizedGenres, mediaType),
        );
      }).toList();

      items.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
      return items;
    } catch (e) {
      return _sampleRecommendations();
    }
  }

  Future<_WatchDetails> fetchDetails(_WatchItem item) async {
    try {
      final docSnap = await _db
          .collection('watch_options')
          .doc(item.tmdbKey)
          .get();

      if (!docSnap.exists) {
        return _WatchDetails(
          item: item,
          cast: const ['Cast unavailable'],
          providers: const ['Streaming options unavailable'],
          tagline: null,
          seasons: item.seasons,
        );
      }

      final data = docSnap.data()!;
      final cast = List<String>.from((data['cast'] as List?) ?? const []);
      final providers = List<String>.from(
        (data['providers'] as List?) ?? const [],
      );

      return _WatchDetails(
        item: item,
        cast: cast.isEmpty ? const ['Cast unavailable'] : cast,
        providers: providers.isEmpty
            ? const ['Streaming options unavailable']
            : providers,
        tagline: _cleanString(data['tagline'] as String?),
        seasons: (data['seasons'] as num?)?.toInt() ?? item.seasons,
      );
    } catch (_) {
      return _WatchDetails(
        item: item,
        cast: const ['Cast unavailable'],
        providers: const ['Streaming options unavailable'],
        tagline: null,
        seasons: item.seasons,
      );
    }
  }

  Future<void> updateInteraction({
    required _WatchItem item,
    bool? liked,
    bool? disliked,
    bool? favorited,
    bool? watched,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final partnerUid = await fetchPartnerUid();
    final now = Timestamp.now();
    final docId = item.tmdbKey;
    final userRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('watchItems')
        .doc(docId);
    final partnerRef = partnerUid == null
        ? null
        : _db
              .collection('users')
              .doc(partnerUid)
              .collection('watchItems')
              .doc(docId);

    final existing = await userRef.get();
    final existingData = existing.data() ?? <String, dynamic>{};
    final partnerExistingData = partnerRef == null
        ? <String, dynamic>{}
        : (await partnerRef.get()).data() ?? <String, dynamic>{};

    final likedBy = Set<String>.from(
      List<String>.from((existingData['likedBy'] as List?) ?? const []),
    );
    final dislikedBy = Set<String>.from(
      List<String>.from((existingData['dislikedBy'] as List?) ?? const []),
    );
    final favoritedBy = Set<String>.from(
      List<String>.from((existingData['favoritedBy'] as List?) ?? const []),
    );
    final watchedBy = Set<String>.from(
      List<String>.from((existingData['watchedBy'] as List?) ?? const []),
    );

    if (liked != null) {
      if (liked) {
        likedBy.add(user.uid);
        dislikedBy.remove(user.uid);
      } else {
        likedBy.remove(user.uid);
      }
    }

    if (disliked != null) {
      if (disliked) {
        dislikedBy.add(user.uid);
        likedBy.remove(user.uid);
      } else {
        dislikedBy.remove(user.uid);
      }
    }

    if (favorited != null) {
      if (favorited) {
        favoritedBy.add(user.uid);
      } else {
        favoritedBy.remove(user.uid);
      }
    }

    if (watched != null) {
      if (watched) {
        watchedBy.add(user.uid);
      } else {
        watchedBy.remove(user.uid);
      }
    }

    final matchedGenres = _deriveMatchedGenres(
      item,
      likedBy: likedBy.toList(),
      dislikedBy: dislikedBy.toList(),
      partnerUid: partnerUid,
    );
    final score = _calculateCoupleScore(
      item: item,
      likedBy: likedBy.toList(),
      dislikedBy: dislikedBy.toList(),
      favoritedBy: favoritedBy.toList(),
      watchedBy: watchedBy.toList(),
      matchedGenres: matchedGenres,
      partnerUid: partnerUid,
    );

    final payload = <String, Object?>{
      'tmdbId': item.tmdbId,
      'mediaType': item.mediaType.name,
      'title': item.title,
      'posterPath': item.posterPath,
      'backdropPath': item.backdropPath,
      'likedBy': likedBy.toList(),
      'dislikedBy': dislikedBy.toList(),
      'favoritedBy': favoritedBy.toList(),
      'watchedBy': watchedBy.toList(),
      'coupleMatchScore': score,
      'matchedGenres': matchedGenres,
      'createdAt': existingData['createdAt'] ?? now,
      'updatedAt': now,
    };

    await userRef.set(payload, SetOptions(merge: true));
    if (partnerUid != null) {
      final sharedMatchRef = _db
          .collection('users')
          .doc(user.uid)
          .collection('watchMatches')
          .doc(docId);
      final partnerMatchRef = _db
          .collection('users')
          .doc(partnerUid)
          .collection('watchMatches')
          .doc(docId);
      final partnerLikedBy = Set<String>.from(
        List<String>.from(
          (partnerExistingData['likedBy'] as List?) ?? const [],
        ),
      );
      final bothLiked =
          likedBy.contains(user.uid) && partnerLikedBy.contains(partnerUid);

      if (bothLiked) {
        final matchPayload = <String, Object?>{
          ...payload,
          'participants': [user.uid, partnerUid],
          'matchedAt': now,
        };
        await sharedMatchRef.set(matchPayload, SetOptions(merge: true));
        await partnerMatchRef.set(matchPayload, SetOptions(merge: true));
      } else {
        await sharedMatchRef.delete();
        await partnerMatchRef.delete();
      }
    }
  }

  Future<void> markWatchedTogether({required _WatchRecord record}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final partnerUid = await fetchPartnerUid();
    if (partnerUid == null) {
      return;
    }

    final now = Timestamp.now();
    final docId = record.id;
    final currentItemRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('watchItems')
        .doc(docId);
    final partnerItemRef = _db
        .collection('users')
        .doc(partnerUid)
        .collection('watchItems')
        .doc(docId);
    final currentMatchRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('watchMatches')
        .doc(docId);
    final partnerMatchRef = _db
        .collection('users')
        .doc(partnerUid)
        .collection('watchMatches')
        .doc(docId);

    final currentItemSnap = await currentItemRef.get();
    final currentItemData = currentItemSnap.data() ?? <String, dynamic>{};
    final partnerItemSnap = await partnerItemRef.get();
    final partnerItemData = partnerItemSnap.data() ?? <String, dynamic>{};

    final currentWatchedBy =
        Set<String>.from(
            List<String>.from(
              (currentItemData['watchedBy'] as List?) ?? const [],
            ),
          )
          ..add(user.uid)
          ..add(partnerUid);
    final partnerWatchedBy =
        Set<String>.from(
            List<String>.from(
              (partnerItemData['watchedBy'] as List?) ?? const [],
            ),
          )
          ..add(user.uid)
          ..add(partnerUid);

    final currentPayload = <String, Object?>{
      'tmdbId': record.tmdbId,
      'mediaType': record.mediaType,
      'title': record.title,
      'posterPath': record.posterPath,
      'backdropPath': record.backdropPath,
      'likedBy': List<String>.from(
        (currentItemData['likedBy'] as List?) ?? const [],
      ),
      'dislikedBy': List<String>.from(
        (currentItemData['dislikedBy'] as List?) ?? const [],
      ),
      'favoritedBy': List<String>.from(
        (currentItemData['favoritedBy'] as List?) ?? const [],
      ),
      'watchedBy': currentWatchedBy.toList(),
      'coupleMatchScore':
          (currentItemData['coupleMatchScore'] as num?)?.toDouble() ??
          record.coupleMatchScore,
      'matchedGenres': List<String>.from(
        (currentItemData['matchedGenres'] as List?) ?? record.matchedGenres,
      ),
      'createdAt': currentItemData['createdAt'] ?? now,
      'updatedAt': now,
    };

    final partnerPayload = <String, Object?>{
      'tmdbId': record.tmdbId,
      'mediaType': record.mediaType,
      'title': record.title,
      'posterPath': record.posterPath,
      'backdropPath': record.backdropPath,
      'likedBy': List<String>.from(
        (partnerItemData['likedBy'] as List?) ?? const [],
      ),
      'dislikedBy': List<String>.from(
        (partnerItemData['dislikedBy'] as List?) ?? const [],
      ),
      'favoritedBy': List<String>.from(
        (partnerItemData['favoritedBy'] as List?) ?? const [],
      ),
      'watchedBy': partnerWatchedBy.toList(),
      'coupleMatchScore':
          (partnerItemData['coupleMatchScore'] as num?)?.toDouble() ??
          record.coupleMatchScore,
      'matchedGenres': List<String>.from(
        (partnerItemData['matchedGenres'] as List?) ?? record.matchedGenres,
      ),
      'createdAt': partnerItemData['createdAt'] ?? now,
      'updatedAt': now,
    };

    await currentItemRef.set(currentPayload, SetOptions(merge: true));
    await partnerItemRef.set(partnerPayload, SetOptions(merge: true));

    final watchedTogetherPayload = <String, Object?>{
      ...currentPayload,
      'participants': [user.uid, partnerUid],
      'watchedTogetherAt': now,
      'watchedBy': [user.uid, partnerUid],
    };

    await currentMatchRef.set(watchedTogetherPayload, SetOptions(merge: true));
    await partnerMatchRef.set(watchedTogetherPayload, SetOptions(merge: true));
  }

  String? _cleanString(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  List<String> _deriveMatchedGenres(
    _WatchItem item, {
    required List<String> likedBy,
    required List<String> dislikedBy,
    required String? partnerUid,
  }) {
    final normalizedGenres = _normalizeGenres(item.genres);

    if (likedBy.isEmpty && dislikedBy.isEmpty) {
      return normalizedGenres.take(2).toList();
    }

    if (partnerUid != null && likedBy.contains(partnerUid)) {
      return normalizedGenres.take(3).toList();
    }

    if (likedBy.isNotEmpty) {
      return normalizedGenres.take(2).toList();
    }

    return normalizedGenres.take(1).toList();
  }

  double _calculateCoupleScore({
    required _WatchItem item,
    required List<String> likedBy,
    required List<String> dislikedBy,
    required List<String> favoritedBy,
    required List<String> watchedBy,
    required List<String> matchedGenres,
    required String? partnerUid,
  }) {
    final hasBothLiked = partnerUid != null && likedBy.contains(partnerUid);
    final hasBothDisliked =
        partnerUid != null && dislikedBy.contains(partnerUid);
    final anyLiked = likedBy.isNotEmpty;
    final anyDisliked = dislikedBy.isNotEmpty;
    final base = item.matchPercentage;

    double score;
    if (hasBothLiked) {
      score = 94;
    } else if (hasBothDisliked) {
      score = 14;
    } else if (anyLiked && anyDisliked) {
      score = 38;
    } else if (anyLiked) {
      score = 74;
    } else if (anyDisliked) {
      score = 22;
    } else {
      score = base;
    }

    score += matchedGenres.length * 1.5;
    score += favoritedBy.isNotEmpty ? 4 : 0;
    score += watchedBy.isNotEmpty ? 2 : 0;
    return score.clamp(0, 100).toDouble();
  }

  double _predictMatchScore(double rating, List<String> genres) {
    final romanceBonus =
        genres.any(
          (genre) => const {'Romance', 'Comedy', 'Drama'}.contains(genre),
        )
        ? 10
        : 4;
    final varietyBonus = genres.length >= 2 ? 8 : 4;
    final ratingScore = (rating / 10) * 70;
    return (ratingScore + romanceBonus + varietyBonus).clamp(35, 92).toDouble();
  }

  String _buildMatchReason(List<String> genres, _WatchMediaType mediaType) {
    if (genres.contains('Romance') && genres.contains('Comedy')) {
      return 'You both like romance and comedy.';
    }
    if (genres.contains('Romance')) {
      return 'A tender pick that leans into romance.';
    }
    if (genres.contains('Comedy')) {
      return 'A lighter pick with easy shared laughs.';
    }
    if (genres.contains('Drama')) {
      return 'A thoughtful story for a slower night together.';
    }
    return mediaType == _WatchMediaType.movie
        ? 'A cozy movie-night option with shared appeal.'
        : 'A relaxed series pick for your shared watchlist.';
  }

  List<String> _defaultGenresFor(_WatchMediaType mediaType) {
    return mediaType == _WatchMediaType.movie
        ? const ['Drama', 'Romance']
        : const ['Comedy', 'Drama'];
  }

  List<_WatchItem> _sampleRecommendations() {
    return [
      _WatchItem(
        tmdbId: 496243,
        mediaType: _WatchMediaType.movie,
        title: 'Parasite',
        overview:
            'Greed and class discrimination threaten the newly formed relationship between the wealthy Park family and the destitute Kim clan.',
        posterPath: '/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg',
        backdropPath: '/sw7mordbZxgITU877yTpZCud90M.jpg',
        rating: 8.5,
        runtimeMinutes: 132,
        releaseDate: DateTime(2019, 5, 30),
        seasons: null,
        genres: const ['Drama', 'Thriller'],
        matchPercentage: 88,
        matchReason:
            'A sharp, conversation-starting thriller with drama at its core.',
      ),
    ];
  }
}

class _FilterPanel extends StatelessWidget {
  final ColorScheme cs;
  final ThemeData theme;
  final _WatchFeedFilter filter;
  final Set<String> selectedRegions;
  final Set<String> selectedGenres;
  final List<String> genres;
  final double minRating;
  final double maxRuntime;
  final RangeValues yearRange;
  final ValueChanged<_WatchFeedFilter> onFilterChanged;
  final ValueChanged<String> onRegionToggled;
  final ValueChanged<String?> onGenreToggled;
  final ValueChanged<double> onRatingChanged;
  final ValueChanged<double> onRuntimeChanged;
  final ValueChanged<RangeValues> onYearRangeChanged;

  const _FilterPanel({
    required this.cs,
    required this.theme,
    required this.filter,
    required this.selectedRegions,
    required this.selectedGenres,
    required this.genres,
    required this.minRating,
    required this.maxRuntime,
    required this.yearRange,
    required this.onFilterChanged,
    required this.onRegionToggled,
    required this.onGenreToggled,
    required this.onRatingChanged,
    required this.onRuntimeChanged,
    required this.onYearRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final chips = [
      ('All Picks', Icons.auto_awesome_rounded, _WatchFeedFilter.all),
      ('Movies', Icons.movie_rounded, _WatchFeedFilter.movies),
      ('TV Shows', Icons.tv_rounded, _WatchFeedFilter.tv),
    ];

    final regionOptions = ['US / CAD', 'Korean', 'Japanese', 'Anime'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterSectionLabel(cs: cs, text: 'Media Type'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: chips.map((chip) {
              final selected = filter == chip.$3;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onFilterChanged(chip.$3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? cs.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          chip.$2,
                          size: 18,
                          color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          chip.$1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 22),
        _FilterSectionLabel(cs: cs, text: 'Region & Type'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: regionOptions.map((region) {
            final isSelected = selectedRegions.contains(region);
            return _SolidChip(
              cs: cs,
              label: region,
              selected: isSelected,
              onTap: () => onRegionToggled(region),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        _FilterSectionLabel(cs: cs, text: 'Genres'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SolidChip(
              cs: cs,
              label: 'All Genres',
              selected: selectedGenres.isEmpty,
              onTap: () => onGenreToggled(null),
            ),
            ...genres.map(
              (genre) => _SolidChip(
                cs: cs,
                label: genre,
                selected: selectedGenres.contains(genre),
                onTap: () => onGenreToggled(genre),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _FilterSliderCard(
          cs: cs,
          icon: Icons.calendar_month_rounded,
          title: 'Release Year',
          valueLabel: '${yearRange.start.round()} - ${yearRange.end.round()}',
          child: RangeSlider(
            values: yearRange,
            min: 1980,
            max: 2026,
            divisions: 46,
            activeColor: cs.primary,
            inactiveColor: cs.outlineVariant,
            labels: RangeLabels(
              '${yearRange.start.round()}',
              '${yearRange.end.round()}',
            ),
            onChanged: onYearRangeChanged,
          ),
        ),
        const SizedBox(height: 12),
        _FilterSliderCard(
          cs: cs,
          icon: Icons.star_rounded,
          title: 'Minimum Rating',
          valueLabel: '${minRating.toStringAsFixed(1)}+',
          child: Slider(
            value: minRating,
            min: 0,
            max: 10,
            divisions: 20,
            activeColor: cs.primary,
            inactiveColor: cs.outlineVariant,
            label: minRating.toStringAsFixed(1),
            onChanged: onRatingChanged,
          ),
        ),
        const SizedBox(height: 12),
        _FilterSliderCard(
          cs: cs,
          icon: Icons.timer_outlined,
          title: 'Maximum Runtime',
          valueLabel: '${maxRuntime.round()} min',
          child: Slider(
            value: maxRuntime,
            min: 20,
            max: 240,
            divisions: 11,
            activeColor: cs.primary,
            inactiveColor: cs.outlineVariant,
            label: '${maxRuntime.round()} min',
            onChanged: onRuntimeChanged,
          ),
        ),
      ],
    );
  }
}

class _FilterSectionLabel extends StatelessWidget {
  final ColorScheme cs;
  final String text;

  const _FilterSectionLabel({required this.cs, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

class _SolidChip extends StatelessWidget {
  final ColorScheme cs;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SolidChip({
    required this.cs,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? cs.onPrimaryContainer : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _FilterSliderCard extends StatelessWidget {
  final ColorScheme cs;
  final IconData icon;
  final String title;
  final String valueLabel;
  final Widget child;

  const _FilterSliderCard({
    required this.cs,
    required this.icon,
    required this.title,
    required this.valueLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(
                  valueLabel,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _MatchedTimelineFeed extends StatefulWidget {
  final ColorScheme cs;
  final String currentUserId;
  final String? partnerUid;
  final Future<void> Function(_WatchRecord record) onMarkWatchedTogether;
  final Future<void> Function(_WatchRecord record) onOpenDetails;
  final List<_MatchedTimelineEntry> entries;

  const _MatchedTimelineFeed({
    required this.cs,
    required this.currentUserId,
    required this.partnerUid,
    required this.onMarkWatchedTogether,
    required this.onOpenDetails,
    required this.entries,
  });

  @override
  State<_MatchedTimelineFeed> createState() => _MatchedTimelineFeedState();
}

enum _MatchedTabFilter { unwatched, watched }

class _MatchedTimelineFeedState extends State<_MatchedTimelineFeed> {
  _MatchedTabFilter _selectedFilter = _MatchedTabFilter.unwatched;
  String? _animatingRecordId;

  String _dateLabel(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  void _handleMarkWatched(_WatchRecord record) async {
    setState(() {
      _animatingRecordId = record.id;
    });

    await Future.delayed(const Duration(milliseconds: 850));
    await widget.onMarkWatchedTogether(record);

    if (mounted) {
      setState(() {
        _animatingRecordId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;

    final sortedEntries = [...widget.entries]
      ..sort(
        (left, right) =>
            right.record.updatedAt.compareTo(left.record.updatedAt),
      );

    final filteredEntries = sortedEntries.where((entry) {
      final isWatched =
          widget.partnerUid != null &&
          entry.record.watchedBy.contains(widget.currentUserId) &&
          entry.record.watchedBy.contains(widget.partnerUid);

      if (_selectedFilter == _MatchedTabFilter.unwatched) {
        return !isWatched;
      } else {
        return isWatched;
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: _selectedFilter == _MatchedTabFilter.unwatched
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(
                        () => _selectedFilter = _MatchedTabFilter.unwatched,
                      ),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color:
                                _selectedFilter == _MatchedTabFilter.unwatched
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                          ),
                          child: const Text('Unwatched'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(
                        () => _selectedFilter = _MatchedTabFilter.watched,
                      ),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedFilter == _MatchedTabFilter.watched
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                          ),
                          child: const Text('Watched'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (filteredEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                _selectedFilter == _MatchedTabFilter.unwatched
                    ? 'No unwatched picks right now.'
                    : 'No watched matches yet.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else
          for (final entry in filteredEntries) ...[
            () {
              final record = entry.record;
              final watchedTogether =
                  widget.partnerUid != null &&
                  record.watchedBy.contains(widget.currentUserId) &&
                  record.watchedBy.contains(widget.partnerUid);
              final isDissolving = _animatingRecordId == record.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => widget.onOpenDetails(record),
                    child: _CardDissolveWrapper(
                      isDissolving: isDissolving,
                      child: Container(
                        height: 212,
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cs.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(24),
                                  ),
                                  child: SizedBox(
                                    width: 132,
                                    height: double.infinity,
                                    child: record.posterPath.isEmpty
                                        ? _PosterFallback(cs: cs)
                                        : Image.network(
                                            record.posterPath.startsWith('http')
                                                ? record.posterPath
                                                : 'https://image.tmdb.org/t/p/w500${record.posterPath}',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _PosterFallback(cs: cs),
                                          ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      14,
                                      14,
                                      12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _TimelineChip(
                                              label: record.mediaType == 'tv'
                                                  ? 'TV Show'
                                                  : 'Movie',
                                              filled: true,
                                            ),
                                            const SizedBox(width: 8),
                                            _TimelineChip(label: 'Shared Yes'),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Flexible(
                                          fit: FlexFit.loose,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                record.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Matched ${_dateLabel(record.updatedAt)}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                    ),
                                              ),
                                              if (record
                                                  .matchedGenres
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: record.matchedGenres
                                                      .take(2)
                                                      .map(
                                                        (genre) =>
                                                            _TimelineChip(
                                                              label: genre,
                                                            ),
                                                      )
                                                      .toList(),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            onPressed:
                                                widget.partnerUid == null ||
                                                    watchedTogether ||
                                                    isDissolving
                                                ? null
                                                : () => _handleMarkWatched(
                                                    record,
                                                  ),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: cs.primary,
                                              foregroundColor: cs.onPrimary,
                                            ),
                                            icon: Icon(
                                              watchedTogether
                                                  ? Icons
                                                        .check_circle_outline_rounded
                                                  : Icons
                                                        .play_circle_outline_rounded,
                                            ),
                                            label: Text(
                                              watchedTogether
                                                  ? 'Watched Together'
                                                  : 'Mark Watched',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (watchedTogether)
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            if (isDissolving)
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: _PopcornKernelRiseOverlay(cs: cs),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }(),
          ],
      ],
    );
  }
}

class _CardDissolveWrapper extends StatefulWidget {
  final bool isDissolving;
  final Widget child;

  const _CardDissolveWrapper({required this.isDissolving, required this.child});

  @override
  State<_CardDissolveWrapper> createState() => _CardDissolveWrapperState();
}

class _CardDissolveWrapperState extends State<_CardDissolveWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInQuad));

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -0.1),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_CardDissolveWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDissolving && !oldWidget.isDissolving) {
      _controller.forward();
    } else if (!widget.isDissolving && oldWidget.isDissolving) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(opacity: _opacityAnimation, child: widget.child),
      ),
    );
  }
}

class _PopcornKernelRiseOverlay extends StatefulWidget {
  final ColorScheme cs;

  const _PopcornKernelRiseOverlay({required this.cs});

  @override
  State<_PopcornKernelRiseOverlay> createState() =>
      _PopcornKernelRiseOverlayState();
}

class _PopcornKernelRiseOverlayState extends State<_PopcornKernelRiseOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_KernelParticle> _kernels = [];

  @override
  void initState() {
    super.initState();
    final rand = math.Random();

    for (int i = 0; i < 7; i++) {
      _kernels.add(
        _KernelParticle(
          startXRatio: 0.15 + (i * 0.11) + (rand.nextDouble() * 0.06 - 0.03),
          horizontalDrift: (rand.nextDouble() - 0.5) * 45.0,
          peakHeight: 90.0 + rand.nextDouble() * 70.0,
          scale: 0.95 + rand.nextDouble() * 0.4,
          rotation: (rand.nextDouble() - 0.5) * 1.8,
        ),
      );
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final opacity = (1.0 - progress).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth;
            final cardHeight = constraints.maxHeight;

            return Stack(
              children: _kernels.map((kernel) {
                final t = progress;
                final dy = -4 * kernel.peakHeight * t * (1 - t);
                final dx = kernel.horizontalDrift * t;

                final posX = (cardWidth * kernel.startXRatio) + dx;
                final posY = cardHeight - 20.0 + dy;

                return Positioned(
                  left: posX,
                  top: posY,
                  child: Transform.rotate(
                    angle: kernel.rotation * t,
                    child: Transform.scale(
                      scale: kernel.scale * (0.8 + t * 0.4),
                      child: Opacity(
                        opacity: opacity,
                        child: CustomPaint(
                          size: const Size(36, 36),
                          painter: _PopcornKernelSilhouettePainter(
                            color: widget.cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _KernelParticle {
  final double startXRatio;
  final double horizontalDrift;
  final double peakHeight;
  final double scale;
  final double rotation;

  _KernelParticle({
    required this.startXRatio,
    required this.horizontalDrift,
    required this.peakHeight,
    required this.scale,
    required this.rotation,
  });
}

class _PopcornKernelSilhouettePainter extends CustomPainter {
  final Color color;

  _PopcornKernelSilhouettePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path = Path();

    path.addOval(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.65), radius: w * 0.32),
    );
    path.addOval(
      Rect.fromCircle(center: Offset(w * 0.32, h * 0.38), radius: w * 0.28),
    );
    path.addOval(
      Rect.fromCircle(center: Offset(w * 0.68, h * 0.38), radius: w * 0.28),
    );
    path.addOval(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.28), radius: w * 0.22),
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MatchedTimelineEntry {
  final _WatchRecord record;

  const _MatchedTimelineEntry({required this.record});
}

class _MatchedPosterThumb extends StatelessWidget {
  final String posterUrl;
  final ColorScheme cs;

  const _MatchedPosterThumb({required this.posterUrl, required this.cs});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        height: 108,
        color: cs.surfaceContainerHighest,
        child: posterUrl.isEmpty
            ? Icon(Icons.image_outlined, color: cs.onSurfaceVariant)
            : Image.network(
                posterUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
              ),
      ),
    );
  }
}

class _TimelineChip extends StatelessWidget {
  final String label;
  final bool filled;

  const _TimelineChip({required this.label, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? cs.primary : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? cs.primary : cs.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: filled ? cs.onPrimary : cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PersonalHistoryPanel extends StatefulWidget {
  final ColorScheme cs;
  final String currentUserId;
  final List<_WatchRecord> records;

  const _PersonalHistoryPanel({
    super.key,
    required this.cs,
    required this.currentUserId,
    required this.records,
  });

  @override
  State<_PersonalHistoryPanel> createState() => _PersonalHistoryPanelState();
}

class _PersonalHistoryPanelState extends State<_PersonalHistoryPanel> {
  int _visibleCount = 5;

  void _loadMore() {
    setState(() {
      _visibleCount += 5;
    });
  }

  String _historySubtitle(_WatchRecord record, String currentUserId) {
    final parts = <String>[];
    if (record.isLikedBy(currentUserId)) parts.add('You Liked');
    if (record.isDislikedBy(currentUserId)) parts.add('You Passed');
    if (record.isWatchedBy(currentUserId)) parts.add('Watched');
    if (parts.isEmpty) parts.add('No personal vote');
    final date = record.updatedAt;
    final dateLabel =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '${parts.join(' • ')} · $dateLabel';
  }

  @override
  Widget build(BuildContext context) {
    final displayedRecords = widget.records.take(_visibleCount).toList();
    final hasMore = widget.records.length > _visibleCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.records.isEmpty)
            _HistoryEmptyState(
              cs: widget.cs,
              icon: Icons.local_fire_department_outlined,
              title: 'Start building your taste profile',
              subtitle:
                  'Your personal milestones will appear here as you vote.',
              milestones: const [
                'Like a few picks you want to revisit',
                'Dislike the ones you want to skip',
                'Save favorites and build a pattern',
              ],
            )
          else ...[
            Column(
              children: displayedRecords
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          _MatchedPosterThumb(
                            posterUrl: record.posterPath.isEmpty
                                ? ''
                                : (record.posterPath.startsWith('http')
                                      ? record.posterPath
                                      : 'https://image.tmdb.org/t/p/w500${record.posterPath}'),
                            cs: widget.cs,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _historySubtitle(
                                    record,
                                    widget.currentUserId,
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: widget.cs.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (hasMore) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loadMore,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: widget.cs.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    Icons.expand_more_rounded,
                    color: widget.cs.primary,
                  ),
                  label: Text(
                    'Load More',
                    style: TextStyle(
                      color: widget.cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TopViewDropdown extends StatefulWidget {
  final _TopView value;
  final ValueChanged<_TopView> onChanged;
  final ColorScheme cs;

  const _TopViewDropdown({
    required this.value,
    required this.onChanged,
    required this.cs,
  });

  @override
  State<_TopViewDropdown> createState() => _TopViewDropdownState();
}

class _TopViewDropdownState extends State<_TopViewDropdown> {
  Future<void> _showMenu() async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final size = MediaQuery.of(context).size;
    final left = offset.dx;
    final top = offset.dy + box.size.height;
    final right = size.width - offset.dx - box.size.width;
    final bottom = size.height - top;

    final selected = await showMenu<_TopView>(
      context: context,
      position: RelativeRect.fromLTRB(left, top, right, bottom),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      items: [
        PopupMenuItem(
          value: _TopView.suggestions,
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, color: widget.cs.onSurface),
              const SizedBox(width: 8),
              const Text('Suggestions'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _TopView.matched,
          child: Row(
            children: [
              Icon(Icons.favorite_border_rounded, color: widget.cs.onSurface),
              const SizedBox(width: 8),
              const Text('Matched'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _TopView.history,
          child: Row(
            children: [
              Icon(Icons.history, color: widget.cs.onSurface),
              const SizedBox(width: 8),
              const Text('History'),
            ],
          ),
        ),
      ],
    );

    if (selected != null) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final label = switch (widget.value) {
      _TopView.suggestions => 'Suggestions',
      _TopView.matched => 'Matched',
      _TopView.history => 'History',
    };
    final icon = switch (widget.value) {
      _TopView.suggestions => Icons.lightbulb_outline,
      _TopView.matched => Icons.favorite_border_rounded,
      _TopView.history => Icons.history,
    };

    return GestureDetector(
      onTap: _showMenu,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.onPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: cs.onPrimary),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final ColorScheme cs;
  final _WatchItem item;
  final double score;
  final _WatchRecord? record;
  final String currentUserId;
  final String? partnerUid;
  final VoidCallback onOpenDetails;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const _RecommendationCard({
    required this.cs,
    required this.item,
    required this.score,
    required this.record,
    required this.currentUserId,
    required this.partnerUid,
    required this.onOpenDetails,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked = record?.isLikedBy(currentUserId) ?? false;
    final isDisliked = record?.isDislikedBy(currentUserId) ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: AspectRatio(
            aspectRatio: 0.65,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: item.posterUrl.isNotEmpty
                        ? Image.network(
                            item.posterUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _PosterFallback(cs: cs),
                          )
                        : _PosterFallback(cs: cs),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.94),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: _Pill(
                    label: item.mediaLabel,
                    background: cs.surface.withValues(alpha: 0.88),
                    foreground: cs.onSurface,
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.mediaType == _WatchMediaType.tv
                            ? '${item.releaseYear} • ${item.seasonsLabel ?? 'TV Show'}'
                            : '${item.releaseYear} • ${item.runtimeLabel}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.genreLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.overview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _StyledActionButton(
                              label: 'Pass',
                              icon: Icons.close_rounded,
                              isPass: true,
                              selected: isDisliked,
                              onTap: onNo,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StyledActionButton(
                              label: 'Interested',
                              icon: Icons.favorite_rounded,
                              isPass: false,
                              selected: isLiked,
                              onTap: onYes,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StyledActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPass;
  final bool selected;
  final VoidCallback onTap;

  const _StyledActionButton({
    required this.label,
    required this.icon,
    required this.isPass,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeBg = isPass ? Colors.grey.shade900 : cs.primary;
    final activeFg = isPass ? Colors.white : cs.onPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? activeBg : Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? (isPass ? Colors.white54 : cs.primary)
                  : Colors.white.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: selected ? activeFg : Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? activeFg : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;

  const _DetailStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelSmall);
  }
}

class _EmptyWatchState extends StatelessWidget {
  final ColorScheme cs;
  final String title;
  final String subtitle;

  const _EmptyWatchState({
    required this.cs,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_filter_outlined, color: cs.primary, size: 48),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchedTimelineState extends StatelessWidget {
  final ColorScheme cs;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> milestones;

  const _MatchedTimelineState({
    required this.cs,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.milestones,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Icon(icon, color: cs.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < milestones.length; index++) ...[
            Padding(
              padding: EdgeInsets.only(
                bottom: index == milestones.length - 1 ? 0 : 12,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 32,
                      child: Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: index.isEven
                                  ? cs.primary
                                  : cs.primaryContainer,
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.primary, width: 1.5),
                            ),
                          ),
                          if (index != milestones.length - 1)
                            Expanded(
                              child: Container(
                                width: 1.5,
                                color: cs.primary.withValues(alpha: 0.2),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: index.isEven
                                ? cs.primaryContainer
                                : theme.brightness == Brightness.dark
                                ? const Color(0xFF231519)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: index.isEven
                                  ? cs.primary.withValues(alpha: 0.3)
                                  : cs.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                index.isEven ? Icons.favorite_rounded : icon,
                                color: cs.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  milestones[index],
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  final ColorScheme cs;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> milestones;

  const _HistoryEmptyState({
    required this.cs,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.milestones,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: cs.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...List.generate(milestones.length, (index) {
            final isLast = index == milestones.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 24,
                          color: cs.outlineVariant,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        milestones[index],
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BackdropFallback extends StatelessWidget {
  final ColorScheme cs;

  const _BackdropFallback({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.9),
            cs.secondaryContainer.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.movie_outlined, color: cs.primary, size: 40),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  final ColorScheme cs;

  const _PosterFallback({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.primaryContainer.withValues(alpha: 0.9),
      child: Icon(Icons.local_movies_outlined, color: cs.primary, size: 28),
    );
  }
}
