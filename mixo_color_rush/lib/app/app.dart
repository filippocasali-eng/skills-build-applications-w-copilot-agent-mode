import 'package:flutter/material.dart';

/// Root widget of MIXO: Color Rush.
class MixoApp extends StatelessWidget {
  const MixoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MIXO: Color Rush',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF7C4DFF),
        useMaterial3: true,
      ),
      home: const Scaffold(body: Center(child: Text('MIXO: Color Rush'))),
    );
  }
}
