#!/usr/bin/env bash
# Gera o projeto Android e compila o APK. Requer Flutter instalado.
set -e
cd "$(dirname "$0")"
[ -d android ] || flutter create --platforms=android --project-name tv_remote --org br.com.winston .
# permissões de rede (o manifest de release não traz INTERNET por padrão)
M=android/app/src/main/AndroidManifest.xml
grep -q "android.permission.INTERNET" "$M" || sed -i 's|<application|<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>\n    <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>\n    <application|' "$M"
sed -i 's|android:label="[^"]*"|android:label="Órbita"|' "$M"
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
echo "APK: build/app/outputs/flutter-apk/app-release.apk"
