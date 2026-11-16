import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../transport/tv_transport.dart';

enum ConnState { disconnected, connecting, connected }

class RemoteController extends ChangeNotifier {
  RemoteController(this._transport);
  final TvTransport _transport;

  ConnState state = ConnState.disconnected;
  TvDevice? current;
  List<TvDevice> saved = [];
  String? toast;
  TvDevice? pairingFor; // não nulo: a UI deve pedir o código da TV

  Timer? _delay;
  Timer? _repeat;
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    saved = (_prefs!.getStringList('devices') ?? [])
        .map(TvDevice.parse)
        .whereType<TvDevice>()
        .toList();
    final last = TvDevice.parse(_prefs!.getString('last') ?? '');
    if (last != null) connect(last);
  }

  Future<List<TvDevice>> discover() => _transport.discover();

  Future<void> connect(TvDevice d) async {
    state = ConnState.connecting;
    current = d;
    notifyListeners();
    try {
      await _transport.connect(d);
      state = ConnState.connected;
      if (!saved.contains(d)) saved = [d, ...saved];
      await _prefs?.setStringList(
          'devices', saved.map((e) => e.serialize()).toList());
      await _prefs?.setString('last', d.serialize());
      HapticFeedback.mediumImpact();
    } on TvPairingRequired {
      state = ConnState.disconnected;
      try {
        await _transport.beginPairing(d);
        pairingFor = d;
      } catch (e) {
        _say(e is TvConnectException ? e.message : 'Falha ao iniciar o pareamento: $e');
      }
    } catch (e) {
      state = ConnState.disconnected;
      _say(e is TvConnectException
          ? e.message
          : 'Não deu para conectar em ${d.name}: $e');
    }
    notifyListeners();
  }

  Future<void> forget(TvDevice d) async {
    saved = saved.where((e) => e != d).toList();
    await _prefs?.setStringList(
        'devices', saved.map((e) => e.serialize()).toList());
    notifyListeners();
  }

  Future<void> press(TvKey k, {bool haptic = true}) async {
    if (state != ConnState.connected) {
      HapticFeedback.heavyImpact();
      _say('Conecte a uma TV box para usar o controle.');
      return;
    }
    if (haptic) HapticFeedback.selectionClick();
    try {
      await _transport.send(k);
    } catch (_) {
      state = ConnState.disconnected;
      _say('Perdeu a conexão com ${current?.name ?? 'a TV box'}.');
      notifyListeners();
    }
  }

  Future<void> sendText(String t) async {
    if (state != ConnState.connected) {
      _say('Conecte a uma TV box para digitar.');
      return;
    }
    await _transport.sendText(t);
  }

  Future<void> submitCode(String code) async {
    final d = pairingFor;
    pairingFor = null;
    if (d == null) return;
    state = ConnState.connecting;
    notifyListeners();
    var ok = false;
    try {
      ok = await _transport.finishPairing(code);
    } catch (_) {}
    if (ok) {
      await connect(d);
    } else {
      state = ConnState.disconnected;
      _say('Código incorreto. Toque em Conectar para tentar de novo.');
      notifyListeners();
    }
  }

  void cancelPairing() {
    pairingFor = null;
    state = ConnState.disconnected;
    notifyListeners();
  }

  void hold(TvKey k) {
    press(k);
    _delay = Timer(const Duration(milliseconds: 380), () {
      _repeat = Timer.periodic(
          const Duration(milliseconds: 110), (_) => press(k, haptic: false));
    });
  }

  void release() {
    _delay?.cancel();
    _repeat?.cancel();
  }

  void _say(String m) {
    toast = m;
    notifyListeners();
  }

  void clearToast() => toast = null;
}

/// Acesso ao controller sem depender de pacotes externos.
class RemoteScope extends InheritedNotifier<RemoteController> {
  const RemoteScope(
      {super.key, required RemoteController controller, required super.child})
      : super(notifier: controller);

  static RemoteController watch(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<RemoteScope>()!.notifier!;
  static RemoteController read(BuildContext c) =>
      c.getInheritedWidgetOfExactType<RemoteScope>()!.notifier!;
}
