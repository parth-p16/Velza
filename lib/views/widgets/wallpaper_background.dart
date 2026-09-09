import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:velza/services/wallpaper_service.dart';

class WallpaperBackgroundWidget extends StatelessWidget {
  final WallpaperModel wallpaper;
  final Widget child;

  const WallpaperBackgroundWidget({
    super.key,
    required this.wallpaper,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (wallpaper.type == WallpaperType.remoteUrl &&
        wallpaper.remoteUrl != null &&
        wallpaper.remoteUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: wallpaper.remoteUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: const Color(0xFF0E0B16),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: const Color(0xFF0E0B16),
              child: const Center(
                child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 40),
              ),
            ),
          ),
          // Semi-transparent overlay to ensure contrast & message readability
          Container(color: Colors.black.withValues(alpha: 0.35)),
          child,
        ],
      );
    }

    if (wallpaper.type == WallpaperType.localImage && wallpaper.localPath != null) {
      final file = File(wallpaper.localPath!);
      if (file.existsSync()) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              file,
              fit: BoxFit.cover,
            ),
            // Semi-transparent overlay to ensure contrast & message readability
            Container(color: Colors.black.withValues(alpha: 0.40)),
            child,
          ],
        );
      }
    }

    // Built-in presets
    final colors = wallpaper.gradientColors ?? const [Color(0xFF0E0B16), Color(0xFF1E162B)];
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        ),
        CustomPaint(
          painter: _WallpaperPatternPainter(pattern: wallpaper.patternType ?? 'default'),
        ),
        child,
      ],
    );
  }
}

class _WallpaperPatternPainter extends CustomPainter {
  final String pattern;
  _WallpaperPatternPainter({required this.pattern});

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern == 'stars') {
      final starPaint = Paint()..color = const Color(0xFFD4AF37).withValues(alpha: 0.25);
      final glowPaint = Paint()..color = const Color(0xFF8E24AA).withValues(alpha: 0.15);

      // Draw subtle scattered stars
      final offsets = [
        Offset(size.width * 0.15, size.height * 0.1),
        Offset(size.width * 0.85, size.height * 0.18),
        Offset(size.width * 0.45, size.height * 0.3),
        Offset(size.width * 0.2, size.height * 0.5),
        Offset(size.width * 0.75, size.height * 0.65),
        Offset(size.width * 0.35, size.height * 0.82),
        Offset(size.width * 0.9, size.height * 0.9),
      ];

      for (var offset in offsets) {
        canvas.drawCircle(offset, 4.0, glowPaint);
        canvas.drawCircle(offset, 1.5, starPaint);
      }
    } else if (pattern == 'geometry') {
      final linePaint = Paint()
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.04)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      const double step = 60.0;
      for (double x = -size.height; x < size.width + size.height; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), linePaint);
        canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), linePaint);
      }
    } else if (pattern == 'nebula') {
      final nebulaPaint = Paint()
        ..color = const Color(0xFF9C27B0).withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

      canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.3), 120, nebulaPaint);
      canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.7), 140, nebulaPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WallpaperPatternPainter oldDelegate) =>
      oldDelegate.pattern != pattern;
}
