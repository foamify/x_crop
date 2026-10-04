import 'dart:math';

import 'package:flutter/material.dart';

enum ResizeHandle {
  topLeft(-1, -1),
  top(0, -1),
  topRight(1, -1),
  right(1, 0),
  bottomRight(1, 1),
  bottom(0, 1),
  bottomLeft(-1, 1),
  left(-1, 0);

  const ResizeHandle(this.horizontal, this.vertical);
  final int horizontal;
  final int vertical;
  bool get isCorner => horizontal != 0 && vertical != 0;
}

enum RotationHandleLayout { singleTop, fourCorners }

@immutable
class BoxTransformConfig {
  const BoxTransformConfig({
    this.minimumSize = Size.zero,
    this.rotationHandleLayout = RotationHandleLayout.singleTop,
    this.rotationHandleOffset = 24,
  });
  final Size minimumSize;
  final RotationHandleLayout rotationHandleLayout;
  final double rotationHandleOffset;

  @override
  bool operator ==(Object other) =>
      other is BoxTransformConfig &&
      other.minimumSize == minimumSize &&
      other.rotationHandleLayout == rotationHandleLayout &&
      other.rotationHandleOffset == rotationHandleOffset;

  @override
  int get hashCode =>
      Object.hash(minimumSize, rotationHandleLayout, rotationHandleOffset);
}

@immutable
class TransformModifiers {
  const TransformModifiers({this.scale = false, this.mirrored = false});
  final bool scale;
  final bool mirrored;
}

Offset rotateOffset(Offset point, double angle) {
  final cosTheta = cos(angle);
  final sinTheta = sin(angle);
  return Offset(
    point.dx * cosTheta - point.dy * sinTheta,
    point.dx * sinTheta + point.dy * cosTheta,
  );
}

@immutable
class TransformBox {
  const TransformBox({
    required this.center,
    required this.size,
    this.rotation = 0,
    this.flipX = false,
    this.flipY = false,
  });

  factory TransformBox.initial() => const TransformBox(
        center: Offset(400, 400),
        size: Size(100, 150),
      );

  final Offset center;
  final Size size;
  final double rotation;
  final bool flipX;
  final bool flipY;

  TransformBox copyWith({
    Offset? center,
    Size? size,
    double? rotation,
    bool? flipX,
    bool? flipY,
  }) =>
      TransformBox(
        center: center ?? this.center,
        size: size ?? this.size,
        rotation: rotation ?? this.rotation,
        flipX: flipX ?? this.flipX,
        flipY: flipY ?? this.flipY,
      );

  Offset localToWorld(Offset point) => center + rotateOffset(point, rotation);

  Offset worldToLocal(Offset point) => rotateOffset(point - center, -rotation);

  Offset resizeHandlePosition(ResizeHandle handle) => localToWorld(Offset(
      handle.horizontal * size.width / 2, handle.vertical * size.height / 2));

  List<Offset> get corners => [
        localToWorld(Offset(-size.width / 2, -size.height / 2)),
        localToWorld(Offset(size.width / 2, -size.height / 2)),
        localToWorld(Offset(size.width / 2, size.height / 2)),
        localToWorld(Offset(-size.width / 2, size.height / 2)),
      ];

  List<Offset> rotationHandlePositions(BoxTransformConfig config) {
    switch (config.rotationHandleLayout) {
      case RotationHandleLayout.singleTop:
        return [
          localToWorld(
              Offset(0, -size.height / 2 - config.rotationHandleOffset)),
        ];
      case RotationHandleLayout.fourCorners:
        const directions = [
          Offset(-1, -1),
          Offset(1, -1),
          Offset(1, 1),
          Offset(-1, 1),
        ];
        return [
          for (final dir in directions)
            localToWorld(
                Offset(dir.dx * size.width / 2, dir.dy * size.height / 2) +
                    dir / dir.distance * config.rotationHandleOffset),
        ];
    }
  }

  String contentLabelAt(ResizeHandle physicalCorner) {
    if (!physicalCorner.isCorner) {
      throw ArgumentError.value(
          physicalCorner, 'physicalCorner', 'must be a corner handle');
    }
    final h = flipX ? -physicalCorner.horizontal : physicalCorner.horizontal;
    final v = flipY ? -physicalCorner.vertical : physicalCorner.vertical;
    return switch ((h, v)) {
      (-1, -1) => 'TL',
      (1, -1) => 'TR',
      (1, 1) => 'BR',
      _ => 'BL',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is TransformBox &&
      other.center == center &&
      other.size == size &&
      other.rotation == rotation &&
      other.flipX == flipX &&
      other.flipY == flipY;

  @override
  int get hashCode => Object.hash(center, size, rotation, flipX, flipY);
}
