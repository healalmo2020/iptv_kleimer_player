import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class StitchContentCard extends StatefulWidget {
  const StitchContentCard({
    super.key,
    required this.title,
    this.imageUrl,
    required this.onTap,
    this.aspectRatio = 16 / 9,
    this.trailing,
  });

  final String title;
  final String? imageUrl;
  final VoidCallback onTap;
  final double aspectRatio;
  final Widget? trailing;

  @override
  State<StitchContentCard> createState() => _StitchContentCardState();
}

class _StitchContentCardState extends State<StitchContentCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      mouseCursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: _focused
          ? (Matrix4.identity()..scaleByDouble(1.1, 1.1, 1.0, 1.0))
          : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: _focused ? Border.all(color: const Color(0xFF40C4FF), width: 3) : null,
          boxShadow: _focused
              ? const [
                  BoxShadow(
                    color: Color(0x8040C4FF),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: widget.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) {
                        return Shimmer.fromColors(
                          baseColor: const Color(0xFF162544),
                          highlightColor: const Color(0xFF2A3E68),
                          child: const ColoredBox(color: Color(0xFF162544)),
                        );
                      },
                      errorWidget: (_, _, _) => const ColoredBox(color: Color(0xFF162544)),
                    )
                  else
                    const ColoredBox(color: Color(0xFF162544)),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      width: double.infinity,
                      color: Colors.black54,
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.trailing != null) widget.trailing!,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
