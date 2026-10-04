import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointer_lock/pointer_lock.dart';
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

Future<TestGesture> hoverAt(WidgetTester tester, Offset position) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: position);
  await gesture.moveTo(position);
  return gesture;
}

PointerLockDragArea areaFor(WidgetTester tester, ResizeHandle handle) {
  return tester.widget<PointerLockDragArea>(find.descendant(
    of: find.byKey(ValueKey('resize-${handle.name}')),
    matching: find.byType(PointerLockDragArea),
  ));
}

Future<void> lockHandle(
    WidgetTester tester, ResizeHandle handle, Offset position) async {
  areaFor(tester, handle).onLock!(PointerLockDragLockDetails(
      trigger: PointerDownEvent(position: position)));
  await tester.pump();
}

Future<void> moveHandle(WidgetTester tester, ResizeHandle handle,
    Offset position, Offset delta) async {
  areaFor(tester, handle).onMove!(PointerLockDragMoveDetails(
    trigger: PointerDownEvent(position: position),
    move: PointerLockMoveEvent(delta: delta),
  ));
  await tester.pump();
}

Future<void> unlockHandle(
    WidgetTester tester, ResizeHandle handle, Offset position) async {
  areaFor(tester, handle).onUnlock!(PointerLockDragUnlockDetails(
      trigger: PointerDownEvent(position: position)));
  await tester.pump();
}

void main() {
  testWidgets('renders all handles, frame, and no old labels', (tester) async {
    await tester.pumpWidget(buildEditor());

    for (final handle in ResizeHandle.values) {
      expect(find.byKey(ValueKey('resize-${handle.name}')), findsOneWidget);
      expect(
          find.byKey(ValueKey('handle-face-${handle.name}')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('rotation-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('transform-frame')), findsOneWidget);
    for (final label in ['TL', 'TR', 'BR', 'BL']) {
      expect(find.text(label), findsNothing);
    }

    final lockAreas = find.byType(PointerLockDragArea);
    expect(lockAreas, findsNWidgets(8));
    for (final element in lockAreas.evaluate()) {
      expect((element.widget as PointerLockDragArea).cursor,
          PointerLockCursor.hidden);
    }
  });

  testWidgets('handle faces are centered on their geometry positions',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    const expected = {
      ResizeHandle.topLeft: Offset(350, 325),
      ResizeHandle.top: Offset(400, 325),
      ResizeHandle.topRight: Offset(450, 325),
      ResizeHandle.right: Offset(450, 400),
      ResizeHandle.bottomRight: Offset(450, 475),
      ResizeHandle.bottom: Offset(400, 475),
      ResizeHandle.bottomLeft: Offset(350, 475),
      ResizeHandle.left: Offset(350, 400),
    };
    for (final entry in expected.entries) {
      final center = tester
          .getCenter(find.byKey(ValueKey('handle-face-${entry.key.name}')));
      expect(center.dx, closeTo(entry.value.dx, 1e-9));
      expect(center.dy, closeTo(entry.value.dy, 1e-9));
    }
  });

  testWidgets('hover alone does not show dimension fields', (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    await tester.pump();

    expect(find.byKey(const ValueKey('dimension-width')), findsNothing);
    expect(find.byKey(const ValueKey('dimension-height')), findsNothing);
    await gesture.removePointer();
  });

  testWidgets('click shows fields; stays while hovered; hides after leave',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    await tester.pump();

    await lockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    expect(find.byKey(const ValueKey('dimension-width')), findsOneWidget);
    expect(find.byKey(const ValueKey('dimension-height')), findsOneWidget);

    await unlockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    expect(find.byKey(const ValueKey('dimension-width')), findsOneWidget);
    expect(find.byKey(const ValueKey('dimension-height')), findsOneWidget);

    await gesture.moveTo(const Offset(700, 700));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('dimension-width')), findsNothing);
    expect(find.byKey(const ValueKey('dimension-height')), findsNothing);
    await gesture.removePointer();
  });

  testWidgets('midpoint click shows only the movement-dimension field',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(450, 400));
    await lockHandle(tester, ResizeHandle.right, const Offset(450, 400));
    expect(find.byKey(const ValueKey('dimension-width')), findsOneWidget);
    expect(find.byKey(const ValueKey('dimension-height')), findsNothing);
    await unlockHandle(tester, ResizeHandle.right, const Offset(450, 400));

    await gesture.moveTo(const Offset(400, 325));
    await tester.pump();
    await lockHandle(tester, ResizeHandle.top, const Offset(400, 325));
    expect(find.byKey(const ValueKey('dimension-height')), findsOneWidget);
    expect(find.byKey(const ValueKey('dimension-width')), findsNothing);
    await gesture.removePointer();
  });

  testWidgets('virtual pointer handle tracks accumulated deltas',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    const key = ValueKey('virtual-pointer-handle');

    expect(find.byKey(key), findsNothing);

    await lockHandle(tester, ResizeHandle.topLeft, const Offset(354, 329));
    expect(find.byKey(key), findsOneWidget);
    final first = tester.getCenter(find.byKey(key));
    expect(first.dx, closeTo(350, 1e-9));
    expect(first.dy, closeTo(325, 1e-9));

    await moveHandle(tester, ResizeHandle.topLeft, const Offset(354, 329),
        const Offset(24, -12));
    final second = tester.getCenter(find.byKey(key));
    expect(second.dx, closeTo(374, 1e-9));
    expect(second.dy, closeTo(313, 1e-9));

    await moveHandle(tester, ResizeHandle.topLeft, const Offset(354, 329),
        const Offset(-4, 7));
    final third = tester.getCenter(find.byKey(key));
    expect(third.dx, closeTo(370, 1e-9));
    expect(third.dy, closeTo(320, 1e-9));

    await unlockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    expect(find.byKey(key), findsNothing);
    await gesture.removePointer();
  });

  testWidgets('fields center on dashed path when they fit', (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    await lockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    await unlockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));

    final heightCenter =
        tester.getCenter(find.byKey(const ValueKey('dimension-height')));
    expect(heightCenter.dx, closeTo(350, 1e-9));

    final widthCenter =
        tester.getCenter(find.byKey(const ValueKey('dimension-width')));
    expect(widthCenter.dy, lessThan(325));

    await gesture.moveTo(const Offset(450, 400));
    await tester.pump();
    await lockHandle(tester, ResizeHandle.right, const Offset(450, 400));
    await unlockHandle(tester, ResizeHandle.right, const Offset(450, 400));

    final midWidthCenter =
        tester.getCenter(find.byKey(const ValueKey('dimension-width')));
    expect(midWidthCenter.dx, closeTo(450, 1e-9));
    await gesture.removePointer();
  });

  testWidgets('width field moves onto the dashed path once it fits',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    await lockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    await unlockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));

    final field = find.descendant(
      of: find.byKey(const ValueKey('dimension-width')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '300');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final widthCenter =
        tester.getCenter(find.byKey(const ValueKey('dimension-width')));
    expect(widthCenter.dy, closeTo(325, 1e-9));
    await gesture.removePointer();
  });

  testWidgets('fields keep 12px visible clearance from handle faces',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    await lockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    await unlockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));

    final handleRect =
        tester.getRect(find.byKey(const ValueKey('handle-face-topLeft')));
    final widthRect =
        tester.getRect(find.byKey(const ValueKey('dimension-width')));
    final heightRect =
        tester.getRect(find.byKey(const ValueKey('dimension-height')));
    expect(handleRect.top - widthRect.bottom, greaterThanOrEqualTo(12 - 1e-9));
    expect(heightRect.top - handleRect.bottom, greaterThanOrEqualTo(12 - 1e-9));

    await gesture.moveTo(const Offset(450, 400));
    await tester.pump();
    await lockHandle(tester, ResizeHandle.right, const Offset(450, 400));
    await unlockHandle(tester, ResizeHandle.right, const Offset(450, 400));

    final rightHandleRect =
        tester.getRect(find.byKey(const ValueKey('handle-face-right')));
    final rightWidthRect =
        tester.getRect(find.byKey(const ValueKey('dimension-width')));
    expect(rightHandleRect.top - rightWidthRect.bottom,
        greaterThanOrEqualTo(12 - 1e-9));
    await gesture.removePointer();
  });

  testWidgets('selected handle remaps to the flipped physical handle',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(450, 325));
    const trFace = ValueKey('handle-face-topRight');
    const tlFace = ValueKey('handle-face-topLeft');
    const ghost = ValueKey('virtual-pointer-handle');

    await lockHandle(tester, ResizeHandle.topRight, const Offset(450, 325));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getSize(find.byKey(trFace)), const Size(26, 26));
    expect(tester.getSize(find.byKey(tlFace)), const Size(14, 14));

    await moveHandle(tester, ResizeHandle.topRight, const Offset(450, 325),
        const Offset(-110, 0));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getSize(find.byKey(trFace)), const Size(14, 14));
    expect(tester.getSize(find.byKey(tlFace)), const Size(26, 26));
    expect(find.byKey(ghost), findsOneWidget);
    final ghostCenter = tester.getCenter(find.byKey(ghost));
    expect(ghostCenter.dx, closeTo(340, 1e-9));
    expect(ghostCenter.dy, closeTo(325, 1e-9));
    expect(find.byKey(const ValueKey('dimension-width')), findsOneWidget);
    expect(find.byKey(const ValueKey('dimension-height')), findsOneWidget);

    await moveHandle(tester, ResizeHandle.topRight, const Offset(450, 325),
        const Offset(120, 0));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getSize(find.byKey(trFace)), const Size(26, 26));
    expect(tester.getSize(find.byKey(tlFace)), const Size(14, 14));

    await unlockHandle(tester, ResizeHandle.topRight, const Offset(450, 325));
    expect(find.byKey(ghost), findsNothing);
    await gesture.removePointer();
  });

  testWidgets('width field accepts a submitted dimension', (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    await lockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    await unlockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));

    final field = find.descendant(
      of: find.byKey(const ValueKey('dimension-width')),
      matching: find.byType(TextField),
    );
    expect(field, findsOneWidget);

    await tester.enterText(field, '123.5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(tester.widget<TextField>(field).controller!.text, '123.5');
    await gesture.removePointer();
  });

  testWidgets('empty submitted dimension restores current value',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    await lockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    await unlockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));

    final field = find.descendant(
      of: find.byKey(const ValueKey('dimension-width')),
      matching: find.byType(TextField),
    );
    expect(field, findsOneWidget);

    await tester.enterText(field, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(tester.widget<TextField>(field).controller!.text, '100.0');
    await gesture.removePointer();
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
