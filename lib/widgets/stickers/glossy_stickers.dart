import 'dart:math' as m;

import 'package:flutter/material.dart';

/// Glossy "puffy gel" animated stickers, drawn natively with [CustomPaint]
/// (no image assets, no extra deps). Each sticker has a thick white die-cut
/// outline + soft drop shadow (so it reads as a raised object), a glossy
/// highlight, and a looping animation. Design space is 300×300, scaled to the
/// requested [GlossyStickerView.size].
enum GlossySticker {
  heart,
  smile,
  loveEyes,
  boba,
  bear,
  camera,
  star,
  like,
  fire,
  party,
  haha,
  flower,
  moon,
  hearts,
}

class GlossyStickerView extends StatefulWidget {
  const GlossyStickerView(this.sticker, {super.key, this.size = 120});

  final GlossySticker sticker;
  final double size;

  @override
  State<GlossyStickerView> createState() => _GlossyStickerViewState();
}

class _GlossyStickerViewState extends State<GlossyStickerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect reduced-motion: hold a pleasant static frame instead of looping.
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
      return CustomPaint(
        size: Size.square(widget.size),
        painter: _StickerPainter(widget.sticker, 0.22),
      );
    }
    if (!_c.isAnimating) _c.repeat();
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _StickerPainter(widget.sticker, _c.value),
        ),
      ),
    );
  }
}

/// Label (VI) for each sticker — handy for a picker grid.
String glossyStickerLabel(GlossySticker s) => switch (s) {
  GlossySticker.heart => 'Tim',
  GlossySticker.smile => 'Cười',
  GlossySticker.loveEyes => 'Mê',
  GlossySticker.boba => 'Trà sữa',
  GlossySticker.bear => 'Gấu',
  GlossySticker.camera => 'Máy ảnh',
  GlossySticker.star => 'Ngôi sao',
  GlossySticker.like => 'Like',
  GlossySticker.fire => 'Lửa',
  GlossySticker.party => 'Party',
  GlossySticker.haha => 'Haha',
  GlossySticker.flower => 'Hoa',
  GlossySticker.moon => 'Trăng',
  GlossySticker.hearts => 'Tim đôi',
};

// ---------------------------------------------------------------------------

const _ink = Color(0xFF3A2B22);
const _blush = Color(0xFFFF7D9A);

class _StickerPainter extends CustomPainter {
  _StickerPainter(this.s, this.t);

  final GlossySticker s;

  /// Loop phase 0..1 over 2s.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 300.0);
    switch (s) {
      case GlossySticker.heart:
        _heart(canvas);
      case GlossySticker.smile:
        _face(canvas, _FaceKind.smile);
      case GlossySticker.loveEyes:
        _face(canvas, _FaceKind.love);
      case GlossySticker.star:
        _star(canvas);
      case GlossySticker.fire:
        _fire(canvas);
      case GlossySticker.camera:
        _camera(canvas);
      case GlossySticker.moon:
        _moon(canvas);
      case GlossySticker.hearts:
        _hearts(canvas);
      case GlossySticker.boba:
        _boba(canvas);
      case GlossySticker.bear:
        _bear(canvas);
      case GlossySticker.like:
        _like(canvas);
      case GlossySticker.party:
        _party(canvas);
      case GlossySticker.haha:
        _haha(canvas);
      case GlossySticker.flower:
        _flower(canvas);
    }
  }

  @override
  bool shouldRepaint(_StickerPainter o) => o.t != t || o.s != s;

  // ---- shared paint helpers ----

  Paint _radial(
    Rect r,
    List<Color> colors,
    List<double> stops, {
    Alignment center = const Alignment(-0.32, -0.46),
    double radius = 0.9,
  }) => Paint()
    ..shader = RadialGradient(
      center: center,
      radius: radius,
      colors: colors,
      stops: stops,
    ).createShader(r);

  /// White die-cut outline + soft drop shadow around a silhouette path.
  void _dieCut(Canvas c, Path body) {
    c.drawPath(
      body.shift(const Offset(0, 11)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    c.drawPath(
      body,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    c.drawPath(body, Paint()..color = Colors.white);
  }

  void _gloss(Canvas c, double cx, double cy, double rx, double ry) {
    final r = Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);
    c.drawOval(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE6FFFFFF), Color(0x00FFFFFF)],
        ).createShader(r),
    );
  }

  void _shine(Canvas c, double cx, double cy, double r) =>
      c.drawCircle(Offset(cx, cy), r, Paint()..color = const Color(0xE6FFFFFF));

  Path _heartPath(double cx, double cy, double s) {
    Offset p(double x, double y) => Offset(cx + x * s, cy + y * s);
    final path = Path()..moveTo(p(0, -22).dx, p(0, -22).dy);
    void cub(double x1, double y1, double x2, double y2, double x, double y) =>
        path.cubicTo(p(x1, y1).dx, p(x1, y1).dy, p(x2, y2).dx, p(x2, y2).dy,
            p(x, y).dx, p(x, y).dy);
    cub(-16, -44, -52, -34, -52, -6);
    cub(-52, 20, -14, 40, 0, 54);
    cub(14, 40, 52, 20, 52, -6);
    cub(52, -34, 16, -44, 0, -22);
    return path..close();
  }

  void _drawHeart(Canvas c, double cx, double cy, double s,
      {List<Color>? colors}) {
    final path = _heartPath(cx, cy, s);
    final b = path.getBounds();
    final cols = colors ??
        const [Color(0xFFFFC0D4), Color(0xFFFF6D94), Color(0xFFE83E6B)];
    // Stops must match the number of colors (2 → [0,1], 3 → [0,.55,1]).
    final stops = cols.length == 2 ? const [0.0, 1.0] : const [0.0, 0.55, 1.0];
    c.drawPath(path, _radial(b, cols, stops));
  }

  void _eyes(Canvas c, double y, {double dx = 0}) {
    final p = Paint()..color = _ink;
    c.drawOval(Rect.fromCenter(center: Offset(124 + dx, y), width: 26, height: 32), p);
    c.drawOval(Rect.fromCenter(center: Offset(176 + dx, y), width: 26, height: 32), p);
    final w = Paint()..color = Colors.white;
    c.drawCircle(Offset(129 + dx, y - 5), 4.5, w);
    c.drawCircle(Offset(181 + dx, y - 5), 4.5, w);
  }

  void _blushMarks(Canvas c) {
    final p = Paint()..color = _blush.withValues(alpha: 0.5);
    c.drawOval(Rect.fromCenter(center: const Offset(100, 176), width: 28, height: 16), p);
    c.drawOval(Rect.fromCenter(center: const Offset(200, 176), width: 28, height: 16), p);
  }

  void _withScale(Canvas c, Offset pivot, double sx, double sy, VoidCallback body) {
    c.save();
    c.translate(pivot.dx, pivot.dy);
    c.scale(sx, sy);
    c.translate(-pivot.dx, -pivot.dy);
    body();
    c.restore();
  }

  // ---- stickers ----

  void _heart(Canvas c) {
    final beat = 1 + 0.10 * m.sin(t * 2 * m.pi * 2); // ~2 beats/loop
    _withScale(c, const Offset(150, 150), beat, beat, () {
      final body = _heartPath(150, 150, 1.5);
      _dieCut(c, body);
      _drawHeart(c, 150, 150, 1.5);
      _gloss(c, 120, 110, 34, 22);
      _shine(c, 118, 120, 7);
    });
  }

  void _face(Canvas c, _FaceKind kind) {
    final bounce = kind == _FaceKind.smile ? -8 * m.sin(t * 2 * m.pi).abs() : 0.0;
    c.save();
    c.translate(0, bounce);
    final body = Path()
      ..addOval(Rect.fromCircle(center: const Offset(150, 156), radius: 96));
    _dieCut(c, body);
    c.drawOval(
      Rect.fromCircle(center: const Offset(150, 156), radius: 96),
      _radial(
        Rect.fromCircle(center: const Offset(150, 156), radius: 96),
        const [Color(0xFFFFEEB0), Color(0xFFFFCF4D), Color(0xFFF3A51E)],
        const [0, 0.55, 1],
      ),
    );
    _gloss(c, 118, 112, 46, 28);
    _blushMarks(c);
    if (kind == _FaceKind.smile) {
      _eyes(c, 150);
      final mouth = Path()
        ..moveTo(118, 182)
        ..quadraticBezierTo(150, 212, 182, 182);
      c.drawPath(
        mouth,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final hb = 1 + 0.12 * m.sin(t * 2 * m.pi * 2); // heart-eyes beat
      _withScale(c, const Offset(124, 150), hb, hb,
          () => _drawHeart(c, 124, 150, 0.55, colors: const [Color(0xFFFF8FB0), Color(0xFFF42A5C)]));
      _withScale(c, const Offset(176, 150), hb, hb,
          () => _drawHeart(c, 176, 150, 0.55, colors: const [Color(0xFFFF8FB0), Color(0xFFF42A5C)]));
      final mouth = Path()
        ..moveTo(126, 192)
        ..quadraticBezierTo(150, 210, 174, 192);
      c.drawPath(
        mouth,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    }
    _shine(c, 112, 118, 8);
    c.restore();

    if (kind == _FaceKind.love) {
      _risingHeart(c, 208, 110, phase: 0);
    }
  }

  void _risingHeart(Canvas c, double x, double y0, {double phase = 0}) {
    final p = (t + phase) % 1.0;
    final y = y0 - 28 * p;
    final op = p < 0.25 ? p / 0.25 : (1 - (p - 0.25) / 0.75);
    c.save();
    c.translate(x, y);
    final s = 0.5 * (0.7 + 0.3 * p);
    c.scale(s, s);
    c.drawPath(
      _heartPath(0, 0, 1).shift(Offset.zero),
      Paint()..color = const Color(0xFFFF6D94).withValues(alpha: op.clamp(0, 1)),
    );
    c.restore();
  }

  void _star(Canvas c) {
    final rot = t * 2 * m.pi;
    _withScaleRot(c, const Offset(150, 150), rot, () {
      final pts = [
        [150, 58], [176, 112], [235, 120], [192, 161], [203, 220],
        [150, 191], [97, 220], [108, 161], [65, 120], [124, 112],
      ];
      final path = Path()..moveTo(pts[0][0].toDouble(), pts[0][1].toDouble());
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i][0].toDouble(), pts[i][1].toDouble());
      }
      path.close();
      _dieCut(c, path);
      c.drawPath(
        path,
        _radial(
          path.getBounds(),
          const [Color(0xFFFFEEB0), Color(0xFFFFCF4D), Color(0xFFF3A51E)],
          const [0, 0.55, 1],
        ),
      );
      _gloss(c, 126, 104, 26, 16);
      _shine(c, 128, 110, 6);
    });
  }

  void _withScaleRot(Canvas c, Offset pivot, double rot, VoidCallback body) {
    c.save();
    c.translate(pivot.dx, pivot.dy);
    c.rotate(rot);
    c.translate(-pivot.dx, -pivot.dy);
    body();
    c.restore();
  }

  void _fire(Canvas c) {
    final sy = 1 + 0.10 * m.sin(t * 2 * m.pi * 2);
    final sx = 1 - 0.05 * m.sin(t * 2 * m.pi * 2);
    _withScale(c, const Offset(150, 230), sx, sy, () {
      // flame silhouette
      final flame = Path()
        ..moveTo(150, 52)
        ..cubicTo(190, 96, 214, 120, 214, 166)
        ..cubicTo(214, 202, 186, 232, 150, 232)
        ..cubicTo(114, 232, 86, 202, 86, 166)
        ..cubicTo(86, 134, 104, 120, 118, 104)
        ..cubicTo(126, 120, 134, 124, 134, 124)
        ..cubicTo(128, 96, 138, 76, 150, 52)
        ..close();
      _dieCut(c, flame);
      c.drawPath(
        flame,
        _radial(
          flame.getBounds(),
          const [Color(0xFFFFE36B), Color(0xFFFF8A3C), Color(0xFFF0452E)],
          const [0, 0.45, 1],
          center: const Alignment(0, 0.55),
          radius: 0.95,
        ),
      );
      // inner flame
      final inner = Path()
        ..moveTo(150, 120)
        ..cubicTo(168, 144, 178, 156, 178, 180)
        ..cubicTo(178, 196, 166, 206, 150, 206)
        ..cubicTo(134, 206, 122, 196, 122, 180)
        ..cubicTo(122, 160, 138, 148, 150, 120)
        ..close();
      c.drawPath(inner, Paint()..color = const Color(0xFFFFE27A));
      _shine(c, 132, 120, 6);
    });
  }

  void _camera(Canvas c) {
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(78, 128, 144, 104), const Radius.circular(22)))
      ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(128, 112, 44, 24), const Radius.circular(8)));
    _dieCut(c, body);
    final fill = _radial(
      const Rect.fromLTWH(78, 112, 144, 120),
      const [Color(0xFFD7CCFF), Color(0xFF9A86FF), Color(0xFF6C54E0)],
      const [0, 0.55, 1],
    );
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(78, 128, 144, 104), const Radius.circular(22)),
        fill);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(128, 112, 44, 24), const Radius.circular(8)),
        fill);
    c.drawCircle(const Offset(150, 182), 36, Paint()..color = const Color(0xFF2C2350));
    c.drawCircle(const Offset(150, 182), 24, Paint()..color = const Color(0xFF6F5BFF));
    c.drawCircle(const Offset(150, 182), 12, Paint()..color = const Color(0xFF2C2350));
    _shine(c, 142, 174, 6);
    // shutter lamp twinkle
    final tw = (0.5 + 0.5 * m.sin(t * 2 * m.pi * 2));
    c.drawCircle(const Offset(198, 150), 7,
        Paint()..color = const Color(0xFFFFD36B).withValues(alpha: tw));
    _gloss(c, 110, 142, 40, 16);
    // flash
    final fp = t % 1.0;
    final flashOp = fp > 0.9 && fp < 0.97 ? 0.85 : 0.0;
    if (flashOp > 0) {
      c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(16, 16, 268, 268), const Radius.circular(36)),
        Paint()..color = Colors.white.withValues(alpha: flashOp),
      );
    }
  }

  void _moon(Canvas c) {
    final glow = 0.82 + 0.18 * (0.5 + 0.5 * m.sin(t * 2 * m.pi));
    // crescent = big circle minus offset circle
    final big = Path()
      ..addOval(Rect.fromCircle(center: const Offset(150, 150), radius: 92));
    final cut = Path()
      ..addOval(Rect.fromCircle(center: const Offset(196, 126), radius: 76));
    final cres = Path.combine(PathOperation.difference, big, cut);
    _dieCut(c, cres);
    c.drawPath(
      cres,
      _radial(
        cres.getBounds(),
        const [Color(0xFFFFEEB0), Color(0xFFFFCF4D), Color(0xFFF3A51E)],
        const [0, 0.55, 1],
      ),
    );
    // soft craters
    final cr = Paint()..color = const Color(0xFFF3A51E).withValues(alpha: 0.35);
    c.drawCircle(const Offset(120, 140), 9, cr);
    c.drawCircle(const Offset(138, 186), 6, cr);
    _shine(c, 118, 112, 8);
    // twinkle stars (glow drives opacity)
    final sp = Paint()..color = const Color(0xFFFFF5CF).withValues(alpha: glow);
    _tinyStar(c, const Offset(96, 90), 10, sp);
    c.drawCircle(const Offset(230, 150), 4,
        Paint()..color = const Color(0xFFFFF5CF).withValues(alpha: 2 - glow <= 1 ? glow : 1));
  }

  void _tinyStar(Canvas c, Offset o, double r, Paint p) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..lineTo(o.dx + r * 0.28, o.dy - r * 0.28)
      ..lineTo(o.dx + r, o.dy)
      ..lineTo(o.dx + r * 0.28, o.dy + r * 0.28)
      ..lineTo(o.dx, o.dy + r)
      ..lineTo(o.dx - r * 0.28, o.dy + r * 0.28)
      ..lineTo(o.dx - r, o.dy)
      ..lineTo(o.dx - r * 0.28, o.dy - r * 0.28)
      ..close();
    c.drawPath(path, p);
  }

  void _hearts(Canvas c) {
    final beat = 1 + 0.10 * m.sin(t * 2 * m.pi * 2);
    _withScale(c, const Offset(132, 160), beat, beat, () {
      final body = _heartPath(132, 160, 1.05);
      _dieCut(c, body);
      _drawHeart(c, 132, 160, 1.05);
      _gloss(c, 108, 128, 26, 16);
      _shine(c, 108, 132, 6);
    });
    final beat2 = 1 + 0.10 * m.sin((t + 0.4) * 2 * m.pi * 2);
    _withScale(c, const Offset(182, 128), beat2, beat2, () {
      final body = _heartPath(182, 128, 0.78);
      _dieCut(c, body);
      _drawHeart(c, 182, 128, 0.78,
          colors: const [Color(0xFFFFC0D4), Color(0xFFFF8AA3)]);
      _shine(c, 168, 108, 5);
    });
  }

  void _boba(Canvas c) {
    final s = 1 + 0.03 * m.sin(t * 2 * m.pi);
    _withScale(c, const Offset(150, 180), s, s, () {
      final cup = Path()
        ..moveTo(110, 122)
        ..lineTo(190, 122)
        ..lineTo(182, 238)
        ..quadraticBezierTo(180, 252, 166, 252)
        ..lineTo(134, 252)
        ..quadraticBezierTo(120, 252, 118, 238)
        ..close();
      final lidRect =
          RRect.fromRectAndRadius(const Rect.fromLTWH(104, 106, 92, 22), const Radius.circular(9));
      final lid = Path()..addRRect(lidRect);
      final straw = Path()
        ..addRRect(RRect.fromRectAndRadius(
            const Rect.fromLTWH(150, 64, 16, 78), const Radius.circular(7)));
      final sm = Matrix4.identity()
        ..translateByDouble(157.0, 105.0, 0, 1)
        ..rotateZ(0.2)
        ..translateByDouble(-157.0, -105.0, 0, 1);
      final strawT = straw.transform(sm.storage);
      var sil = Path.combine(PathOperation.union, cup, lid);
      sil = Path.combine(PathOperation.union, sil, strawT);
      _dieCut(c, sil);
      c.drawPath(strawT, Paint()..color = const Color(0xFFFF7D9A));
      c.drawPath(
          cup,
          _radial(cup.getBounds(), const [Color(0xFFFFF6EA), Color(0xFFF3DCC0)],
              const [0, 1]));
      c.save();
      c.clipPath(cup);
      c.drawRect(const Rect.fromLTWH(104, 196, 96, 70),
          Paint()..color = const Color(0xFFCAA06E).withValues(alpha: 0.6));
      c.restore();
      c.drawRRect(lidRect, Paint()..color = const Color(0xFFFF9DB5));
      final pearl = Paint()..color = const Color(0xFF3A2B22);
      for (final o in const [
        Offset(132, 246), Offset(152, 250), Offset(170, 244),
        Offset(144, 236), Offset(164, 236),
      ]) {
        c.drawCircle(o, 7, pearl);
      }
      _gloss(c, 126, 150, 16, 44);
    });
  }

  void _bear(Canvas c) {
    final dy = -8 * m.sin(t * 2 * m.pi).abs();
    c.save();
    c.translate(0, dy);
    final earL = Path()..addOval(Rect.fromCircle(center: const Offset(104, 104), radius: 30));
    final earR = Path()..addOval(Rect.fromCircle(center: const Offset(196, 104), radius: 30));
    final face = Path()..addOval(Rect.fromCircle(center: const Offset(150, 158), radius: 92));
    var sil = Path.combine(PathOperation.union, face, earL);
    sil = Path.combine(PathOperation.union, sil, earR);
    _dieCut(c, sil);
    final fill = _radial(
        Rect.fromCircle(center: const Offset(150, 150), radius: 104),
        const [Color(0xFFD7A06A), Color(0xFFB07840), Color(0xFF875A2E)],
        const [0, 0.6, 1]);
    c.drawPath(earL, fill);
    c.drawPath(earR, fill);
    c.drawCircle(const Offset(104, 104), 15, Paint()..color = const Color(0xFFE9B887));
    c.drawCircle(const Offset(196, 104), 15, Paint()..color = const Color(0xFFE9B887));
    c.drawCircle(const Offset(150, 158), 92, fill);
    _gloss(c, 120, 118, 42, 26);
    c.drawOval(Rect.fromCenter(center: const Offset(150, 186), width: 80, height: 64),
        Paint()..color = const Color(0xFFE4C196));
    final bl = Paint()..color = const Color(0xFFFF8AA0).withValues(alpha: 0.6);
    c.drawOval(Rect.fromCenter(center: const Offset(118, 184), width: 26, height: 16), bl);
    c.drawOval(Rect.fromCenter(center: const Offset(182, 184), width: 26, height: 16), bl);
    c.drawCircle(const Offset(126, 152), 10, Paint()..color = _ink);
    c.drawCircle(const Offset(174, 152), 10, Paint()..color = _ink);
    c.drawCircle(const Offset(123, 148), 3.3, Paint()..color = Colors.white);
    c.drawCircle(const Offset(171, 148), 3.3, Paint()..color = Colors.white);
    c.drawOval(Rect.fromCenter(center: const Offset(150, 176), width: 22, height: 16),
        Paint()..color = _ink);
    final mouth = Path()
      ..moveTo(150, 184)
      ..quadraticBezierTo(140, 194, 132, 186)
      ..moveTo(150, 184)
      ..quadraticBezierTo(160, 194, 168, 186);
    c.drawPath(
        mouth,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    _shine(c, 116, 120, 7);
    c.restore();
  }

  void _like(Canvas c) {
    final dy = -6 * (0.5 + 0.5 * m.sin(t * 2 * m.pi));
    c.save();
    c.translate(0, dy);
    final fist = Path()
      ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(96, 150, 118, 96), const Radius.circular(22)));
    final thumb = Path()
      ..addRRect(RRect.fromRectAndCorners(
        const Rect.fromLTWH(106, 92, 42, 84),
        topLeft: const Radius.circular(21),
        topRight: const Radius.circular(21),
        bottomLeft: const Radius.circular(8),
        bottomRight: const Radius.circular(8),
      ));
    final sil = Path.combine(PathOperation.union, fist, thumb);
    _dieCut(c, sil);
    c.drawPath(
        sil,
        _radial(const Rect.fromLTWH(96, 92, 118, 154),
            const [Color(0xFFFFEEB0), Color(0xFFFFCF4D), Color(0xFFF3A51E)],
            const [0, 0.55, 1]));
    final ln = Paint()
      ..color = const Color(0xFFE59A1E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final x = 124.0 + i * 30;
      c.drawLine(Offset(x, 174), Offset(x, 236), ln);
    }
    _gloss(c, 118, 120, 30, 14);
    _shine(c, 112, 118, 6);
    c.restore();
  }

  void _party(Canvas c) {
    final rot = 0.05 * m.sin(t * 2 * m.pi * 3);
    _withScaleRot(c, const Offset(150, 232), rot, () {
      final cone = Path()
        ..moveTo(150, 232)
        ..lineTo(190, 114)
        ..lineTo(224, 136)
        ..close();
      _dieCut(c, cone);
      c.drawPath(
          cone,
          _radial(cone.getBounds(),
              const [Color(0xFFFFEEB0), Color(0xFFFFCF4D), Color(0xFFF3A51E)],
              const [0, 0.55, 1]));
      c.drawPath(
          Path()
            ..moveTo(150, 232)
            ..lineTo(190, 114)
            ..lineTo(207, 125)
            ..close(),
          Paint()..color = const Color(0xFFF3A51E));
    });
    const items = [
      [120, 86, 0xFFFF4D79, 0, 0.0],
      [170, 80, 0xFF6FD3B8, 0, 0.5],
      [196, 110, 0xFF9A86FF, 1, 0.9],
      [104, 120, 0xFFFFCF4D, 1, 0.3],
      [150, 70, 0xFFFF4D79, 2, 0.7],
    ];
    for (final it in items) {
      final p = (t + (it[4] as double)) % 1.0;
      final dy = 42 * p;
      final op = (p < 0.15 ? p / 0.15 : 1 - (p - 0.15) / 0.85).clamp(0.0, 1.0);
      final paint = Paint()..color = Color(it[2] as int).withValues(alpha: op);
      c.save();
      c.translate((it[0] as int).toDouble(), (it[1] as int).toDouble() + dy);
      c.rotate(p * 2);
      switch (it[3] as int) {
        case 0:
          c.drawRRect(
              RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -6, 12, 12),
                  const Radius.circular(3)),
              paint);
        case 1:
          c.drawCircle(Offset.zero, 6, paint);
        default:
          c.drawPath(
              Path()
                ..moveTo(0, -7)
                ..lineTo(6, 5)
                ..lineTo(-6, 5)
                ..close(),
              paint);
      }
      c.restore();
    }
  }

  void _haha(Canvas c) {
    final rot = 0.07 * m.sin(t * 2 * m.pi * 4);
    _withScaleRot(c, const Offset(150, 160), rot, () {
      final body = Path()
        ..addOval(Rect.fromCircle(center: const Offset(150, 156), radius: 96));
      _dieCut(c, body);
      c.drawOval(
          Rect.fromCircle(center: const Offset(150, 156), radius: 96),
          _radial(Rect.fromCircle(center: const Offset(150, 156), radius: 96),
              const [Color(0xFFFFEEB0), Color(0xFFFFCF4D), Color(0xFFF3A51E)],
              const [0, 0.55, 1]));
      _gloss(c, 118, 112, 46, 28);
      _blushMarks(c);
      final ep = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;
      c.drawPath(
          Path()
            ..moveTo(104, 142)
            ..quadraticBezierTo(122, 128, 140, 142),
          ep);
      c.drawPath(
          Path()
            ..moveTo(160, 142)
            ..quadraticBezierTo(178, 128, 196, 142),
          ep);
      final mouth = Path()
        ..moveTo(114, 180)
        ..quadraticBezierTo(150, 224, 186, 180)
        ..quadraticBezierTo(150, 196, 114, 180)
        ..close();
      c.drawPath(mouth, Paint()..color = _ink);
      c.drawPath(
          Path()
            ..moveTo(126, 186)
            ..quadraticBezierTo(150, 204, 174, 186),
          Paint()..color = const Color(0xFFFF7D9A));
      _shine(c, 112, 118, 8);
    });
    _tear(c, 86, 158, 0.0);
    _tear(c, 214, 158, 0.5);
  }

  void _tear(Canvas c, double x, double y0, double phase) {
    final p = (t + phase) % 1.0;
    final y = y0 + 26 * p;
    final op = (p < 0.2 ? p / 0.2 : 1 - (p - 0.2) / 0.8).clamp(0.0, 1.0);
    c.save();
    c.translate(x, y);
    c.scale(x > 150 ? -1.0 : 1.0, 1.0);
    c.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-9, 10, -3, 20)
          ..quadraticBezierTo(6, 22, 6, 9)
          ..quadraticBezierTo(5, 2, 0, 0)
          ..close(),
        Paint()..color = const Color(0xFF8FD6FF).withValues(alpha: op));
    c.restore();
  }

  void _flower(Canvas c) {
    final rot = 0.09 * m.sin(t * 2 * m.pi);
    _withScaleRot(c, const Offset(150, 160), rot, () {
      final petals = Path();
      for (final a in const [0, 60, 120, 180, 240, 300]) {
        final mx = Matrix4.identity()
          ..translateByDouble(150.0, 150.0, 0, 1)
          ..rotateZ(a * m.pi / 180)
          ..translateByDouble(-150.0, -150.0, 0, 1);
        final petal = Path()
          ..addOval(Rect.fromCenter(
              center: const Offset(150, 104), width: 44, height: 68));
        petals.addPath(petal.transform(mx.storage), Offset.zero);
      }
      final center =
          Path()..addOval(Rect.fromCircle(center: const Offset(150, 150), radius: 30));
      final sil = Path.combine(PathOperation.union, petals, center);
      _dieCut(c, sil);
      c.drawPath(
          petals,
          _radial(const Rect.fromLTWH(98, 70, 104, 160),
              const [Color(0xFFFFC0D4), Color(0xFFFF6D94), Color(0xFFE83E6B)],
              const [0, 0.55, 1]));
      c.drawCircle(
          const Offset(150, 150),
          30,
          _radial(Rect.fromCircle(center: const Offset(150, 150), radius: 30),
              const [Color(0xFFFFEEB0), Color(0xFFFFCF4D), Color(0xFFF3A51E)],
              const [0, 0.55, 1]));
      _shine(c, 140, 140, 7);
    });
  }
}

enum _FaceKind { smile, love }
