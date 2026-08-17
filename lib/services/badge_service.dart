// lib/services/badge_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/badge_model.dart';

class BadgeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> streamCoupleBadges(String coupleId) {
    return _db.collection('couples').doc(coupleId).snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      final stats = Map<String, dynamic>.from(data['stats'] ?? {});

      return allBadges.map((badgeDef) {
        final currentProgress = (stats[badgeDef.statKey] as num? ?? 0).toInt();
        final isUnlocked = currentProgress >= badgeDef.target;

        return {
          'id': badgeDef.id,
          'title': badgeDef.title,
          'description': badgeDef.description,
          'progress': currentProgress.clamp(0, badgeDef.target),
          'target': badgeDef.target,
          'points': badgeDef.points,
          'isUnlocked': isUnlocked,
          'icon': badgeDef.icon,
          'category': badgeDef.category.name,
        };
      }).toList();
    });
  }

  Future<void> incrementCoupleStat({
    required String coupleId,
    required String statKey,
    int by = 1,
  }) async {
    final coupleRef = _db.collection('couples').doc(coupleId);

    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(coupleRef);
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final stats = Map<String, dynamic>.from(data['stats'] ?? {});
      final currentVal = (stats[statKey] as num? ?? 0).toInt();
      final newVal = currentVal + by;
      stats[statKey] = newVal;

      int newlyAwardedCoins = 0;

      for (final badge in allBadges.where((b) => b.statKey == statKey)) {
        final hadBadgeBefore = currentVal >= badge.target;
        final hasBadgeNow = newVal >= badge.target;

        if (!hadBadgeBefore && hasBadgeNow) {
          newlyAwardedCoins += badge.points;
        }
      }

      transaction.update(coupleRef, {
        'stats': stats,
        if (newlyAwardedCoins > 0)
          'stats.total_shared_coins': FieldValue.increment(newlyAwardedCoins),
      });
    });
  }
}
