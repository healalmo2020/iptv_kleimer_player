import 'package:flutter/material.dart';

class StitchInlineLoader extends StatelessWidget {
  const StitchInlineLoader({super.key, this.height, this.label});

  final double? height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          if (label != null) ...[
            const SizedBox(height: 10),
            Text(
              label!,
              style: const TextStyle(
                color: Color(0xFF9DB3B3),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );

    if (height == null) {
      return content;
    }

    return SizedBox(height: height, child: content);
  }
}

class StitchErrorStrip extends StatelessWidget {
  const StitchErrorStrip({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x26FF4D4D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x59FF4D4D)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFFFC8C8),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class StitchErrorPanel extends StatelessWidget {
  const StitchErrorPanel({
    super.key,
    required this.message,
    this.maxWidth = 520,
    this.padding = const EdgeInsets.all(20),
  });

  final String message;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0x26FF4D4D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x59FF4D4D)),
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFFC7C7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
