import 'package:flutter/material.dart';
import '../state/remote_controller.dart';
import '../transport/tv_transport.dart';
import '../theme.dart';

/// Modo touchpad: deslize para navegar, toque para OK, toque duplo para voltar.
class Touchpad extends StatefulWidget {
  const Touchpad({super.key});
  @override
  State<Touchpad> createState() => _TouchpadState();
}

class _TouchpadState extends State<Touchpad> {
  Offset acc = Offset.zero;
  Offset? touch;
  static const step = 34.0;

  void _drain() {
    final c = RemoteScope.read(context);
    while (acc.dx.abs() >= step || acc.dy.abs() >= step) {
      if (acc.dx.abs() >= acc.dy.abs()) {
        c.press(acc.dx > 0 ? TvKey.right : TvKey.left);
        acc = Offset(acc.dx - step * acc.dx.sign, acc.dy);
      } else {
        c.press(acc.dy > 0 ? TvKey.down : TvKey.up);
        acc = Offset(acc.dx, acc.dy - step * acc.dy.sign);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => RemoteScope.read(context).press(TvKey.ok),
      onDoubleTap: () => RemoteScope.read(context).press(TvKey.back),
      onPanStart: (d) => setState(() {
        touch = d.localPosition;
        acc = Offset.zero;
      }),
      onPanUpdate: (d) {
        acc += d.delta;
        setState(() => touch = d.localPosition);
        _drain();
      },
      onPanEnd: (_) => setState(() => touch = null),
      onPanCancel: () => setState(() => touch = null),
      child: Container(
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _PadPainter(touch),
          child: Align(
            alignment: const Alignment(0, .78),
            child: Text(
              'Deslize para navegar\nToque para OK · toque duplo para voltar',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
      ),
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter(this.touch);
  final Offset? touch;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = alpha(Palette.muted, .35);
    for (double x = 20; x < size.width; x += 26) {
      for (double y = 20; y < size.height; y += 26) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
    if (touch != null) {
      canvas.drawCircle(
        touch!,
        60,
        Paint()
          ..shader = RadialGradient(
            colors: [alpha(Palette.accent, .38), alpha(Palette.accent, 0)],
          ).createShader(Rect.fromCircle(center: touch!, radius: 60)),
      );
      canvas.drawCircle(touch!, 9, Paint()..color = Palette.accent);
    }
  }

  @override
  bool shouldRepaint(_PadPainter old) => old.touch != touch;
}
