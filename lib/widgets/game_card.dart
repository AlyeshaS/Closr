// lib/widgets/game_card.dart
import 'package:flutter/material.dart';
import '../theme/closr_colors.dart'; // Import to use the extension properties

Widget buildGameCard(BuildContext context, String title, IconData icon) {
  // Grab the active colors instantly based on whichever theme is active
  final closrColors = Theme.of(context).extension<ClosrColors>()!;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: closrColors.surfaceCard,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [closrColors.gradientStart!, closrColors.gradientEnd!],
          ).createShader(bounds),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ],
    ),
  );
}
