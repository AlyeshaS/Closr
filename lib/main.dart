import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'tabs/suggestions/suggestions_screen.dart';
import 'welcome_screen.dart';
import 'main_page.dart';
import 'auth/auth_gate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme_provider.dart';
import 'services/notifications_service.dart';
import 'theme/closr_colors.dart'; // Ensure you import your custom colors file!

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // ── Light Theme (Your Signature Pink, Yellow, & Beige) ────────────────────
  static ThemeData _lightTheme() {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFFC4737F),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFFD4A0AB),
      onSecondary: Color(0xFFFFFFFF),
      surface: Color(0xFFFDF6EE), // Beautiful warm beige/yellow background
      onSurface: Color(0xFF5C4349),
      error: Color(0xFFB94A4A),
      onError: Colors.white,
      primaryContainer: Color(0xFFF5E4E7),
      onPrimaryContainer: Color(0xFF5C2D35),
      secondaryContainer: Color(0xFFFAEDF0),
      onSecondaryContainer: Color(0xFF2A1A1F),
      surfaceContainerHighest: Color(0xFFF7EDE0),
      onSurfaceVariant: Color(0xFF8A6A72),
      outline: Color(0xFFDDB8C0),
      outlineVariant: Color(0xFFF0DCE0),
      scrim: Color(0xFF1A0A0F),
      inverseSurface: Color(0xFF2A1A1F),
      onInverseSurface: Color(0xFFFDF6EE),
      inversePrimary: Color(0xFFD4A0AB),
    );

    return _buildTheme(
      cs,
      customExtensions: <ThemeExtension<dynamic>>[
        const ClosrColors(
          primaryAccent: Color(0xFFC4737F), // Main pink
          gradientStart: Color(0xFFFF8EAF), // Warm pastel pink highlight
          gradientEnd: Color(0xFFC4737F), // Your structural signature pink
          surfaceCard: Color(0xCCFFFFFF), // Translucent white for glassmorphism
          innerHighlight: Color(0x33FFFFFF),
        ),
      ],
    );
  }

  // ── Dark Theme (Moody with Soft Pink Highlights) ───────────────────────────
  static ThemeData _darkTheme() {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFD4949F),
      onPrimary: Color(0xFF1A0A0F),
      secondary: Color(0xFFB87A88),
      onSecondary: Color(0xFFFDF0F2),
      surface: Color(0xFF1C1214), // Midnight plum-charcoal background
      onSurface: Color(0xFFF2E0E4),
      error: Color(0xFFCF6679),
      onError: Color(0xFF1A0A0F),
      primaryContainer: Color(0xFF3D1E25),
      onPrimaryContainer: Color(0xFFEDC5CC),
      secondaryContainer: Color(0xFF2E1519),
      onSecondaryContainer: Color(0xFFF2DCE0),
      surfaceContainerHighest: Color(0xFF271519),
      onSurfaceVariant: Color(0xFFB09098),
      outline: Color(0xFF5C3840),
      outlineVariant: Color(0xFF3A2028),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFF2E0E4),
      onInverseSurface: Color(0xFF1C1214),
      inversePrimary: Color(0xFFC4737F),
    );

    return _buildTheme(
      cs,
      customExtensions: <ThemeExtension<dynamic>>[
        const ClosrColors(
          primaryAccent: Color(0xFFD4949F),
          gradientStart: Color(0xFF3D1E25), // Deeper plum gradient start
          gradientEnd: Color(0xFF1C1214),
          surfaceCard: Color(0xFF231519), // Solid dark surface card
          innerHighlight: Color(0x1AFFFFFF), // Minimal clear border ring
        ),
      ],
    );
  }

  // ── Unified Theme Builder ──────────────────────────────────────────────────
  static ThemeData _buildTheme(
    ColorScheme cs, {
    required List<ThemeExtension<dynamic>> customExtensions,
  }) {
    final isDark = cs.brightness == Brightness.dark;
    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      fontFamily: 'DMSans',
      scaffoldBackgroundColor: cs.surface,
      splashColor: cs.primary.withValues(alpha: 0.16),
      highlightColor: cs.primary.withValues(alpha: 0.08),
      hoverColor: cs.primary.withValues(alpha: 0.06),
      focusColor: cs.primary.withValues(alpha: 0.10),

      // Injecting our custom layout system variables into Flutter's extensions engine
      extensions: customExtensions,

      textTheme: TextTheme(
        displayMedium: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontSize: 32,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
          color: cs.onSurface,
        ),
        titleLarge: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        titleMedium: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: cs.onSurface,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: cs.onSurface,
        ),
        labelSmall: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.08,
          color: cs.onSurfaceVariant,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF231519) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            24,
          ), // Upgraded to smooth 24px modern curves
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary, width: 1.5),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2A1A1F) : const Color(0xFFF7EDE0),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        hintStyle: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 14,
          color: cs.onSurfaceVariant.withOpacity(0.6),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontSize: 26,
          fontWeight: FontWeight.w400,
          color: cs.onSurface,
        ),
        iconTheme: IconThemeData(color: cs.primary),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF1C1214)
            : const Color(0xFFFFFAF5),
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant.withOpacity(0.6),
        selectedLabelStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 10,
          fontWeight: FontWeight.w400,
        ),
        elevation: 0,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 14,
          color: cs.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: cs.primaryContainer,
        selectedColor: cs.primary,
        labelStyle: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: cs.onPrimaryContainer,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),

      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? cs.onPrimary : cs.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? cs.primary
              : cs.outlineVariant,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'Closr',
          debugShowCheckedModeBanner: false,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          themeMode: themeProvider.themeMode,
          home: const AuthGate(),
          routes: {
            '/welcome': (context) => const WelcomeScreen(),
            '/main': (context) => const MainPage(),
            '/suggestions': (context) => SuggestionsScreen(),
          },
        );
      },
    );
  }
}
