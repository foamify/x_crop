import 'package:flutter/material.dart';
import 'box_transform_editor.dart';

void main() => runApp(const MainApp());

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: BoxTransformEditor(),
      ),
    );
  }
}
