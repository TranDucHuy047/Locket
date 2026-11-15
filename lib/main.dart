import 'package:flutter/material.dart';

import 'screens/studio_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LocketStudioApp());
}

class LocketStudioApp extends StatelessWidget {
  const LocketStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Locket Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB800),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
      ),
      home: const StudioHomeScreen(),
    );
  }
}
