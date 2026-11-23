# Órbita — Android TV Remote (Flutter)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.3+-0175C2?style=flat-square&logo=dart)](https://dart.dev)

Controle remoto para Android TV e TV Box implementado em Flutter usando o protocolo oficial **Android TV Remote v2** sobre sockets locais.

## Destaques

- **Sem ADB ou modo desenvolvedor**: comunica diretamente nas portas `6467` (pareamento) e `6466` (controle), como o app oficial do Google TV.
- **Pareamento seguro**: na primeira conexão, a TV exibe um código de 6 caracteres para autenticação.
- **Modo Demo**: permite testar a interface sem precisar de uma TV física conectada.

## Requisitos

- Flutter SDK (Dart `>=3.3.0 <4.0.0`)

## Como usar

### Testar a interface (Modo Demo)

```bash
flutter run --dart-define=DEMO=true
```

### Gerar o APK de release

```bash
./build.sh
```

O APK será gerado em `build/app/outputs/flutter-apk/app-release.apk`.
