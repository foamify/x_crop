import 'package:flutter/material.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'box_transform_editor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pointerLock.ensureInitialized();
  runApp(const MainApp());
}

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
