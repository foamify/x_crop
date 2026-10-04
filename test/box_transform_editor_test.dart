import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:x_crop/box_transform.dart';
import 'package:x_crop/box_transform_editor.dart';
import 'package:x_crop/src/box_transform/drag_to_pointer_lock_area.dart';
import 'package:x_crop/src/box_transform/modifier_state.dart';
import 'package:x_crop/src/box_transform/pointer_warp.dart';

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

PointerLockDragArea rotationAreaFor(WidgetTester tester, int index) {
  return tester.widget<PointerLockDragArea>(find.descendant(
    of: find.byKey(ValueKey('rotation-$index')),
    matching: find.byType(PointerLockDragArea),
  ));
}

Future<void> lockRotation(WidgetTester tester, int index) async {
  final position =
      tester.getCenter(find.byKey(ValueKey('rotation-face-$index')));
  rotationAreaFor(tester, index).onLock!(PointerLockDragLockDetails(
      trigger: PointerDownEvent(position: position)));
  await tester.pump();
}

Future<void> moveRotation(WidgetTester tester, int index, Offset delta) async {
  final position =
      tester.getCenter(find.byKey(ValueKey('rotation-face-$index')));
  rotationAreaFor(tester, index).onMove!(PointerLockDragMoveDetails(
    trigger: PointerDownEvent(position: position),
    move: PointerLockMoveEvent(delta: delta),
  ));
  await tester.pump();
}

Future<void> unlockRotation(WidgetTester tester, int index) async {
  final position =
      tester.getCenter(find.byKey(ValueKey('rotation-face-$index')));
  rotationAreaFor(tester, index).onUnlock!(PointerLockDragUnlockDetails(
      trigger: PointerDownEvent(position: position)));
  await tester.pump();
}

List<Offset> mockWarpCalls() {
  final calls = <Offset>[];
  debugPointerWarpDelegate = (normalized) async => calls.add(normalized);
  addTearDown(() => debugPointerWarpDelegate = null);
  return calls;
}

void main() {
  setUp(() {
    debugPointerWarpDelegate = (_) async {};
    debugPlatformModifierStateReader =
        () => (shiftPressed: false, altPressed: false);
  });
  tearDown(() {
    debugPointerWarpDelegate = null;
    debugPlatformModifierStateReader = null;
  });

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

    for (final handle in ResizeHandle.values) {
      final area = find.descendant(
        of: find.byKey(ValueKey('resize-${handle.name}')),
        matching: find.byType(PointerLockDragArea),
      );
      expect(area, findsOneWidget);
      expect(tester.widget<PointerLockDragArea>(area).cursor,
          PointerLockCursor.hidden);
    }

    final rotationArea = find.descendant(
      of: find.byKey(const ValueKey('rotation-0')),
      matching: find.byType(PointerLockDragArea),
    );
    expect(rotationArea, findsOneWidget);
    expect(tester.widget<PointerLockDragArea>(rotationArea).cursor,
        PointerLockCursor.hidden);
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('rotation-0')),
          matching: find.byType(DragToPointerLockArea),
        ),
        findsNothing);
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
    await tester.pump(const Duration(milliseconds: 420));
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

  testWidgets(
      'corner fields follow the dashed path and midpoint fields sit inside',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    await lockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    await unlockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));

    final heightCenter =
        tester.getCenter(find.byKey(const ValueKey('dimension-height')));
    expect(heightCenter.dx, closeTo(350, 1e-9));

    final widthCenter =
        tester.getCenter(find.byKey(const ValueKey('dimension-width')));
    expect(widthCenter.dy, closeTo(325, 1e-9));
    expect(widthCenter.dx, lessThan(350));

    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('dimension-width')),
            matching: find.byType(TextField)),
        '300');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final rightHandle =
        tester.getCenter(find.byKey(const ValueKey('handle-face-right')));
    await gesture.moveTo(rightHandle);
    await tester.pump();
    await lockHandle(tester, ResizeHandle.right, rightHandle);
    await unlockHandle(tester, ResizeHandle.right, rightHandle);
    await tester.pump(const Duration(milliseconds: 300));

    final midWidthCenter =
        tester.getCenter(find.byKey(const ValueKey('dimension-width')));
    final midHandleCenter =
        tester.getCenter(find.byKey(const ValueKey('handle-face-right')));
    expect(midWidthCenter.dx, lessThan(midHandleCenter.dx));
    expect(midWidthCenter.dy, closeTo(midHandleCenter.dy, 1e-9));
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
    await tester.pump(const Duration(milliseconds: 600));

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
    expect(handleRect.left - widthRect.right, greaterThanOrEqualTo(12 - 1e-9));
    expect(widthRect.center.dy, closeTo(handleRect.center.dy, 1e-9));
    expect(heightRect.top - handleRect.bottom, greaterThanOrEqualTo(12 - 1e-9));

    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('dimension-width')),
            matching: find.byType(TextField)),
        '300');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final rightHandle =
        tester.getCenter(find.byKey(const ValueKey('handle-face-right')));
    await gesture.moveTo(rightHandle);
    await tester.pump();
    await lockHandle(tester, ResizeHandle.right, rightHandle);
    await unlockHandle(tester, ResizeHandle.right, rightHandle);

    final rightHandleRect =
        tester.getRect(find.byKey(const ValueKey('handle-face-right')));
    final rightWidthRect =
        tester.getRect(find.byKey(const ValueKey('dimension-width')));
    expect(rightHandleRect.left - rightWidthRect.right,
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
    await tester.pump(const Duration(milliseconds: 600));

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
      expect(find.byKey(ValueKey('rotation-face-$i')), findsOneWidget);
    }
  });

  testWidgets('rotation handle renders centered and inactive', (tester) async {
    await tester.pumpWidget(buildEditor());
    final center =
        tester.getCenter(find.byKey(const ValueKey('rotation-face-0')));
    expect(center.dx, closeTo(400, 1e-9));
    expect(center.dy, closeTo(301, 1e-9));
    expect(tester.getSize(find.byKey(const ValueKey('rotation-face-0'))),
        const Size(10, 10));
  });

  testWidgets(
      'rotation handle mouse-down activates, drag shows ghost, updates field, and hides on leave',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(400, 301));
    const face = ValueKey('rotation-face-0');
    const ghost = ValueKey('virtual-rotation-handle');
    const field = ValueKey('rotation-value');

    expect(find.byKey(field), findsNothing);

    await lockRotation(tester, 0);
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getSize(find.byKey(face)), const Size(26, 26));
    expect(find.byKey(field), findsOneWidget);
    expect(find.byKey(ghost), findsOneWidget);
    expect(tester.getCenter(find.byKey(ghost)), const Offset(400, 301));
    expect(
        tester.widget(find.byKey(const ValueKey('rotation-field-drag-area'))),
        isA<DragToPointerLockArea>());

    await moveRotation(tester, 0, const Offset(50, 49));
    expect(tester.getCenter(find.byKey(ghost)), const Offset(450, 350));
    final fieldWidget = tester.widget<TextField>(find.descendant(
        of: find.byKey(field), matching: find.byType(TextField)));
    expect(fieldWidget.controller!.text, '45.0');

    await gesture.moveTo(tester.getCenter(find.byKey(field)));
    await tester.pump();
    await unlockRotation(tester, 0);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(ghost), findsNothing);
    expect(tester.getSize(find.byKey(face)), const Size(10, 10));
    expect(find.byKey(field), findsOneWidget);

    await tester.tap(find.byKey(field));
    await tester.pump();
    expect(find.byKey(ghost), findsNothing);
    expect(tester.getSize(find.byKey(face)), const Size(10, 10));

    final textField = find.descendant(
        of: find.byKey(field), matching: find.byType(TextField));
    await tester.enterText(textField, '270');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<TextField>(textField).controller!.text, '-90.0');

    await gesture.moveTo(const Offset(700, 700));
    await tester.pump(const Duration(milliseconds: 420));
    expect(find.byKey(field), findsNothing);
    await gesture.removePointer();
  });

  testWidgets('resize unlock warps pointer to the remapped handle center',
      (tester) async {
    final calls = mockWarpCalls();
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(450, 325));
    final rootSize = tester.getSize(find.byType(BoxTransformEditor));

    await lockHandle(tester, ResizeHandle.topRight, const Offset(450, 325));
    await moveHandle(tester, ResizeHandle.topRight, const Offset(450, 325),
        const Offset(-110, 0));

    final expected =
        tester.getCenter(find.byKey(const ValueKey('handle-face-topLeft')));

    await unlockHandle(tester, ResizeHandle.topRight, const Offset(450, 325));

    expect(calls, hasLength(1));
    expect(calls.single.dx, closeTo(expected.dx / rootSize.width, 1e-9));
    expect(calls.single.dy, closeTo(expected.dy / rootSize.height, 1e-9));
    await gesture.removePointer();
  });

  testWidgets('resize unlock clamps warped pointer to the window',
      (tester) async {
    final calls = mockWarpCalls();
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(450, 400));
    final rootSize = tester.getSize(find.byType(BoxTransformEditor));

    await lockHandle(tester, ResizeHandle.right, const Offset(450, 400));
    await moveHandle(tester, ResizeHandle.right, const Offset(450, 400),
        const Offset(500, 0));
    final handleCenter =
        tester.getCenter(find.byKey(const ValueKey('handle-face-right')));
    expect(handleCenter.dx, greaterThan(800));

    await unlockHandle(tester, ResizeHandle.right, const Offset(450, 400));

    expect(calls, hasLength(1));
    expect(calls.single.dx, 1.0);
    expect(calls.single.dy, closeTo(handleCenter.dy / rootSize.height, 1e-9));
    await gesture.removePointer();
  });

  testWidgets('rotation unlock warps to the current geometric handle',
      (tester) async {
    final calls = mockWarpCalls();
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(400, 301));
    final rootSize = tester.getSize(find.byType(BoxTransformEditor));

    await lockRotation(tester, 0);
    await moveRotation(tester, 0, const Offset(50, 49));

    final ghostCenter =
        tester.getCenter(find.byKey(const ValueKey('virtual-rotation-handle')));
    expect(ghostCenter, const Offset(450, 350));
    final handleCenter =
        tester.getCenter(find.byKey(const ValueKey('rotation-face-0')));
    expect(handleCenter, isNot(ghostCenter));

    await unlockRotation(tester, 0);

    expect(calls, hasLength(1));
    expect(calls.single.dx, closeTo(handleCenter.dx / rootSize.width, 1e-9));
    expect(calls.single.dy, closeTo(handleCenter.dy / rootSize.height, 1e-9));
    await gesture.removePointer();
  });

  testWidgets('warp ignores non-finite positions and empty windows',
      (tester) async {
    final calls = mockWarpCalls();
    const size = Size(800, 600);
    await warpPointerInWindow(const Offset(400, 300), size);
    expect(calls, hasLength(1));
    expect(calls.single, const Offset(0.5, 0.5));

    await warpPointerInWindow(const Offset(double.nan, 300), size);
    await warpPointerInWindow(const Offset(400, double.infinity), size);
    await warpPointerInWindow(const Offset(400, 300), Size.zero);
    expect(calls, hasLength(1));
  });

  testWidgets('dimension fields fade in fast and fade out slower',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    const fadeKey = ValueKey('dimension-width-fade');
    const fieldKey = ValueKey('dimension-width');

    await lockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    final fadeIn =
        tester.widget<TweenAnimationBuilder<double>>(find.byKey(fadeKey));
    expect(fadeIn.duration, const Duration(milliseconds: 140));

    await tester.pump(const Duration(milliseconds: 70));
    final midOpacity = tester.widget<Opacity>(find.descendant(
        of: find.byKey(fadeKey), matching: find.byType(Opacity)));
    expect(midOpacity.opacity, greaterThan(0));
    expect(midOpacity.opacity, lessThan(1));
    await tester.pump(const Duration(milliseconds: 140));
    final fullOpacity = tester.widget<Opacity>(find.descendant(
        of: find.byKey(fadeKey), matching: find.byType(Opacity)));
    expect(fullOpacity.opacity, 1.0);

    await unlockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    await gesture.moveTo(const Offset(700, 700));
    await tester.pump(const Duration(milliseconds: 120));
    final fadeOut =
        tester.widget<TweenAnimationBuilder<double>>(find.byKey(fadeKey));
    expect(fadeOut.duration, const Duration(milliseconds: 260));
    expect(find.byKey(fieldKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 260));
    expect(find.byKey(fieldKey), findsNothing);
    await gesture.removePointer();
  });

  testWidgets('rotation field fades in and out', (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(400, 301));
    const fadeKey = ValueKey('rotation-value-fade');
    const fieldKey = ValueKey('rotation-value');

    await lockRotation(tester, 0);
    final fadeIn =
        tester.widget<TweenAnimationBuilder<double>>(find.byKey(fadeKey));
    expect(fadeIn.duration, const Duration(milliseconds: 140));

    await gesture.moveTo(tester.getCenter(find.byKey(fieldKey)));
    await tester.pump();
    await unlockRotation(tester, 0);
    await gesture.moveTo(const Offset(700, 700));
    await tester.pump(const Duration(milliseconds: 120));
    final fadeOut =
        tester.widget<TweenAnimationBuilder<double>>(find.byKey(fadeKey));
    expect(fadeOut.duration, const Duration(milliseconds: 260));
    expect(find.byKey(fieldKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 260));
    expect(find.byKey(fieldKey), findsNothing);
    await gesture.removePointer();
  });

  testWidgets('typed width animates bounds smoothly to the target',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    await lockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    await unlockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));

    final field = find.descendant(
      of: find.byKey(const ValueKey('dimension-width')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '200');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final leftCenter =
        tester.getCenter(find.byKey(const ValueKey('handle-face-left')));
    expect(leftCenter.dx, greaterThan(250));
    expect(leftCenter.dx, lessThan(350));
    final rightCenter =
        tester.getCenter(find.byKey(const ValueKey('handle-face-right')));
    expect(rightCenter.dx, closeTo(450, 1e-9));

    await tester.pump(const Duration(milliseconds: 600));
    final leftFinal =
        tester.getCenter(find.byKey(const ValueKey('handle-face-left')));
    expect(leftFinal.dx, closeTo(250, 1e-9));
    expect(tester.widget<TextField>(field).controller!.text, '200.0');
    await gesture.removePointer();
  });

  testWidgets('typed rotation animates smoothly to the target', (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(400, 301));
    const face = ValueKey('rotation-face-0');
    const fieldKey = ValueKey('rotation-value');

    await lockRotation(tester, 0);
    await gesture.moveTo(tester.getCenter(find.byKey(fieldKey)));
    await tester.pump();
    await unlockRotation(tester, 0);

    final textField = find.descendant(
        of: find.byKey(fieldKey), matching: find.byType(TextField));
    await tester.enterText(textField, '90');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final mid = tester.getCenter(find.byKey(face));
    expect(mid.dx, greaterThan(400));
    expect(mid.dx, lessThan(499));
    expect(mid.dy, greaterThan(301));
    expect(mid.dy, lessThan(400));

    await tester.pump(const Duration(milliseconds: 200));
    final end = tester.getCenter(find.byKey(face));
    expect(end.dx, closeTo(499, 1e-9));
    expect(end.dy, closeTo(400, 1e-9));
    expect(tester.widget<TextField>(textField).controller!.text, '90.0');
    await gesture.removePointer();
  });

  testWidgets('a new gesture interrupts an in-flight typed animation',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    await lockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    await unlockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));

    final field = find.descendant(
      of: find.byKey(const ValueKey('dimension-width')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '200');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final midLeft =
        tester.getCenter(find.byKey(const ValueKey('handle-face-left')));
    expect(midLeft.dx, greaterThan(250));
    expect(midLeft.dx, lessThan(350));

    await lockHandle(tester, ResizeHandle.topLeft, midLeft);
    await unlockHandle(tester, ResizeHandle.topLeft, midLeft);
    await tester.pump(const Duration(milliseconds: 600));

    final afterLeft =
        tester.getCenter(find.byKey(const ValueKey('handle-face-left')));
    expect(afterLeft.dx, closeTo(midLeft.dx, 1e-9));
    await gesture.removePointer();
  });

  testWidgets('resize samples live modifier state on each update',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(450, 400));
    await lockHandle(tester, ResizeHandle.right, const Offset(450, 400));

    await moveHandle(tester, ResizeHandle.right, const Offset(450, 400),
        const Offset(20, 0));
    final left = find.byKey(const ValueKey('handle-face-left'));
    final right = find.byKey(const ValueKey('handle-face-right'));
    expect(tester.getCenter(left).dx, closeTo(350, 1e-9));
    expect(tester.getCenter(right).dx, closeTo(470, 1e-9));

    debugPlatformModifierStateReader =
        () => (shiftPressed: false, altPressed: true);
    await moveHandle(tester, ResizeHandle.right, const Offset(450, 400),
        const Offset(20, 0));
    final frame = find.byKey(const ValueKey('transform-frame'));
    expect(tester.getCenter(frame).dx, closeTo(400, 1e-9));
    expect(tester.getCenter(left).dx, closeTo(310, 1e-9));
    expect(tester.getCenter(right).dx, closeTo(490, 1e-9));

    await unlockHandle(tester, ResizeHandle.right, const Offset(450, 400));
    await gesture.removePointer();
  });

  testWidgets('dimension field width adapts to its text', (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    await lockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    await unlockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    final field = find.byKey(const ValueKey('dimension-width'));
    final initialWidth = tester.getSize(field).width;

    await tester.enterText(
        find.descendant(of: field, matching: find.byType(TextField)),
        '1234567890.0');
    await tester.pump();
    final grown = tester.getSize(field).width;
    expect(grown, greaterThan(initialWidth));
    expect(grown, lessThanOrEqualTo(180));

    await tester.enterText(
        find.descendant(of: field, matching: find.byType(TextField)), '1');
    await tester.pump();
    final shrunk = tester.getSize(field).width;
    expect(shrunk, lessThan(grown));
    expect(shrunk, greaterThanOrEqualTo(52));
    await gesture.removePointer();
  });

  testWidgets('dimension fields show W and H corner badges', (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    await lockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    await unlockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));

    final widthField = find.byKey(const ValueKey('dimension-width'));
    final heightField = find.byKey(const ValueKey('dimension-height'));
    expect(
        find.descendant(of: widthField, matching: find.text('W')),
        findsOneWidget);
    expect(
        find.descendant(of: heightField, matching: find.text('H')),
        findsOneWidget);

    final fieldRect = tester.getRect(widthField);
    final badgeRect =
        tester.getRect(find.descendant(of: widthField, matching: find.text('W')));
    expect(badgeRect.center.dx,
        closeTo(fieldRect.right, 1));
    expect(badgeRect.center.dy,
        closeTo(fieldRect.bottom, 1));

    expect(find.text('R'), findsNothing);
    await gesture.removePointer();
  });

  testWidgets('badge does not affect field container layout', (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(350, 325));
    await lockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));
    await unlockHandle(tester, ResizeHandle.topLeft, const Offset(350, 325));

    final fieldRect =
        tester.getRect(find.byKey(const ValueKey('dimension-width')));
    final textRect = tester.getRect(find.descendant(
        of: find.byKey(const ValueKey('dimension-width')),
        matching: find.byType(TextField)));

    expect(fieldRect.height, 36);
    expect(textRect.center.dy, closeTo(fieldRect.center.dy, 0.5));
    expect(textRect.left, greaterThanOrEqualTo(fieldRect.left));
    expect(textRect.right, lessThanOrEqualTo(fieldRect.right));
    await gesture.removePointer();
  });

  testWidgets('rotation field width adapts to its text', (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(400, 301));
    await lockRotation(tester, 0);
    await unlockRotation(tester, 0);
    final field = find.byKey(const ValueKey('rotation-value'));
    final initialWidth = tester.getSize(field).width;

    await tester.enterText(
        find.descendant(of: field, matching: find.byType(TextField)),
        '-1234567890.0');
    await tester.pump();
    final grown = tester.getSize(field).width;
    expect(grown, greaterThan(initialWidth));
    expect(grown, lessThanOrEqualTo(180));
    expect(find.text('°'), findsOneWidget);

    await tester.enterText(
        find.descendant(of: field, matching: find.byType(TextField)), '1');
    await tester.pump();
    final shrunk = tester.getSize(field).width;
    expect(shrunk, lessThan(grown));
    expect(shrunk, greaterThanOrEqualTo(58));
    await gesture.removePointer();
  });

  testWidgets('midpoint fields sit inside their edge with 12px clearance',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(450, 400));

    await lockHandle(tester, ResizeHandle.right, const Offset(450, 400));
    await unlockHandle(tester, ResizeHandle.right, const Offset(450, 400));

    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('dimension-width')),
            matching: find.byType(TextField)),
        '300');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    Future<Rect> clickMidpoint(
        ResizeHandle handle, String face, String field) async {
      final position = tester.getCenter(find.byKey(ValueKey(face)));
      await gesture.moveTo(position);
      await tester.pump();
      await lockHandle(tester, handle, position);
      await unlockHandle(tester, handle, position);
      await tester.pump(const Duration(milliseconds: 300));
      return tester.getRect(find.byKey(ValueKey(field)));
    }

    final rightHandleRect =
        tester.getRect(find.byKey(const ValueKey('handle-face-right')));
    final rightField = await clickMidpoint(
        ResizeHandle.right, 'handle-face-right', 'dimension-width');
    expect(rightHandleRect.left - rightField.right,
        greaterThanOrEqualTo(12 - 1e-9));
    expect(rightField.center.dy, closeTo(rightHandleRect.center.dy, 1e-9));

    final leftField = await clickMidpoint(
        ResizeHandle.left, 'handle-face-left', 'dimension-width');
    final leftHandleRect =
        tester.getRect(find.byKey(const ValueKey('handle-face-left')));
    expect(
        leftField.left - leftHandleRect.right, greaterThanOrEqualTo(12 - 1e-9));
    expect(leftField.center.dy, closeTo(leftHandleRect.center.dy, 1e-9));

    final topField = await clickMidpoint(
        ResizeHandle.top, 'handle-face-top', 'dimension-height');
    final topHandleRect =
        tester.getRect(find.byKey(const ValueKey('handle-face-top')));
    expect(
        topField.top - topHandleRect.bottom, greaterThanOrEqualTo(12 - 1e-9));
    expect(topField.center.dx, closeTo(topHandleRect.center.dx, 1e-9));

    final bottomField = await clickMidpoint(
        ResizeHandle.bottom, 'handle-face-bottom', 'dimension-height');
    final bottomHandleRect =
        tester.getRect(find.byKey(const ValueKey('handle-face-bottom')));
    expect(bottomHandleRect.top - bottomField.bottom,
        greaterThanOrEqualTo(12 - 1e-9));
    expect(bottomField.center.dx, closeTo(bottomHandleRect.center.dx, 1e-9));

    await gesture.removePointer();
  });

  testWidgets('field position animates smoothly when placement flips',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(450, 400));
    await lockHandle(tester, ResizeHandle.right, const Offset(450, 400));
    await unlockHandle(tester, ResizeHandle.right, const Offset(450, 400));

    const fieldKey = ValueKey('dimension-width');
    final field = find.descendant(
      of: find.byKey(fieldKey),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '200');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final inside = tester.getCenter(find.byKey(fieldKey));
    final insideHandle =
        tester.getCenter(find.byKey(const ValueKey('handle-face-right')));
    expect(inside.dx, lessThan(insideHandle.dx));

    await tester.enterText(field, '10');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 60));

    final mid = tester.getCenter(find.byKey(fieldKey));
    expect(mid.dx, lessThan(inside.dx));

    await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('handle-face-right'))));
    await tester.pump(const Duration(milliseconds: 600));
    final settled = tester.getCenter(find.byKey(fieldKey));
    expect(settled.dx, lessThan(mid.dx));
    final handleRect =
        tester.getRect(find.byKey(const ValueKey('handle-face-right')));
    final settledRect = tester.getRect(find.byKey(fieldKey));
    expect(settledRect.left - handleRect.right,
        greaterThanOrEqualTo(12 - 1e-9));
    expect(settled.dy, closeTo(400, 1e-9));
    await gesture.removePointer();
  });

  testWidgets('field tracks the box exactly during normal motion',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(450, 400));
    await lockHandle(tester, ResizeHandle.right, const Offset(450, 400));
    await unlockHandle(tester, ResizeHandle.right, const Offset(450, 400));

    const fieldKey = ValueKey('dimension-width');
    const faceKey = ValueKey('handle-face-right');
    final field = find.descendant(
      of: find.byKey(fieldKey),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '200');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    // Let the box animation and the resulting outside->inside mirror
    // glide finish completely.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));

    await gesture.moveTo(tester.getCenter(find.byKey(faceKey)));

    // Shrinking 200 -> 150 keeps the field inside the right edge, so it
    // must follow the live handle position with no animation trail.
    await tester.enterText(field, '150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final face = tester.getCenter(find.byKey(faceKey));
    final rect = tester.getRect(find.byKey(fieldKey));
    expect(rect.center.dx, closeTo(face.dx - 19 - rect.width / 2, 0.5));
    await gesture.removePointer();
  });

  testWidgets('midpoint field falls outside when the edge cannot fit it',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(450, 400));
    await lockHandle(tester, ResizeHandle.right, const Offset(450, 400));
    await unlockHandle(tester, ResizeHandle.right, const Offset(450, 400));

    final field = find.descendant(
      of: find.byKey(const ValueKey('dimension-width')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '10');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final fieldRect =
        tester.getRect(find.byKey(const ValueKey('dimension-width')));
    final handleRect =
        tester.getRect(find.byKey(const ValueKey('handle-face-right')));
    expect(fieldRect.left - handleRect.right, greaterThanOrEqualTo(12 - 1e-9));
    expect(fieldRect.center.dy, closeTo(handleRect.center.dy, 1e-9));
    await gesture.removePointer();
  });

  testWidgets('inactive resize handle container rotates with the box',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(400, 301));
    await lockRotation(tester, 0);
    await unlockRotation(tester, 0);

    final field = find.descendant(
      of: find.byKey(const ValueKey('rotation-value')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '90');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final face = find.byKey(const ValueKey('handle-face-right'));
    final transforms = find.descendant(
      of: face,
      matching: find.byType(Transform),
    );
    expect(transforms, findsOneWidget);
    final matrix = tester.widget<Transform>(transforms).transform;
    expect(matrix.storage[0], closeTo(0, 1e-9));
    expect(matrix.storage[1], closeTo(1, 1e-9));
    expect(matrix.storage[4], closeTo(-1, 1e-9));
    expect(matrix.storage[5], closeTo(0, 1e-9));

    final center = tester.getCenter(face);
    expect(center.dx, closeTo(400, 1e-9));
    expect(center.dy, closeTo(450, 1e-9));
    expect(tester.getSize(face), const Size(14, 14));
    await gesture.removePointer();
  });

  testWidgets('active resize handle rotates container and arrow separately',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    final gesture = await hoverAt(tester, const Offset(400, 301));
    await lockRotation(tester, 0);
    await unlockRotation(tester, 0);

    final field = find.descendant(
      of: find.byKey(const ValueKey('rotation-value')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '90');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final handlePosition =
        tester.getCenter(find.byKey(const ValueKey('handle-face-right')));
    await lockHandle(tester, ResizeHandle.right, handlePosition);
    await tester.pump(const Duration(milliseconds: 150));

    final face = find.byKey(const ValueKey('handle-face-right'));
    final transforms = tester
        .widgetList<Transform>(find.descendant(
          of: face,
          matching: find.byType(Transform),
        ))
        .toList();
    expect(transforms, hasLength(2));
    final outer = transforms.first.transform;
    expect(outer.storage[0], closeTo(0, 1e-9));
    expect(outer.storage[1], closeTo(1, 1e-9));
    expect(outer.storage[4], closeTo(-1, 1e-9));
    expect(outer.storage[5], closeTo(0, 1e-9));
    final arrow = transforms.last.transform;
    expect(arrow.storage[0], closeTo(1, 1e-9));
    expect(arrow.storage[1], closeTo(0, 1e-9));
    expect(arrow.storage[4], closeTo(0, 1e-9));
    expect(arrow.storage[5], closeTo(1, 1e-9));

    await unlockHandle(tester, ResizeHandle.right, handlePosition);
    await gesture.removePointer();
  });
}
