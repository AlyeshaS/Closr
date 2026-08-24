// lib/services/scrapbook_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/scrapbook_entry.dart';
import './badge_service.dart';

class ScrapbookService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final BadgeService _badgeService = BadgeService();

  Stream<List<ScrapbookEntry>> streamForCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('scrapbookEntries')
        .orderBy('entryDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ScrapbookEntry.fromDoc).toList());
  }

  Future<String?> _getPartnerUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData == null) return null;

    final partnerEmail =
        ((userData['partnerEmailLower'] as String?) ??
                (userData['partnerEmail'] as String?) ??
                '')
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

    final allUsers = await _db.collection('users').limit(250).get();
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

  Future<String> _uploadImage({
    required String ownerUid,
    required String dateKey,
    required String uploadStamp,
    required XFile imageFile,
  }) async {
    final storageRef = _storage
        .ref()
        .child('scrapbook')
        .child(ownerUid)
        .child(dateKey)
        .child('$uploadStamp.jpg');

    final bytes = await imageFile.readAsBytes();
    final contentType = imageFile.name.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    await storageRef.putData(bytes, SettableMetadata(contentType: contentType));

    return await storageRef.getDownloadURL();
  }

  Future<void> _saveEntryForUser({
    required String uid,
    required String dateKey,
    required ScrapbookEntry entry,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('scrapbookEntries')
        .doc(dateKey)
        .set(entry.toMap());
  }

  Future<void> deleteImageFromEntry({
    required DateTime entryDate,
    required String existingImagePath,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final date = DateTime(entryDate.year, entryDate.month, entryDate.day);
    final dateKey = ScrapbookEntry.dateKeyFor(date);
    final partnerUid = await _getPartnerUid();

    if (existingImagePath.isNotEmpty) {
      try {
        await _storage.ref(existingImagePath).delete();
      } catch (_) {}
    }

    final updateData = <String, Object?>{
      'imageUrl': '',
      'imagePath': '',
      'updatedAt': Timestamp.now(),
    };

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('scrapbookEntries')
        .doc(dateKey)
        .set(updateData, SetOptions(merge: true));

    if (partnerUid != null) {
      await _db
          .collection('users')
          .doc(partnerUid)
          .collection('scrapbookEntries')
          .doc(dateKey)
          .set(updateData, SetOptions(merge: true));
    }
  }

  Future<void> upsertEntry({
    required DateTime entryDate,
    required String description,
    required String existingImageUrl,
    required String existingImagePath,
    XFile? pickedImage,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final date = DateTime(entryDate.year, entryDate.month, entryDate.day);
    final dateKey = ScrapbookEntry.dateKeyFor(date);
    final now = DateTime.now();
    final partnerUid = await _getPartnerUid();

    var imageUrl = existingImageUrl;
    var imagePath = existingImagePath;
    final isNewImageUpload = pickedImage != null;

    if (pickedImage != null) {
      final uploadStamp = now.microsecondsSinceEpoch.toString();
      imageUrl = await _uploadImage(
        ownerUid: user.uid,
        dateKey: dateKey,
        uploadStamp: uploadStamp,
        imageFile: pickedImage,
      );
      imagePath = _storage
          .ref()
          .child('scrapbook')
          .child(user.uid)
          .child(dateKey)
          .child('$uploadStamp.jpg')
          .fullPath;
    }

    final entry = ScrapbookEntry(
      id: dateKey,
      authorId: user.uid,
      recipientId: partnerUid ?? '',
      entryDate: date,
      imageUrl: imageUrl,
      imagePath: imagePath,
      description: description,
      createdAt: now,
      updatedAt: now,
    );

    await _saveEntryForUser(uid: user.uid, dateKey: dateKey, entry: entry);
    if (partnerUid != null) {
      await _saveEntryForUser(uid: partnerUid, dateKey: dateKey, entry: entry);
    }

    // Increment photo badge progress for this user
    if (isNewImageUpload) {
      try {
        await _badgeService.incrementStat(statKey: 'photos_count', by: 1);
      } catch (e) {
        // Continue silently without blocking entry creation
      }
    }
  }
}
