import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class StitchContentCard extends StatefulWidget {
  const StitchContentCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.fallbackImageUrl,
    this.imageCacheWidth,
    this.imageCacheHeight,
    this.imageFit = BoxFit.cover,
    this.useShimmerPlaceholder = true,
    required this.onTap,
    this.aspectRatio = 16 / 9,
    this.trailing,
  });

  final String title;
  final String? imageUrl;
  final String? fallbackImageUrl;
  final int? imageCacheWidth;
  final int? imageCacheHeight;
  final BoxFit imageFit;
  final bool useShimmerPlaceholder;
  final VoidCallback onTap;
  final double aspectRatio;
  final Widget? trailing;

  @override
  State<StitchContentCard> createState() => _StitchContentCardState();
}

class _StitchContentCardState extends State<StitchContentCard> {
  bool _focused = false;
  bool _usingFallbackImage = false;

  @override
  void didUpdateWidget(covariant StitchContentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.fallbackImageUrl != widget.fallbackImageUrl) {
      _usingFallbackImage = false;
    }
  }

  Widget _buildMissingImagePlaceholder(BuildContext context) {
    final isPosterAspect = widget.aspectRatio <= (3 / 4);
    final icon = isPosterAspect
        ? Icons.movie_creation_outlined
        : Icons.live_tv_rounded;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1A35), Color(0xFF152A56), Color(0xFF0A141F)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x330DF2F2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x550DF2F2)),
              ),
              child: const Text(
                'NO ARTWORK',
                style: TextStyle(
                  color: Color(0xFFD6F6F6),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: isPosterAspect ? 62 : 54,
              height: isPosterAspect ? 62 : 54,
              decoration: BoxDecoration(
                color: const Color(0x220DF2F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x440DF2F2)),
              ),
              child: Icon(icon, color: const Color(0xFFD9F9F9), size: 30),
            ),
          ),
        ],
      ),
    );
  }

  String? get _resolvedImageUrl {
    final primary = widget.imageUrl?.trim();
    final fallback = widget.fallbackImageUrl?.trim();
    if (!_usingFallbackImage && primary != null && primary.isNotEmpty) {
      return primary;
    }
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    return primary;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolvedImageUrl;
    final fallbackUrl = widget.fallbackImageUrl?.trim();
    final defaultWidth = widget.aspectRatio == 2 / 3 ? 420 : 520;
    final defaultHeight = widget.aspectRatio == 2 / 3 ? 630 : 292;
    final cacheWidth = widget.imageCacheWidth ?? defaultWidth;
    final cacheHeight = widget.imageCacheHeight ?? defaultHeight;

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
          border: _focused
              ? Border.all(color: const Color(0xFF40C4FF), width: 3)
              : null,
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
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: widget.imageFit,
                      filterQuality: FilterQuality.low,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholderFadeInDuration: Duration.zero,
                      memCacheWidth: cacheWidth,
                      memCacheHeight: cacheHeight,
                      maxWidthDiskCache: cacheWidth,
                      maxHeightDiskCache: cacheHeight,
                      placeholder: (context, url) {
                        if (!widget.useShimmerPlaceholder) {
                          return _buildMissingImagePlaceholder(context);
                        }
                        return Shimmer.fromColors(
                          baseColor: const Color(0xFF162544),
                          highlightColor: const Color(0xFF2A3E68),
                          child: const ColoredBox(color: Color(0xFF162544)),
                        );
                      },
                      errorWidget: (context, error, stackTrace) {
                        final canUseFallback =
                            !_usingFallbackImage &&
                            fallbackUrl != null &&
                            fallbackUrl.isNotEmpty &&
                            fallbackUrl != imageUrl;

                        if (canUseFallback) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _usingFallbackImage = true;
                            });
                          });

                          return Shimmer.fromColors(
                            baseColor: const Color(0xFF162544),
                            highlightColor: const Color(0xFF2A3E68),
                            child: const ColoredBox(color: Color(0xFF162544)),
                          );
                        }

                        return _buildMissingImagePlaceholder(context);
                      },
                    )
                  else
                    _buildMissingImagePlaceholder(context),
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
