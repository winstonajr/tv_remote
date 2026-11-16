import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state/remote_controller.dart';
import '../transport/tv_transport.dart';
import '../theme.dart';

enum _Zone { none, up, down, left, right, ok }

TvKey _keyOf(_Zone z) => switch (z) {
      _Zone.up => TvKey.up,
      _Zone.down => TvKey.down,
      _Zone.left => TvKey.left,
      _Zone.right => TvKey.right,
      _ => TvKey.ok,
    };

/// Anel direcional com 4 setores + botão OK central.
/// Toque dispara; segurar uma direção repete o comando.
class DPad extends StatefulWidget {
  const DPad({super.key, this.size = 280});
  final double size;

  @override
  State<DPad> createState() => _DPadState();
}

class _DPadState extends State<DPad> {
  _Zone zone = _Zone.none;

  _Zone _zoneAt(Offset p) {
    final s = widget.size;
    final d = p - Offset(s / 2, s / 2);
    final r = d.distance;
    if (r > s / 2) return _Zone.none;
    if (r < s * .19) return _Zone.ok;
    if (r < s * .27) return _Zone.none;
    final a = math.atan2(d.dy, d.dx);
    if (a >= -math.pi * .75 && a < -math.pi * .25) return _Zone.up;
    if (a >= -math.pi * .25 && a < math.pi * .25) return _Zone.right;
    if (a >= math.pi * .25 && a < math.pi * .75) return _Zone.down;
    return _Zone.left;
  }

  void _release() {
    if (zone == _Zone.none) return;
    RemoteScope.read(context).release();
    setState(() => zone = _Zone.none);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          final z = _zoneAt(d.localPosition);
          if (z == _Zone.none) return;
          setState(() => zone = z);
          final c = RemoteScope.read(context);
          z == _Zone.ok ? c.press(TvKey.ok) : c.hold(_keyOf(z));
        },
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        child: CustomPaint(painter: _DPadPainter(zone)),
      ),
    );
  }
}

class _DPadPainter extends CustomPainter {
  _DPadPainter(this.zone);
  final _Zone zone;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final inner = size.width * .27;
    const gap = .07;

    canvas.drawCircle(
      c,
      outer + 4,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    void sector(_Zone z, double center, IconData icon) {
      final sweep = math.pi / 2 - gap;
      final start = center - sweep / 2;
      final path = Path()
        ..arcTo(Rect.fromCircle(center: c, radius: outer), start, sweep, true)
        ..arcTo(Rect.fromCircle(center: c, radius: inner), start + sweep,
            -sweep, false)
        ..close();
      final on = zone == z;
      if (on) {
        canvas.drawPath(
          path,
          Paint()
            ..color = alpha(Palette.accent, .45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: on
                ? [alpha(Palette.accent, .95), alpha(Palette.accent, .7)]
                : const [Palette.surfaceHi, Palette.surface],
          ).createShader(Rect.fromCircle(center: c, radius: outer)),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Palette.line,
      );
      final mid = (outer + inner) / 2;
      final pos = c + Offset(math.cos(center), math.sin(center)) * mid;
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: size.width * .12,
            color: on ? Palette.bg : Palette.text,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    sector(_Zone.up, -math.pi / 2, Icons.keyboard_arrow_up_rounded);
    sector(_Zone.right, 0, Icons.keyboard_arrow_right_rounded);
    sector(_Zone.down, math.pi / 2, Icons.keyboard_arrow_down_rounded);
    sector(_Zone.left, math.pi, Icons.keyboard_arrow_left_rounded);

    final okOn = zone == _Zone.ok;
    final okR = size.width * .19;
    if (okOn) {
      canvas.drawCircle(
        c,
        okR + 4,
        Paint()
          ..color = alpha(Palette.accent, .5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }
    final r = okOn ? okR * .96 : okR;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: okOn
              ? const [Palette.accent, Color(0xFFE59A2E)]
              : const [Palette.surfaceHi, Palette.surface],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = okOn ? alpha(Palette.accent, .9) : Palette.line,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'OK',
        style: TextStyle(
          fontSize: size.width * .075,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: okOn ? Palette.bg : Palette.text,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_DPadPainter old) => old.zone != zone;
}
