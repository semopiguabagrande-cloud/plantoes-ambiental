import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Fundo abstrato em tons de verde com linhas luminosas/neon.
/// Não depende de imagens ou de assets externos.
class NeonGreenBackground extends StatelessWidget {
  const NeonGreenBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(
        painter: _NeonGreenPainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _NeonGreenPainter extends CustomPainter {
  const _NeonGreenPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF00150D),
          Color(0xFF00251A),
          Color(0xFF000D09),
        ],
        stops: [0, 0.52, 1],
      ).createShader(rect);
    canvas.drawRect(rect, background);

    // Grandes halos verdes suaves nos cantos, sem atrapalhar o formulário.
    _glowCircle(canvas, Offset(size.width * 0.10, size.height * 0.24),
        size.shortestSide * 0.42, const Color(0xFF00FF80), 38);
    _glowCircle(canvas, Offset(size.width * 0.94, size.height * 0.10),
        size.shortestSide * 0.32, const Color(0xFF18FFB0), 30);
    _glowCircle(canvas, Offset(size.width * 0.88, size.height * 0.88),
        size.shortestSide * 0.48, const Color(0xFF00D96F), 42);

    // Curvas orgânicas com brilho neon, inclinadas nas bordas.
    final p1 = Path()
      ..moveTo(-size.width * 0.15, size.height * 0.30)
      ..cubicTo(size.width * 0.18, size.height * 0.02,
          size.width * 0.42, size.height * 0.55,
          size.width * 0.70, size.height * 0.21)
      ..cubicTo(size.width * 0.84, size.height * 0.05,
          size.width * 0.91, size.height * 0.03,
          size.width * 1.15, size.height * 0.16);
    _glowPath(canvas, p1, const Color(0xFF00FF88), 2.2, 13);

    final p2 = Path()
      ..moveTo(-size.width * 0.12, size.height * 0.76)
      ..cubicTo(size.width * 0.18, size.height * 0.54,
          size.width * 0.36, size.height * 1.04,
          size.width * 0.60, size.height * 0.79)
      ..cubicTo(size.width * 0.80, size.height * 0.59,
          size.width * 0.94, size.height * 0.62,
          size.width * 1.14, size.height * 0.77);
    _glowPath(canvas, p2, const Color(0xFF39FF9A), 1.8, 11);

    final p3 = Path()
      ..moveTo(size.width * 0.08, -size.height * 0.08)
      ..cubicTo(size.width * 0.31, size.height * 0.16,
          size.width * 0.15, size.height * 0.38,
          size.width * 0.35, size.height * 0.52);
    _glowPath(canvas, p3, const Color(0xFF00CC70), 1.3, 8);

    final p4 = Path()
      ..moveTo(size.width * 0.75, size.height * 1.08)
      ..cubicTo(size.width * 0.64, size.height * 0.84,
          size.width * 0.93, size.height * 0.47,
          size.width * 1.08, size.height * 0.40);
    _glowPath(canvas, p4, const Color(0xFF00FFB3), 1.5, 10);

    // Anéis abertos delicados nas bordas.
    _ring(canvas, Offset(size.width * 0.02, size.height * 0.92),
        size.shortestSide * 0.19, const Color(0xFF00FF88));
    _ring(canvas, Offset(size.width * 0.98, size.height * 0.23),
        size.shortestSide * 0.14, const Color(0xFF43FFAE));

    // Pequenos pontos luminosos discretos nas laterais.
    final dotPaint = Paint()..color = const Color(0xFF9CFFC8).withOpacity(0.55);
    final points = <Offset>[
      Offset(size.width * .08, size.height * .45),
      Offset(size.width * .15, size.height * .50),
      Offset(size.width * .89, size.height * .39),
      Offset(size.width * .94, size.height * .45),
      Offset(size.width * .78, size.height * .91),
      Offset(size.width * .24, size.height * .12),
    ];
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], i.isEven ? 1.7 : 1.1, dotPaint);
    }
  }

  void _glowCircle(Canvas canvas, Offset center, double radius,
      Color color, double blur) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withOpacity(0.08)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = color.withOpacity(0.08),
    );
  }

  void _glowPath(Canvas canvas, Path path, Color color, double width,
      double blur) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width * 5
        ..color = color.withOpacity(0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width
        ..color = color.withOpacity(0.72),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.45, width * 0.22)
        ..color = const Color(0xFFD8FFE9).withOpacity(0.52),
    );
  }

  void _ring(Canvas canvas, Offset center, double radius, Color color) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final path = Path()
      ..addArc(rect, -math.pi * 0.20, math.pi * 1.15);
    _glowPath(canvas, path, color, 1.2, 7);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
