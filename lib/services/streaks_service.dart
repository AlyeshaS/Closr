// lib/services/streaks_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/timeline_event.dart';
import './badge_service.dart';

class StreaksService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BadgeService _badgeService = BadgeService();

  Future<String?> _resolvePartnerUid(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data();
    final partnerEmail =
        ((userData?['partnerEmailLower'] as String?) ??
                (userData?['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();
    if (partnerEmail.isEmpty) return null;

    final partnerQuery = await _firestore
        .collection('users')
        .where('emailLower', isEqualTo: partnerEmail)
        .get();
    if (partnerQuery.docs.isNotEmpty) return partnerQuery.docs.first.id;

    final fallbackQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: partnerEmail)
        .get();
    if (fallbackQuery.docs.isNotEmpty) return fallbackQuery.docs.first.id;

    final allUsers = await _firestore.collection('users').limit(250).get();
    for (final doc in allUsers.docs) {
      final data = doc.data();
      final email =
          ((data['emailLower'] as String?) ?? (data['email'] as String?) ?? '')
              .trim()
              .toLowerCase();
      if (email == partnerEmail) return doc.id;
    }
    return null;
  }

  DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> _readStreakState(Map<String, dynamic>? data) {
    final source = data ?? const <String, dynamic>{};
    return {
      'current':
          (source['sharedStreakCurrent'] as int?) ??
          (source['streakCurrent'] as int?) ??
          0,
      'best':
          (source['sharedStreakBest'] as int?) ??
          (source['streakBest'] as int?) ??
          0,
      'lastActive':
          _readDateTime(source['sharedStreakLastActive']) ??
          _readDateTime(source['streakLastActive']),
    };
  }

  Future<void> recordActivity(String activity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userRef = _firestore.collection('users').doc(user.uid);
    final partnerUid = await _resolvePartnerUid(user.uid);
    final partnerRef = partnerUid == null
        ? null
        : _firestore.collection('users').doc(partnerUid);

    final userSnap = await userRef.get();
    final partnerSnap = partnerRef == null ? null : await partnerRef.get();
    final userState = _readStreakState(userSnap.data());
    final partnerState = _readStreakState(partnerSnap?.data());

    int current = userState['current'] as int;
    int best = userState['best'] as int;
    DateTime? lastActive = userState['lastActive'] as DateTime?;

    final partnerCurrent = partnerState['current'] as int;
    final partnerBest = partnerState['best'] as int;
    final partnerLastActive = partnerState['lastActive'] as DateTime?;

    if (partnerRef != null) {
      current = current > partnerCurrent ? current : partnerCurrent;
      best = best > partnerBest ? best : partnerBest;
      if (partnerLastActive != null &&
          (lastActive == null || partnerLastActive.isAfter(lastActive))) {
        lastActive = partnerLastActive;
      }
    }

    final now = DateTime.now();

    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    bool isYesterday(DateTime a, DateTime b) {
      final diff = a.difference(b).inDays;
      return diff == 1 && a.isAfter(b);
    }

    bool streakIncremented = false;

    if (lastActive == null) {
      current = 1;
      streakIncremented = true;
    } else if (sameDay(lastActive, now)) {
      // already active today — no change
    } else if (isYesterday(now, lastActive)) {
      current = current + 1;
      streakIncremented = true;
    } else {
      current = 1;
      streakIncremented = true;
    }

    if (current > best) best = current;

    final payload = {
      'streakCurrent': current,
      'streakBest': best,
      'streakLastActive': now.toIso8601String(),
      'sharedStreakCurrent': current,
      'sharedStreakBest': best,
      'sharedStreakLastActive': now.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await userRef.set(payload, SetOptions(merge: true));
    if (partnerRef != null) {
      await partnerRef.set(payload, SetOptions(merge: true));
    }

    if (streakIncremented) {
      try {
        await _badgeService.incrementStat(
          statKey: 'current_streak_days',
          by: 1,
        );
      } catch (_) {}
    }

    try {
      await userRef
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
    final data = doc.data() ?? const <String, dynamic>{};
    return (data['sharedStreakCurrent'] as int?) ??
        (data['streakCurrent'] as int?) ??
        0;
  }
}
