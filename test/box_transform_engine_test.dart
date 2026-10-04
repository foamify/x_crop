import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x_crop/box_transform.dart';

const config = BoxTransformConfig();

TransformBox startBox() => const TransformBox(
      center: Offset(2, 4),
      size: Size(4, 8),
    );

Matcher offsetCloseTo(Offset expected) {
  return predicate<Offset>(
    (o) =>
        (o.dx - expected.dx).abs() <= 1e-9 &&
        (o.dy - expected.dy).abs() <= 1e-9,
    'is within 1e-9 of $expected',
  );
}

Matcher sizeCloseTo(Size expected) {
  return predicate<Size>(
    (s) =>
        (s.width - expected.width).abs() <= 1e-9 &&
        (s.height - expected.height).abs() <= 1e-9,
    'is within 1e-9 of $expected',
  );
}

void expectFiniteBox(TransformBox box) {
  expect(box.center.dx.isFinite, isTrue);
  expect(box.center.dy.isFinite, isTrue);
  expect(box.size.width.isFinite, isTrue);
  expect(box.size.height.isFinite, isTrue);
  expect(box.rotation.isFinite, isTrue);
  expect(box.size.width, greaterThanOrEqualTo(0));
  expect(box.size.height, greaterThanOrEqualTo(0));
}

void main() {
  test('MoveSession uses absolute pointer without accumulating', () {
    final session = MoveSession(startBox(), const Offset(2, 4));
    session.update(const Offset(3, 5));
    final result = session.update(const Offset(5, 7));
    expect(result.center, offsetCloseTo(const Offset(5, 7)));
  });

  test('free topRight resize', () {
    final box = startBox();
    final session =
        ResizeSession(box, ResizeHandle.topRight, const Offset(4, 0), config);
    final result =
        session.update(const Offset(6, -2), const TransformModifiers());
    expect(result.size, sizeCloseTo(const Size(6, 10)));
    expect(result.center, offsetCloseTo(const Offset(3, 3)));
    expect(result.flipX, isFalse);
    expect(result.flipY, isFalse);
  });

  test('free right midpoint resize ignores vertical axis', () {
    final session = ResizeSession(
        startBox(), ResizeHandle.right, const Offset(4, 4), config);
    final result =
        session.update(const Offset(6, 100), const TransformModifiers());
    expect(result.size, sizeCloseTo(const Size(6, 8)));
    expect(result.center, offsetCloseTo(const Offset(3, 4)));
  });

  test('free resize crossing both anchors flips both axes', () {
    final session = ResizeSession(
        startBox(), ResizeHandle.topRight, const Offset(4, 0), config);
    final result =
        session.update(const Offset(-1, 9), const TransformModifiers());
    expect(result.size, sizeCloseTo(const Size(1, 1)));
    expect(result.center, offsetCloseTo(const Offset(-0.5, 8.5)));
    expect(result.flipX, isTrue);
    expect(result.flipY, isTrue);
  });

  test('shift resize with smaller normalized distance keeps box unchanged', () {
    final session = ResizeSession(
        startBox(), ResizeHandle.topRight, const Offset(4, 0), config);
    const modifiers = TransformModifiers(scale: true);
    expect(session.update(const Offset(3, 0), modifiers), startBox());
    expect(session.update(const Offset(4, 1), modifiers), startBox());
  });

  test('shift topRight resize scales uniformly', () {
    final session = ResizeSession(
        startBox(), ResizeHandle.topRight, const Offset(4, 0), config);
    final result = session.update(
        const Offset(6, 0), const TransformModifiers(scale: true));
    expect(result.size, sizeCloseTo(const Size(6, 12)));
    expect(result.center, offsetCloseTo(const Offset(3, 2)));
    expect(result.flipX, isFalse);
    expect(result.flipY, isFalse);
  });

  test('shift topRight crossing one axis flips only that axis', () {
    final session = ResizeSession(
        startBox(), ResizeHandle.topRight, const Offset(4, 0), config);
    final result = session.update(
        const Offset(4, 9), const TransformModifiers(scale: true));
    expect(result.size, sizeCloseTo(const Size(4, 8)));
    expect(result.center, offsetCloseTo(const Offset(2, 12)));
    expect(result.flipX, isFalse);
    expect(result.flipY, isTrue);
    expect(result.corners[0], offsetCloseTo(const Offset(0, 8)));
    expect(result.corners[1], offsetCloseTo(const Offset(4, 8)));
    expect(result.corners[2], offsetCloseTo(const Offset(4, 16)));
    expect(result.corners[3], offsetCloseTo(const Offset(0, 16)));
  });

  test('mirrored free resize keeps center', () {
    final session = ResizeSession(
        startBox(), ResizeHandle.topRight, const Offset(4, 0), config);
    final result = session.update(
        const Offset(5, -2), const TransformModifiers(mirrored: true));
    expect(result.center, offsetCloseTo(const Offset(2, 4)));
    expect(result.size, sizeCloseTo(const Size(6, 12)));
    expect(result.flipX, isFalse);
    expect(result.flipY, isFalse);
  });

  test('mirrored shift resize scales around center', () {
    final session = ResizeSession(
        startBox(), ResizeHandle.topRight, const Offset(4, 0), config);
    final result = session.update(const Offset(5, 0),
        const TransformModifiers(scale: true, mirrored: true));
    expect(result.center, offsetCloseTo(const Offset(2, 4)));
    expect(result.size, sizeCloseTo(const Size(6, 12)));
  });

  test('shift right midpoint scales uniformly', () {
    final session = ResizeSession(
        startBox(), ResizeHandle.right, const Offset(4, 4), config);
    final result = session.update(
        const Offset(6, 4), const TransformModifiers(scale: true));
    expect(result.size, sizeCloseTo(const Size(6, 12)));
    expect(result.center, offsetCloseTo(const Offset(3, 4)));
  });

  test('free resize clamps to configured minimum at anchor', () {
    const minConfig = BoxTransformConfig(minimumSize: Size(2, 3));
    final session = ResizeSession(
        startBox(), ResizeHandle.topRight, const Offset(4, 0), minConfig);
    final result =
        session.update(const Offset(0, 8), const TransformModifiers());
    expect(result.size, sizeCloseTo(const Size(2, 3)));
    expect(result.center, offsetCloseTo(const Offset(1, 6.5)));
    expect(result.flipX, isFalse);
    expect(result.flipY, isFalse);
  });

  test('RotateSession updates rotation from angle delta', () {
    final box = startBox();
    final session = RotateSession(box, const Offset(2, 0));
    final result = session.update(const Offset(6, 4));
    expect(result.rotation, closeTo(pi / 2, 1e-9));
    expect(result.center, box.center);
    expect(result.size, box.size);
  });

  test('rotated box resize works in local space', () {
    const box = TransformBox(
        center: Offset(10, 10), size: Size(4, 8), rotation: pi / 2);
    final session = ResizeSession(box, ResizeHandle.topRight,
        box.resizeHandlePosition(ResizeHandle.topRight), config);
    final result = session.update(
        box.localToWorld(const Offset(3, -6)), const TransformModifiers());
    expect(result.size, sizeCloseTo(const Size(5, 10)));
    expect(result.center, offsetCloseTo(const Offset(11, 10.5)));
    expect(result.rotation, closeTo(pi / 2, 1e-9));
  });

  test('modifier changes recompute from gesture-start snapshot', () {
    final session = ResizeSession(
        startBox(), ResizeHandle.topRight, const Offset(4, 0), config);
    final free = session.update(const Offset(3, 0), const TransformModifiers());
    expect(free.size, sizeCloseTo(const Size(3, 8)));
    final scaled = session.update(
        const Offset(3, 0), const TransformModifiers(scale: true));
    expect(scaled.size, sizeCloseTo(const Size(4, 8)));
  });

  test('crossing toggles an already-flipped axis back', () {
    const flipped =
        TransformBox(center: Offset(2, 4), size: Size(4, 8), flipX: true);
    final session = ResizeSession(
        flipped, ResizeHandle.topRight, const Offset(4, 0), config);
    final result =
        session.update(const Offset(-1, 0), const TransformModifiers());
    expect(result.flipX, isFalse);
    expect(result.flipY, isFalse);
  });

  test('contentLabelAt accounts for flips', () {
    const base = TransformBox(center: Offset(2, 4), size: Size(4, 8));
    expect(base.contentLabelAt(ResizeHandle.topLeft), 'TL');
    expect(
        base.copyWith(flipX: true).contentLabelAt(ResizeHandle.topLeft), 'TR');
    expect(
        base.copyWith(flipY: true).contentLabelAt(ResizeHandle.topLeft), 'BL');
    expect(
        base
            .copyWith(flipX: true, flipY: true)
            .contentLabelAt(ResizeHandle.topLeft),
        'BR');
  });

  test('rotation handle positions follow configured layout', () {
    final box = startBox();
    final single = box.rotationHandlePositions(config);
    expect(single, hasLength(1));
    final edge = box.resizeHandlePosition(ResizeHandle.top) - box.center;
    expect((single[0] - box.center).distance, greaterThan(edge.distance));

    const cornersConfig = BoxTransformConfig(
        rotationHandleLayout: RotationHandleLayout.fourCorners);
    final four = box.rotationHandlePositions(cornersConfig);
    expect(four, hasLength(4));
    for (final (i, position) in four.indexed) {
      final corner = box.corners[i] - box.center;
      expect((position - box.center).distance, greaterThan(corner.distance));
    }
  });

  test('shift resize honors minimum size from a zero-size box', () {
    const zero = TransformBox(center: Offset(2, 4), size: Size.zero);
    const minimumConfig = BoxTransformConfig(minimumSize: Size(2, 3));
    final session = ResizeSession(
      zero,
      ResizeHandle.topRight,
      const Offset(2, 4),
      minimumConfig,
    );
    final result = session.update(
      const Offset(6, 1),
      const TransformModifiers(scale: true),
    );
    expect(result.size, sizeCloseTo(const Size(2, 3)));
    expectFiniteBox(result);
  });

  test('resizeBoxToDimensions applies typed corner size', () {
    final result = resizeBoxToDimensions(
      startBox(),
      ResizeHandle.topRight,
      width: 6,
      height: 10,
    );
    expect(result.size, sizeCloseTo(const Size(6, 10)));
    expect(result.center, offsetCloseTo(const Offset(3, 3)));
    expect(result.rotation, startBox().rotation);
    expect(result.flipX, isFalse);
    expect(result.flipY, isFalse);
  });

  test('resizeBoxToDimensions ignores inactive dimensions', () {
    final result = resizeBoxToDimensions(
      startBox(),
      ResizeHandle.right,
      width: 6,
      height: 100,
    );
    expect(result.size, sizeCloseTo(const Size(6, 8)));
    expect(result.center, offsetCloseTo(const Offset(3, 4)));
  });

  test('resizeBoxToDimensions keeps opposite corner fixed when rotated', () {
    const box = TransformBox(
        center: Offset(10, 10), size: Size(4, 8), rotation: pi / 2);
    final oppositeBefore = box.localToWorld(const Offset(-2, 4));
    final result = resizeBoxToDimensions(
      box,
      ResizeHandle.topRight,
      width: 6,
      height: 10,
    );
    final oppositeAfter = result.localToWorld(const Offset(-3, 5));
    expect(oppositeAfter, offsetCloseTo(oppositeBefore));
    expect(result.rotation, closeTo(pi / 2, 1e-9));
    expect(result.flipX, isFalse);
    expect(result.flipY, isFalse);
  });

  test('resizeBoxToDimensions clamps to configured minimum', () {
    final result = resizeBoxToDimensions(
      startBox(),
      ResizeHandle.topRight,
      width: 1,
      height: 1,
      minimumSize: const Size(2, 3),
    );
    expect(result.size, sizeCloseTo(const Size(2, 3)));
  });

  test('equal transform configurations use value equality', () {
    expect(
      const BoxTransformConfig(minimumSize: Size(1, 2)),
      const BoxTransformConfig(minimumSize: Size(1, 2)),
    );
  });

  test('normalizeRotation wraps into [-pi, pi)', () {
    expect(normalizeRotation(3 * pi / 2), closeTo(-pi / 2, 1e-9));
  });

  test('setRotation normalizes and preserves the rest of the box', () {
    final controller =
        BoxTransformController(initialBox: startBox(), config: config);
    controller.value = startBox().copyWith(flipX: true, flipY: true);
    controller.setRotation(3 * pi / 2);
    expect(controller.value.rotation, closeTo(-pi / 2, 1e-9));
    expect(controller.value.center, startBox().center);
    expect(controller.value.size, startBox().size);
    expect(controller.value.flipX, isTrue);
    expect(controller.value.flipY, isTrue);
  });

  test('produced boxes are finite with nonnegative size, even from zero size',
      () {
    const zero = TransformBox(center: Offset(2, 4), size: Size.zero);
    final session =
        ResizeSession(zero, ResizeHandle.topRight, const Offset(2, 4), config);
    final result = session.update(
        const Offset(6, 1), const TransformModifiers(scale: true));
    expectFiniteBox(result);
    expectFiniteBox(startBox());
  });
}
