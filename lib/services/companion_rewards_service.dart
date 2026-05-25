import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/achievement_badge_reward.dart';

class CompanionRewardsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DateTime? _readTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> _companionDataFrom(Map<String, dynamic>? data) {
    return data ?? const <String, dynamic>{};
  }

  Future<String?> _resolvePartnerUid(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    final userData = userDoc.data();
    final partnerEmail =
        ((userData?['partnerEmailLower'] as String?) ??
                (userData?['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();

    if (partnerEmail.isEmpty) return null;

    final partnerQuery = await _db
        .collection('users')
        .where('emailLower', isEqualTo: partnerEmail)
        .get();
    if (partnerQuery.docs.isNotEmpty) return partnerQuery.docs.first.id;

    final fallbackQuery = await _db
        .collection('users')
        .where('email', isEqualTo: partnerEmail)
        .get();
    if (fallbackQuery.docs.isNotEmpty) return fallbackQuery.docs.first.id;

    final allUsers = await _db.collection('users').limit(250).get();
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

  Future<int> claimBadgeRewards({
    required String userId,
    required List<AchievementBadgeReward> rewards,
  }) async {
    if (rewards.isEmpty) return 0;

    return _db.runTransaction<int>((transaction) async {
      final userRef = _db.collection('users').doc(userId);
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? const <String, dynamic>{};

      final claimedIds = Set<String>.from(
        List<String>.from(
          (data['claimedAchievementBadgeIds'] as List?) ?? const [],
        ),
      );
      var currentPoints = (data['companionPoints'] as int?) ?? 0;
      var pointsAwarded = 0;

      for (final reward in rewards) {
        if (claimedIds.add(reward.id)) {
          currentPoints += reward.points;
          pointsAwarded += reward.points;
        }
      }

      transaction.set(userRef, {
        'companionPoints': currentPoints,
        'claimedAchievementBadgeIds': claimedIds.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return pointsAwarded;
    });
  }

  Future<void> syncCompanionProfile({
    required String userId,
    required String emoji,
    required String name,
  }) async {
    final partnerUid = await _resolvePartnerUid(userId);
    final updates = <String, Object?>{
      'companionEmoji': emoji,
      'companionName': name,
      'companionUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _db
        .collection('users')
        .doc(userId)
        .set(updates, SetOptions(merge: true));

    if (partnerUid != null) {
      await _db
          .collection('users')
          .doc(partnerUid)
          .set(updates, SetOptions(merge: true));
    }
  }

  Future<Map<String, String>?> normalizeCompanionProfile({
    required String userId,
  }) async {
    final partnerUid = await _resolvePartnerUid(userId);
    final userDoc = await _db.collection('users').doc(userId).get();
    final userData = _companionDataFrom(userDoc.data());

    if (partnerUid == null) {
      final emoji = (userData['companionEmoji'] as String?) ?? '🦊';
      final name = (userData['companionName'] as String?) ?? 'Ember';
      return {'emoji': emoji, 'name': name};
    }

    final partnerDoc = await _db.collection('users').doc(partnerUid).get();
    final partnerData = _companionDataFrom(partnerDoc.data());

    final userUpdatedAt = _readTimestamp(userData['companionUpdatedAt']);
    final partnerUpdatedAt = _readTimestamp(partnerData['companionUpdatedAt']);
    final usePartner =
        partnerUpdatedAt != null &&
        (userUpdatedAt == null || partnerUpdatedAt.isAfter(userUpdatedAt));

    final chosenData = usePartner ? partnerData : userData;
    final emoji = (chosenData['companionEmoji'] as String?) ?? '🦊';
    final name = (chosenData['companionName'] as String?) ?? 'Ember';

    final userEmoji = (userData['companionEmoji'] as String?) ?? '🦊';
    final userName = (userData['companionName'] as String?) ?? 'Ember';
    final partnerEmoji = (partnerData['companionEmoji'] as String?) ?? '🦊';
    final partnerName = (partnerData['companionName'] as String?) ?? 'Ember';

    if (emoji != userEmoji ||
        name != userName ||
        emoji != partnerEmoji ||
        name != partnerName) {
      await syncCompanionProfile(userId: userId, emoji: emoji, name: name);
    }

    return {'emoji': emoji, 'name': name};
  }

  Future<int> purchaseShopItem({
    required String userId,
    required String itemId,
    required int cost,
  }) async {
    if (cost <= 0) return 0;

    final partnerUid = await _resolvePartnerUid(userId);

    return _db.runTransaction<int>((transaction) async {
      final userRef = _db.collection('users').doc(userId);
      final userSnap = await transaction.get(userRef);
      final userData = userSnap.data() ?? const <String, dynamic>{};

      final ownedIds = Set<String>.from(
        List<String>.from(
          (userData['companionShopOwnedIds'] as List?) ?? const [],
        ),
      );
      if (ownedIds.contains(itemId)) {
        return 0;
      }

      var currentPoints = (userData['companionPoints'] as int?) ?? 0;
      if (currentPoints < cost) {
        throw StateError('Not enough companion points');
      }

      ownedIds.add(itemId);
      currentPoints -= cost;

      final userUpdates = <String, Object?>{
        'companionPoints': currentPoints,
        'companionShopOwnedIds': ownedIds.toList(),
        'companionShopEquippedId': itemId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.set(userRef, userUpdates, SetOptions(merge: true));

      if (partnerUid != null) {
        final partnerRef = _db.collection('users').doc(partnerUid);
        final partnerSnap = await transaction.get(partnerRef);
        final partnerData = partnerSnap.data() ?? const <String, dynamic>{};
        final partnerOwnedIds = Set<String>.from(
          List<String>.from(
            (partnerData['companionShopOwnedIds'] as List?) ?? const [],
          ),
        )..add(itemId);

        transaction.set(partnerRef, {
          'companionShopOwnedIds': partnerOwnedIds.toList(),
          'companionShopEquippedId': itemId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return cost;
    });
  }
}
