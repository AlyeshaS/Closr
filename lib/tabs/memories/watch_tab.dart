import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class WatchTab extends StatefulWidget {
  const WatchTab({super.key});

  @override
  State<WatchTab> createState() => _WatchTabState();
}

class _WatchTabState extends State<WatchTab> {
  final _repository = _WatchRepository();

  late Future<List<_WatchItem>> _recommendationsFuture;
  late Future<String?> _partnerUidFuture;

  _WatchFeedFilter _filter = _WatchFeedFilter.all;
  _TopView _topView = _TopView.suggestions;
  String? _selectedGenre;
  double _minRating = 0;
  double _maxRuntime = 240;

  @override
  void initState() {
    super.initState();
    _recommendationsFuture = _repository.fetchRecommendations();
    _partnerUidFuture = _repository.fetchPartnerUid();
  }

  String _activeFilterLabel(_WatchFeedFilter filter, String? genre) {
    final filterLabel = switch (filter) {
      _WatchFeedFilter.all => 'All media',
      _WatchFeedFilter.bothYes => 'Both yes',
      _WatchFeedFilter.oneYes => 'One yes',
      _WatchFeedFilter.anyNo => 'Any no',
      _WatchFeedFilter.favorites => 'Favorites',
      _WatchFeedFilter.watched => 'Watched',
      _WatchFeedFilter.unwatched => 'Unwatched',
      _WatchFeedFilter.movies => 'Movies only',
      _WatchFeedFilter.tv => 'TV shows only',
    };

    if (genre == null) {
      return filterLabel;
    }

    return '$filterLabel · $genre';
  }

  Future<void> _openFilterSheet({
    required ColorScheme cs,
    required _WatchFeedFilter filter,
    required String? selectedGenre,
    required List<String> genres,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filter watch picks',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filter = _WatchFeedFilter.all;
                          _selectedGenre = null;
                          _minRating = 0;
                          _maxRuntime = 240;
                        });
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _FilterPanel(
                  cs: cs,
                  filter: filter,
                  selectedGenre: selectedGenre,
                  genres: genres,
                  minRating: _minRating,
                  maxRuntime: _maxRuntime,
                  onFilterChanged: (value) => setState(() => _filter = value),
                  onGenreChanged: (value) =>
                      setState(() => _selectedGenre = value),
                  onRatingChanged: (value) =>
                      setState(() => _minRating = value),
                  onRuntimeChanged: (value) =>
                      setState(() => _maxRuntime = value),
                ),
              ],
            ),
          ),
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
      genres.addAll(item.genres);
    }
    for (final record in records) {
      genres.addAll(record.matchedGenres);
    }
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
    final currentLiked = record?.isLikedBy(currentUid) ?? false;
    final currentDisliked = record?.isDislikedBy(currentUid) ?? false;
    final currentFavorited = record?.isFavoritedBy(currentUid) ?? false;
    final currentWatched = record?.isWatchedBy(currentUid) ?? false;
    final partnerLiked = partnerUid != null
        ? record?.isLikedBy(partnerUid) ?? false
        : false;
    final partnerDisliked = partnerUid != null
        ? record?.isDislikedBy(partnerUid) ?? false
        : false;

    switch (_filter) {
      case _WatchFeedFilter.all:
        break;
      case _WatchFeedFilter.bothYes:
        if (!(currentLiked && partnerLiked)) return false;
        break;
      case _WatchFeedFilter.oneYes:
        final yesCount = (currentLiked ? 1 : 0) + (partnerLiked ? 1 : 0);
        if (yesCount != 1) return false;
        break;
      case _WatchFeedFilter.anyNo:
        if (!(currentDisliked || partnerDisliked)) return false;
        break;
      case _WatchFeedFilter.favorites:
        if (!currentFavorited) return false;
        break;
      case _WatchFeedFilter.watched:
        if (!currentWatched) return false;
        break;
      case _WatchFeedFilter.unwatched:
        if (currentWatched) return false;
        break;
      case _WatchFeedFilter.movies:
        if (item.mediaType != _WatchMediaType.movie) return false;
        break;
      case _WatchFeedFilter.tv:
        if (item.mediaType != _WatchMediaType.tv) return false;
        break;
    }

    if (_selectedGenre != null && !item.genres.contains(_selectedGenre)) {
      return false;
    }

    if (item.rating < _minRating) {
      return false;
    }

    if (item.runtimeMinutes > _maxRuntime) {
      return false;
    }

    return true;
  }

  String _headlineForFilter() {
    switch (_filter) {
      case _WatchFeedFilter.all:
        return 'Your cozy movie and TV shortlist.';
      case _WatchFeedFilter.bothYes:
        return 'Items you both already said yes to.';
      case _WatchFeedFilter.oneYes:
        return 'Ideas where one of you has already shown interest.';
      case _WatchFeedFilter.anyNo:
        return 'Places where you have mixed opinions.';
      case _WatchFeedFilter.favorites:
        return 'Your saved favorites, ready for tonight.';
      case _WatchFeedFilter.watched:
        return 'What you have already watched together.';
      case _WatchFeedFilter.unwatched:
        return 'Fresh picks you have not watched yet.';
      case _WatchFeedFilter.movies:
        return 'Just movies for a film night.';
      case _WatchFeedFilter.tv:
        return 'Just TV shows for a longer cuddle session.';
    }
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
    if ((currentLiked && partnerDisliked) || (currentDisliked && partnerLiked))
      return 34;
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
                          value: details.item.rating.toStringAsFixed(1),
                        ),
                        const SizedBox(width: 10),
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
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      details.item.overview,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 18),
                    const _SectionLabel(text: 'Cast'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: details.cast
                          .map((castMember) => Chip(label: Text(castMember)))
                          .toList(),
                    ),
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
                    const SizedBox(height: 16),
                    Text(
                      'Data and images via TMDb.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
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

        return FutureBuilder<String?>(
          future: _partnerUidFuture,
          builder: (context, partnerSnapshot) {
            final partnerUid = partnerSnapshot.data;

            return StreamBuilder<List<_WatchRecord>>(
              stream: _repository.streamWatchRecords(),
              builder: (context, recordsSnapshot) {
                final records = recordsSnapshot.data ?? const <_WatchRecord>[];
                final genres = _collectGenres(recommendations, records);
                final selectedGenre = genres.contains(_selectedGenre)
                    ? _selectedGenre
                    : null;
                final filteredItems = recommendations.where((item) {
                  final record = _recordFor(item, records);
                  if (selectedGenre != null &&
                      !item.genres.contains(selectedGenre)) {
                    return false;
                  }
                  return _matchesFilter(item, record, user.uid, partnerUid);
                }).toList();

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                      sliver: SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: _TopViewDropdown(
                                  value: _topView,
                                  cs: cs,
                                  onChanged: (value) {
                                    setState(() {
                                      _topView = value;
                                      if (value == _TopView.suggestions) {
                                        _filter = _WatchFeedFilter.all;
                                      } else if (value == _TopView.matched) {
                                        _filter = _WatchFeedFilter.bothYes;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 110,
                                child: FilledButton.tonal(
                                  onPressed: () => _openFilterSheet(
                                    cs: cs,
                                    filter: _filter,
                                    selectedGenre: selectedGenre,
                                    genres: genres,
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.tune_rounded,
                                        size: 18,
                                        color: cs.onSurface,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Filter',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: cs.onSurface),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (recommendationsSnapshot.connectionState ==
                        ConnectionState.waiting)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(color: cs.primary),
                        ),
                      )
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        sliver: SliverToBoxAdapter(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: _topView == _TopView.history
                                ? _PersonalHistoryPanel(
                                    key: const ValueKey('history'),
                                    cs: cs,
                                    currentUserId: user.uid,
                                    records: records,
                                  )
                                : const SizedBox.shrink(key: ValueKey('empty')),
                          ),
                        ),
                      ),

                      if (_topView == _TopView.matched)
                        if (filteredItems.isEmpty)
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
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                            sliver: SliverToBoxAdapter(
                              child: _MatchedTimelineFeed(
                                cs: cs,
                                entries: filteredItems
                                    .map(
                                      (item) => _MatchedTimelineEntry(
                                        item: item,
                                        record: _recordFor(item, records),
                                        score: _displayScore(
                                          item,
                                          _recordFor(item, records),
                                          user.uid,
                                          partnerUid,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                currentUserId: user.uid,
                                partnerUid: partnerUid,
                              ),
                            ),
                          )
                      // FIX 3: Do not render the card grid when in history view
                      else if (_topView == _TopView.history ||
                          filteredItems.isEmpty)
                        const SliverToBoxAdapter(child: SizedBox.shrink())
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 420,
                                  mainAxisExtent: 560,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final item = filteredItems[index];
                              final record = _recordFor(item, records);
                              final score = _displayScore(
                                item,
                                record,
                                user.uid,
                                partnerUid,
                              );
                              return _RecommendationCard(
                                cs: cs,
                                item: item,
                                score: score,
                                record: record,
                                currentUserId: user.uid,
                                partnerUid: partnerUid,
                                onOpenDetails: () => _openDetails(item),
                                onYes: () => _toggleAction(
                                  item: item,
                                  liked:
                                      !(record?.isLikedBy(user.uid) ?? false),
                                ),
                                onNo: () => _toggleAction(
                                  item: item,
                                  disliked:
                                      !(record?.isDislikedBy(user.uid) ??
                                          false),
                                ),
                                onFavorite: () => _toggleAction(
                                  item: item,
                                  favorited:
                                      !(record?.isFavoritedBy(user.uid) ??
                                          false),
                                ),
                                onWatched: () => _toggleAction(
                                  item: item,
                                  watched:
                                      !(record?.isWatchedBy(user.uid) ?? false),
                                ),
                              );
                            }, childCount: filteredItems.length),
                          ),
                        ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

enum _WatchFeedFilter {
  all,
  bothYes,
  oneYes,
  anyNo,
  favorites,
  watched,
  unwatched,
  movies,
  tv,
}

enum _WatchMediaType { movie, tv }

enum _TopView { suggestions, matched, history }

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
    required this.genres,
    required this.matchPercentage,
    required this.matchReason,
  });

  String get tmdbKey => '${mediaType.name}_$tmdbId';
  String get posterUrl =>
      posterPath.isEmpty ? '' : 'https://image.tmdb.org/t/p/w500$posterPath';
  String get backdropUrl => backdropPath.isEmpty
      ? ''
      : 'https://image.tmdb.org/t/p/w780$backdropPath';
  String get releaseYear =>
      releaseDate == null ? 'Unknown' : '${releaseDate!.year}';
  String get runtimeLabel =>
      runtimeMinutes > 0 ? '$runtimeMinutes min' : 'Runtime unavailable';
  String get genreLabel => genres.isEmpty ? 'Genre mix' : genres.join(' • ');
  String get mediaLabel =>
      mediaType == _WatchMediaType.movie ? 'Movie' : 'TV show';

  _WatchItem copyWith({
    String? overview,
    String? posterPath,
    String? backdropPath,
    double? rating,
    int? runtimeMinutes,
    DateTime? releaseDate,
    List<String>? genres,
    double? matchPercentage,
    String? matchReason,
  }) {
    return _WatchItem(
      tmdbId: tmdbId,
      mediaType: mediaType,
      title: title,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      rating: rating ?? this.rating,
      runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
      releaseDate: releaseDate ?? this.releaseDate,
      genres: genres ?? this.genres,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      matchReason: matchReason ?? this.matchReason,
    );
  }
}

class _WatchDetails {
  final _WatchItem item;
  final List<String> cast;
  final List<String> providers;
  final String? tagline;

  const _WatchDetails({
    required this.item,
    required this.cast,
    required this.providers,
    required this.tagline,
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
      matchedGenres: List<String>.from(
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

  String get _apiKey => dotenv.env['TMDB_API_KEY'] ?? '';

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

    final partnerEmail = (userData['partnerEmail'] as String?) ?? '';
    if (partnerEmail.isEmpty) {
      return null;
    }

    final partnerQuery = await _db
        .collection('users')
        .where('email', isEqualTo: partnerEmail)
        .limit(1)
        .get();

    if (partnerQuery.docs.isEmpty) {
      return null;
    }

    return partnerQuery.docs.first.id;
  }

  Future<List<_WatchItem>> fetchRecommendations() async {
    if (_apiKey.isEmpty) {
      return _sampleRecommendations();
    }

    try {
      final seeds = await Future.wait([
        _fetchSeeds(_WatchMediaType.movie),
        _fetchSeeds(_WatchMediaType.tv),
      ]);
      final allSeeds = [...seeds[0], ...seeds[1]];
      final enriched = await Future.wait(allSeeds.take(10).map(_enrichSeed));
      enriched.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
      return enriched;
    } catch (_) {
      return _sampleRecommendations();
    }
  }

  Future<_WatchDetails> fetchDetails(_WatchItem item) async {
    if (_apiKey.isEmpty) {
      return _WatchDetails(
        item: item,
        cast: const ['Cast unavailable'],
        providers: const ['TMDb'],
        tagline: null,
      );
    }

    try {
      final details = await _getJson('/${item.mediaType.name}/${item.tmdbId}');
      final credits = await _getJson(
        '/${item.mediaType.name}/${item.tmdbId}/credits',
      );
      final providers = await _getJson(
        '/${item.mediaType.name}/${item.tmdbId}/watch/providers',
      );

      final cast = (credits['cast'] as List? ?? const [])
          .take(6)
          .map(
            (member) =>
                (member as Map<String, dynamic>)['name'] as String? ?? '',
          )
          .where((name) => name.isNotEmpty)
          .toList();

      final providerNames = _extractProviders(providers);
      return _WatchDetails(
        item: item.copyWith(
          overview: ((details['overview'] as String?) ?? item.overview).trim(),
          posterPath: (details['poster_path'] as String?) ?? item.posterPath,
          backdropPath:
              (details['backdrop_path'] as String?) ?? item.backdropPath,
          rating: (details['vote_average'] as num?)?.toDouble() ?? item.rating,
          runtimeMinutes: _runtimeFromDetails(
            details,
            item.mediaType,
            item.runtimeMinutes,
          ),
          releaseDate:
              _releaseDateFromDetails(details, item.mediaType) ??
              item.releaseDate,
          genres: _genresFromDetails(details).isEmpty
              ? item.genres
              : _genresFromDetails(details),
        ),
        cast: cast.isEmpty ? const ['Cast unavailable'] : cast,
        providers: providerNames.isEmpty ? const ['TMDb'] : providerNames,
        tagline: _cleanString(details['tagline'] as String?),
      );
    } catch (_) {
      return _WatchDetails(
        item: item,
        cast: const ['Cast unavailable'],
        providers: const ['TMDb'],
        tagline: null,
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

    final existing = await userRef.get();
    final existingData = existing.data() ?? <String, dynamic>{};

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
      await _db
          .collection('users')
          .doc(partnerUid)
          .collection('watchItems')
          .doc(docId)
          .set(payload, SetOptions(merge: true));
    }
  }

  Future<List<_WatchSeed>> _fetchSeeds(_WatchMediaType type) async {
    final path = type == _WatchMediaType.movie
        ? '/movie/popular'
        : '/tv/popular';
    final json = await _getJson(path);
    final results = json['results'] as List? ?? const [];

    return results
        .take(8)
        .map((raw) {
          final data = Map<String, dynamic>.from(raw as Map);
          final title = type == _WatchMediaType.movie
              ? (data['title'] as String?) ?? 'Untitled'
              : (data['name'] as String?) ?? 'Untitled';
          final release = type == _WatchMediaType.movie
              ? (data['release_date'] as String?)
              : (data['first_air_date'] as String?);
          return _WatchSeed(
            id: (data['id'] as num?)?.toInt() ?? 0,
            mediaType: type,
            title: title,
            overview: (data['overview'] as String?) ?? '',
            posterPath: (data['poster_path'] as String?) ?? '',
            backdropPath: (data['backdrop_path'] as String?) ?? '',
            rating: (data['vote_average'] as num?)?.toDouble() ?? 0,
            releaseDate: DateTime.tryParse(release ?? ''),
          );
        })
        .where((seed) => seed.id != 0)
        .toList();
  }

  Future<_WatchItem> _enrichSeed(_WatchSeed seed) async {
    final details = await _getJson('/${seed.mediaType.name}/${seed.id}');
    final runtime = _runtimeFromDetails(details, seed.mediaType, 0);
    final genres = _genresFromDetails(details);
    final rating = (details['vote_average'] as num?)?.toDouble() ?? seed.rating;

    return seed.toItem().copyWith(
      overview: _cleanString(details['overview'] as String?) ?? seed.overview,
      posterPath: (details['poster_path'] as String?) ?? seed.posterPath,
      backdropPath: (details['backdrop_path'] as String?) ?? seed.backdropPath,
      rating: rating,
      runtimeMinutes: runtime,
      releaseDate:
          _releaseDateFromDetails(details, seed.mediaType) ?? seed.releaseDate,
      genres: genres.isEmpty ? _defaultGenresFor(seed.mediaType) : genres,
      matchPercentage: _predictMatchScore(rating, genres),
      matchReason: _buildMatchReason(genres, seed.mediaType),
    );
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final uri = Uri.https('api.themoviedb.org', '/3$path', {
      'api_key': _apiKey,
      'language': 'en-US',
    });
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('TMDb request failed with status ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  List<String> _extractProviders(Map<String, dynamic> data) {
    final results = data['results'] as Map<String, dynamic>? ?? const {};
    final us = results['US'] as Map<String, dynamic>? ?? const {};
    final providerList =
        us['flatrate'] as List? ??
        us['rent'] as List? ??
        us['buy'] as List? ??
        const [];
    return providerList
        .take(5)
        .map(
          (provider) =>
              (provider as Map<String, dynamic>)['provider_name'] as String? ??
              '',
        )
        .where((name) => name.isNotEmpty)
        .toList();
  }

  List<String> _genresFromDetails(Map<String, dynamic> details) {
    final genres = details['genres'] as List? ?? const [];
    return genres
        .map(
          (genre) => (genre as Map<String, dynamic>)['name'] as String? ?? '',
        )
        .where((name) => name.isNotEmpty)
        .toList();
  }

  int _runtimeFromDetails(
    Map<String, dynamic> details,
    _WatchMediaType mediaType,
    int fallback,
  ) {
    if (mediaType == _WatchMediaType.movie) {
      return (details['runtime'] as num?)?.toInt() ?? fallback;
    }

    final runTimes = details['episode_run_time'] as List?;
    if (runTimes != null && runTimes.isNotEmpty) {
      return (runTimes.first as num?)?.toInt() ?? fallback;
    }
    return fallback;
  }

  DateTime? _releaseDateFromDetails(
    Map<String, dynamic> details,
    _WatchMediaType mediaType,
  ) {
    final raw = mediaType == _WatchMediaType.movie
        ? details['release_date'] as String?
        : details['first_air_date'] as String?;
    return DateTime.tryParse(raw ?? '');
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
    if (likedBy.isEmpty && dislikedBy.isEmpty) {
      return item.genres.take(2).toList();
    }

    if (partnerUid != null && likedBy.contains(partnerUid)) {
      return item.genres.take(3).toList();
    }

    if (likedBy.isNotEmpty) {
      return item.genres.take(2).toList();
    }

    return item.genres.take(1).toList();
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
        genres: const ['Drama', 'Thriller'],
        matchPercentage: 88,
        matchReason:
            'A sharp, conversation-starting thriller with drama at its core.',
      ),
      _WatchItem(
        tmdbId: 906126,
        mediaType: _WatchMediaType.tv,
        title: 'Heartstopper',
        overview:
            'Teens Charlie and Nick discover that their unlikely friendship might be something more as they navigate school and young love.',
        posterPath: '/6R4P3C7pY6R5xQ0n2r3o1k7m8Ff.jpg',
        backdropPath: '/uY3j0I2b0M3Pp2n0Z3u4w7K5WnJ.jpg',
        rating: 8.6,
        runtimeMinutes: 30,
        releaseDate: DateTime(2022, 4, 22),
        genres: const ['Drama', 'Romance'],
        matchPercentage: 91,
        matchReason: 'A gentle TV pick centered on romance and warmth.',
      ),
      _WatchItem(
        tmdbId: 537915,
        mediaType: _WatchMediaType.movie,
        title: 'After the Sunset',
        overview:
            'A jewel thief and his wife try to enjoy a quieter life, but one last score draws them back into the game.',
        posterPath: '/nGcqdZl4z6C3m7j1yQmGg2K8f9j.jpg',
        backdropPath: '/xAqK7VY4P0TzQ4p8kQWvJ6yF4v7.jpg',
        rating: 7.1,
        runtimeMinutes: 110,
        releaseDate: DateTime(2004, 11, 12),
        genres: const ['Action', 'Comedy'],
        matchPercentage: 76,
        matchReason:
            'A playful movie-night pick with action and a light touch.',
      ),
      _WatchItem(
        tmdbId: 568124,
        mediaType: _WatchMediaType.tv,
        title: 'The Good Place',
        overview:
            'A surprisingly sweet afterlife comedy about becoming better, together, and still having fun while doing it.',
        posterPath: '/qIHSB9K5uP1eY1k0sM0l4Yl3oB8.jpg',
        backdropPath: '/wP8jQpR4sY2zQ7pL5tB2mS9dV2.jpg',
        rating: 8.2,
        runtimeMinutes: 22,
        releaseDate: DateTime(2016, 9, 19),
        genres: const ['Comedy', 'Fantasy'],
        matchPercentage: 89,
        matchReason: 'A cozy binge with comedy and a feel-good tone.',
      ),
      _WatchItem(
        tmdbId: 157336,
        mediaType: _WatchMediaType.movie,
        title: 'Interstellar',
        overview:
            'A team of explorers travel through a wormhole in space in an attempt to ensure humanity\'s survival.',
        posterPath: '/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
        backdropPath: '/rAiYTfKGqDCRIIqo664sY9XZIvQ.jpg',
        rating: 8.7,
        runtimeMinutes: 169,
        releaseDate: DateTime(2014, 11, 5),
        genres: const ['Adventure', 'Drama', 'Sci-Fi'],
        matchPercentage: 82,
        matchReason:
            'For nights when you want something big, emotional, and immersive.',
      ),
      _WatchItem(
        tmdbId: 1399,
        mediaType: _WatchMediaType.tv,
        title: 'Game of Thrones',
        overview:
            'Nine noble families fight for control over the lands of Westeros, while an ancient enemy returns.',
        posterPath: '/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg',
        backdropPath: '/mQeXW0nQx3M5Qn8pU4n2s9Bq2hN.jpg',
        rating: 8.4,
        runtimeMinutes: 60,
        releaseDate: DateTime(2011, 4, 17),
        genres: const ['Drama', 'Fantasy'],
        matchPercentage: 71,
        matchReason: 'An epic, high-drama series for longer shared evenings.',
      ),
    ];
  }
}

class _WatchSeed {
  final int id;
  final _WatchMediaType mediaType;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final double rating;
  final DateTime? releaseDate;

  const _WatchSeed({
    required this.id,
    required this.mediaType,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.rating,
    required this.releaseDate,
  });

  _WatchItem toItem() {
    return _WatchItem(
      tmdbId: id,
      mediaType: mediaType,
      title: title,
      overview: overview,
      posterPath: posterPath,
      backdropPath: backdropPath,
      rating: rating,
      runtimeMinutes: 0,
      releaseDate: releaseDate,
      genres: const [],
      matchPercentage: 0,
      matchReason: '',
    );
  }
}

class _WatchHeroCard extends StatelessWidget {
  final ColorScheme cs;
  final String title;
  final String subtitle;
  final String headline;
  final String filterLabel;
  final int count;
  final bool partnerLinked;
  final VoidCallback onFilterTap;

  const _WatchHeroCard({
    required this.cs,
    required this.title,
    required this.subtitle,
    required this.headline,
    required this.filterLabel,
    required this.count,
    required this.partnerLinked,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.72),
            cs.secondaryContainer.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.78),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.theaters_outlined,
                  color: cs.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: onFilterTap,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Filter'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(label: 'Visible picks', value: '$count'),
              _HeroMetric(
                label: 'Couple link',
                value: partnerLinked ? 'Connected' : 'Waiting',
              ),
              _HeroMetric(label: 'Focus', value: headline),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Showing $filterLabel',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final ColorScheme cs;
  final _WatchFeedFilter filter;
  final String? selectedGenre;
  final List<String> genres;
  final double minRating;
  final double maxRuntime;
  final ValueChanged<_WatchFeedFilter> onFilterChanged;
  final ValueChanged<String?> onGenreChanged;
  final ValueChanged<double> onRatingChanged;
  final ValueChanged<double> onRuntimeChanged;

  const _FilterPanel({
    required this.cs,
    required this.filter,
    required this.selectedGenre,
    required this.genres,
    required this.minRating,
    required this.maxRuntime,
    required this.onFilterChanged,
    required this.onGenreChanged,
    required this.onRatingChanged,
    required this.onRuntimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Map<String, dynamic>>[
      {'label': 'All', 'value': _WatchFeedFilter.all},
      {'label': 'Both yes', 'value': _WatchFeedFilter.bothYes},
      {'label': 'One yes', 'value': _WatchFeedFilter.oneYes},
      {'label': 'Any no', 'value': _WatchFeedFilter.anyNo},
      {'label': 'Favorites', 'value': _WatchFeedFilter.favorites},
      {'label': 'Watched', 'value': _WatchFeedFilter.watched},
      {'label': 'Unwatched', 'value': _WatchFeedFilter.unwatched},
      {'label': 'Movies', 'value': _WatchFeedFilter.movies},
      {'label': 'TV shows', 'value': _WatchFeedFilter.tv},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Couple match filters',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((chip) {
              final value = chip['value'] as _WatchFeedFilter;
              return ChoiceChip(
                label: Text(chip['label'] as String),
                selected: filter == value,
                onSelected: (_) => onFilterChanged(value),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Genres both users matched on',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All genres'),
                    selected: selectedGenre == null,
                    onSelected: (_) => onGenreChanged(null),
                  ),
                ),
                ...genres.map(
                  (genre) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(genre),
                      selected: selectedGenre == genre,
                      onSelected: (_) => onGenreChanged(genre),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Rating', style: Theme.of(context).textTheme.labelSmall),
          Slider(
            value: minRating,
            min: 0,
            max: 10,
            divisions: 20,
            label: minRating.toStringAsFixed(1),
            onChanged: onRatingChanged,
          ),
          Text('Runtime', style: Theme.of(context).textTheme.labelSmall),
          Slider(
            value: maxRuntime,
            min: 20,
            max: 240,
            divisions: 11,
            label: '${maxRuntime.round()} min',
            onChanged: onRuntimeChanged,
          ),
        ],
      ),
    );
  }
}

class _MatchHistoryPanel extends StatelessWidget {
  final ColorScheme cs;
  final String currentUserId;
  final String? partnerUid;
  final List<_WatchRecord> records;

  const _MatchHistoryPanel({
    required this.cs,
    required this.currentUserId,
    required this.partnerUid,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final partnerId = partnerUid;
    if (partnerId == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _MatchedTimelineState(
              cs: cs,
              icon: Icons.link_rounded,
              title: 'No partner connected',
              subtitle:
                  'Connect a partner to unlock the shared match timeline.',
              milestones: const [
                'Link your partner account',
                'Vote on a few movies or shows together',
                'See your shared story appear here',
              ],
            ),
          ],
        ),
      );
    }

    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _MatchedTimelineState(
              cs: cs,
              icon: Icons.favorite_border_rounded,
              title: 'No shared history yet',
              subtitle:
                  'Start voting together and this area will fill with moments.',
              milestones: const [
                'Swipe through a few recommendations',
                'Mark what you both like or skip',
                'See mutual taste and disagreements build up',
              ],
            ),
          ],
        ),
      );
    }

    final bothLiked = records.where((record) {
      return record.isLikedBy(currentUserId) && record.isLikedBy(partnerId);
    }).toList();
    final bothDisliked = records.where((record) {
      return record.isDislikedBy(currentUserId) &&
          record.isDislikedBy(partnerId);
    }).toList();
    final disagreements = records.where((record) {
      final currentLiked = record.isLikedBy(currentUserId);
      final currentDisliked = record.isDislikedBy(currentUserId);
      final partnerLiked = record.isLikedBy(partnerId);
      final partnerDisliked = record.isDislikedBy(partnerId);
      return (currentLiked && partnerDisliked) ||
          (currentDisliked && partnerLiked);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Match history', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HistoryBadge(
                label: 'Both liked',
                value: bothLiked.length.toString(),
                color: cs.primary,
              ),
              _HistoryBadge(
                label: 'Both disliked',
                value: bothDisliked.length.toString(),
                color: cs.secondary,
              ),
              _HistoryBadge(
                label: 'Disagreed',
                value: disagreements.length.toString(),
                color: cs.tertiary,
              ),
              _HistoryBadge(
                label: 'Your yes',
                value: records
                    .where((record) => record.isLikedBy(currentUserId))
                    .length
                    .toString(),
                color: cs.primaryContainer,
              ),
              _HistoryBadge(
                label: 'Your no',
                value: records
                    .where((record) => record.isDislikedBy(currentUserId))
                    .length
                    .toString(),
                color: cs.secondaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _HistorySection(title: 'What you both liked', items: bothLiked),
          const SizedBox(height: 12),
          _HistorySection(title: 'What you both disliked', items: bothDisliked),
          const SizedBox(height: 12),
          _HistorySection(title: 'Where you disagreed', items: disagreements),
        ],
      ),
    );
  }
}

class _MatchedTimelineFeed extends StatelessWidget {
  final ColorScheme cs;
  final List<_MatchedTimelineEntry> entries;
  final String currentUserId;
  final String? partnerUid;

  const _MatchedTimelineFeed({
    required this.cs,
    required this.entries,
    required this.currentUserId,
    required this.partnerUid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Matched timeline',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Your shared yeses', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'A timeline view of the picks you both liked.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < entries.length; index++) ...[
            Padding(
              padding: EdgeInsets.only(
                bottom: index == entries.length - 1 ? 0 : 12,
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
                          if (index != entries.length - 1)
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
                      child: Builder(
                        builder: (context) {
                          final entry = entries[index];
                          final item = entry.item;
                          final record = entry.record;
                          final score = entry.score;
                          final dark = theme.brightness == Brightness.dark;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: index.isEven
                                  ? cs.primaryContainer
                                  : dark
                                  ? const Color(0xFF231519)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _MatchedPosterThumb(
                                  posterUrl: item.posterUrl,
                                  cs: cs,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.mediaLabel} · ${item.releaseYear} · ${item.runtimeLabel}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.matchReason,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          _TimelineChip(
                                            label:
                                                '${score.toStringAsFixed(0)}% match',
                                            filled: true,
                                          ),
                                          for (final genre in item.genres.take(
                                            3,
                                          ))
                                            _TimelineChip(label: genre),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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

class _MatchedTimelineEntry {
  final _WatchItem item;
  final _WatchRecord? record;
  final double score;

  const _MatchedTimelineEntry({
    required this.item,
    required this.record,
    required this.score,
  });
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
        height: 96,
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

class _PersonalHistoryPanel extends StatelessWidget {
  final ColorScheme cs;
  final String currentUserId;
  final List<_WatchRecord> records;

  const _PersonalHistoryPanel({
    Key? key,
    required this.cs,
    required this.currentUserId,
    required this.records,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (records.isEmpty)
            _HistoryEmptyState(
              cs: cs,
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
          else
            const SizedBox.shrink(),
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
      // FIX 2: Remove the border from the popup menu by providing a clean shape
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide.none,
      ),
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
          // FIX 1: Use outline heart icon instead of filled heart
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
      // FIX 1: Also use outline heart in the button itself when Matched is selected
      _TopView.matched => Icons.favorite_border_rounded,
      _TopView.history => Icons.history,
    };

    return GestureDetector(
      onTap: _showMenu,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.onPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onPrimary),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: cs.onPrimary),
          ],
        ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final String title;
  final List<_WatchRecord> items;

  const _HistorySection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text(
            'Nothing yet. Keep voting to populate this section.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .take(5)
                .map((record) => Chip(label: Text(record.title)))
                .toList(),
          ),
      ],
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
  final VoidCallback onFavorite;
  final VoidCallback onWatched;

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
    required this.onFavorite,
    required this.onWatched,
  });

  @override
  Widget build(BuildContext context) {
    final isFavorite = record?.isFavoritedBy(currentUserId) ?? false;
    final isWatched = record?.isWatchedBy(currentUserId) ?? false;
    final isLiked = record?.isLikedBy(currentUserId) ?? false;
    final isDisliked = record?.isDislikedBy(currentUserId) ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item.backdropUrl.isNotEmpty)
                        Image.network(
                          item.backdropUrl,
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
                              Colors.black.withValues(alpha: 0.12),
                              Colors.black.withValues(alpha: 0.6),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _Pill(
                              label: item.mediaLabel,
                              background: cs.surface.withValues(alpha: 0.86),
                              foreground: cs.onSurface,
                            ),
                            _Pill(
                              label: '${score.toStringAsFixed(0)}%',
                              background: cs.primary,
                              foreground: cs.onPrimary,
                            ),
                          ],
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
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 84,
                                height: 124,
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.releaseYear} • ${item.runtimeLabel}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: Colors.white70),
                                  ),
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.genreLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.overview,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionChip(
                            label: isLiked ? 'Yes' : 'Interested',
                            icon: Icons.favorite_rounded,
                            selected: isLiked,
                            onTap: onYes,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionChip(
                            label: isDisliked ? 'No' : 'Pass',
                            icon: Icons.close_rounded,
                            selected: isDisliked,
                            onTap: onNo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionChip(
                            label: isFavorite ? 'Saved' : 'Favorite',
                            icon: isFavorite
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            selected: isFavorite,
                            onTap: onFavorite,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionChip(
                            label: isWatched ? 'Watched' : 'Watch',
                            icon: Icons.visibility_rounded,
                            selected: isWatched,
                            onTap: onWatched,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onOpenDetails,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open details'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Data and images via TMDb.',
                      style: Theme.of(context).textTheme.labelSmall,
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
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer
              : cs.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? cs.primary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
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

class _HistoryBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HistoryBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
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
        // outer border removed per design
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
                  // inner circle border removed per design
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
