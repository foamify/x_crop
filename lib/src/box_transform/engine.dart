import 'dart:math';

import 'package:flutter/material.dart';

import 'model.dart';

double _normalizeAngle(double angle) => (angle + pi) % (2 * pi) - pi;

class MoveSession {
  MoveSession(TransformBox box, Offset pointer)
      : _box = box,
        _startPointer = pointer;

  final TransformBox _box;
  final Offset _startPointer;

  TransformBox update(Offset pointer) =>
      _box.copyWith(center: _box.center + (pointer - _startPointer));
}

class RotateSession {
  RotateSession(TransformBox box, Offset pointer)
      : _box = box,
        _startAngle = (pointer - box.center).direction;

  final TransformBox _box;
  final double _startAngle;

  TransformBox update(Offset pointer) {
    final currentAngle = (pointer - _box.center).direction;
    final delta = _normalizeAngle(currentAngle - _startAngle);
    return _box.copyWith(rotation: _normalizeAngle(_box.rotation + delta));
  }
}

class ResizeSession {
  ResizeSession(
    TransformBox box,
    ResizeHandle handle,
    Offset pointer,
    this._config,
  )   : _box = box,
        _handle = handle,
        _grabOffset = box.worldToLocal(pointer) -
            Offset(handle.horizontal * box.size.width / 2,
                handle.vertical * box.size.height / 2);

  final TransformBox _box;
  final ResizeHandle _handle;
  final BoxTransformConfig _config;
  final Offset _grabOffset;

  TransformBox update(Offset pointer, TransformModifiers modifiers) {
    final hx = _handle.horizontal;
    final hy = _handle.vertical;
    final w = _box.size.width;
    final h = _box.size.height;

    final desiredLocal = _box.worldToLocal(pointer) - _grabOffset;
    final anchor =
        modifiers.mirrored ? Offset.zero : Offset(-hx * w / 2, -hy * h / 2);

    final rawWidth = hx == 0
        ? w
        : modifiers.mirrored
            ? hx * desiredLocal.dx * 2
            : hx * (desiredLocal.dx - anchor.dx);
    final rawHeight = hy == 0
        ? h
        : modifiers.mirrored
            ? hy * desiredLocal.dy * 2
            : hy * (desiredLocal.dy - anchor.dy);

    final double signedWidth;
    final double signedHeight;
    if (modifiers.scale) {
      final magnitude = _scaleMagnitude(rawWidth, rawHeight, w, h, hx, hy);
      final scaledWidth = max(w * magnitude, _config.minimumSize.width);
      final scaledHeight = max(h * magnitude, _config.minimumSize.height);
      signedWidth = scaledWidth * (hx != 0 && rawWidth < 0 ? -1 : 1);
      signedHeight = scaledHeight * (hy != 0 && rawHeight < 0 ? -1 : 1);
    } else {
      signedWidth = hx == 0
          ? w
          : (rawWidth < 0 ? -1 : 1) *
              max(rawWidth.abs(), _config.minimumSize.width);
      signedHeight = hy == 0
          ? h
          : (rawHeight < 0 ? -1 : 1) *
              max(rawHeight.abs(), _config.minimumSize.height);
    }

    final localCenter = modifiers.mirrored
        ? Offset.zero
        : Offset(hx != 0 ? anchor.dx + hx * signedWidth / 2 : 0,
            hy != 0 ? anchor.dy + hy * signedHeight / 2 : 0);

    return _box.copyWith(
      center: _box.center + rotateOffset(localCenter, _box.rotation),
      size: Size(signedWidth.abs(), signedHeight.abs()),
      flipX: _box.flipX != (hx != 0 && signedWidth < 0),
      flipY: _box.flipY != (hy != 0 && signedHeight < 0),
    );
  }

  double _scaleMagnitude(
      double rawWidth, double rawHeight, double w, double h, int hx, int hy) {
    var magnitude = 0.0;
    if (hx != 0 && hy != 0) {
      if (w != 0) magnitude = max(magnitude, (rawWidth / w).abs());
      if (h != 0) magnitude = max(magnitude, (rawHeight / h).abs());
    } else if (hx != 0) {
      if (w != 0) magnitude = (rawWidth / w).abs();
    } else if (hy != 0) {
      if (h != 0) magnitude = (rawHeight / h).abs();
    }

    var minimum = 0.0;
    if (w != 0 && _config.minimumSize.width > 0) {
      minimum = max(minimum, _config.minimumSize.width / w);
    }
    if (h != 0 && _config.minimumSize.height > 0) {
      minimum = max(minimum, _config.minimumSize.height / h);
    }
    return max(magnitude, minimum);
  }
}
