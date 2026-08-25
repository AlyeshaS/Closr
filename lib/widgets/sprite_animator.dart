// lib/widgets/sprite_animator.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class SpriteAnimator extends StatefulWidget {
  final String imagePath;
  final int totalFrames;
  final double displayWidth;
  final double displayHeight;
  final Duration duration;

  const SpriteAnimator({
    super.key,
    required this.imagePath,
    required this.totalFrames,
    required this.displayWidth,
    required this.displayHeight,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  State<SpriteAnimator> createState() => _SpriteAnimatorState();
}

class _SpriteAnimatorState extends State<SpriteAnimator>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    final frameDuration = widget.duration.inMilliseconds / widget.totalFrames;

    _ticker = createTicker((elapsed) {
      final frameIndex =
          (elapsed.inMilliseconds ~/ frameDuration) % widget.totalFrames;
      if (frameIndex != _currentIndex) {
        if (mounted) {
          setState(() {
            _currentIndex = frameIndex;
          });
        }
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.displayWidth,
      height: widget.displayHeight,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: Offset(-(_currentIndex * widget.displayWidth), 0),
            child: Image.asset(
              widget.imagePath,
              fit: BoxFit.none,
              alignment: Alignment.topLeft,
              filterQuality: FilterQuality.none,
            ),
          ),
        ),
      ),
    );
  }
}
