import 'package:flutter/material.dart';
import '../state/remote_controller.dart';
import '../transport/tv_transport.dart';
import '../theme.dart';

Future<void> showDevicesSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Palette.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _DevicesSheet(),
  );
}

class _DevicesSheet extends StatefulWidget {
  const _DevicesSheet();
  @override
  State<_DevicesSheet> createState() => _DevicesSheetState();
}

class _DevicesSheetState extends State<_DevicesSheet> {
  bool searching = false;
  List<TvDevice> found = [];
  final ip = TextEditingController();

  Future<void> _search() async {
    setState(() => searching = true);
    final r = await RemoteScope.read(context).discover();
    if (!mounted) return;
    setState(() {
      found = r;
      searching = false;
    });
  }

  void _connect(TvDevice d) {
    RemoteScope.read(context).connect(d);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = RemoteScope.watch(context);
    final list = [
      ...c.saved,
      ...found.where((d) => !c.saved.contains(d)),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Palette.line, borderRadius: BorderRadius.circular(2))),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Text('Suas TV boxes', style: Theme.of(context).textTheme.titleMedium)),
          TextButton.icon(
            onPressed: searching ? null : _search,
            icon: searching
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.radar_rounded, size: 18),
            label: Text(searching ? 'Procurando…' : 'Buscar na rede'),
          ),
        ]),
        const SizedBox(height: 6),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Nenhuma TV box ainda. Toque em “Buscar na rede” ou digite o IP abaixo.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        for (final d in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.tv_rounded,
                color: d == c.current && c.state == ConnState.connected ? Palette.good : Palette.muted),
            title: Text(d.name),
            subtitle: Text(d.host, style: Theme.of(context).textTheme.labelSmall),
            trailing: c.saved.contains(d)
                ? IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Palette.muted),
                    onPressed: () => c.forget(d))
                : null,
            onTap: () => _connect(d),
          ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: ip,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'IP da TV box, ex.: 192.168.18.169',
                filled: true,
                fillColor: Palette.surfaceHi,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Palette.accent,
                foregroundColor: Palette.bg,
                minimumSize: const Size(56, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () {
              final v = ip.text.trim();
              if (v.isEmpty) return;
              final parts = v.split(':');
              _connect(TvDevice('TV Box ${parts[0]}', parts[0],
                  port: parts.length > 1 ? int.tryParse(parts[1]) ?? 6466 : 6466));
            },
            child: const Text('Conectar'),
          ),
        ]),
      ]),
    );
  }
}

Future<void> showKeyboardSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Palette.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _KeyboardSheet(),
  );
}

class _KeyboardSheet extends StatefulWidget {
  const _KeyboardSheet();
  @override
  State<_KeyboardSheet> createState() => _KeyboardSheetState();
}

class _KeyboardSheetState extends State<_KeyboardSheet> {
  final ctrl = TextEditingController();

  void _send() {
    final t = ctrl.text;
    if (t.isEmpty) return;
    RemoteScope.read(context).sendText(t);
    ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = RemoteScope.read(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Digitar na TV', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('O texto vai para o campo que estiver selecionado na tela da TV.',
            style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 14),
        TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
          decoration: InputDecoration(
            hintText: 'Pesquisar, senha, nome…',
            filled: true,
            fillColor: Palette.surfaceHi,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            suffixIcon: IconButton(
                icon: const Icon(Icons.send_rounded, color: Palette.accent), onPressed: _send),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton.icon(
              onPressed: () => c.press(TvKey.backspace),
              icon: const Icon(Icons.backspace_outlined, size: 18),
              label: const Text('Apagar')),
          const SizedBox(width: 10),
          OutlinedButton.icon(
              onPressed: () => c.press(TvKey.enter),
              icon: const Icon(Icons.keyboard_return_rounded, size: 18),
              label: const Text('Enter')),
        ]),
      ]),
    );
  }
}

