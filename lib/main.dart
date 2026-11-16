import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/remote_screen.dart';
import 'state/remote_controller.dart';
import 'theme.dart';
import 'transport/android_tv_transport.dart';
import 'transport/tv_transport.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Palette.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Para testar só a interface: flutter run --dart-define=DEMO=true
  const demo = bool.fromEnvironment('DEMO');
  final controller =
      RemoteController(demo ? DemoTransport() : AndroidTvTransport());
  await controller.init();

  runApp(RemoteScope(
    controller: controller,
    child: MaterialApp(
      title: 'Órbita',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const RemoteScreen(),
    ),
  ));
}
