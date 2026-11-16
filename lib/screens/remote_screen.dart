import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state/remote_controller.dart';
import '../transport/tv_transport.dart';
import '../theme.dart';
import '../widgets/dpad.dart';
import '../widgets/press_area.dart';
import '../widgets/rocker.dart';
import '../widgets/sheets.dart';
import '../widgets/touchpad.dart';

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key});
  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  bool touchpad = false;
  bool _asking = false;
  RemoteController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c?.removeListener(_onChange);
    _c = RemoteScope.read(context)..addListener(_onChange);
  }

  @override
  void dispose() {
    _c?.removeListener(_onChange);
    super.dispose();
  }

  Future<void> _askCode() async {
    final c = _c;
    if (c == null || !mounted) {
      _asking = false;
      return;
    }
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.surface,
        title: const Text('Código da TV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Olhe a tela da TV: apareceu um código de 4 ou 6 caracteres. Digite aqui.',
              style: TextStyle(color: Palette.text, height: 1.35),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 6,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                  fontSize: 26, letterSpacing: 6, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: Palette.surfaceHi,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Parear')),
        ],
      ),
    );
    _asking = false;
    final len = code?.trim().length ?? 0;
    if (len != 4 && len != 6) {
      c.cancelPairing();
    } else {
      c.submitCode(code!);
    }
  }

  void _onChange() {
    if (_c?.pairingFor != null && !_asking && mounted) {
      _asking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _askCode());
    }
    final t = _c?.toast;
    if (t == null || !mounted) return;
    _c!.clearToast();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.surfaceHi,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: alpha(Palette.danger, .7), width: 1.2),
        ),
        content: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline_rounded,
                color: Palette.danger, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t,
              style: const TextStyle(
                color: Palette.text,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ]),
        action: SnackBarAction(
            label: 'Conectar',
            textColor: Palette.accent,
            onPressed: () => showDevicesSheet(context)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final c = RemoteScope.watch(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(children: [
            _Header(c: c),
            const SizedBox(height: 16),
            _Tabs(
              touchpad: touchpad,
              onChanged: (v) => setState(() => touchpad = v),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: touchpad
                    ? const _TouchpadPage(key: ValueKey('pad'))
                    : const _ButtonsPage(key: ValueKey('btn')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.c});
  final RemoteController c;

  @override
  Widget build(BuildContext context) {
    final (dot, text) = switch (c.state) {
      ConnState.connected => (Palette.good, c.current?.name ?? 'Conectado'),
      ConnState.connecting => (Palette.accent, 'Conectando…'),
      ConnState.disconnected => (Palette.danger, 'Sem conexão'),
    };
    return Row(children: [
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => showDevicesSheet(context),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(
                color: Palette.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Palette.line),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dot, boxShadow: [
                    BoxShadow(color: alpha(dot, .6), blurRadius: 8),
                  ]),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more_rounded, color: Palette.muted, size: 20),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      const KeyButton(
          tvKey: TvKey.power,
          icon: Icons.power_settings_new_rounded,
          label: null,
          size: 50,
          color: Palette.danger),
    ]);
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.touchpad, required this.onChanged});
  final bool touchpad;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(String t, IconData i, bool value) {
      final on = touchpad == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(i, size: 18, color: on ? Palette.bg : Palette.muted),
              const SizedBox(width: 6),
              Text(t,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: on ? Palette.bg : Palette.muted)),
            ]),
          ),
        ),
      );
    }

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Palette.line),
      ),
      child: Stack(children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: touchpad ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: .5,
            child: Container(
              decoration: BoxDecoration(
                  color: Palette.accent, borderRadius: BorderRadius.circular(19)),
            ),
          ),
        ),
        Row(children: [
          item('Botões', Icons.gamepad_rounded, false),
          item('Touchpad', Icons.touch_app_rounded, true),
        ]),
      ]),
    );
  }
}

class _ButtonsPage extends StatelessWidget {
  const _ButtonsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final dpad = math.min(box.maxWidth, 300.0);
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(children: [
          const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            KeyButton(tvKey: TvKey.back, icon: Icons.arrow_back_rounded, label: 'Voltar'),
            KeyButton(tvKey: TvKey.home, icon: Icons.home_rounded, label: 'Início'),
            KeyButton(tvKey: TvKey.menu, icon: Icons.menu_rounded, label: 'Menu'),
          ]),
          const SizedBox(height: 22),
          DPad(size: dpad),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Rocker(label: 'Volume', up: TvKey.volUp, down: TvKey.volDown),
            Column(children: [
              const KeyButton(tvKey: TvKey.mute, icon: Icons.volume_off_rounded, label: 'Mudo'),
              const SizedBox(height: 18),
              Column(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () => showKeyboardSheet(context),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.surface,
                      border: Border.all(color: Palette.line),
                    ),
                    child: const Icon(Icons.keyboard_alt_outlined, size: 24),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Teclado', style: Theme.of(context).textTheme.labelSmall),
              ]),
            ]),
            const Rocker(label: 'Canal', up: TvKey.chUp, down: TvKey.chDown),
          ]),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Palette.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Palette.line),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _Media(TvKey.previous, Icons.skip_previous_rounded),
              _Media(TvKey.rewind, Icons.fast_rewind_rounded),
              _Media(TvKey.playPause, Icons.play_arrow_rounded, big: true),
              _Media(TvKey.forward, Icons.fast_forward_rounded),
              _Media(TvKey.next, Icons.skip_next_rounded),
            ]),
          ),
        ]),
      );
    });
  }
}

class _Media extends StatelessWidget {
  const _Media(this.k, this.icon, {this.big = false});
  final TvKey k;
  final IconData icon;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return PressArea(
      tvKey: k,
      builder: (_, down) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: big ? 56 : 46,
        height: big ? 56 : 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: big
              ? (down ? alpha(Palette.accent, .8) : Palette.accent)
              : (down ? alpha(Palette.accent, .2) : Colors.transparent),
        ),
        child: Icon(icon,
            size: big ? 30 : 26, color: big ? Palette.bg : Palette.text),
      ),
    );
  }
}

class _TouchpadPage extends StatelessWidget {
  const _TouchpadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(children: [
      Expanded(child: Touchpad()),
      SizedBox(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        KeyButton(tvKey: TvKey.back, icon: Icons.arrow_back_rounded, label: 'Voltar'),
        KeyButton(tvKey: TvKey.home, icon: Icons.home_rounded, label: 'Início'),
        KeyButton(tvKey: TvKey.volDown, icon: Icons.volume_down_rounded, label: 'Vol −', repeat: true),
        KeyButton(tvKey: TvKey.volUp, icon: Icons.volume_up_rounded, label: 'Vol +', repeat: true),
      ]),
    ]);
  }
}
