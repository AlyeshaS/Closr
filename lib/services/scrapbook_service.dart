import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/scrapbook_entry.dart';

class ScrapbookService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
    if (user == null) {
      print('🔗 Partner lookup: no current user');
      return null;
    }

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData == null) {
      print('🔗 Partner lookup: user doc not found');
      return null;
    }

    final partnerEmail =
        ((userData['partnerEmailLower'] as String?) ??
                (userData['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();
    if (partnerEmail.isEmpty) {
      print('🔗 Partner lookup: no partnerEmail in user profile');
      return null;
    }

    print('🔗 Looking for partner with email: $partnerEmail');
    final partnerQuery = await _db
        .collection('users')
        .where('emailLower', isEqualTo: partnerEmail)
        .get();

    if (partnerQuery.docs.isNotEmpty) {
      final partnerId = partnerQuery.docs.first.id;
      print('✅ Partner lookup: found partner $partnerId');
      return partnerId;
    }

    final fallbackQuery = await _db
        .collection('users')
        .where('email', isEqualTo: partnerEmail)
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
          final partnerId = doc.id;
          print('✅ Partner lookup: found partner $partnerId');
          return partnerId;
        }
      }
      print('❌ Partner lookup: no user found with email $partnerEmail');
      return null;
    }

    final partnerId = fallbackQuery.docs.first.id;
    print('✅ Partner lookup: found partner $partnerId');
    return partnerId;
  }

  Future<String> _uploadImage({
    required String ownerUid,
    required String dateKey,
    required String uploadStamp,
    required XFile imageFile,
  }) async {
    try {
      final storageRef = _storage
          .ref()
          .child('scrapbook')
          .child(ownerUid)
          .child(dateKey)
          .child('$uploadStamp.jpg');

      print('📸 Uploading to: ${storageRef.fullPath}');
      print('📸 File size: ${await imageFile.length()} bytes');

      final bytes = await imageFile.readAsBytes();
      final contentType = imageFile.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      print('📸 Content type: $contentType');

      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );

      print('📸 Upload successful');

      final downloadUrl = await storageRef.getDownloadURL();
      print('📸 Download URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Upload error: $e');
      rethrow;
    }
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
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    final date = DateTime(entryDate.year, entryDate.month, entryDate.day);
    final dateKey = ScrapbookEntry.dateKeyFor(date);
    final partnerUid = await _getPartnerUid();

    if (existingImagePath.isNotEmpty) {
      try {
        await _storage.ref(existingImagePath).delete();
        print('🗑️ Deleted image from storage: $existingImagePath');
      } catch (error) {
        print('⚠️ Storage delete skipped: $error');
      }
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
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    final date = DateTime(entryDate.year, entryDate.month, entryDate.day);
    final dateKey = ScrapbookEntry.dateKeyFor(date);
    final now = DateTime.now();
    final partnerUid = await _getPartnerUid();

    var imageUrl = existingImageUrl;
    var imagePath = existingImagePath;

    if (pickedImage != null) {
      final uploadStamp = now.microsecondsSinceEpoch.toString();
      try {
        print('🔼 Starting image upload...');
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
        print('✅ Image uploaded successfully');
      } catch (e) {
        print('❌ Image upload failed: $e');
        rethrow;
      }
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

    print('💾 Saving entry to Firestore...');
    await _saveEntryForUser(uid: user.uid, dateKey: dateKey, entry: entry);
    if (partnerUid != null) {
      await _saveEntryForUser(uid: partnerUid, dateKey: dateKey, entry: entry);
    }
    print('✅ Entry saved to Firestore');
  }
}
