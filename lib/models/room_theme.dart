import 'package:flutter/material.dart';

class RoomTheme {
  final String name;
  final Color leftTop;
  final Color leftBottom;
  final Color rightTop;
  final Color rightBottom;
  final Color floorTop;
  final Color floorBottom;
  final Color baseboardLight;
  final Color baseboardDark;
  final Color seam;

  const RoomTheme({
    required this.name,
    required this.leftTop,
    required this.leftBottom,
    required this.rightTop,
    required this.rightBottom,
    required this.floorTop,
    required this.floorBottom,
    required this.baseboardLight,
    required this.baseboardDark,
    required this.seam,
  });
}

const Map<String, RoomTheme> kRoomThemes = {
  'room_pink': RoomTheme(
    name: 'Rose Room',
    leftTop: Color(0xFFCD9186),
    leftBottom: Color(0xFFCC9086),
    rightTop: Color(0xFFB87569),
    rightBottom: Color(0xFFB8766A),
    floorTop: Color(0xFFA8685C),
    floorBottom: Color(0xFFA7665A),
    baseboardLight: Color(0xFFD99B90),
    baseboardDark: Color(0xFFB87569),
    seam: Color(0xFF8E554C),
  ),
  'room_beige': RoomTheme(
    name: 'Sand Room',
    leftTop: Color(0xFFB99E75),
    leftBottom: Color(0xFFB59B72),
    rightTop: Color(0xFF917B58),
    rightBottom: Color(0xFF927D5A),
    floorTop: Color(0xFFB69A7D),
    floorBottom: Color(0xFFB29679),
    baseboardLight: Color(0xFFBCA57C),
    baseboardDark: Color(0xFF8F7957),
    seam: Color(0xFF69583F),
  ),
  'room_blue': RoomTheme(
    name: 'Sky Room',
    leftTop: Color(0xFF9FC5D8),
    leftBottom: Color(0xFF8EB6CC),
    rightTop: Color(0xFF789EB8),
    rightBottom: Color(0xFF6B91AA),
    floorTop: Color(0xFF7099AA),
    floorBottom: Color(0xFF628A9B),
    baseboardLight: Color(0xFFB8D7E4),
    baseboardDark: Color(0xFF6C92A8),
    seam: Color(0xFF4F7183),
  ),
  'room_green': RoomTheme(
    name: 'Fern Room',
    leftTop: Color(0xFFA9C9B1),
    leftBottom: Color(0xFF97BDA1),
    rightTop: Color(0xFF789F87),
    rightBottom: Color(0xFF6B9279),
    floorTop: Color(0xFF70977B),
    floorBottom: Color(0xFF62886E),
    baseboardLight: Color(0xFFC4DEC7),
    baseboardDark: Color(0xFF6C9277),
    seam: Color(0xFF4E7058),
  ),
  'room_lavender': RoomTheme(
    name: 'Lavender Room',
    leftTop: Color(0xFFC3B8D6),
    leftBottom: Color(0xFFB1A5C8),
    rightTop: Color(0xFF9688B0),
    rightBottom: Color(0xFF887AA4),
    floorTop: Color(0xFF8D7FA0),
    floorBottom: Color(0xFF7D708F),
    baseboardLight: Color(0xFFD9D0E6),
    baseboardDark: Color(0xFF897BA2),
    seam: Color(0xFF665777),
  ),
};
