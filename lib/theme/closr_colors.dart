// lib/theme/closr_colors.dart
import 'package:flutter/material.dart';

@immutable
class ClosrColors extends ThemeExtension<ClosrColors> {
  final Color? primaryAccent;
  final Color? gradientStart;
  final Color? gradientEnd;
  final Color? surfaceCard;
  final Color? innerHighlight;

  const ClosrColors({
    required this.primaryAccent,
    required this.gradientStart,
    required this.gradientEnd,
    required this.surfaceCard,
    required this.innerHighlight,
  });

  @override
  ClosrColors copyWith({
    Color? primaryAccent,
    Color? gradientStart,
    Color? gradientEnd,
    Color? surfaceCard,
    Color? innerHighlight,
  }) {
    return ClosrColors(
      primaryAccent: primaryAccent ?? this.primaryAccent,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      innerHighlight: innerHighlight ?? this.innerHighlight,
    );
  }

  @override
  ClosrColors lerp(ThemeExtension<ClosrColors>? other, double t) {
    if (other is! ClosrColors) return this;
    return ClosrColors(
      primaryAccent: Color.lerp(primaryAccent, other.primaryAccent, t),
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t),
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t),
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t),
      innerHighlight: Color.lerp(innerHighlight, other.innerHighlight, t),
    );
  }
}
