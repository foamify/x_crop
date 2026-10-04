import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_lock/pointer_lock.dart';

import 'box_transform.dart';

const _dashLength = 8.0;
const _dashGap = 6.0;
const _frameStrokeWidth = 1.5;
const _handleHalf = 7.0;
const _dashInner = _handleHalf + _dashGap;
const _fieldHandleGap = 12.0;

class BoxTransformEditor extends StatefulWidget {
  const BoxTransformEditor(
      {super.key, this.config = const BoxTransformConfig()});

  final BoxTransformConfig config;

  @override
  State<BoxTransformEditor> createState() => _BoxTransformEditorState();
}

class _BoxTransformEditorState extends State<BoxTransformEditor> {
  static const _fieldSize = Size(96, 36);
  static const _hideDelay = Duration(milliseconds: 120);

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

  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final FocusNode _widthFocus = FocusNode();
  final FocusNode _heightFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = BoxTransformController(config: widget.config);
    _widthFocus.addListener(_syncFieldText);
    _heightFocus.addListener(_syncFieldText);
  }

  @override
  void didUpdateWidget(covariant BoxTransformEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      final box = _controller.value;
      _controller.dispose();
      _controller =
          BoxTransformController(initialBox: box, config: widget.config);
      _activeHandle = null;
      _virtualPointer = null;
      _resizePointer = null;
      _resizeStartFlipX = null;
      _resizeStartFlipY = null;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _widthController.dispose();
    _heightController.dispose();
    _widthFocus.dispose();
    _heightFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Offset? _localPosition(Offset globalPosition) {
    final renderBox = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.globalToLocal(globalPosition);
  }

  TransformModifiers get _modifiers => TransformModifiers(
        scale: HardwareKeyboard.instance.isShiftPressed,
        mirrored: HardwareKeyboard.instance.isAltPressed,
      );

  void _enterRegion(ResizeHandle handle) {
    _hideTimer?.cancel();
    _hovered[handle] = (_hovered[handle] ?? 0) + 1;
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
        setState(() => _fieldHandle = null);
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
    _controller.setDimensions(
      handle,
      width: width ? parsed : null,
      height: width ? null : parsed,
    );
    focusNode.unfocus();
    _syncFieldText();
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
                      if (p != null) _controller.beginMove(p);
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
                        _hideTimer?.cancel();
                        setState(() {
                          _activeHandle = handle;
                          _fieldHandle = handle;
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
                  left: position.dx - 5,
                  top: position.dy - 5,
                  child: GestureDetector(
                    onPanStart: (details) {
                      final p = _localPosition(details.globalPosition);
                      if (p != null) _controller.beginRotate(p);
                    },
                    onPanUpdate: (details) {
                      final p = _localPosition(details.globalPosition);
                      if (p != null) _controller.updateRotate(p);
                    },
                    onPanEnd: (_) => _controller.endGesture(),
                    onPanCancel: () => _controller.endGesture(),
                    child: const _RotationHandle(),
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
              if (_fieldHandle != null) ..._buildFields(box),
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

  Offset _fieldCenter(TransformBox box, ResizeHandle handle, bool widthField) {
    const safe = _handleHalf + _fieldHandleGap;
    final fw = _fieldSize.width;
    final fh = _fieldSize.height;
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
      if (halfH - _dashInner - safe >= fh) {
        return box.localToWorld(Offset(hx * halfW, -hx * (safe + fh / 2)));
      }
      return box.localToWorld(Offset(hx * (halfW + safe + fw / 2), 0));
    }
    if (halfW - _dashInner - safe >= fw) {
      return box.localToWorld(Offset(-hy * (safe + fw / 2), hy * halfH));
    }
    return box.localToWorld(Offset(0, hy * (halfH + safe + fh / 2)));
  }

  Widget _buildField(TransformBox box, ResizeHandle handle,
      {required bool width}) {
    final center = _fieldCenter(box, handle, width);
    final textController = width ? _widthController : _heightController;
    final focusNode = width ? _widthFocus : _heightFocus;
    return Positioned(
      left: center.dx - _fieldSize.width / 2,
      top: center.dy - _fieldSize.height / 2,
      child: MouseRegion(
        onEnter: (_) => _enterRegion(handle),
        onExit: (_) => _exitRegion(handle),
        child: _DimensionField(
          key: ValueKey(width ? 'dimension-width' : 'dimension-height'),
          prefix: width ? 'W' : 'H',
          controller: textController,
          focusNode: focusNode,
          readOnly: _activeHandle != null,
          onSubmitted: (_) => _submit(width: width),
        ),
      ),
    );
  }
}

class _DimensionField extends StatelessWidget {
  const _DimensionField({
    super.key,
    required this.prefix,
    required this.controller,
    required this.focusNode,
    required this.readOnly,
    required this.onSubmitted,
  });

  final String prefix;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool readOnly;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 36,
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
          Text(
            prefix,
            style: const TextStyle(
                color: Color(0xFF8F86E8),
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
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
    return AnimatedContainer(
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
              angle: rotation + _arrowAngle(handle),
              child: CustomPaint(painter: _ArrowPainter()),
            )
          : null,
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
  const _RotationHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1A28),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF3ED6C3), width: 1.4),
        boxShadow: const [
          BoxShadow(
              color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
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
