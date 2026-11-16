import 'package:flutter/material.dart';
import '../transport/tv_transport.dart';
import '../theme.dart';
import 'press_area.dart';

/// Gangorra vertical (+ / −) para volume e canais.
class Rocker extends StatelessWidget {
  const Rocker(
      {super.key, required this.label, required this.up, required this.down});
  final String label;
  final TvKey up;
  final TvKey down;

  @override
  Widget build(BuildContext context) {
    Widget half(TvKey k, IconData icon, bool top) => Expanded(
          child: PressArea(
            tvKey: k,
            repeat: true,
            builder: (_, on) => AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              decoration: BoxDecoration(
                color: on ? alpha(Palette.accent, .22) : Colors.transparent,
                borderRadius: BorderRadius.vertical(
                  top: top ? const Radius.circular(36) : Radius.zero,
                  bottom: top ? Radius.zero : const Radius.circular(36),
                ),
              ),
              child: Center(
                child: Icon(icon,
                    color: on ? Palette.accent : Palette.text, size: 28),
              ),
            ),
          ),
        );

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72,
        height: 164,
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: Palette.line),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 6))
          ],
        ),
        child: Column(children: [
          half(up, Icons.add_rounded, true),
          Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 18),
              color: Palette.line),
          half(down, Icons.remove_rounded, false),
        ]),
      ),
      const SizedBox(height: 8),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ]);
  }
}
