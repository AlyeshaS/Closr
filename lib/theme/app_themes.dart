// lib/theme/app_themes.dart
import 'package:flutter/material.dart';
import 'closr_colors.dart'; // Import the extension class

class AppThemes {
  // --- DEFAULT PINK & BEIGE THEME ---
  static final ThemeData pinkDefault = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(
      0xFFFDFBF7,
    ), // Warm beige/yellow background
    extensions: <ThemeExtension<dynamic>>[
      const ClosrColors(
        primaryAccent: Color(0xFFFF6B9D), // Signature pink
        gradientStart: Color(0xFFFF8EAF), // Warm highlight pink
        gradientEnd: Color(0xFFFF528F), // Rich deep pink
        surfaceCard: Color(0xCCFFFFFF), // Translucent white for glass effect
        innerHighlight: Color(0x33FFFFFF),
      ),
    ],
  );

  // --- BLUE THEME VARIANT ---
  static final ThemeData blueAlternative = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(
      0xFFF4F7F9,
    ), // Cool ice-blue background
    extensions: <ThemeExtension<dynamic>>[
      const ClosrColors(
        primaryAccent: Color(0xFF3B82F6), // Cool Blue
        gradientStart: Color(0xFF60A5FA),
        gradientEnd: Color(0xFF1D4ED8),
        surfaceCard: Color(0xCCFFFFFF),
        innerHighlight: Color(0x33FFFFFF),
      ),
    ],
  );
}
