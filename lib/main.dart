import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
  runApp(const PxlrApp());
}

class PxlrApp extends StatelessWidget {
  const PxlrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PXLR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050506),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
