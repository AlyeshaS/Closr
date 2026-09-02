// lib/tabs/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../auth/auth_service.dart';
import '../theme_provider.dart';
import '../services/notifications_service.dart';
import '../services/companion_rewards_service.dart';
import '../services/badge_service.dart';
import '../widgets/sprite_animator.dart';
import 'preferences/preferences_service.dart';

// ── Companion Data with Frame Counts & Dimensions ──────────────────────────

class _CompanionOption {
  final String emoji;
  final String defaultName;
  final String species;
  final String assetPath;
  final int totalFrames;
  final double frameWidth;
  final double frameHeight;
  const _CompanionOption(
    this.emoji,
    this.defaultName,
    this.species,
    this.assetPath,
    this.totalFrames,
    this.frameWidth,
    this.frameHeight,
  );
}

const _kCompanions = [
  _CompanionOption(
    '🐱',
    'Mochi',
    'Cat',
    'assets/images/cat.png',
    7,
    32.0,
    32.0,
  ),
  _CompanionOption(
    '🐢',
    'Shelly',
    'Turtle',
    'assets/images/turtle.png',
    8,
    32.0,
    32.0,
  ),
  _CompanionOption(
    '🐻',
    'Cosmo',
    'Bear',
    'assets/images/bear.png',
    6,
    32.0,
    32.0,
  ),
  _CompanionOption(
    '🐦',
    'Lilac',
    'Bird',
    'assets/images/bird.png',
    6,
    16.0,
    16.0,
  ),
  _CompanionOption(
    '🐰',
    'Brownie',
    'Bunny',
    'assets/images/bunny.png',
    12,
    32.0,
    32.0,
  ),
];

// Sofa Shop Items mapping the 4 individual image files
class _SofaShopItem {
  final String id;
  final String title;
  final String description;
  final String variantKey;
  final int cost;
  final String assetPath;

  const _SofaShopItem({
    required this.id,
    required this.title,
    required this.description,
    required this.variantKey,
    required this.cost,
    required this.assetPath,
  });
}

const _kSofaShopItems = [
  _SofaShopItem(
    id: 'sofa_brown',
    title: 'Brown Sofa',
    description: 'A warm, classic tone for a cozy reading corner.',
    variantKey: 'brown',
    cost: 0,
    assetPath: 'assets/images/furniture/sofa_brown.png',
  ),
  _SofaShopItem(
    id: 'sofa_green',
    title: 'Green Sofa',
    description: 'An earthy hue that brings a fresh, natural vibe.',
    variantKey: 'green',
    cost: 30,
    assetPath: 'assets/images/furniture/sofa_green.png',
  ),
  _SofaShopItem(
    id: 'sofa_grey',
    title: 'Grey Sofa',
    description: 'A sleek, neutral modern seating option.',
    variantKey: 'grey',
    cost: 40,
    assetPath: 'assets/images/furniture/sofa_grey.png',
  ),
  _SofaShopItem(
    id: 'sofa_blue',
    title: 'Blue Sofa',
    description: 'A calm, cool accent piece for your room.',
    variantKey: 'blue',
    cost: 50,
    assetPath: 'assets/images/furniture/sofa_blue.png',
  ),
];

// ── Interests Data ─────────────────────────────────────────────────────────────

const _kInterestOptions = {
  'food': [
    'Coffee',
    'Sushi',
    'Pizza',
    'Brunch',
    'Wine',
    'Ramen',
    'Tacos',
    'BBQ',
    'Desserts',
    'Cocktails',
  ],
  'outing': [
    'Hiking',
    'Concerts',
    'Museums',
    'Beach',
    'Camping',
    'Markets',
    'Galleries',
    'Parks',
    'Drives',
    'Picnics',
  ],
  'interests': [
    'Movies',
    'Gaming',
    'Books',
    'Fitness',
    'Cooking',
    'Travel',
    'Music',
    'Photography',
    'Yoga',
    'Gardening',
  ],
  'location': [
    'Indoors',
    'Outdoors',
    'Local',
    'Day trip',
    'Walkable',
    'City',
    'Nature',
    'Hidden gems',
  ],
};

// ─────────────────────────────────────────────────────────────────────────────

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Companion state
  String _companionEmoji = '🐱';
  String _companionName = 'Mochi';
  String _companionAsset = 'assets/images/cat.png';
  int _companionPoints = 0;
  Set<String> _ownedSofaIds = <String>{'sofa_brown'};
  String _equippedSofa = 'brown';
  bool _companionLoading = true;

  final CompanionRewardsService _companionRewardsService =
      CompanionRewardsService();
  final BadgeService _badgeService = BadgeService();

  // Partner state
  String _partnerEmail = '';
  DateTime? _anniversaryDate;

  final _prefsService = PreferencesService();

  @override
  void initState() {
    super.initState();
    _loadCompanion();
  }

  Future<void> _loadCompanion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _companionLoading = false);
      return;
    }
    final normalized = await _companionRewardsService.normalizeCompanionProfile(
      userId: user.uid,
    );

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final furnitureSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('furniture')
        .get();

    final data = doc.data() ?? {};
    final ownedIds = furnitureSnapshot.docs.map((d) => d.id).toSet();
    if (ownedIds.isEmpty) {
      ownedIds.add('sofa_brown');
    }

    setState(() {
      _companionEmoji =
          normalized?['emoji'] ?? (data['companionEmoji'] as String?) ?? '🐱';
      _companionName =
          normalized?['name'] ?? (data['companionName'] as String?) ?? 'Mochi';
      _companionAsset =
          (data['companionAsset'] as String?) ??
          (data['companionLottie'] as String?) ??
          'assets/images/cat.png';
      _companionPoints = (data['companionPoints'] as int?) ?? 0;

      _ownedSofaIds = ownedIds;
      _equippedSofa = (data['equippedSofa'] as String?) ?? 'brown';

      _partnerEmail =
          ((data['partnerEmailLower'] as String?) ??
                  (data['partnerEmail'] as String?) ??
                  '')
              .trim()
              .toLowerCase();
      final annivStr = data['anniversaryDate'] as String?;
      if (annivStr != null && annivStr.isNotEmpty) {
        _anniversaryDate = DateTime.tryParse(annivStr);
      }
      _companionLoading = false;
    });
  }

  // ── Sync Helper to update both users via email connection ────────────────
  Future<void> _syncToPartnerAndSelf({
    required String userEmail,
    required String partnerEmail,
    required Map<String, dynamic> dataToUpdate,
    Map<String, dynamic>? furnitureItemToAdd,
  }) async {
    final firestore = FirebaseFirestore.instance;

    final userQuery = await firestore
        .collection('users')
        .where('email', isEqualTo: userEmail)
        .get();
    final partnerQuery = partnerEmail.isNotEmpty
        ? await firestore
              .collection('users')
              .where('email', isEqualTo: partnerEmail)
              .get()
        : null;

    final batch = firestore.batch();

    for (var doc in userQuery.docs) {
      batch.set(doc.reference, dataToUpdate, SetOptions(merge: true));
      if (furnitureItemToAdd != null) {
        final furnitureRef = doc.reference
            .collection('furniture')
            .doc(furnitureItemToAdd['id']);
        batch.set(furnitureRef, furnitureItemToAdd['data']);
      }
    }

    if (partnerQuery != null) {
      for (var doc in partnerQuery.docs) {
        batch.set(doc.reference, dataToUpdate, SetOptions(merge: true));
        if (furnitureItemToAdd != null) {
          final furnitureRef = doc.reference
              .collection('furniture')
              .doc(furnitureItemToAdd['id']);
          batch.set(furnitureRef, furnitureItemToAdd['data']);
        }
      }
    }

    await batch.commit();
  }

  Future<void> _equipSofa(String variantKey) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    setState(() => _equippedSofa = variantKey);

    await _syncToPartnerAndSelf(
      userEmail: user.email!,
      partnerEmail: _partnerEmail,
      dataToUpdate: {'equippedSofa': variantKey},
    );
  }

  Future<void> _showCompletedBadgesSheet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.military_tech_rounded,
                    color: cs.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Completed Badges',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Badges you and your partner have successfully unlocked together.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _badgeService.streamBadges(user.uid),
                  builder: (context, snapshot) {
                    final allLiveBadges = snapshot.data ?? [];
                    final completedBadges = allLiveBadges
                        .where((b) => b['isUnlocked'] == true)
                        .toList();

                    if (completedBadges.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 40,
                                color: cs.onSurfaceVariant.withOpacity(0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No completed badges yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Work together on shared activities to earn your first badge!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: completedBadges.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final badge = completedBadges[idx];
                        final icon =
                            badge['icon'] as IconData? ??
                            Icons.military_tech_rounded;
                        final points = badge['points'] ?? 50;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).brightness == Brightness.dark
                                ? const Color(0xFF231519)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cs.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    icon,
                                    color: cs.primary,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      badge['title'] ?? 'Badge',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      badge['description'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '+$points pts',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCompanionShop() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    var points = _companionPoints;
    var ownedIds = Set<String>.from(_ownedSofaIds);
    var equippedKey = _equippedSofa;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Furniture shop',
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use your companion points to unlock new sofa color variants for your room.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Points available',
                          style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      Text(
                        '$points',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _kSofaShopItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _kSofaShopItems[index];
                      final owned =
                          item.variantKey == 'brown' ||
                          ownedIds.contains(item.id);
                      final isEquipped = equippedKey == item.variantKey;
                      final canBuy = !owned && points >= item.cost;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).brightness == Brightness.dark
                              ? const Color(0xFF231519)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Theme.of(ctx).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  ctx,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Image.asset(
                                  item.assetPath,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: Theme.of(ctx).textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description,
                                    style: Theme.of(ctx).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            ctx,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    owned
                                        ? (isEquipped ? 'Equipped' : 'Owned')
                                        : '${item.cost} points',
                                    style: Theme.of(ctx).textTheme.labelMedium
                                        ?.copyWith(
                                          color: owned
                                              ? Theme.of(
                                                  ctx,
                                                ).colorScheme.primary
                                              : Theme.of(
                                                  ctx,
                                                ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: owned
                                  ? (isEquipped
                                        ? null
                                        : () async {
                                            await _equipSofa(item.variantKey);
                                            setSheet(() {
                                              equippedKey = item.variantKey;
                                            });
                                            setState(() {
                                              _equippedSofa = item.variantKey;
                                            });
                                          })
                                  : (!canBuy
                                        ? null
                                        : () async {
                                            try {
                                              await _syncToPartnerAndSelf(
                                                userEmail: user.email!,
                                                partnerEmail: _partnerEmail,
                                                dataToUpdate: {
                                                  'companionPoints':
                                                      FieldValue.increment(
                                                        -item.cost,
                                                      ),
                                                  'equippedSofa':
                                                      item.variantKey,
                                                },
                                                furnitureItemToAdd: {
                                                  'id': item.id,
                                                  'data': {
                                                    'variantKey':
                                                        item.variantKey,
                                                    'title': item.title,
                                                    'unlockedAt':
                                                        FieldValue.serverTimestamp(),
                                                  },
                                                },
                                              );

                                              setSheet(() {
                                                points -= item.cost;
                                                ownedIds.add(item.id);
                                                equippedKey = item.variantKey;
                                              });
                                              setState(() {
                                                _equippedSofa = item.variantKey;
                                                _ownedSofaIds = ownedIds;
                                                _companionPoints = points;
                                              });
                                              if (!mounted) return;
                                              await _loadCompanion();
                                            } catch (_) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Could not complete purchase',
                                                  ),
                                                ),
                                              );
                                            }
                                          }),
                              child: Text(
                                owned
                                    ? (isEquipped ? 'Equipped' : 'Equip')
                                    : 'Buy',
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
      ),
    );
  }

  Future<void> _showSupportDialog({
    required String title,
    required String message,
    String? actionLabel,
    Future<void> Function()? onAction,
  }) async {
    final cs = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (actionLabel != null && onAction != null)
            FilledButton(
              onPressed: () async {
                await onAction();
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }

  Future<void> _showAboutSupport() async {
    await _showSupportDialog(
      title: 'About Closr',
      message:
          'Closr helps you and your partner keep track of suggestions, interests, and shared settings in one place.',
    );
  }

  Future<void> _showPrivacySupport() async {
    await _showSupportDialog(
      title: 'Privacy policy',
      message:
          'Closr stores your account, companion, and preference data in Firebase so your experience stays in sync across devices. Review the app settings before sharing anything sensitive.',
    );
  }

  Future<void> _showHelpSupport() async {
    await _showHelpSupportDialog();
  }

  Future<void> _showHelpSupportDialog() async {
    await _showSupportDialog(
      title: 'Help & feedback',
      message:
          'If something feels off, copy a short note about what happened and share it with your team or support channel.',
      actionLabel: 'Copy note',
      onAction: () async {
        await Clipboard.setData(
          const ClipboardData(
            text:
                'Closr feedback: describe the issue, what you expected, and what happened instead.',
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback note copied to clipboard')),
        );
      },
    );
  }

  Future<void> _showAddPartnerDialog() async {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: _partnerEmail);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Partner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your partner\'s email to link your accounts.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'partner@email.com'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final email = controller.text.trim().toLowerCase();
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set({
                      'partnerEmail': email,
                      'partnerEmailLower': email,
                    }, SetOptions(merge: true));
                setState(() => _partnerEmail = email);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSetAnniversaryDialog() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _anniversaryDate ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );

    if (selected != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'anniversaryDate': selected.toIso8601String(),
        }, SetOptions(merge: true));
        setState(() => _anniversaryDate = selected);
      }
    }
  }

  Future<void> _showCompanionPicker() async {
    final cs = Theme.of(context).colorScheme;
    int selectedIdx = _kCompanions.indexWhere(
      (c) => c.emoji == _companionEmoji || c.assetPath == _companionAsset,
    );
    if (selectedIdx < 0) selectedIdx = 0;
    final nameCtrl = TextEditingController(text: _companionName);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose your companion',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your companion grows with your relationship.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                    children: List.generate(_kCompanions.length, (i) {
                      final c = _kCompanions[i];
                      final selected = i == selectedIdx;
                      final isSprite = c.assetPath.endsWith('.png');

                      return GestureDetector(
                        onTap: () {
                          setSheet(() => selectedIdx = i);
                          if (_kCompanions.any(
                            (x) => x.defaultName == nameCtrl.text,
                          )) {
                            nameCtrl.text = c.defaultName;
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: selected
                                ? cs.primaryContainer
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? cs.primary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: isSprite
                                    ? Center(
                                        child: Transform.scale(
                                          scale: c.frameWidth == 64.0
                                              ? 0.55
                                              : 1.0,
                                          child: SpriteAnimator(
                                            imagePath: c.assetPath,
                                            totalFrames: c.totalFrames,
                                            displayWidth: c.frameWidth,
                                            displayHeight: c.frameHeight,
                                            duration: const Duration(
                                              milliseconds: 800,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          c.emoji,
                                          style: const TextStyle(fontSize: 28),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.species,
                                style: Theme.of(ctx).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Name your companion',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Give them a name...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final chosen = _kCompanions[selectedIdx];
                        final newName = nameCtrl.text.trim().isEmpty
                            ? chosen.defaultName
                            : nameCtrl.text.trim();
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null && user.email != null) {
                          final updateData = {
                            'companionEmoji': chosen.emoji,
                            'companionName': newName,
                            'companionSpecies': chosen.species,
                            'companionAsset': chosen.assetPath,
                            'companionLottie': chosen.assetPath,
                          };

                          await _syncToPartnerAndSelf(
                            userEmail: user.email!,
                            partnerEmail: _partnerEmail,
                            dataToUpdate: updateData,
                          );

                          await _companionRewardsService.syncCompanionProfile(
                            userId: user.uid,
                            emoji: chosen.emoji,
                            name: newName,
                          );
                        }
                        setState(() {
                          _companionEmoji = chosen.emoji;
                          _companionName = newName;
                          _companionAsset = chosen.assetPath;
                        });
                        if (mounted) {
                          await _loadCompanion();
                        }

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    Icons.favorite_rounded,
                                    color: cs.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('Companion saved successfully!'),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.pets_rounded, size: 18),
                      label: const Text('Save companion'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showInterestsEditor(
    String key,
    String label,
    List<String> current,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final options = _kInterestOptions[key] ?? [];
    final selected = Set<String>.from(current);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Edit $label',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to select what fits you both.',
                style: Theme.of(
                  ctx,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: options.map((opt) {
                  final isOn = selected.contains(opt);
                  return GestureDetector(
                    onTap: () => setSheet(() {
                      isOn ? selected.remove(opt) : selected.add(opt);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isOn ? cs.primary : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isOn ? cs.primary : cs.outlineVariant,
                        ),
                      ),
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isOn ? cs.onPrimary : cs.onSurface,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _prefsService.updatePreference(
                      key,
                      selected.toList(),
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      setState(() {});
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Your Name';
    final email = user?.email ?? '';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((p) => p[0]).take(2).join().toUpperCase()
        : '?';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 20),

          // ── Profile card ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF231519)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primaryContainer,
                    border: Border.all(
                      color: cs.primary.withOpacity(0.3),
                      width: 2,
                    ),
                    image: user?.photoURL != null
                        ? DecorationImage(
                            image: NetworkImage(user!.photoURL!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: user?.photoURL == null
                      ? Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: cs.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.edit_outlined, size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Companion group ─────────────────────────────────────────
          _GroupLabel(text: 'Companion', cs: cs),
          const SizedBox(height: 8),
          _SettingsGroup(
            cs: cs,
            rows: [
              _SettingsRowData(
                icon: Icons.favorite_outline_rounded,
                label: 'Partner email',
                onTap: _showAddPartnerDialog,
                trailing: _partnerEmail.isEmpty
                    ? Text(
                        'Not set',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    : Text(
                        _partnerEmail,
                        style: TextStyle(fontSize: 13, color: cs.primary),
                      ),
              ),
              _SettingsRowData(
                icon: Icons.cake_outlined,
                label: 'Anniversary date',
                onTap: _showSetAnniversaryDialog,
                trailing: _anniversaryDate == null
                    ? const _TrailingArrow()
                    : Text(
                        '${_anniversaryDate!.month}/${_anniversaryDate!.day}/${_anniversaryDate!.year}',
                        style: TextStyle(fontSize: 13, color: cs.primary),
                      ),
              ),
              _SettingsRowData(
                icon: Icons.pets_rounded,
                label: 'Companion name',
                onTap: _companionLoading ? null : _showCompanionPicker,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _companionName,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 14,
                        color: cs.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const _TrailingArrow(),
                  ],
                ),
              ),
              _SettingsRowData(
                icon: Icons.military_tech_rounded,
                label: 'Completed Badges',
                onTap: _showCompletedBadgesSheet,
                trailing: const _TrailingArrow(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Furniture shop ──────────────────────────────────────────
          _GroupLabel(text: 'Furniture shop', cs: cs),
          const SizedBox(height: 8),
          _SettingsGroup(
            cs: cs,
            rows: [
              _SettingsRowData(
                icon: Icons.storefront_rounded,
                label: 'Open furniture shop',
                onTap: _openCompanionShop,
                trailing: const _TrailingArrow(),
              ),
              _SettingsRowData(
                icon: Icons.stars_rounded,
                label: 'Points balance',
                trailing: Text(
                  '$_companionPoints',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Preferences group ───────────────────────────────────────
          _GroupLabel(text: 'Preferences', cs: cs),
          const SizedBox(height: 8),
          _SettingsGroup(
            cs: cs,
            rows: [
              _SettingsRowData(
                icon: Icons.notifications_outlined,
                label: 'Daily reminder',
                trailing: Consumer<NotificationsService>(
                  builder: (_, ns, __) => _ToggleSwitch(
                    cs: cs,
                    value: ns.enabled,
                    onChanged: ns.setEnabled,
                  ),
                ),
              ),
              _SettingsRowData(
                icon: Icons.dark_mode_outlined,
                label: 'Dark mode',
                trailing: Consumer<ThemeProvider>(
                  builder: (_, tp, __) => _ToggleSwitch(
                    cs: cs,
                    value: tp.isDark,
                    onChanged: tp.setDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Interests ───────────────────────────────────────────────
          _GroupLabel(text: 'Interests', cs: cs),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>?>(
            future: _prefsService.getPreferences(),
            builder: (context, snapshot) {
              final prefs = snapshot.data ?? {};
              return _CollapsibleInterests(
                prefs: prefs,
                cs: cs,
                onEdit: _showInterestsEditor,
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Support group ───────────────────────────────────────────
          _GroupLabel(text: 'Support', cs: cs),
          const SizedBox(height: 8),
          _SettingsGroup(
            cs: cs,
            rows: [
              _SettingsRowData(
                icon: Icons.info_outline_rounded,
                label: 'About Closr',
                onTap: _showAboutSupport,
                trailing: const _TrailingArrow(),
              ),
              _SettingsRowData(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy policy',
                onTap: _showPrivacySupport,
                trailing: const _TrailingArrow(),
              ),
              _SettingsRowData(
                icon: Icons.help_outline_rounded,
                label: 'Help & feedback',
                onTap: _showHelpSupport,
                trailing: const _TrailingArrow(),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Sign out ────────────────────────────────────────────────
          ElevatedButton(
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/welcome');
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Sign out'),
          ),
          const SizedBox(height: 12),

          Center(
            child: Text(
              'Closr v1.0.0',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Interests collapsible widget & helper classes ────────────────────────────

class _CollapsibleInterests extends StatefulWidget {
  final Map<String, dynamic> prefs;
  final ColorScheme cs;
  final Future<void> Function(String key, String label, List<String> current)
  onEdit;
  const _CollapsibleInterests({
    required this.prefs,
    required this.cs,
    required this.onEdit,
  });

  @override
  State<_CollapsibleInterests> createState() => _CollapsibleInterestsState();
}

class _CollapsibleInterestsState extends State<_CollapsibleInterests> {
  final Map<String, bool> _expanded = {
    'food': false,
    'outing': false,
    'interests': false,
    'location': false,
  };

  static const _labels = {
    'food': 'Food',
    'outing': 'Outing',
    'interests': 'Interests',
    'location': 'Location',
  };

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF231519)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: _labels.entries.map((entry) {
          final key = entry.key;
          final label = entry.value;
          final isLast = key == 'location';
          final isExpanded = _expanded[key]!;
          final items = widget.prefs[key] is List
              ? List<String>.from(widget.prefs[key])
              : <String>[];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _expanded[key] = !isExpanded),
                        child: Row(
                          children: [
                            Icon(
                              const {
                                'food': Icons.restaurant_outlined,
                                'outing': Icons.explore_outlined,
                                'interests': Icons.auto_awesome_outlined,
                                'location': Icons.place_outlined,
                              }[key]!,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              label,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_right,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onEdit(key, label, items),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: cs.primary,
                      ),
                      child: const Text('Edit', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(50, 0, 16, 14),
                        child: Text(
                          'None set — tap Edit to add some.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(50, 0, 16, 14),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: items
                              .map(
                                (item) => Chip(
                                  label: Text(item),
                                  backgroundColor: cs.primaryContainer,
                                  side: BorderSide(color: cs.primary),
                                  labelStyle: TextStyle(
                                    color: cs.onPrimaryContainer,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                              .toList(),
                        ),
                      ),
              ),
              if (!isLast)
                Divider(height: 1, color: cs.outlineVariant, indent: 50),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _GroupLabel({required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}

class _SettingsRowData {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget trailing;
  const _SettingsRowData({
    required this.icon,
    required this.label,
    this.onTap,
    required this.trailing,
  });
}

class _SettingsGroup extends StatelessWidget {
  final ColorScheme cs;
  final List<_SettingsRowData> rows;
  const _SettingsGroup({required this.cs, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF231519)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          final row = rows[i];
          final isLast = i == rows.length - 1;
          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: row.onTap,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(i == 0 ? 18 : 0),
                    bottom: Radius.circular(isLast ? 18 : 0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(row.icon, size: 20, color: cs.onSurfaceVariant),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            row.label,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        row.trailing,
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Divider(height: 1, color: cs.outlineVariant, indent: 50),
            ],
          );
        }),
      ),
    );
  }
}

class _TrailingArrow extends StatelessWidget {
  const _TrailingArrow();
  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right_rounded,
      size: 20,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

class _ToggleSwitch extends StatelessWidget {
  final ColorScheme cs;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleSwitch({
    required this.cs,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: cs.primary,
      activeColor: cs.surface,
      inactiveThumbColor: cs.onSurfaceVariant.withOpacity(0.4),
      inactiveTrackColor: cs.outlineVariant,
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }
}
