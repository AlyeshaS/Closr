part of '../tabs/home_page.dart';

class _FurnitureInventorySheet extends StatefulWidget {
  final ColorScheme cs;
  final VoidCallback? onEditModeRequested;
  final String selectedRoomTheme;
  final ValueChanged<String>? onRoomThemeChanged;

  const _FurnitureInventorySheet({
    required this.cs,
    required this.selectedRoomTheme,
    this.onRoomThemeChanged,
    this.onEditModeRequested,
  });

  @override
  State<_FurnitureInventorySheet> createState() =>
      _FurnitureInventorySheetState();
}

class _FurnitureInventorySheetState extends State<_FurnitureInventorySheet> {
  String _selectedCategory = 'Rooms';

  final List<String> _categories = [
    'Rooms',
    'Sofas',
    'Chairs',
    'Beds',
    'Desks',
    'Rugs',
    'Storage',
    'Tables',
    'Lighting',
    'Plants',
    'Wall',
    'Tabletop',
    'Tech',
    'Books',
    'Toys',
    'Aquarium',
  ];

  String _getItemTitle(String category, String variantKey) {
    final formatted = variantKey.replaceAll('_', ' ');
    final capitalized = formatted.isEmpty
        ? ''
        : formatted[0].toUpperCase() + formatted.substring(1);

    switch (category.toLowerCase()) {
      case 'sofas':
        switch (variantKey) {
          case 'green':
            return 'Fern Sofa';
          case 'blue':
            return 'Sky Sofa';
          case 'brown':
            return 'Sand Sofa';
          case 'grey':
            return 'Slate Sofa';
          default:
            return '$capitalized Sofa';
        }
      case 'beds':
        return '$capitalized Bed';
      case 'desks':
        return '$capitalized Desk';
      case 'rugs':
        return '$capitalized Rug';
      case 'decor':
        return capitalized;
      default:
        return capitalized;
    }
  }

  Map<String, String> _getAssetsForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'sofas':
        return kSofaAssets;
      case 'beds':
        return kBedAssets;
      case 'desks':
        return kDeskAssets;
      case 'rugs':
        return kRugAssets;
      case 'chairs':
        return _decorAssetsWhere((key) => key.startsWith('chair_'));
      case 'storage':
        return _decorAssetsWhere(
          (key) => key == 'bookcase' || key.startsWith('drawers_'),
        );
      case 'tables':
        return _decorAssetsWhere(
          (key) => key.startsWith('table_') || key.startsWith('littletable_'),
        );
      case 'lighting':
        return _decorAssetsWhere(
          (key) =>
              key.startsWith('lamp_') ||
              key == 'decorative_lamp' ||
              key == 'decorative_light',
        );
      case 'plants':
        return _decorAssetsWhere(
          (key) => key == 'plant' || key.startsWith('plant_'),
        );
      case 'wall':
        return _decorAssetsWhere(
          (key) =>
              key.startsWith('littleframes_') ||
              key.startsWith('littlewallpainting_') ||
              key.startsWith('wallpainting_') ||
              key.startsWith('window_'),
        );
      case 'tabletop':
        return _decorAssetsWhere(
          (key) => key == 'candle' || key.startsWith('coffeecup_'),
        );
      case 'tech':
        return _decorAssetsWhere(
          (key) => key.startsWith('laptop_') || key == 'television',
        );
      case 'books':
        return _decorAssetsWhere((key) => key.startsWith('book_'));
      case 'toys':
        return _decorAssetsWhere((key) => key.startsWith('teddybear_'));
      case 'aquarium':
        return _decorAssetsWhere((key) => key == 'aquarium');
      default:
        return {};
    }
  }

  Map<String, String> _decorAssetsWhere(bool Function(String key) test) {
    return Map.fromEntries(
      kDecorAssets.entries.where((entry) => test(entry.key)),
    );
  }

  String _categoryPrefix(String category) {
    switch (category.toLowerCase()) {
      case 'sofas':
        return 'sofa_';
      case 'beds':
        return 'bed_';
      case 'desks':
        return 'desk_';
      case 'rugs':
        return 'carpet_';
      default:
        return '';
    }
  }

  Future<void> _addPlacedItem(
    User user,
    String itemKey,
    String category,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? {};
    final partnerEmail =
        ((userData['partnerEmailLower'] as String?) ??
                (userData['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();

    final meta = getFurnitureMeta(itemKey);
    final instanceId =
        'placed_${DateTime.now().microsecondsSinceEpoch}_${itemKey.replaceAll('/', '_')}';
    final itemData = <String, dynamic>{
      'type': 'furnitureInstance',
      'itemKey': itemKey,
      'isEquipped': true,
      'category': category,
      'roomSurface': meta.surface == RoomSurface.floor
          ? 'floor'
          : (meta.surface == RoomSurface.leftWall ? 'leftWall' : 'rightWall'),
      'location': {
        'col': 0.5,
        'row': meta.surface == RoomSurface.floor ? 0.35 : 0.5,
      },
      'visualScale': 1.0,
      'visualRotation': 0.0,
      'flipX': false,
      'flipY': false,
      'isLocked': false,
    };

    final batch = firestore.batch();
    batch.set(userRef.collection('furniture').doc(instanceId), itemData);

    if (partnerEmail.isNotEmpty) {
      final partnerQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: partnerEmail)
          .get();
      for (final pDoc in partnerQuery.docs) {
        batch.set(
          pDoc.reference.collection('furniture').doc(instanceId),
          itemData,
        );
      }
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final cs = widget.cs;
    final cardBackgroundColor = cs.surfaceContainerHighest;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.fromLTRB(
        12,
        16,
        12,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.chair_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Text(
                  'Furniture Inventory',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.edit_rounded, color: cs.primary, size: 22),
                  tooltip: 'Edit Layout',
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onEditModeRequested?.call();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.onSurface.withValues(alpha: 0.05)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _categories.map((category) {
                    final active = category == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 36,
                        decoration: BoxDecoration(
                          color: active ? cs.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active
                                ? cs.primary.withValues(alpha: 0.45)
                                : Colors.transparent,
                          ),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: cs.primary.withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              setState(() => _selectedCategory = category),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Center(
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active
                                      ? cs.onSurface
                                      : cs.onSurfaceVariant.withValues(
                                          alpha: 0.85,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: user == null
                  ? const SizedBox()
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('furniture')
                          .snapshots(),
                      builder: (context, furnitureSnapshot) {
                        if (!furnitureSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = furnitureSnapshot.data!.docs;
                        final isRoomCategory =
                            _selectedCategory.toLowerCase() == 'rooms';

                        if (isRoomCategory) {
                          final roomEntries = kRoomThemes.entries.toList();

                          return GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.15,
                                ),
                            itemCount: roomEntries.length,
                            itemBuilder: (context, index) {
                              final entry = roomEntries[index];
                              final key = entry.key;
                              final theme = entry.value;
                              final roomDoc = docs
                                  .where((doc) => doc.id == key)
                                  .firstOrNull;
                              final roomData =
                                  roomDoc?.data() as Map<String, dynamic>?;
                              final selected =
                                  roomData?['isEquipped'] == true ||
                                  (roomDoc == null &&
                                      widget.selectedRoomTheme == key);

                              return GestureDetector(
                                onTap: () {
                                  widget.onRoomThemeChanged?.call(key);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selected
                                          ? cs.primary
                                          : cs.outlineVariant,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: CustomPaint(
                                            painter: _RoomBackgroundPainter(
                                              theme: theme,
                                            ),
                                            child: const SizedBox.expand(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              theme.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          if (selected)
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 17,
                                              color: cs.primary,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }

                        final categoryAssets = _getAssetsForCategory(
                          _selectedCategory,
                        );
                        final prefix = _categoryPrefix(_selectedCategory);

                        List<Map<String, dynamic>> catalogItems = [];

                        categoryAssets.forEach((variantKey, assetPath) {
                          final itemKey = prefix.isNotEmpty
                              ? '$prefix$variantKey'
                              : variantKey;

                          int placedCount = 0;
                          for (final doc in docs) {
                            if (kRoomThemes.containsKey(doc.id)) continue;
                            final data =
                                (doc.data() as Map<String, dynamic>?) ??
                                const {};
                            final storedItemKey =
                                (data['itemKey'] as String?) ?? doc.id;
                            if (storedItemKey == itemKey &&
                                data['isEquipped'] == true) {
                              placedCount++;
                            }
                          }

                          catalogItems.add({
                            'itemKey': itemKey,
                            'variantKey': variantKey,
                            'assetPath': assetPath,
                            'placedCount': placedCount,
                          });
                        });

                        if (catalogItems.isEmpty) {
                          return Center(
                            child: Text(
                              'No items available in $_selectedCategory.',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                        return GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.0,
                              ),
                          itemCount: catalogItems.length,
                          itemBuilder: (context, index) {
                            final itemInfo = catalogItems[index];
                            final itemKey = itemInfo['itemKey'] as String;
                            final variantKey = itemInfo['variantKey'] as String;
                            final assetPath = itemInfo['assetPath'] as String;
                            final placedCount = itemInfo['placedCount'] as int;
                            final itemTitle = _getItemTitle(
                              _selectedCategory,
                              variantKey,
                            );

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: user == null
                                    ? null
                                    : () => _addPlacedItem(
                                        user,
                                        itemKey,
                                        _selectedCategory,
                                      ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: placedCount > 0
                                          ? cs.primary.withValues(alpha: 0.7)
                                          : cs.outlineVariant,
                                      width: placedCount > 0 ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Container(
                                                color: cs
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.3),
                                                child: const SizedBox.expand(),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  6.0,
                                                ),
                                                child: Image.asset(
                                                  assetPath,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                              Positioned(
                                                right: 6,
                                                top: 6,
                                                child: Container(
                                                  width: 28,
                                                  height: 28,
                                                  decoration: BoxDecoration(
                                                    color: cs.primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.add_rounded,
                                                    size: 19,
                                                    color: cs.onPrimary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              itemTitle,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (placedCount > 0)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: cs.primary.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
                                              child: Text(
                                                'x$placedCount',
                                                style: TextStyle(
                                                  color: cs.primary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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
    );
  }
}
