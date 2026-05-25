import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/timeline_event.dart';

class StreaksService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> recordActivity(String activity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docRef = _firestore.collection('users').doc(user.uid);
    final snap = await docRef.get();
    final data = snap.data() ?? {};

    final lastActiveStr = data['streakLastActive'] as String?;
    DateTime? lastActive = lastActiveStr != null
        ? DateTime.tryParse(lastActiveStr)
        : null;
    final now = DateTime.now();

    int current = (data['streakCurrent'] as int?) ?? 0;
    int best = (data['streakBest'] as int?) ?? 0;

    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    bool isYesterday(DateTime a, DateTime b) {
      final diff = a.difference(b).inDays;
      return diff == 1 && a.isAfter(b);
    }

    if (lastActive == null) {
      // first activity
      current = 1;
    } else if (sameDay(lastActive, now)) {
      // already active today — no change
    } else if (isYesterday(now, lastActive)) {
      // consecutive day
      current = current + 1;
    } else {
      // gap — reset
      current = 1;
    }

    if (current > best) best = current;

    await docRef.set({
      'streakCurrent': current,
      'streakBest': best,
      'streakLastActive': now.toIso8601String(),
    }, SetOptions(merge: true));

    try {
      await docRef
          .collection('timelineEvents')
          .doc('activity_${now.microsecondsSinceEpoch}')
          .set(
            TimelineEntry.activityPayload(
              activity: activity,
              occurredAt: now,
              currentStreak: current,
              bestStreak: best,
            ),
            SetOptions(merge: true),
          );
    } catch (_) {}
  }

  Future<int> getCurrentStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return (doc.data()?['streakCurrent'] as int?) ?? 0;
  }
}
