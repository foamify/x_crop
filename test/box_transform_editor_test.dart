import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x_crop/box_transform.dart';
import 'package:x_crop/box_transform_editor.dart';

Widget buildEditor({BoxTransformConfig config = const BoxTransformConfig()}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 800,
        child: BoxTransformEditor(config: config),
      ),
    ),
  );
}

void main() {
  testWidgets('renders all handles and content labels', (tester) async {
    await tester.pumpWidget(buildEditor());

    for (final handle in ResizeHandle.values) {
      expect(find.byKey(ValueKey('resize-${handle.name}')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('rotation-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('rotation-1')), findsNothing);
    for (final label in ['TL', 'TR', 'BR', 'BL']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('body drag completes without exception', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.dragFrom(const Offset(400, 400), const Offset(50, 50));
    await tester.pump();
  });

  testWidgets('fourCorners layout renders four rotation handles',
      (tester) async {
    await tester.pumpWidget(buildEditor(
        config: const BoxTransformConfig(
            rotationHandleLayout: RotationHandleLayout.fourCorners)));
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('rotation-$i')), findsOneWidget);
    }
  });
}
