// lib/services/badge_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/badge_model.dart';

class BadgeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Resolve partner UID via user document
  Future<String?> _resolvePartnerUid(String currentUid) async {
    try {
      final userDoc = await _db.collection('users').doc(currentUid).get();
      if (!userDoc.exists) return null;

      final data = userDoc.data() ?? {};
      final partnerEmail =
          (data['partnerEmailLower'] ?? data['partnerEmail'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (partnerEmail.isEmpty) return null;

      final partnerQuery = await _db
          .collection('users')
          .where('emailLower', isEqualTo: partnerEmail)
          .get();

      if (partnerQuery.docs.isNotEmpty) {
        return partnerQuery.docs.first.id;
      }

      final fallbackQuery = await _db
          .collection('users')
          .where('email', isEqualTo: partnerEmail)
          .get();

      if (fallbackQuery.docs.isNotEmpty) {
        return fallbackQuery.docs.first.id;
      }
    } catch (e) {
      debugPrint('Error resolving partner UID: $e');
    }
    return null;
  }

  // Stream badges from users/{userId}/achievements/data/badges
  Stream<List<Map<String, dynamic>>> streamBadges(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('achievements')
        .doc('data')
        .collection('badges')
        .snapshots()
        .map((snapshot) {
          final savedBadgesMap = {
            for (var doc in snapshot.docs) doc.id: doc.data(),
          };

          return allBadges.map((badgeDef) {
            final saved = savedBadgesMap[badgeDef.id] ?? <String, dynamic>{};
            final userCounts = Map<String, dynamic>.from(
              saved['user_contributions'] ?? {},
            );

            final myCount = (userCounts[userId] as num? ?? 0).toInt();
            final partnerCount = userCounts.entries
                .where((e) => e.key != userId)
                .fold<int>(
                  0,
                  (sum, e) => sum + ((e.value as num?)?.toInt() ?? 0),
                );

            final perPersonTarget = badgeDef.target <= 1 ? 1 : badgeDef.target;
            final totalTarget = perPersonTarget * 2;

            final userCapped = myCount.clamp(0, perPersonTarget);
            final partnerCapped = partnerCount.clamp(0, perPersonTarget);
            final combinedProgress = userCapped + partnerCapped;

            final userDone = userCapped >= perPersonTarget;
            final partnerDone = partnerCapped >= perPersonTarget;
            final isUnlocked =
                saved['isUnlocked'] == true || (userDone && partnerDone);

            return {
              'id': badgeDef.id,
              'title': badgeDef.title,
              'description': badgeDef.description,
              'progress': combinedProgress,
              'target': totalTarget,
              'userDone': userDone,
              'partnerDone': partnerDone,
              'points': badgeDef.points,
              'isUnlocked': isUnlocked,
              'icon': badgeDef.icon,
              'category': badgeDef.category.name,
            };
          }).toList();
        });
  }

  // Increment badge progress and update users/{uid}/achievements
  Future<void> incrementStat({required String statKey, int by = 1}) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final partnerUid = await _resolvePartnerUid(currentUid);

    try {
      final matchingBadges = allBadges
          .where((b) => b.statKey == statKey)
          .toList();

      for (final badge in matchingBadges) {
        final badgeDocRef = _db
            .collection('users')
            .doc(currentUid)
            .collection('achievements')
            .doc('data')
            .collection('badges')
            .doc(badge.id);

        final docSnap = await badgeDocRef.get();
        final badgeData = docSnap.data() ?? {};
        final userCounts = Map<String, dynamic>.from(
          badgeData['user_contributions'] ?? {},
        );

        final myPrev = (userCounts[currentUid] as num? ?? 0).toInt();
        final myNew = myPrev + by;
        userCounts[currentUid] = myNew;

        final partnerTotal = userCounts.entries
            .where((e) => e.key != currentUid)
            .fold<int>(0, (sum, e) => sum + ((e.value as num?)?.toInt() ?? 0));

        final perPersonReq = badge.target <= 1 ? 1 : badge.target;
        final totalTarget = perPersonReq * 2;
        final combinedProgress =
            myNew.clamp(0, perPersonReq) + partnerTotal.clamp(0, perPersonReq);

        final wasUnlocked = badgeData['isUnlocked'] == true;
        final isNowUnlocked =
            (myNew >= perPersonReq) && (partnerTotal >= perPersonReq);

        final updatedBadgeMap = {
          'id': badge.id,
          'title': badge.title,
          'statKey': badge.statKey,
          'points': badge.points,
          'target': totalTarget,
          'progress': combinedProgress,
          'userDone': myNew >= perPersonReq,
          'partnerDone': partnerTotal >= perPersonReq,
          'isUnlocked': isNowUnlocked,
          'user_contributions': userCounts,
          'iconCodePoint': badge.icon.codePoint,
          if (isNowUnlocked && badgeData['unlockedAt'] == null)
            'unlockedAt': FieldValue.serverTimestamp(),
        };

        final batch = _db.batch();

        // 1. Update current user's achievement badge
        batch.set(badgeDocRef, updatedBadgeMap, SetOptions(merge: true));

        // 2. Award points if unlocked
        if (!wasUnlocked && isNowUnlocked) {
          final userAchDoc = _db
              .collection('users')
              .doc(currentUid)
              .collection('achievements')
              .doc('data');

          batch.set(userAchDoc, {
            'totalPoints': FieldValue.increment(badge.points),
          }, SetOptions(merge: true));
        }

        // 3. Dual-write to partner if linked
        if (partnerUid != null && partnerUid.isNotEmpty) {
          final partnerBadgeDoc = _db
              .collection('users')
              .doc(partnerUid)
              .collection('achievements')
              .doc('data')
              .collection('badges')
              .doc(badge.id);

          final partnerBadgeMap = Map<String, dynamic>.from(updatedBadgeMap);
          partnerBadgeMap['userDone'] = partnerTotal >= perPersonReq;
          partnerBadgeMap['partnerDone'] = myNew >= perPersonReq;

          batch.set(partnerBadgeDoc, partnerBadgeMap, SetOptions(merge: true));

          if (!wasUnlocked && isNowUnlocked) {
            final partnerAchDoc = _db
                .collection('users')
                .doc(partnerUid)
                .collection('achievements')
                .doc('data');

            batch.set(partnerAchDoc, {
              'totalPoints': FieldValue.increment(badge.points),
            }, SetOptions(merge: true));
          }
        }

        await batch.commit();
      }
    } catch (e, stack) {
      debugPrint('Error updating achievement badge: $e\n$stack');
    }
  }
}
