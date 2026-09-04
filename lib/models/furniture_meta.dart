enum RoomSurface { floor, leftWall, rightWall }

class FurnitureItemMeta {
  final String assetPath;
  final RoomSurface surface;
  final int widthSquares;
  final int lengthSquares;
  final int heightSquares;

  const FurnitureItemMeta({
    required this.assetPath,
    required this.surface,
    this.widthSquares = 1,
    this.lengthSquares = 1,
    this.heightSquares = 1,
  });
}

const Map<String, String> kSofaAssets = {
  'green': 'assets/images/furniture/sofa_green.png',
  'blue': 'assets/images/furniture/sofa_blue.png',
  'brown': 'assets/images/furniture/sofa_brown.png',
  'grey': 'assets/images/furniture/sofa_grey.png',
};

const Map<String, String> kBedAssets = {
  'black': 'assets/images/furniture/bed_black.png',
  'blue': 'assets/images/furniture/bed_blue.png',
  'green': 'assets/images/furniture/bed_green.png',
  'orange': 'assets/images/furniture/bed_orange.png',
  'purple': 'assets/images/furniture/bed_purple.png',
  'red': 'assets/images/furniture/bed_red.png',
  'white': 'assets/images/furniture/bed_white.png',
  'yellow': 'assets/images/furniture/bed_yellow.png',
};

const Map<String, String> kDeskAssets = {
  'beige': 'assets/images/furniture/desk_beige.png',
  'black': 'assets/images/furniture/desk_black.png',
  'blue': 'assets/images/furniture/desk_blue.png',
  'brown': 'assets/images/furniture/desk_brown.png',
  'purple': 'assets/images/furniture/desk_purple.png',
  'yellow': 'assets/images/furniture/desk_yellow.png',
};

const Map<String, String> kRugAssets = {
  'blue': 'assets/images/furniture/carpet_blue.png',
  'brown': 'assets/images/furniture/carpet_brown.png',
  'green': 'assets/images/furniture/carpet_green.png',
  'purple': 'assets/images/furniture/carpet_purple.png',
  'red': 'assets/images/furniture/carpet_red.png',
  'white': 'assets/images/furniture/carpet_white.png',
  'yellow': 'assets/images/furniture/carpet_yellow.png',
};

const Map<String, String> kDecorAssets = {
  'aquarium': 'assets/images/furniture/aquarium.png',
  'bookcase': 'assets/images/furniture/BookCase.png',
  'candle': 'assets/images/furniture/Candle.png',
  'dog': 'assets/images/furniture/Dog.png',
  'television': 'assets/images/furniture/Television.png',
  'plant': 'assets/images/furniture/Plant.png',
};

FurnitureItemMeta getFurnitureMeta(String docId) {
  if (docId == 'aquarium') {
    return const FurnitureItemMeta(
      assetPath: 'assets/images/furniture/aquarium.png',
      surface: RoomSurface.floor,
      widthSquares: 3,
      lengthSquares: 2,
      heightSquares: 2,
    );
  }
  if (kSofaAssets.containsKey(docId) || docId.startsWith('sofa_')) {
    final v = docId.replaceFirst('sofa_', '');
    return FurnitureItemMeta(
      assetPath: kSofaAssets[v] ?? 'assets/images/furniture/sofa_brown.png',
      surface: RoomSurface.floor,
      widthSquares: 4,
      lengthSquares: 2,
      heightSquares: 2,
    );
  }
  if (kBedAssets.containsKey(docId) || docId.startsWith('bed_')) {
    final v = docId.replaceFirst('bed_', '');
    return FurnitureItemMeta(
      assetPath: kBedAssets[v] ?? 'assets/images/furniture/bed_black.png',
      surface: RoomSurface.floor,
      widthSquares: 4,
      lengthSquares: 3,
      heightSquares: 2,
    );
  }
  if (kDeskAssets.containsKey(docId) || docId.startsWith('desk_')) {
    final v = docId.replaceFirst('desk_', '');
    return FurnitureItemMeta(
      assetPath: kDeskAssets[v] ?? 'assets/images/furniture/desk_beige.png',
      surface: RoomSurface.floor,
      widthSquares: 3,
      lengthSquares: 2,
      heightSquares: 2,
    );
  }
  if (kRugAssets.containsKey(docId) || docId.startsWith('carpet_')) {
    final v = docId.replaceFirst('carpet_', '');
    return FurnitureItemMeta(
      assetPath: kRugAssets[v] ?? 'assets/images/furniture/carpet_blue.png',
      surface: RoomSurface.floor,
      widthSquares: 5,
      lengthSquares: 4,
      heightSquares: 1,
    );
  }
  if (docId == 'bookcase') {
    return const FurnitureItemMeta(
      assetPath: 'assets/images/furniture/BookCase.png',
      surface: RoomSurface.floor,
      widthSquares: 2,
      lengthSquares: 1,
      heightSquares: 3,
    );
  }
  if (docId == 'candle') {
    return const FurnitureItemMeta(
      assetPath: 'assets/images/furniture/Candle.png',
      surface: RoomSurface.floor,
      widthSquares: 1,
      lengthSquares: 1,
      heightSquares: 1,
    );
  }
  if (docId == 'dog') {
    return const FurnitureItemMeta(
      assetPath: 'assets/images/furniture/Dog.png',
      surface: RoomSurface.floor,
      widthSquares: 2,
      lengthSquares: 1,
      heightSquares: 2,
    );
  }
  if (docId == 'television') {
    return const FurnitureItemMeta(
      assetPath: 'assets/images/furniture/Television.png',
      surface: RoomSurface.floor,
      widthSquares: 3,
      lengthSquares: 1,
      heightSquares: 2,
    );
  }
  if (docId == 'plant') {
    return const FurnitureItemMeta(
      assetPath: 'assets/images/furniture/Plant.png',
      surface: RoomSurface.floor,
      widthSquares: 1,
      lengthSquares: 1,
      heightSquares: 2,
    );
  }
  return const FurnitureItemMeta(
    assetPath: 'assets/images/furniture/sofa_brown.png',
    surface: RoomSurface.floor,
    widthSquares: 3,
    lengthSquares: 2,
    heightSquares: 2,
  );
}
