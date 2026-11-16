import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart' as hash;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tv_transport.dart';

/// Protocolo Android TV Remote (v1 legado para TV Boxes genéricas e v2 moderno para Google TV).
/// Pareamento na porta 6467 (código de 4 ou 6 caracteres na tela da TV) e
/// controle na porta 6466, ambos com TLS e certificado do cliente.
class AndroidTvTransport implements TvTransport {
  static const _pairPort = 6467;
  static const _remotePort = 6466;

  _Channel? _remote;
  _PairSession? _pair;
  List<String>? _id; // [certPem, keyPem]
  int _v1Counter = 0;

  // ---------------------------------------------------------- identidade
  Future<List<String>> _identity() async {
    if (_id != null) return _id!;
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList('tv_identity') ?? const <String>[];
    if (saved.length != 2) {
      saved = await compute<int, List<String>>(_generateIdentity, 0);
      await prefs.setStringList('tv_identity', saved);
    }
    return _id = saved;
  }

  SecurityContext _context(List<String> id) => SecurityContext(withTrustedRoots: false)
    ..useCertificateChainBytes(utf8.encode(id[0]))
    ..usePrivateKeyBytes(utf8.encode(id[1]));

  Future<SecureSocket> _open(String host, int port, List<String> id) =>
      SecureSocket.connect(host, port,
          context: _context(id),
          onBadCertificate: (_) => true,
          timeout: const Duration(seconds: 8));

  // ---------------------------------------------------------- descoberta
  @override
  Future<List<TvDevice>> discover() async {
    final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    final mine = ifaces
        .expand((i) => i.addresses)
        .map((a) => a.address)
        .where((a) =>
            a.startsWith('192.168.') || a.startsWith('10.') || a.startsWith('172.'))
        .toList();
    if (mine.isEmpty) return [];
    final base = mine.first.substring(0, mine.first.lastIndexOf('.') + 1);
    final found = <TvDevice>[];
    // Evita tocar na 6467 com socket TCP puro para não derrubar o serviço de pareamento em TV boxes legadas.
    const ports = [6466, 8008, 8009, 5555, 80, 8080];

    Future<void> probe(int i) async {
      final host = '$base$i';
      if (host == mine.first) return;
      final open = <int>[];
      await Future.wait(ports.map((p) async {
        try {
          final s = await Socket.connect(host, p,
              timeout: const Duration(milliseconds: 600));
          s.destroy();
          open.add(p);
        } catch (_) {}
      }));
      if (open.isEmpty) return;
      open.sort();
      final tv = open.contains(_remotePort);
      found.add(TvDevice(
        tv ? 'TV Box $host' : 'Dispositivo $host · portas ${open.join(', ')}',
        host,
        port: _remotePort,
      ));
    }

    for (var start = 1; start < 255; start += 32) {
      await Future.wait([
        for (var i = start; i < min(start + 32, 255); i++) probe(i),
      ]);
    }
    found.sort((a, b) =>
        (b.name.startsWith('TV Box') ? 1 : 0) - (a.name.startsWith('TV Box') ? 1 : 0));
    return found;
  }

  // ---------------------------------------------------------- pareamento
  @override
  Future<void> beginPairing(TvDevice d) async {
    _pair?.ch.socket.destroy();
    _pair = null;
    final id = await _identity();

    // IMPORTANTE: tentamos primeiro os modos v1 (cabeçalho de 4 bytes big-endian [0, 0, 0, len]).
    // Se enviarmos varint v2 ([0x17, 0x08, 0x02, 0x10]) para uma TV Box com Android TV Remote Service v1,
    // ela lê os 4 primeiros bytes como tamanho (386 MB) e sofre crash ("Android TV Remote Service parou").
    Object? lastErr;
    for (final mode in [_PairMode.v1Json, _PairMode.v1Proto, _PairMode.v2Proto]) {
      SecureSocket? sock;
      try {
        sock = await _open(d.host, _pairPort, id);
      } catch (e) {
        lastErr = e;
        if (mode == _PairMode.v1Json) {
          throw TvConnectException(
              'Não consegui abrir o pareamento em ${d.host}. A TV está ligada e na mesma rede?');
        }
        continue;
      }
      final server = sock.peerCertificate;
      if (server == null) {
        sock.destroy();
        throw TvConnectException('A TV não apresentou certificado.');
      }
      final ch = _Channel(sock, mode.framing);
      try {
        await _handshakePairing(ch, mode);
        _pair = _PairSession(
          ch,
          _rsaFromDer(server.der),
          _rsaFromDer(_pemToDer(id[0])),
          d.host,
          mode,
        );
        return;
      } catch (e) {
        lastErr = e;
        sock.destroy();
      }
    }
    throw TvConnectException('A TV não respondeu ao pareamento: $lastErr');
  }

  Future<void> _handshakePairing(_Channel ch, _PairMode mode) async {
    const t = Duration(seconds: 5);
    if (mode == _PairMode.v1Json) {
      ch.send(_jsonBytes({
        'protocol_version': 1,
        'status': 200,
        'type': 10,
        'payload': {'service_name': 'androidtvremote', 'client_name': 'Orbita'},
      }));
      final ack1 = _parseJson(await ch.next(timeout: t));
      if (ack1['status'] != 200 || ack1['type'] != 11) {
        throw StateError('ack1 inválido');
      }
      ch.send(_jsonBytes({
        'protocol_version': 1,
        'status': 200,
        'type': 20,
        'payload': {
          'output_encodings': [
            {'symbol_length': 4, 'type': 3},
            {'symbol_length': 6, 'type': 3},
          ],
          'input_encodings': [
            {'symbol_length': 4, 'type': 3},
            {'symbol_length': 6, 'type': 3},
          ],
          'preferred_role': 1,
        },
      }));
      final opt = _parseJson(await ch.next(timeout: t));
      if (opt['status'] != 200 || opt['type'] != 20) {
        throw StateError('options inválido');
      }
      var symLen = 4;
      final payload = opt['payload'];
      if (payload is Map) {
        final outs = payload['output_encodings'];
        if (outs is List && outs.isNotEmpty && outs.first is Map) {
          symLen = (outs.first['symbol_length'] as int?) ?? 4;
        }
      }
      ch.send(_jsonBytes({
        'protocol_version': 1,
        'status': 200,
        'type': 30,
        'payload': {
          'encoding': {'symbol_length': symLen, 'type': 3},
          'client_role': 1,
        },
      }));
      final ack3 = _parseJson(await ch.next(timeout: t));
      if (ack3['status'] != 200 || ack3['type'] != 31) {
        throw StateError('config ack inválido');
      }
      return;
    }

    if (mode == _PairMode.v1Proto) {
      ch.send(_om(10, _cat([
        _fBytes(1, utf8.encode('androidtvremote')),
        _fBytes(2, utf8.encode('Orbita')),
      ])));
      final ack1 = _decode(await ch.next(timeout: t));
      if (ack1[2] != 200 || ack1[3] != 11) throw StateError('ack1 v1Proto inválido');

      final enc4 = _cat([_fVar(1, 3), _fVar(2, 4)]);
      final enc6 = _cat([_fVar(1, 3), _fVar(2, 6)]);
      ch.send(_om(20, _cat([_fBytes(1, enc4), _fBytes(1, enc6), _fVar(3, 1)])));
      final optOuter = _decode(await ch.next(timeout: t));
      if (optOuter[2] != 200 || optOuter[3] != 20) {
        throw StateError('options v1Proto inválido');
      }
      var symLen = 4;
      final optPayload = optOuter[4];
      if (optPayload is Uint8List) {
        final optMsg = _decode(optPayload);
        final outEnc = optMsg[2];
        if (outEnc is Uint8List) {
          symLen = (_decode(outEnc)[2] as int?) ?? 4;
        }
      }
      final enc = _cat([_fVar(1, 3), _fVar(2, symLen)]);
      ch.send(_om(30, _cat([_fBytes(1, enc), _fVar(2, 1)])));
      final ack3 = _decode(await ch.next(timeout: t));
      if (ack3[2] != 200 || ack3[3] != 31) throw StateError('config v1Proto inválido');
      return;
    }

    // v2Proto
    ch.send(_pm(10, _cat([
      _fBytes(1, utf8.encode('orbita')),
      _fBytes(2, utf8.encode('Orbita')),
    ])));
    final ack1 = _decode(await ch.next(timeout: t));
    if (ack1[2] != 200) throw StateError('ack1 v2 inválido');
    final enc = _cat([_fVar(1, 3), _fVar(2, 6)]); // hexadecimal, 6 símbolos
    ch.send(_pm(20, _cat([_fBytes(1, enc), _fVar(3, 1)])));
    final opt = _decode(await ch.next(timeout: t));
    if (opt[2] != 200) throw StateError('options v2 inválido');
    ch.send(_pm(30, _cat([_fBytes(1, enc), _fVar(2, 1)])));
    final ack3 = _decode(await ch.next(timeout: t));
    if (ack3[2] != 200) throw StateError('config v2 inválido');
  }

  @override
  Future<bool> finishPairing(String code) async {
    final s = _pair;
    if (s == null) return false;
    try {
      final c = code.trim();
      final b = BytesBuilder()
        ..add(s.client.n)
        ..add(s.client.e)
        ..add(s.server.n)
        ..add(s.server.e)
        ..add(_hexBytes(c.substring(2)));
      final digest = hash.sha256.convert(b.toBytes()).bytes;
      // o 1º byte do código é um byte de verificação
      if (digest[0] != int.parse(c.substring(0, 2), radix: 16)) return false;

      final bool ok;
      if (s.mode == _PairMode.v1Json) {
        s.ch.send(_jsonBytes({
          'protocol_version': 1,
          'status': 200,
          'type': 40,
          'payload': {'secret': base64.encode(digest)},
        }));
        final reply = _parseJson(await s.ch.next());
        ok = reply['status'] == 200 && reply['type'] == 41;
      } else if (s.mode == _PairMode.v1Proto) {
        s.ch.send(_om(40, _fBytes(1, digest)));
        final reply = _decode(await s.ch.next());
        ok = reply[2] == 200 && reply[3] == 41;
      } else {
        s.ch.send(_pm(40, _fBytes(1, digest)));
        final reply = _decode(await s.ch.next());
        ok = reply.containsKey(41);
      }

      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList('tv_paired') ?? <String>[];
        if (!list.contains(s.host)) list.add(s.host);
        await prefs.setStringList('tv_paired', list);

        final v1List = prefs.getStringList('tv_v1') ?? <String>[];
        if (s.mode != _PairMode.v2Proto) {
          if (!v1List.contains(s.host)) v1List.add(s.host);
        } else {
          v1List.remove(s.host);
        }
        await prefs.setStringList('tv_v1', v1List);
      }
      return ok;
    } catch (_) {
      return false;
    } finally {
      s.ch.socket.destroy();
      _pair = null;
    }
  }

  // ---------------------------------------------------------- conexão
  @override
  Future<void> connect(TvDevice d) async {
    await disconnect();
    final prefs = await SharedPreferences.getInstance();
    final paired = prefs.getStringList('tv_paired') ?? <String>[];
    if (!paired.contains(d.host)) throw TvPairingRequired();

    final v1List = prefs.getStringList('tv_v1') ?? <String>[];
    final isV1 = v1List.contains(d.host);

    final id = await _identity();
    final SecureSocket sock;
    try {
      sock = await _open(d.host, _remotePort, id);
    } catch (_) {
      throw TvConnectException(
          'Não consegui falar com ${d.host}. Confira se a TV está ligada e na mesma rede Wi‑Fi.');
    }
    final ch = _Channel(
      sock,
      isV1 ? _Framing.v1Remote : _Framing.varint,
    );
    _remote = ch;
    _v1Counter = 0;
    final ready = Completer<void>();

    if (isV1) {
      ch.onMessage = (m) {
        if (m.length >= 2 && m[0] == 1) {
          if (m[1] == 7) {
            if (!ready.isCompleted) ready.complete();
          } else if (m[1] == 20) {
            // Ping v1 -> Pong v1
            ch.send(Uint8List.fromList(const [1, 21, 0, 0]));
          }
        }
      };
      // Em v1 o cliente envia a configuração inicial logo após abrir o TLS
      ch.send(Uint8List.fromList(const [
        1, 0, 0, 21, 0, 0, 0, 1, 0, 0, 0, 1, 32, 3, 0, 0, 0, 0, 0, 0, 4, 116, 101, 115, 116
      ]));
    } else {
      ch.onMessage = (m) {
        final msg = _decode(m);
        if (msg.containsKey(1)) {
          // a TV pediu a configuração do cliente
          final info = _cat([
            _fBytes(1, utf8.encode('orbita')),
            _fBytes(2, utf8.encode('orbita')),
            _fVar(3, 1),
            _fBytes(4, utf8.encode('1')),
            _fBytes(5, utf8.encode('br.com.winston.orbita')),
            _fBytes(6, utf8.encode('1.0.0')),
          ]);
          ch.send(_fBytes(1, _cat([_fVar(1, 622), _fBytes(2, info)])));
        } else if (msg.containsKey(2)) {
          ch.send(_fBytes(2, _fVar(1, 622)));
          if (!ready.isCompleted) ready.complete();
        } else if (msg.containsKey(8)) {
          final ping = msg[8];
          final v = ping is Uint8List ? (_decode(ping)[1] as int? ?? 0) : 0;
          ch.send(_fBytes(9, _fVar(1, v)));
        }
      };
    }

    ch.onClose = () {
      if (!ready.isCompleted) ready.completeError(TvPairingRequired());
      if (identical(_remote, ch)) _remote = null;
    };

    try {
      await ready.future.timeout(const Duration(seconds: 10));
    } on TvPairingRequired {
      // a TV não reconhece mais este app: precisa parear de novo
      paired.remove(d.host);
      await prefs.setStringList('tv_paired', paired);
      rethrow;
    } on TimeoutException {
      sock.destroy();
      throw TvConnectException('A TV não respondeu ao controle remoto. Tente de novo.');
    }
  }

  @override
  Future<void> disconnect() async {
    _remote?.socket.destroy();
    _remote = null;
  }

  // ---------------------------------------------------------- comandos
  @override
  Future<void> send(TvKey key) async {
    final ch = _remote;
    if (ch == null) throw StateError('sem conexão');
    if (ch.framing == _Framing.v1Remote) {
      _sendV1Key(ch, key.code);
    } else {
      ch.send(_keyMsg(key.code));
    }
  }

  void _sendV1Key(_Channel ch, int code) {
    final down = Uint8List.fromList([
      1, 2, 0, 16,
      0, 0, 0, 0, 0, 0, 0, _v1Counter & 0xff,
      0, 0, 0, 0,
      0, 0, (code >> 8) & 0xff, code & 0xff,
    ]);
    _v1Counter++;
    final up = Uint8List.fromList([
      1, 2, 0, 16,
      0, 0, 0, 0, 0, 0, 0, _v1Counter & 0xff,
      0, 0, 0, 1,
      0, 0, (code >> 8) & 0xff, code & 0xff,
    ]);
    _v1Counter++;
    ch.send(down);
    ch.send(up);
  }

  static const _chars = {' ': 62, '.': 56, ',': 55, '-': 69, '@': 77, '/': 76};

  @override
  Future<void> sendText(String text) async {
    final ch = _remote;
    if (ch == null) throw StateError('sem conexão');
    for (final r in text.toLowerCase().runes) {
      final s = String.fromCharCode(r);
      int? code;
      if (r >= 97 && r <= 122) {
        code = 29 + (r - 97); // KEYCODE_A..Z
      } else if (r >= 48 && r <= 57) {
        code = 7 + (r - 48); // KEYCODE_0..9
      } else {
        code = _chars[s];
      }
      if (code == null) continue;
      if (ch.framing == _Framing.v1Remote) {
        _sendV1Key(ch, code);
      } else {
        ch.send(_keyMsg(code));
      }
      await Future.delayed(const Duration(milliseconds: 35));
    }
  }
}

// ============================================================ auxiliares

enum _Framing { varint, be32, v1Remote }

enum _PairMode {
  v1Json(_Framing.be32),
  v1Proto(_Framing.be32),
  v2Proto(_Framing.varint);

  const _PairMode(this.framing);
  final _Framing framing;
}

/// Roda em isolate: gerar RSA 2048 em Dart puro leva alguns segundos.
List<String> _generateIdentity(int _) {
  final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
  final priv = pair.privateKey as RSAPrivateKey;
  final pub = pair.publicKey as RSAPublicKey;
  final csr = X509Utils.generateRsaCsrPem({'CN': 'orbita', 'O': 'Orbita'}, priv, pub);
  final cert = X509Utils.generateSelfSignedCertificate(priv, csr, 3650);
  final key = CryptoUtils.encodeRSAPrivateKeyToPem(priv);
  return [cert, key];
}

class _PairSession {
  _PairSession(this.ch, this.server, this.client, this.host, this.mode);
  final _Channel ch;
  final _Rsa server;
  final _Rsa client;
  final String host;
  final _PairMode mode;
}

/// Canal com mensagens enquadradas por varint (v2), 4 bytes big-endian (v1 pair) ou cabeçalho v1 (v1 remote).
class _Channel {
  _Channel(this.socket, [this.framing = _Framing.varint]) {
    socket.listen(
      (d) {
        _data.addAll(d);
        _drain();
      },
      onDone: _closed,
      onError: (_) => _closed(),
      cancelOnError: true,
    );
  }

  final SecureSocket socket;
  final _Framing framing;
  final List<int> _data = [];
  final List<Uint8List> _queue = [];
  Completer<Uint8List>? _waiter;
  bool isClosed = false;
  void Function(Uint8List)? onMessage;
  void Function()? onClose;

  void _drain() {
    while (true) {
      Uint8List? msg;
      if (framing == _Framing.be32) {
        if (_data.length < 4) return;
        final len = (_data[0] << 24) | (_data[1] << 16) | (_data[2] << 8) | _data[3];
        if (len < 0 || len > 65536 || _data.length < 4 + len) return;
        msg = Uint8List.fromList(_data.sublist(4, 4 + len));
        _data.removeRange(0, 4 + len);
      } else if (framing == _Framing.v1Remote) {
        if (_data.length < 4) return;
        final len = (_data[2] << 8) | _data[3];
        if (_data.length < 4 + len) return;
        msg = Uint8List.fromList(_data.sublist(0, 4 + len));
        _data.removeRange(0, 4 + len);
      } else {
        var len = 0, shift = 0, i = 0;
        var ok = false;
        while (i < _data.length) {
          final b = _data[i++];
          len |= (b & 0x7f) << shift;
          shift += 7;
          if (b & 0x80 == 0) {
            ok = true;
            break;
          }
        }
        if (!ok || _data.length < i + len) return;
        msg = Uint8List.fromList(_data.sublist(i, i + len));
        _data.removeRange(0, i + len);
      }

      if (onMessage != null) {
        onMessage!(msg);
      } else if (_waiter != null) {
        final w = _waiter!;
        _waiter = null;
        w.complete(msg);
      } else {
        _queue.add(msg);
      }
    }
  }

  void _closed() {
    isClosed = true;
    _waiter?.completeError(StateError('conexão fechada pela TV'));
    _waiter = null;
    onClose?.call();
  }

  Future<Uint8List> next({Duration timeout = const Duration(seconds: 15)}) {
    if (_queue.isNotEmpty) return Future.value(_queue.removeAt(0));
    if (isClosed) return Future.error(StateError('conexão fechada pela TV'));
    final w = Completer<Uint8List>();
    _waiter = w;
    return w.future.timeout(timeout);
  }

  void send(Uint8List msg) {
    if (isClosed) throw StateError('conexão fechada');
    if (framing == _Framing.be32) {
      final n = msg.length;
      socket.add(Uint8List.fromList([
        (n >> 24) & 0xff,
        (n >> 16) & 0xff,
        (n >> 8) & 0xff,
        n & 0xff,
        ...msg,
      ]));
    } else if (framing == _Framing.v1Remote) {
      socket.add(msg);
    } else {
      socket.add(Uint8List.fromList([..._varint(msg.length), ...msg]));
    }
  }
}

Uint8List _jsonBytes(Map<String, Object?> map) =>
    Uint8List.fromList(utf8.encode(jsonEncode(map)));

Map<String, Object?> _parseJson(Uint8List b) =>
    (jsonDecode(utf8.decode(b, allowMalformed: true)) as Map).cast<String, Object?>();

// ----- protobuf mínimo
Uint8List _varint(int v) {
  final o = <int>[];
  while (v > 0x7f) {
    o.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  o.add(v);
  return Uint8List.fromList(o);
}

Uint8List _fVar(int f, int v) =>
    Uint8List.fromList([..._varint(f << 3), ..._varint(v)]);

Uint8List _fBytes(int f, List<int> b) => Uint8List.fromList(
    [..._varint((f << 3) | 2), ..._varint(b.length), ...b]);

Uint8List _cat(List<Uint8List> parts) {
  final b = BytesBuilder();
  for (final p in parts) {
    b.add(p);
  }
  return b.toBytes();
}

/// Decodifica campos de nível único: número do campo -> int ou Uint8List.
Map<int, Object> _decode(Uint8List b) {
  final out = <int, Object>{};
  var i = 0;
  int readVarint() {
    var v = 0, shift = 0;
    while (i < b.length) {
      final x = b[i++];
      v |= (x & 0x7f) << shift;
      shift += 7;
      if (x & 0x80 == 0) break;
    }
    return v;
  }

  while (i < b.length) {
    final key = readVarint();
    final f = key >> 3;
    switch (key & 7) {
      case 0:
        out[f] = readVarint();
      case 2:
        final n = readVarint();
        out[f] = Uint8List.sublistView(b, i, min(i + n, b.length));
        i += n;
      case 1:
        i += 8;
      case 5:
        i += 4;
      default:
        return out;
    }
  }
  return out;
}

/// Polo OuterMessage (v1): protocol_version=1, status=200, type=field, payload=bytes.
Uint8List _om(int type, Uint8List payload) =>
    _cat([_fVar(1, 1), _fVar(2, 200), _fVar(3, type), _fBytes(4, payload)]);

/// PairingMessage (v2): protocol_version=2, status=200 (OK) + payload.
Uint8List _pm(int field, Uint8List payload) =>
    _cat([_fVar(1, 2), _fVar(2, 200), _fBytes(field, payload)]);

/// RemoteMessage.remote_key_inject { key_code, direction = SHORT(3) }.
Uint8List _keyMsg(int code) => _fBytes(10, _cat([_fVar(1, code), _fVar(2, 3)]));

Uint8List _hexBytes(String s) {
  final out = <int>[];
  for (var i = 0; i + 1 < s.length; i += 2) {
    out.add(int.parse(s.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(out);
}

// ----- DER mínimo: extrai módulo e expoente RSA de um certificado X.509
class _Rsa {
  _Rsa(this.n, this.e);
  final Uint8List n;
  final Uint8List e;
}

class _Tlv {
  _Tlv(this.tag, this.body, this.end);
  final int tag;
  final int body;
  final int end;
}

_Tlv _tlv(Uint8List b, int off) {
  final tag = b[off];
  var len = b[off + 1];
  var p = off + 2;
  if (len & 0x80 != 0) {
    final n = len & 0x7f;
    len = 0;
    for (var i = 0; i < n; i++) {
      len = (len << 8) | b[p++];
    }
  }
  return _Tlv(tag, p, p + len);
}

Uint8List _pemToDer(String pem) {
  final b64 = pem
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('-----'))
      .join();
  return base64.decode(b64);
}

_Rsa _rsaFromDer(Uint8List der) {
  final cert = _tlv(der, 0);
  final tbs = _tlv(der, cert.body);
  var p = tbs.body;
  final first = _tlv(der, p);
  if (first.tag == 0xA0) p = first.end; // versão explícita
  for (var i = 0; i < 5; i++) {
    p = _tlv(der, p).end; // serial, algoritmo, emissor, validade, sujeito
  }
  final spki = _tlv(der, p);
  final alg = _tlv(der, spki.body);
  final bits = _tlv(der, alg.end);
  final seq = _tlv(der, bits.body + 1); // pula o byte de bits não usados
  final nT = _tlv(der, seq.body);
  final eT = _tlv(der, nT.end);
  Uint8List strip(_Tlv t) {
    var s = t.body;
    while (s < t.end - 1 && der[s] == 0) {
      s++;
    }
    return Uint8List.fromList(der.sublist(s, t.end));
  }

  return _Rsa(strip(nT), strip(eT));
}
