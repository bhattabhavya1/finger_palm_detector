// lib/presentation/widgets/camera_overlays.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../core/constants/app_colors.dart';

/// Rectangular palm overlay with corner brackets
class PalmOverlay extends StatelessWidget {
  final bool isActive;
  final bool isError;
  final String? statusText;

  const PalmOverlay({
    super.key,
    this.isActive = false,
    this.isError = false,
    this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final overlayW = size.width * 0.80;
    final overlayH = size.height * 0.45;

    return Stack(
      children: [
        // Dark blurred surround
        CustomPaint(
          size: Size(size.width, size.height),
          painter: _HolePainter(
            holeRect: Rect.fromCenter(
              center: Offset(size.width / 2, size.height * 0.45),
              width: overlayW,
              height: overlayH,
            ),
          ),
        ),
        // Center frame
        Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: size.height * 0.05),
            child: SizedBox(
              width: overlayW,
              height: overlayH,
              child: CustomPaint(
                painter: _CornerBracketPainter(
                  color: isError
                      ? AppColors.overlayBorderError
                      : isActive
                          ? AppColors.overlayBorderActive
                          : AppColors.overlayBorder,
                ),
              ),
            ),
          ),
        ),
        // Status text overlay inside frame
        if (statusText != null)
          Positioned(
            bottom: size.height * 0.30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Oval finger overlay with blurred background
class FingerOvalOverlay extends StatelessWidget {
  final bool isActive;
  final bool isError;
  final String? statusText;

  const FingerOvalOverlay({
    super.key,
    this.isActive = false,
    this.isError = false,
    this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final ovalW = size.width * 0.50;
    final ovalH = size.height * 0.60;

    return Stack(
      children: [
        // Blurred background outside oval
        ClipPath(
          clipper: _OvalHoleClipper(
            ovalRect: Rect.fromCenter(
              center: Offset(size.width / 2, size.height * 0.42),
              width: ovalW,
              height: ovalH,
            ),
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: Colors.black.withOpacity(0.45)),
          ),
        ),
        // Oval border
        Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: size.height * 0.10),
            child: SizedBox(
              width: ovalW,
              height: ovalH,
              child: CustomPaint(
                painter: _OvalBorderPainter(
                  color: isError
                      ? AppColors.overlayBorderError
                      : isActive
                          ? AppColors.overlayBorderActive
                          : AppColors.overlayBorder,
                ),
              ),
            ),
          ),
        ),
        // Status text
        if (statusText != null)
          Positioned(
            bottom: size.height * 0.22,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Painters ──────────────────────────────────────────────────────────────

class _HolePainter extends CustomPainter {
  final Rect holeRect;

  _HolePainter({required this.holeRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRect(holeRect);
    final combined = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(combined, paint);
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.holeRect != holeRect;
}

class _CornerBracketPainter extends CustomPainter {
  final Color color;

  _CornerBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r = 12.0;

    void drawCorner(double x, double y, bool flipX, bool flipY) {
      final dx = flipX ? -1 : 1;
      final dy = flipY ? -1 : 1;
      final path = Path()
        ..moveTo(x, y + dy * (r + len))
        ..lineTo(x, y + dy * r)
        ..arcToPoint(
          Offset(x + dx * r, y),
          radius: const Radius.circular(r),
          clockwise: flipX == flipY,
        )
        ..lineTo(x + dx * (r + len), y);
      canvas.drawPath(path, paint);
    }

    drawCorner(0, 0, false, false);
    drawCorner(size.width, 0, true, false);
    drawCorner(0, size.height, false, true);
    drawCorner(size.width, size.height, true, true);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter old) => old.color != color;
}

class _OvalBorderPainter extends CustomPainter {
  final Color color;

  _OvalBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawOval(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_OvalBorderPainter old) => old.color != color;
}

class _OvalHoleClipper extends CustomClipper<Path> {
  final Rect ovalRect;

  _OvalHoleClipper({required this.ovalRect});

  @override
  Path getClip(Size size) {
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final oval = Path()..addOval(ovalRect);
    return Path.combine(PathOperation.difference, full, oval);
  }

  @override
  bool shouldReclip(_OvalHoleClipper old) => old.ovalRect != ovalRect;
}
