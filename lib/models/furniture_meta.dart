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
  'book_1': 'assets/images/furniture/book_1.png',
  'book_2': 'assets/images/furniture/book_2.png',
  'book_3': 'assets/images/furniture/book_3.png',
  'book_4': 'assets/images/furniture/book_4.png',
  'book_5': 'assets/images/furniture/book_5.png',
  'book_6': 'assets/images/furniture/book_6.png',
  'book_7': 'assets/images/furniture/book_7.png',
  'book_8': 'assets/images/furniture/book_8.png',
  'candle': 'assets/images/furniture/Candle.png',
  'chair_beige': 'assets/images/furniture/chair_beige.png',
  'chair_black': 'assets/images/furniture/chair_black.png',
  'chair_blue': 'assets/images/furniture/chair_blue.png',
  'chair_brown': 'assets/images/furniture/chair_brown.png',
  'chair_green': 'assets/images/furniture/chair_green.png',
  'chair_purple': 'assets/images/furniture/chair_purple.png',
  'chair_red': 'assets/images/furniture/chair_red.png',
  'chair_white': 'assets/images/furniture/chair_white.png',
  'clock_black': 'assets/images/furniture/clock_black.png',
  'clock_blue': 'assets/images/furniture/clock_blue.png',
  'clock_brown': 'assets/images/furniture/clock_brown.png',
  'clock_red': 'assets/images/furniture/clock_red.png',
  'coffeecup_black': 'assets/images/furniture/coffeecup_black.png',
  'coffeecup_brown': 'assets/images/furniture/coffeecup_brown.png',
  'coffeecup_green': 'assets/images/furniture/coffeecup_green.png',
  'coffeecup_grey': 'assets/images/furniture/coffeecup_grey.png',
  'decorative_lamp': 'assets/images/furniture/DecorativeLamp.png',
  'decorative_light': 'assets/images/furniture/DecorativeLight.png',
  'drawers_beige_L': 'assets/images/furniture/drawers_beige_L.png',
  'drawers_beige_M': 'assets/images/furniture/drawers_beige_M.png',
  'drawers_beige_S': 'assets/images/furniture/drawers_beige_S.png',
  'drawers_beige_XL': 'assets/images/furniture/drawers_beige_XL.png',
  'drawers_black_L': 'assets/images/furniture/drawers_black_L.png',
  'drawers_black_M': 'assets/images/furniture/drawers_black_M.png',
  'drawers_black_S': 'assets/images/furniture/drawers_black_S.png',
  'drawers_black_XL': 'assets/images/furniture/drawers_black_XL.png',
  'drawers_brown_L': 'assets/images/furniture/drawers_brown_L.png',
  'drawers_brown_M': 'assets/images/furniture/drawers_brown_M.png',
  'drawers_brown_S': 'assets/images/furniture/drawers_brown_S.png',
  'drawers_brown_XL': 'assets/images/furniture/drawers_brown_XL.png',
  'drawers_green_L': 'assets/images/furniture/drawers_green_L.png',
  'drawers_green_M': 'assets/images/furniture/drawers_green_M.png',
  'drawers_green_S': 'assets/images/furniture/drawers_green_S.png',
  'drawers_green_XL': 'assets/images/furniture/drawers_green_XL.png',
  'drawers_purple_L': 'assets/images/furniture/drawers_purple_L.png',
  'drawers_purple_M': 'assets/images/furniture/drawers_purple_M.png',
  'drawers_purple_S': 'assets/images/furniture/drawers_purple_S.png',
  'drawers_purple_XL': 'assets/images/furniture/drawers_purple_XL.png',
  'drawers_white_L': 'assets/images/furniture/drawers_white_L.png',
  'drawers_white_M': 'assets/images/furniture/drawers_white_M.png',
  'drawers_white_S': 'assets/images/furniture/drawers_white_S.png',
  'drawers_white_XL': 'assets/images/furniture/drawers_white_XL.png',
  'television': 'assets/images/furniture/Television.png',
  'plant': 'assets/images/furniture/Plant.png',
  'lamp_1': 'assets/images/furniture/lamp_1.png',
  'lamp_2': 'assets/images/furniture/lamp_2.png',
  'lamp_3': 'assets/images/furniture/lamp_3.png',
  'laptop_1': 'assets/images/furniture/laptop_1.png',
  'laptop_2': 'assets/images/furniture/laptop_2.png',
  'littleframes_1': 'assets/images/furniture/littleframes_1.png',
  'littleframes_2': 'assets/images/furniture/littleframes_2.png',
  'littleframes_3': 'assets/images/furniture/littleframes_3.png',
  'littleframes_4': 'assets/images/furniture/littleframes_4.png',
  'littletable_brown': 'assets/images/furniture/littletable_brown.png',
  'littletable_darkgrey': 'assets/images/furniture/littletable_darkgrey.png',
  'littletable_green': 'assets/images/furniture/littletable_green.png',
  'littletable_grey': 'assets/images/furniture/littletable_grey.png',
  'littletable_pink': 'assets/images/furniture/littletable_pink.png',
  'littletable_white': 'assets/images/furniture/littletable_white.png',
  'littlewallpainting_1': 'assets/images/furniture/littlewallpainting_1.png',
  'littlewallpainting_2': 'assets/images/furniture/littlewallpainting_2.png',
  'littlewallpainting_3': 'assets/images/furniture/littlewallpainting_3.png',
  'littlewallpainting_4': 'assets/images/furniture/littlewallpainting_4.png',
  'littlewallpainting_5': 'assets/images/furniture/littlewallpainting_5.png',
  'littlewallpainting_6': 'assets/images/furniture/littlewallpainting_6.png',
  'littlewallpainting_7': 'assets/images/furniture/littlewallpainting_7.png',
  'littlewallpainting_8': 'assets/images/furniture/littlewallpainting_8.png',
  'littlewallpainting_9': 'assets/images/furniture/littlewallpainting_9.png',
  'plant_1': 'assets/images/furniture/plant_1.png',
  'plant_2': 'assets/images/furniture/plant_2.png',
  'plant_3': 'assets/images/furniture/plant_3.png',
  'plant_4': 'assets/images/furniture/plant_4.png',
  'plant_5': 'assets/images/furniture/plant_5.png',
  'plant_6': 'assets/images/furniture/plant_6.png',
  'plant_7': 'assets/images/furniture/plant_7.png',
  'plant_8': 'assets/images/furniture/plant_8.png',
  'table_beige': 'assets/images/furniture/table_beige.png',
  'table_darkgrey': 'assets/images/furniture/table_darkgrey.png',
  'table_grey': 'assets/images/furniture/table_grey.png',
  'table_pink': 'assets/images/furniture/table_pink.png',
  'teddybear_black': 'assets/images/furniture/teddybear_black.png',
  'teddybear_brown': 'assets/images/furniture/teddybear_brown.png',
  'teddybear_lightbrown': 'assets/images/furniture/teddybear_lightbrown.png',
  'teddybear_white1': 'assets/images/furniture/teddybear_white1.png',
  'teddybear_white2': 'assets/images/furniture/teddybear_white2.png',
  'wallpainting_1': 'assets/images/furniture/wallpainting_1.png',
  'wallpainting_2': 'assets/images/furniture/wallpainting_2.png',
  'wallpainting_3': 'assets/images/furniture/wallpainting_3.png',
  'wallpainting_4': 'assets/images/furniture/wallpainting_4.png',
  'window_blue': 'assets/images/furniture/window_blue.png',
  'window_pink': 'assets/images/furniture/window_pink.png',
  'window_red': 'assets/images/furniture/window_red.png',
  'window_white': 'assets/images/furniture/window_white.png',
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
  if (kDecorAssets.containsKey(docId)) {
    return FurnitureItemMeta(
      assetPath: kDecorAssets[docId]!,
      surface: RoomSurface.floor,
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
