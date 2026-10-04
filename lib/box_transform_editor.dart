import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_lock/pointer_lock.dart';

import 'box_transform.dart';
import 'src/box_transform/drag_to_pointer_lock_area.dart';
import 'src/box_transform/modifier_state.dart';
import 'src/box_transform/pointer_warp.dart';

const _dashLength = 8.0;
const _dashGap = 6.0;
const _frameStrokeWidth = 1.5;
const _handleHalf = 7.0;
const _dashInner = _handleHalf + _dashGap;
const _fieldHandleGap = 12.0;
const _fieldHeight = 36.0;
const _dimensionFieldMinWidth = 52.0;
const _rotationFieldMinWidth = 58.0;
const _fieldMaxWidth = 180.0;
const _fieldHorizontalChrome = 24.0;

double _adaptiveFieldWidth(String text, {required bool rotation}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text.isEmpty ? '0' : text,
      style: const TextStyle(fontSize: 13),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final textWidth = painter.width;
  painter.dispose();
  var suffixWidth = 0.0;
  if (rotation) {
    final suffix = TextPainter(
      text: const TextSpan(text: '°', style: TextStyle(fontSize: 12)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    suffixWidth = suffix.width;
    suffix.dispose();
  }
  return (textWidth + suffixWidth + _fieldHorizontalChrome).clamp(
    rotation ? _rotationFieldMinWidth : _dimensionFieldMinWidth,
    _fieldMaxWidth,
  );
}

class BoxTransformEditor extends StatefulWidget {
  const BoxTransformEditor(
      {super.key, this.config = const BoxTransformConfig()});

  final BoxTransformConfig config;

  @override
  State<BoxTransformEditor> createState() => _BoxTransformEditorState();
}

class _BoxTransformEditorState extends State<BoxTransformEditor>
    with SingleTickerProviderStateMixin {
  static const _hideDelay = Duration(milliseconds: 120);
  static const _fieldFadeInDuration = Duration(milliseconds: 140);
  static const _fieldFadeOutDuration = Duration(milliseconds: 260);
  static const _boxAnimationDuration = Duration(milliseconds: 240);

  final GlobalKey _rootKey = GlobalKey();
  late BoxTransformController _controller;

  final Map<ResizeHandle, int> _hovered = {};
  ResizeHandle? _fieldHandle;
  ResizeHandle? _activeHandle;
  Offset? _virtualPointer;
  Offset? _resizePointer;
  bool? _resizeStartFlipX;
  bool? _resizeStartFlipY;
  Timer? _hideTimer;
  bool _fieldsVisible = false;
  Timer? _fieldRemovalTimer;

  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final FocusNode _widthFocus = FocusNode();
  final FocusNode _heightFocus = FocusNode();

  final Map<int, int> _rotationHovered = {};
  int? _rotationFieldIndex;
  int? _activeRotationIndex;
  Offset? _rotationPointer;
  Offset? _rotationVirtualPointer;
  Timer? _rotationHideTimer;
  bool _rotationFieldVisible = false;
  Timer? _rotationFieldRemovalTimer;
  final TextEditingController _rotationController = TextEditingController();
  final FocusNode _rotationFocus = FocusNode();

  late final AnimationController _boxAnimationController;
  TransformBox? _boxAnimationStart;
  TransformBox? _boxAnimationTarget;

  @override
  void initState() {
    super.initState();
    _controller = BoxTransformController(config: widget.config);
    _boxAnimationController =
        AnimationController(vsync: this, duration: _boxAnimationDuration)
          ..addListener(_tickBoxAnimation);
    _widthFocus.addListener(_syncFieldText);
    _heightFocus.addListener(_syncFieldText);
    _rotationFocus.addListener(_syncRotationText);
  }

  @override
  void didUpdateWidget(covariant BoxTransformEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _stopBoxAnimation();
      final box = _controller.value;
      _controller.dispose();
      _controller =
          BoxTransformController(initialBox: box, config: widget.config);
      _activeHandle = null;
      _virtualPointer = null;
      _resizePointer = null;
      _resizeStartFlipX = null;
      _resizeStartFlipY = null;
      _activeRotationIndex = null;
      _rotationPointer = null;
      _rotationVirtualPointer = null;
      if (_rotationFieldIndex != null &&
          _rotationFieldIndex! >=
              box.rotationHandlePositions(widget.config).length) {
        _rotationFieldIndex = null;
        _rotationFieldVisible = false;
      }
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _fieldRemovalTimer?.cancel();
    _rotationFieldRemovalTimer?.cancel();
    _boxAnimationController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _widthFocus.dispose();
    _heightFocus.dispose();
    _rotationHideTimer?.cancel();
    _rotationController.dispose();
    _rotationFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Offset? _localPosition(Offset globalPosition) {
    final renderBox = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.globalToLocal(globalPosition);
  }

  TransformModifiers get _modifiers => readTransformModifiers();

  void _stopBoxAnimation() {
    _boxAnimationController.stop();
    _boxAnimationStart = null;
    _boxAnimationTarget = null;
  }

  void _animateBoxTo(TransformBox target) {
    _boxAnimationController.stop();
    final start = _controller.value;
    _boxAnimationStart = start;
    _boxAnimationTarget = target;
    if (start == target) {
      _controller.value = target;
      _syncFieldText();
      _syncRotationText();
      return;
    }
    _boxAnimationController.forward(from: 0);
  }

  void _tickBoxAnimation() {
    final start = _boxAnimationStart;
    final target = _boxAnimationTarget;
    if (start == null || target == null) return;
    final raw = _boxAnimationController.value;
    if (raw == 1) {
      _controller.value = target;
    } else {
      final t = Curves.easeOutCubic.transform(raw);
      final rotationDelta = normalizeRotation(target.rotation - start.rotation);
      _controller.value = TransformBox(
        center: Offset.lerp(start.center, target.center, t)!,
        size: Size.lerp(start.size, target.size, t)!,
        rotation: normalizeRotation(start.rotation + rotationDelta * t),
        flipX: target.flipX,
        flipY: target.flipY,
      );
    }
    _syncFieldText();
    _syncRotationText();
  }

  void _enterRegion(ResizeHandle handle) {
    _hideTimer?.cancel();
    _fieldRemovalTimer?.cancel();
    _hovered[handle] = (_hovered[handle] ?? 0) + 1;
    if (_fieldHandle == handle && !_fieldsVisible) {
      setState(() => _fieldsVisible = true);
    }
  }

  void _exitRegion(ResizeHandle handle) {
    _hovered[handle] = (_hovered[handle] ?? 1) - 1;
    if ((_hovered[handle] ?? 0) <= 0) _hovered.remove(handle);
    _scheduleHide(handle);
  }

  void _scheduleHide(ResizeHandle handle) {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (!mounted) return;
      if (!_hovered.containsKey(handle) &&
          _activeHandle != handle &&
          _fieldHandle == handle) {
        setState(() => _fieldsVisible = false);
        _fieldRemovalTimer = Timer(_fieldFadeOutDuration, () {
          if (!mounted) return;
          if (!_hovered.containsKey(handle) &&
              _activeHandle != handle &&
              _fieldHandle == handle &&
              !_fieldsVisible) {
            setState(() => _fieldHandle = null);
          }
        });
      }
    });
  }

  ResizeHandle _remapHandle(ResizeHandle handle,
      {required bool flipX, required bool flipY}) {
    final horizontal = flipX ? -handle.horizontal : handle.horizontal;
    final vertical = flipY ? -handle.vertical : handle.vertical;
    return ResizeHandle.values.singleWhere((candidate) =>
        candidate.horizontal == horizontal && candidate.vertical == vertical);
  }

  void _syncFieldText() {
    final size = _controller.value.size;
    if (!_widthFocus.hasFocus) {
      _widthController.text = size.width.toStringAsFixed(1);
    }
    if (!_heightFocus.hasFocus) {
      _heightController.text = size.height.toStringAsFixed(1);
    }
  }

  void _submit({required bool width}) {
    final handle = _fieldHandle;
    if (handle == null) return;
    final text = (width ? _widthController : _heightController).text;
    final focusNode = width ? _widthFocus : _heightFocus;
    final parsed = double.tryParse(text);
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      focusNode.unfocus();
      _syncFieldText();
      return;
    }
    _animateBoxTo(resizeBoxToDimensions(
      _controller.value,
      handle,
      width: width ? parsed : null,
      height: width ? null : parsed,
      minimumSize: widget.config.minimumSize,
    ));
    focusNode.unfocus();
    _syncFieldText();
  }

  void _enterRotationRegion(int index) {
    _rotationHideTimer?.cancel();
    _rotationFieldRemovalTimer?.cancel();
    _rotationHovered[index] = (_rotationHovered[index] ?? 0) + 1;
    if (_rotationFieldIndex == index && !_rotationFieldVisible) {
      setState(() => _rotationFieldVisible = true);
    }
  }

  void _exitRotationRegion(int index) {
    _rotationHovered[index] = (_rotationHovered[index] ?? 1) - 1;
    if ((_rotationHovered[index] ?? 0) <= 0) _rotationHovered.remove(index);
    _scheduleRotationHide(index);
  }

  void _scheduleRotationHide(int index) {
    _rotationHideTimer?.cancel();
    _rotationHideTimer = Timer(_hideDelay, () {
      if (!mounted) return;
      if (!_rotationHovered.containsKey(index) &&
          _activeRotationIndex != index &&
          _rotationFieldIndex == index) {
        setState(() => _rotationFieldVisible = false);
        _rotationFieldRemovalTimer = Timer(_fieldFadeOutDuration, () {
          if (!mounted) return;
          if (!_rotationHovered.containsKey(index) &&
              _activeRotationIndex != index &&
              _rotationFieldIndex == index &&
              !_rotationFieldVisible) {
            setState(() => _rotationFieldIndex = null);
          }
        });
      }
    });
  }

  void _warpPointerTo(Offset position) {
    final renderBox = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    unawaited(warpPointerInWindow(position, renderBox.size));
  }

  void _syncRotationText() {
    if (!_rotationFocus.hasFocus) {
      _rotationController.text =
          (normalizeRotation(_controller.value.rotation) * 180 / pi)
              .toStringAsFixed(1);
    }
  }

  void _submitRotation() {
    if (_rotationFieldIndex == null) return;
    final parsed = double.tryParse(_rotationController.text);
    if (parsed == null || !parsed.isFinite) {
      _rotationFocus.unfocus();
      _syncRotationText();
      return;
    }
    _animateBoxTo(_controller.value
        .copyWith(rotation: normalizeRotation(parsed * pi / 180)));
    _rotationFocus.unfocus();
    _syncRotationText();
  }

  void _beginRotationLock(int index) {
    final positions = _controller.value.rotationHandlePositions(widget.config);
    if (index < 0 || index >= positions.length) return;
    final start = positions[index];
    _stopBoxAnimation();
    _rotationHideTimer?.cancel();
    _rotationFieldRemovalTimer?.cancel();
    setState(() {
      _activeRotationIndex = index;
      _rotationFieldIndex = index;
      _rotationFieldVisible = true;
      _rotationPointer = start;
      _rotationVirtualPointer = start;
    });
    _controller.beginRotate(start);
    _syncRotationText();
  }

  void _moveRotationLock(Offset delta) {
    final pointer = _rotationPointer;
    final virtual = _rotationVirtualPointer;
    if (pointer == null || virtual == null) return;
    _rotationPointer = pointer + delta;
    _rotationVirtualPointer = virtual + delta;
    _controller.updateRotate(pointer + delta);
    _syncRotationText();
    setState(() {});
  }

  void _endRotationLock() {
    _controller.endGesture();
    final activeIndex = _activeRotationIndex;
    if (activeIndex != null) {
      final positions =
          _controller.value.rotationHandlePositions(widget.config);
      if (activeIndex < positions.length) {
        _warpPointerTo(positions[activeIndex]);
      }
    }
    final fieldIndex = _rotationFieldIndex;
    setState(() {
      _activeRotationIndex = null;
      _rotationPointer = null;
      _rotationVirtualPointer = null;
    });
    _syncRotationText();
    if (fieldIndex != null && !_rotationHovered.containsKey(fieldIndex)) {
      _scheduleRotationHide(fieldIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _rootKey,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.4,
          colors: [Color(0xFF161525), Color(0xFF0B0B12)],
        ),
      ),
      child: ValueListenableBuilder<TransformBox>(
        valueListenable: _controller,
        builder: (context, box, _) {
          final corners = box.corners;
          return Stack(
            children: [
              CustomPaint(
                key: const ValueKey('transform-frame'),
                size: Size.infinite,
                painter: _DashedFramePainter(box: box),
              ),
              Positioned.fill(
                child: ClipPath(
                  clipper: _BoxClipper(corners: corners),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      final p = _localPosition(details.globalPosition);
                      if (p != null) {
                        _stopBoxAnimation();
                        _controller.beginMove(p);
                      }
                    },
                    onPanUpdate: (details) {
                      final p = _localPosition(details.globalPosition);
                      if (p != null) _controller.updateMove(p);
                    },
                    onPanEnd: (_) => _controller.endGesture(),
                    onPanCancel: () => _controller.endGesture(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              for (final handle in ResizeHandle.values)
                Positioned(
                  key: ValueKey('resize-${handle.name}'),
                  left: box.resizeHandlePosition(handle).dx - 13,
                  top: box.resizeHandlePosition(handle).dy - 13,
                  child: MouseRegion(
                    onEnter: (_) => _enterRegion(handle),
                    onExit: (_) => _exitRegion(handle),
                    child: PointerLockDragArea(
                      cursor: PointerLockCursor.hidden,
                      onLock: (details) {
                        final p = _localPosition(details.trigger.position);
                        if (p == null) return;
                        _stopBoxAnimation();
                        _hideTimer?.cancel();
                        _fieldRemovalTimer?.cancel();
                        setState(() {
                          _activeHandle = handle;
                          _fieldHandle = handle;
                          _fieldsVisible = true;
                          _virtualPointer =
                              _controller.value.resizeHandlePosition(handle);
                          _resizePointer = p;
                          _resizeStartFlipX = _controller.value.flipX;
                          _resizeStartFlipY = _controller.value.flipY;
                        });
                        _controller.beginResize(handle, p);
                        _syncFieldText();
                      },
                      onMove: (details) {
                        final pointer = _virtualPointer;
                        final resizePointer = _resizePointer;
                        if (pointer == null || resizePointer == null) return;
                        final virtual = pointer + details.move.delta;
                        final resize = resizePointer + details.move.delta;
                        _virtualPointer = virtual;
                        _resizePointer = resize;
                        _controller.updateResize(resize, _modifiers);
                        final effective = _remapHandle(
                          handle,
                          flipX: _controller.value.flipX !=
                              (_resizeStartFlipX ?? false),
                          flipY: _controller.value.flipY !=
                              (_resizeStartFlipY ?? false),
                        );
                        _activeHandle = effective;
                        _fieldHandle = effective;
                        _syncFieldText();
                        setState(() {});
                      },
                      onUnlock: (_) {
                        _controller.endGesture();
                        final activeHandle = _activeHandle;
                        if (activeHandle != null) {
                          _warpPointerTo(_controller.value
                              .resizeHandlePosition(activeHandle));
                        }
                        final fieldHandle = _fieldHandle;
                        setState(() {
                          _activeHandle = null;
                          _virtualPointer = null;
                          _resizePointer = null;
                          _resizeStartFlipX = null;
                          _resizeStartFlipY = null;
                        });
                        _syncFieldText();
                        if (fieldHandle != null &&
                            !_hovered.containsKey(fieldHandle)) {
                          _scheduleHide(fieldHandle);
                        }
                      },
                      child: SizedBox.square(
                        dimension: 26,
                        child: Center(
                          child: _HandleFace(
                            key: ValueKey('handle-face-${handle.name}'),
                            handle: handle,
                            active: _activeHandle == handle,
                            rotation: box.rotation,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              for (final (i, position)
                  in box.rotationHandlePositions(widget.config).indexed)
                Positioned(
                  key: ValueKey('rotation-$i'),
                  left: position.dx - 13,
                  top: position.dy - 13,
                  child: MouseRegion(
                    onEnter: (_) => _enterRotationRegion(i),
                    onExit: (_) => _exitRotationRegion(i),
                    child: PointerLockDragArea(
                      cursor: PointerLockCursor.hidden,
                      onLock: (_) => _beginRotationLock(i),
                      onMove: (details) =>
                          _moveRotationLock(details.move.delta),
                      onUnlock: (_) => _endRotationLock(),
                      child: SizedBox.square(
                        dimension: 26,
                        child: Center(
                          child: _RotationHandle(
                            key: ValueKey('rotation-face-$i'),
                            active: _activeRotationIndex == i,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_activeHandle case final handle?)
                if (_virtualPointer case final pointer?)
                  Positioned(
                    key: const ValueKey('virtual-pointer-handle'),
                    left: pointer.dx - 13,
                    top: pointer.dy - 13,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.68,
                        child: _HandleFace(
                          key: const ValueKey('virtual-pointer-handle-face'),
                          handle: handle,
                          active: true,
                          rotation: box.rotation,
                        ),
                      ),
                    ),
                  ),
              if (_activeRotationIndex != null)
                if (_rotationVirtualPointer case final pointer?)
                  Positioned(
                    key: const ValueKey('virtual-rotation-handle'),
                    left: pointer.dx - 13,
                    top: pointer.dy - 13,
                    child: const IgnorePointer(
                      child: Opacity(
                        opacity: 0.68,
                        child: _RotationHandle(
                          key: ValueKey('virtual-rotation-handle-face'),
                          active: true,
                        ),
                      ),
                    ),
                  ),
              if (_fieldHandle != null) ..._buildFields(box),
              if (_rotationFieldIndex != null &&
                  _rotationFieldIndex! <
                      box.rotationHandlePositions(widget.config).length)
                _buildRotationField(box, _rotationFieldIndex!),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildFields(TransformBox box) {
    final handle = _fieldHandle!;
    final fields = <Widget>[];
    if (handle.horizontal != 0) {
      fields.add(_buildField(box, handle, width: true));
    }
    if (handle.vertical != 0) {
      fields.add(_buildField(box, handle, width: false));
    }
    return fields;
  }

  Offset _fieldCenter(
      TransformBox box, ResizeHandle handle, bool widthField, Size fieldSize) {
    const safe = _handleHalf + _fieldHandleGap;
    final fw = fieldSize.width;
    final fh = fieldSize.height;
    final halfW = box.size.width / 2;
    final halfH = box.size.height / 2;
    final hx = handle.horizontal;
    final hy = handle.vertical;
    if (handle.isCorner) {
      if (widthField) {
        if (halfW - _dashInner - safe >= fw) {
          return box
              .localToWorld(Offset(hx * (halfW - safe - fw / 2), hy * halfH));
        }
        return box.localToWorld(Offset(hx * max(0.0, halfW - safe - fw / 2),
            hy * (halfH + safe + fh / 2)));
      }
      if (halfH - _dashInner - safe >= fh) {
        return box
            .localToWorld(Offset(hx * halfW, hy * (halfH - safe - fh / 2)));
      }
      return box.localToWorld(Offset(
          hx * (halfW + safe + fw / 2), hy * max(0.0, halfH - safe - fh / 2)));
    }
    if (handle.horizontal != 0) {
      final fitsInside = box.size.width >= fw + 2 * safe;
      final x = fitsInside
          ? hx * (halfW - safe - fw / 2)
          : hx * (halfW + safe + fw / 2);
      return box.localToWorld(Offset(x, 0));
    }
    final fitsInside = box.size.height >= fh + 2 * safe;
    final y = fitsInside
        ? hy * (halfH - safe - fh / 2)
        : hy * (halfH + safe + fh / 2);
    return box.localToWorld(Offset(0, y));
  }

  Widget _buildField(TransformBox box, ResizeHandle handle,
      {required bool width}) {
    final textController = width ? _widthController : _heightController;
    final focusNode = width ? _widthFocus : _heightFocus;
    final size = Size(_adaptiveFieldWidth(textController.text, rotation: false),
        _fieldHeight);
    final center = _fieldCenter(box, handle, width, size);
    return Positioned(
      left: center.dx,
      top: center.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: IgnorePointer(
          ignoring: !_fieldsVisible,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(
                width ? 'dimension-width-fade' : 'dimension-height-fade'),
            tween: Tween(begin: 0, end: _fieldsVisible ? 1 : 0),
            duration:
                _fieldsVisible ? _fieldFadeInDuration : _fieldFadeOutDuration,
            curve: _fieldsVisible ? Curves.easeOut : Curves.easeInOut,
            builder: (_, opacity, child) =>
                Opacity(opacity: opacity, child: child),
            child: MouseRegion(
              onEnter: (_) => _enterRegion(handle),
              onExit: (_) => _exitRegion(handle),
              child: _DimensionField(
                key: ValueKey(width ? 'dimension-width' : 'dimension-height'),
                controller: textController,
                focusNode: focusNode,
                readOnly: _activeHandle != null,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(width: width),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRotationField(TransformBox box, int index) {
    final size = Size(
        _adaptiveFieldWidth(_rotationController.text, rotation: true),
        _fieldHeight);
    final position = box.rotationHandlePositions(widget.config)[index];
    final offset = position - box.center;
    final direction = offset.distance > 0
        ? offset / offset.distance
        : rotateOffset(const Offset(0, -1), box.rotation);
    final support = direction.dx.abs() * size.width / 2 +
        direction.dy.abs() * size.height / 2;
    final distance = max(43.0, support + _handleHalf + _fieldHandleGap);
    final center = position + direction * distance;
    return Positioned(
      left: center.dx,
      top: center.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: IgnorePointer(
          ignoring: !_rotationFieldVisible,
          child: TweenAnimationBuilder<double>(
            key: const ValueKey('rotation-value-fade'),
            tween: Tween(begin: 0, end: _rotationFieldVisible ? 1 : 0),
            duration: _rotationFieldVisible
                ? _fieldFadeInDuration
                : _fieldFadeOutDuration,
            curve: _rotationFieldVisible ? Curves.easeOut : Curves.easeInOut,
            builder: (_, opacity, child) =>
                Opacity(opacity: opacity, child: child),
            child: MouseRegion(
              onEnter: (_) => _enterRotationRegion(index),
              onExit: (_) => _exitRotationRegion(index),
              child: DragToPointerLockArea(
                key: const ValueKey('rotation-field-drag-area'),
                onLock: () => _beginRotationLock(index),
                onMove: _moveRotationLock,
                onUnlock: _endRotationLock,
                child: _RotationField(
                  key: const ValueKey('rotation-value'),
                  controller: _rotationController,
                  focusNode: _rotationFocus,
                  readOnly: _activeRotationIndex != null,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submitRotation(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DimensionField extends StatelessWidget {
  const _DimensionField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.readOnly,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool readOnly;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, child) => SizedBox(
        width: _adaptiveFieldWidth(value.text, rotation: false),
        height: _fieldHeight,
        child: child,
      ),
      child: _buildFieldChrome(),
    );
  }

  Widget _buildFieldChrome() {
    return Container(
      height: _fieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xE6141424),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6C5CE7), width: 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) =>
                    RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)
                        ? newValue
                        : oldValue),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              cursorColor: const Color(0xFF8F86E8),
            ),
          ),
        ],
      ),
    );
  }
}

class _RotationField extends StatelessWidget {
  const _RotationField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.readOnly,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool readOnly;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, child) => SizedBox(
        width: _adaptiveFieldWidth(value.text, rotation: true),
        height: _fieldHeight,
        child: child,
      ),
      child: _buildFieldChrome(),
    );
  }

  Widget _buildFieldChrome() {
    return Container(
      height: _fieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xE6141424),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3ED6C3), width: 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) =>
                    RegExp(r'^-?\d*\.?\d*$').hasMatch(newValue.text)
                        ? newValue
                        : oldValue),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              cursorColor: const Color(0xFF3ED6C3),
            ),
          ),
          const Text(
            '°',
            style: TextStyle(color: Color(0xFF3ED6C3), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HandleFace extends StatelessWidget {
  const _HandleFace({
    super.key,
    required this.handle,
    required this.active,
    required this.rotation,
  });

  final ResizeHandle handle;
  final bool active;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final size = active ? 26.0 : 14.0;
    return Transform.rotate(
      angle: rotation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2A2750) : const Color(0xFF1B1A28),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? const Color(0xFF8F86E8) : const Color(0xFF5A54A8),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: active
            ? Transform.rotate(
                angle: _arrowAngle(handle),
                child: CustomPaint(painter: _ArrowPainter()),
              )
            : null,
      ),
    );
  }

  static double _arrowAngle(ResizeHandle handle) {
    if (handle.horizontal != 0 && handle.vertical != 0) {
      return (handle.horizontal * handle.vertical) > 0 ? pi / 4 : -pi / 4;
    }
    if (handle.horizontal != 0) return 0;
    return pi / 2;
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB9B3FF)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final half = size.width / 2 - 4;
    const head = 4.0;
    canvas.drawLine(Offset(cx - half, cy), Offset(cx + half, cy), paint);
    canvas.drawLine(
        Offset(cx - half + head, cy - head), Offset(cx - half, cy), paint);
    canvas.drawLine(
        Offset(cx - half + head, cy + head), Offset(cx - half, cy), paint);
    canvas.drawLine(
        Offset(cx + half - head, cy - head), Offset(cx + half, cy), paint);
    canvas.drawLine(
        Offset(cx + half - head, cy + head), Offset(cx + half, cy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RotationHandle extends StatelessWidget {
  const _RotationHandle({super.key, this.active = false});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final size = active ? 26.0 : 10.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF14332E) : const Color(0xFF1B1A28),
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? const Color(0xFF6FF0E0) : const Color(0xFF3ED6C3),
          width: active ? 1.8 : 1.4,
        ),
        boxShadow: [
          if (active)
            const BoxShadow(color: Color(0x553ED6C3), blurRadius: 10)
          else
            const BoxShadow(
                color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: active
          ? const Icon(Icons.rotate_right, size: 16, color: Color(0xFF9BF3E7))
          : null,
    );
  }
}

class _DashedFramePainter extends CustomPainter {
  _DashedFramePainter({required this.box});

  final TransformBox box;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6C5CE7)
      ..strokeWidth = _frameStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    canvas.save();
    canvas.translate(box.center.dx, box.center.dy);
    canvas.rotate(box.rotation);

    _drawSide(canvas, paint, -box.size.width / 2, -box.size.height / 2,
        box.size.width / 2, -box.size.height / 2);
    _drawSide(canvas, paint, -box.size.width / 2, box.size.height / 2,
        box.size.width / 2, box.size.height / 2);
    _drawSide(canvas, paint, -box.size.width / 2, -box.size.height / 2,
        -box.size.width / 2, box.size.height / 2);
    _drawSide(canvas, paint, box.size.width / 2, -box.size.height / 2,
        box.size.width / 2, box.size.height / 2);

    canvas.restore();
  }

  void _drawSide(
      Canvas canvas, Paint paint, double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final length = sqrt(dx * dx + dy * dy);
    if (length == 0) return;
    final ux = dx / length;
    final uy = dy / length;
    final halfExtent = length / 2;
    final midX = (x1 + x2) / 2;
    final midY = (y1 + y2) / 2;

    const inner = _dashInner;
    final outer = halfExtent - _dashGap;
    if (inner >= outer) return;

    var d = inner;
    while (d < outer) {
      final end = min(d + _dashLength, outer);
      canvas.drawLine(Offset(midX + ux * d, midY + uy * d),
          Offset(midX + ux * end, midY + uy * end), paint);
      canvas.drawLine(Offset(midX - ux * d, midY - uy * d),
          Offset(midX - ux * end, midY - uy * end), paint);
      d = end + _dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedFramePainter oldDelegate) =>
      oldDelegate.box != box;
}

class _BoxClipper extends CustomClipper<Path> {
  _BoxClipper({required this.corners});

  final List<Offset> corners;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(corners[0].dx, corners[0].dy)
    ..lineTo(corners[1].dx, corners[1].dy)
    ..lineTo(corners[2].dx, corners[2].dy)
    ..lineTo(corners[3].dx, corners[3].dy)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}
