import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:x_crop/src/box_transform/drag_to_pointer_lock_area.dart';

void main() {
  testWidgets('click without drag never locks', (tester) async {
    var factoryCalls = 0;
    var lockCalls = 0;
    var unlockCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: DragToPointerLockArea(
            createSession: ({required unlockOnPointerUp}) {
              factoryCalls++;
              return const Stream<PointerLockMoveEvent>.empty();
            },
            onLock: () => lockCalls++,
            onMove: (_) {},
            onUnlock: () => unlockCalls++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    ));

    final gesture = await tester.createGesture();
    await gesture.addPointer(location: const Offset(400, 300));
    await gesture.down(const Offset(400, 300));
    await gesture.moveTo(const Offset(402, 301));
    await gesture.up();
    await tester.pump();

    expect(factoryCalls, 0);
    expect(lockCalls, 0);
    expect(unlockCalls, 0);
    await gesture.removePointer();
  });

  testWidgets('natural stream completion resets tracking for a new drag',
      (tester) async {
    var factoryCalls = 0;
    var lockCalls = 0;
    var unlockCalls = 0;
    final deltas = <Offset>[];
    final sessions = <StreamController<PointerLockMoveEvent>>[];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: DragToPointerLockArea(
            createSession: ({required unlockOnPointerUp}) {
              factoryCalls++;
              final controller = StreamController<PointerLockMoveEvent>();
              sessions.add(controller);
              return controller.stream;
            },
            onLock: () => lockCalls++,
            onMove: deltas.add,
            onUnlock: () => unlockCalls++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    ));

    final first = await tester.createGesture();
    await first.addPointer(location: const Offset(400, 300));
    await first.down(const Offset(400, 300));
    await first.moveTo(const Offset(410, 300));
    await tester.pump();

    expect(factoryCalls, 1);
    expect(lockCalls, 1);

    sessions[0].add(PointerLockMoveEvent(delta: const Offset(8, -3)));
    await tester.pump();
    expect(deltas, [const Offset(8, -3)]);

    await sessions[0].close();
    await tester.pump();
    expect(unlockCalls, 1);

    final second = await tester.createGesture();
    await second.addPointer(location: const Offset(400, 300));
    await second.down(const Offset(400, 300));
    await second.moveTo(const Offset(410, 300));
    await tester.pump();

    expect(factoryCalls, 2);
    expect(lockCalls, 2);

    await sessions[1].close();
    await tester.pump();
    expect(unlockCalls, 2);

    await first.up();
    await tester.pump();
    expect(unlockCalls, 2);
    await first.removePointer();

    await second.up();
    await tester.pump();
    expect(unlockCalls, 2);
    await second.removePointer();
  });

  testWidgets('dispose suppresses onUnlock after teardown', (tester) async {
    var unlockCalls = 0;
    final session = StreamController<PointerLockMoveEvent>();

    Widget buildArea() => MaterialApp(
          home: Scaffold(
            body: Center(
              child: DragToPointerLockArea(
                createSession: ({required unlockOnPointerUp}) => session.stream,
                onLock: () {},
                onMove: (_) {},
                onUnlock: () => unlockCalls++,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildArea());
    final gesture = await tester.createGesture();
    await gesture.addPointer(location: const Offset(400, 300));
    await gesture.down(const Offset(400, 300));
    await gesture.moveTo(const Offset(410, 300));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    unawaited(session.close());
    await gesture.up();
    await tester.pump();

    expect(unlockCalls, 0);
    await gesture.removePointer();
  });
}
