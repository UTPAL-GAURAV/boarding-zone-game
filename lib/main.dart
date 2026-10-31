import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home/boarding_home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BoardingZoneApp());
}

class BoardingZoneApp extends StatelessWidget {
  const BoardingZoneApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Boarding Zone',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF2F4F8),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5EB8E8),
        brightness: Brightness.light,
      ),
      fontFamily: 'sans-serif',
    ),
    home: const BoardingHomeShell(),
    builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFFF2F4F8),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: child!,
    ),
  );
}
