import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/scrapbook_entry.dart';
import '../models/love_letter.dart';
import '../models/timeline_event.dart';

class TimelineService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> logDateIdeasGeneratedFromReload({int? ideaCount}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('timelineEvents')
        .add({
          'activity': 'date_ideas_generated',
          'title': 'New date ideas created',
          'subtitle': ideaCount == null
              ? 'Generated from reload'
              : 'Generated $ideaCount fresh date ideas from reload',
          'emoji': '✨',
          'occurredAt': FieldValue.serverTimestamp(),
          'isMilestone': false,
        });
  }

  Stream<List<TimelineEntry>> streamTimelineEntries() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    late final StreamController<List<TimelineEntry>> controller;
    StreamSubscription<List<ScrapbookEntry>>? scrapbookSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? loveLettersSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? watchItemsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? watchMatchesSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? activitySub;

    var scrapbookEntries = <ScrapbookEntry>[];
    var loveLetterDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var watchItemDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var watchMatchDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var activityDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    void emit() {
      final entries =
          <TimelineEntry>[
            ..._mapScrapbookEntries(scrapbookEntries),
            ..._mapLoveLetters(loveLetterDocs),
            ..._mapWatchEntries(watchItemDocs, watchMatchDocs),
            ...activityDocs
                .where(
                  (doc) =>
                      (doc.data()['activity'] as String?) != 'deep_talk_view',
                )
                .map(
                  (doc) => TimelineEntry.fromActivityDoc(doc.id, doc.data()),
                ),
          ]..sort((left, right) {
            final byTime = right.occurredAt.compareTo(left.occurredAt);
            if (byTime != 0) return byTime;
            if (left.isMilestone != right.isMilestone) {
              return left.isMilestone ? -1 : 1;
            }
            return left.title.compareTo(right.title);
          });

      if (!controller.isClosed) {
        controller.add(entries);
      }
    }

    controller = StreamController<List<TimelineEntry>>(
      onListen: () {
        scrapbookSub = _db
            .collection('users')
            .doc(user.uid)
            .collection('scrapbookEntries')
            .orderBy('entryDate', descending: true)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs.map(ScrapbookEntry.fromDoc).toList(),
            )
            .listen((entries) {
              scrapbookEntries = entries;
              emit();
            }, onError: controller.addError);

        loveLettersSub = _db
            .collection('users')
            .doc(user.uid)
            .collection('loveLetters')
            .orderBy('createdAt', descending: true)
            .snapshots()
            .listen((snapshot) {
              loveLetterDocs = snapshot.docs;
              emit();
            }, onError: controller.addError);

        watchItemsSub = _db
            .collection('users')
            .doc(user.uid)
            .collection('watchItems')
            .orderBy('updatedAt', descending: true)
            .snapshots()
            .listen((snapshot) {
              watchItemDocs = snapshot.docs;
              emit();
            }, onError: controller.addError);

        watchMatchesSub = _db
            .collection('users')
            .doc(user.uid)
            .collection('watchMatches')
            .orderBy('updatedAt', descending: true)
            .snapshots()
            .listen((snapshot) {
              watchMatchDocs = snapshot.docs;
              emit();
            }, onError: controller.addError);

        activitySub = _db
            .collection('users')
            .doc(user.uid)
            .collection('timelineEvents')
            .orderBy('occurredAt', descending: true)
            .snapshots()
            .listen((snapshot) {
              activityDocs = snapshot.docs;
              emit();
            }, onError: controller.addError);
      },
      onCancel: () async {
        await Future.wait([
          scrapbookSub?.cancel() ?? Future.value(),
          loveLettersSub?.cancel() ?? Future.value(),
          watchItemsSub?.cancel() ?? Future.value(),
          watchMatchesSub?.cancel() ?? Future.value(),
          activitySub?.cancel() ?? Future.value(),
        ]);
        await controller.close();
      },
    );

    return controller.stream;
  }

  List<TimelineEntry> _mapScrapbookEntries(List<ScrapbookEntry> entries) {
    return entries.map((entry) {
      final hasDescription = entry.description.trim().isNotEmpty;
      final title = hasDescription
          ? entry.description.trim()
          : 'Scrapbook entry';
      final subtitle = entry.hasImage
          ? 'Photo logged on ${_monthDayLabel(entry.entryDate)}'
          : 'Logged on ${_monthDayLabel(entry.entryDate)}';

      return TimelineEntry(
        id: 'scrapbook:${entry.id}',
        type: TimelineEntryType.scrapbook,
        title: title,
        subtitle: subtitle,
        emoji: entry.hasImage ? '📷' : '📝',
        occurredAt: entry.entryDate,
        isMilestone: false,
      );
    }).toList();
  }

  List<TimelineEntry> _mapLoveLetters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> loveLetterDocs,
  ) {
    return loveLetterDocs.map((doc) {
      final letter = LoveLetter.fromDoc(doc);
      return TimelineEntry(
        id: 'love-letter:${letter.id}',
        type: TimelineEntryType.loveLetter,
        title: 'Love letter sent',
        subtitle: TimelineEntry.loveLetterSnippet(),
        emoji: '💌',
        occurredAt: letter.createdAt,
        isMilestone: false,
      );
    }).toList();
  }

  List<TimelineEntry> _mapWatchEntries(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> watchItemDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> watchMatchDocs,
  ) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const [];

    final sharedWatchIds = <String>{};
    final sharedEntries = <TimelineEntry>[];

    for (final doc in watchMatchDocs) {
      final data = doc.data();
      final watchedTogetherAt = data['watchedTogetherAt'] as Timestamp?;
      final watchedBy = List<String>.from(
        (data['watchedBy'] as List?) ?? const [],
      );
      if (watchedTogetherAt == null || !watchedBy.contains(currentUser.uid)) {
        continue;
      }

      sharedWatchIds.add(doc.id);
      sharedEntries.add(
        TimelineEntry(
          id: 'watch-match:${doc.id}',
          type: TimelineEntryType.watch,
          title: (data['title'] as String?) ?? 'Untitled watch',
          subtitle: 'Watched together',
          emoji: '🎬',
          occurredAt: watchedTogetherAt.toDate(),
          isMilestone: true,
        ),
      );
    }

    final soloEntries = <TimelineEntry>[];
    for (final doc in watchItemDocs) {
      if (sharedWatchIds.contains(doc.id)) {
        continue;
      }

      final data = doc.data();
      final watchedBy = List<String>.from(
        (data['watchedBy'] as List?) ?? const [],
      );
      if (!watchedBy.contains(currentUser.uid)) {
        continue;
      }

      final updatedTs = data['updatedAt'] as Timestamp?;
      final mediaType = (data['mediaType'] as String?) ?? 'movie';
      soloEntries.add(
        TimelineEntry(
          id: 'watch-item:${doc.id}',
          type: TimelineEntryType.watch,
          title: (data['title'] as String?) ?? 'Untitled watch',
          subtitle: mediaType == 'tv' ? 'Watched TV show' : 'Watched movie',
          emoji: '🎞️',
          occurredAt: updatedTs?.toDate() ?? DateTime.now(),
          isMilestone: false,
        ),
      );
    }

    return [...sharedEntries, ...soloEntries];
  }

  String _monthDayLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
