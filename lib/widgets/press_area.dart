import 'package:flutter/material.dart';
import '../state/remote_controller.dart';
import '../transport/tv_transport.dart';
import '../theme.dart';

/// Área tocável que dispara uma tecla; com [repeat], segurar repete o comando.
class PressArea extends StatefulWidget {
  const PressArea(
      {super.key, required this.tvKey, required this.builder, this.repeat = false});
  final TvKey tvKey;
  final bool repeat;
  final Widget Function(BuildContext, bool down) builder;

  @override
  State<PressArea> createState() => _PressAreaState();
}

class _PressAreaState extends State<PressArea> {
  bool down = false;

  void _up() {
    if (!down) return;
    setState(() => down = false);
    RemoteScope.read(context).release();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => down = true);
        final c = RemoteScope.read(context);
        widget.repeat ? c.hold(widget.tvKey) : c.press(widget.tvKey);
      },
      onTapUp: (_) => _up(),
      onTapCancel: _up,
      child: widget.builder(context, down),
    );
  }
}

/// Tecla redonda padrão.
class KeyButton extends StatelessWidget {
  const KeyButton({
    super.key,
    required this.tvKey,
    required this.icon,
    this.label,
    this.size = 58,
    this.color,
    this.repeat = false,
  });
  final TvKey tvKey;
  final IconData icon;
  final String? label;
  final double size;
  final Color? color;
  final bool repeat;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Palette.text;
    return Semantics(
      button: true,
      label: label,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        PressArea(
          tvKey: tvKey,
          repeat: repeat,
          builder: (_, down) => AnimatedScale(
            scale: down ? .92 : 1,
            duration: const Duration(milliseconds: 90),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: down ? alpha(tint, .22) : Palette.surface,
                border:
                    Border.all(color: down ? alpha(tint, .7) : Palette.line),
                boxShadow: down
                    ? [BoxShadow(color: alpha(tint, .35), blurRadius: 18)]
                    : const [
                        BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 10,
                            offset: Offset(0, 5))
                      ],
              ),
              child: Icon(icon, color: tint, size: size * .42),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label!, style: Theme.of(context).textTheme.labelSmall),
        ],
      ]),
    );
  }
}
