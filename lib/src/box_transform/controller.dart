import 'package:flutter/material.dart';

import 'engine.dart';
import 'model.dart';

class BoxTransformController extends ValueNotifier<TransformBox> {
  BoxTransformController({
    TransformBox? initialBox,
    this.config = const BoxTransformConfig(),
  }) : super(initialBox ?? TransformBox.initial());

  final BoxTransformConfig config;

  MoveSession? _moveSession;
  ResizeSession? _resizeSession;
  RotateSession? _rotateSession;

  void beginMove(Offset pointer) {
    _resizeSession = null;
    _rotateSession = null;
    _moveSession = MoveSession(value, pointer);
  }

  void updateMove(Offset pointer) {
    final session = _moveSession;
    if (session == null) return;
    value = session.update(pointer);
  }

  void beginResize(ResizeHandle handle, Offset pointer) {
    _moveSession = null;
    _rotateSession = null;
    _resizeSession = ResizeSession(value, handle, pointer, config);
  }

  void updateResize(Offset pointer, TransformModifiers modifiers) {
    final session = _resizeSession;
    if (session == null) return;
    value = session.update(pointer, modifiers);
  }

  void beginRotate(Offset pointer) {
    _moveSession = null;
    _resizeSession = null;
    _rotateSession = RotateSession(value, pointer);
  }

  void updateRotate(Offset pointer) {
    final session = _rotateSession;
    if (session == null) return;
    value = session.update(pointer);
  }

  void setDimensions(
    ResizeHandle handle, {
    double? width,
    double? height,
  }) {
    value = resizeBoxToDimensions(
      value,
      handle,
      width: width,
      height: height,
      minimumSize: config.minimumSize,
    );
  }

  void endGesture() {
    _moveSession = null;
    _resizeSession = null;
    _rotateSession = null;
  }
}
