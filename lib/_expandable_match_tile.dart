// lib/_expandable_match_tile.dart
import 'package:flutter/material.dart';

class ExpandableMatchTile extends StatefulWidget {
  final String title;
  final String description;

  const ExpandableMatchTile({
    required this.title,
    required this.description,
    super.key,
  });

  @override
  State<ExpandableMatchTile> createState() => _ExpandableMatchTileState();
}

class _ExpandableMatchTileState extends State<ExpandableMatchTile> {
  bool _expanded = false;
  double _scale = 1.0;

  void _set(double v) => setState(() => _scale = v);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _set(0.98),
      onTapUp: (_) => _set(1.0),
      onTapCancel: () => _set(1.0),
      onTap: () {
        setState(() {
          _expanded = !_expanded;
        });
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            // Added explicit thin primary pink border accent outline line
            border: Border.all(color: cs.primary.withOpacity(0.35), width: 1),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: cs.onSurface,
                              ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: !_expanded && widget.description.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    widget.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontFamily: 'CormorantGaramond',
                                          fontStyle: FontStyle.italic,
                                          color: cs.onSurfaceVariant
                                              .withOpacity(0.85),
                                          fontSize: 14,
                                        ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _expanded && widget.description.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(52, 10, 4, 2),
                        child: Text(
                          widget.description,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontFamily: 'CormorantGaramond',
                                fontStyle: FontStyle.italic,
                                color: cs.onSurface.withOpacity(0.9),
                                fontSize: 15,
                                height: 1.45,
                              ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
