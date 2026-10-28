import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:handicraft_app/app/business_app.dart';
import 'package:handicraft_app/data/business_database.dart';

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.repository,
    this.cameras = const [],
  });

  final BusinessRepository? repository;
  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handicraft Business',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF39745A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE9EDE7)),
          ),
        ),
      ),
      home: BusinessApp(repository: repository, cameras: cameras),
    );
  }
}
