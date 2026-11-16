import 'dart:async';

/// Códigos de tecla do Android (KeyEvent). Servem para ADB
/// (`input keyevent N`) e também mapeiam bem para outros protocolos.
enum TvKey {
  up(19),
  down(20),
  left(21),
  right(22),
  ok(23),
  back(4),
  home(3),
  menu(82),
  power(26),
  volUp(24),
  volDown(25),
  mute(164),
  chUp(166),
  chDown(167),
  playPause(85),
  rewind(89),
  forward(90),
  next(87),
  previous(88),
  backspace(67),
  enter(66);

  const TvKey(this.code);
  final int code;
}

class TvConnectException implements Exception {
  TvConnectException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A TV ainda não foi pareada com este app (precisa do código da tela).
class TvPairingRequired implements Exception {}

class TvDevice {
  const TvDevice(this.name, this.host, {this.port = 6466});
  final String name;
  final String host;
  final int port;

  String get id => '$host:$port';
  String serialize() => '$name|$host|$port';

  static TvDevice? parse(String s) {
    final p = s.split('|');
    if (p.length != 3) return null;
    return TvDevice(p[0], p[1], port: int.tryParse(p[2]) ?? 6466);
  }

  @override
  bool operator ==(Object other) => other is TvDevice && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// Contrato entre a interface e o protocolo real.
/// Para falar com a TV box de verdade, basta implementar esta classe
/// e trocar em main.dart.
abstract class TvTransport {
  Future<List<TvDevice>> discover();
  Future<void> connect(TvDevice device);
  Future<void> disconnect();
  Future<void> send(TvKey key);
  Future<void> sendText(String text);
  /// Pede à TV para mostrar o código de pareamento.
  Future<void> beginPairing(TvDevice device);

  /// Confirma o código digitado pelo usuário.
  Future<bool> finishPairing(String code);
}

/// Transporte de demonstração: não envia nada pra rede.
/// Útil para testar toda a experiência do app sem uma TV box.
class DemoTransport implements TvTransport {
  @override
  Future<List<TvDevice>> discover() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    return const [
      TvDevice('TV Box da sala', '192.168.0.42'),
      TvDevice('TV Box do quarto', '192.168.0.57'),
    ];
  }

  @override
  Future<void> connect(TvDevice device) =>
      Future.delayed(const Duration(milliseconds: 700));

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(TvKey key) async {}

  @override
  Future<void> sendText(String text) async {}

  @override
  Future<void> beginPairing(TvDevice device) async {}

  @override
  Future<bool> finishPairing(String code) async => true;
}
