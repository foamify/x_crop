import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'box_transform.dart';

class BoxTransformEditor extends StatefulWidget {
  const BoxTransformEditor(
      {super.key, this.config = const BoxTransformConfig()});

  final BoxTransformConfig config;

  @override
  State<BoxTransformEditor> createState() => _BoxTransformEditorState();
}

class _BoxTransformEditorState extends State<BoxTransformEditor> {
  final GlobalKey _rootKey = GlobalKey();
  late BoxTransformController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BoxTransformController(config: widget.config);
  }

  @override
  void didUpdateWidget(covariant BoxTransformEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      final box = _controller.value;
      _controller.dispose();
      _controller =
          BoxTransformController(initialBox: box, config: widget.config);
    }
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: _rootKey,
      child: ValueListenableBuilder<TransformBox>(
        valueListenable: _controller,
        builder: (context, box, _) {
          final corners = box.corners;
          return Stack(
            children: [
              Positioned.fill(
                child: ClipPath(
                  clipper: _BoxClipper(corners: corners),
                  child: GestureDetector(
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
                    child: CustomPaint(
                      painter:
                          _BoxPainter(corners: corners, color: Colors.blue),
                    ),
                  ),
                ),
              ),
              for (final handle in ResizeHandle.values)
                Positioned(
                  key: ValueKey('resize-${handle.name}'),
                  left: box.resizeHandlePosition(handle).dx - 5,
                  top: box.resizeHandlePosition(handle).dy - 5,
                  child: GestureDetector(
                    onPanStart: (details) {
                      final p = _localPosition(details.globalPosition);
                      if (p != null) _controller.beginResize(handle, p);
                    },
                    onPanUpdate: (details) {
                      final p = _localPosition(details.globalPosition);
                      if (p != null) {
                        _controller.updateResize(p, _modifiers);
                      }
                    },
                    onPanEnd: (_) => _controller.endGesture(),
                    onPanCancel: () => _controller.endGesture(),
                    child: const _Handle(color: Colors.red),
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
                    child: const _Handle(color: Colors.teal),
                  ),
                ),
              for (final (i, corner) in corners.indexed)
                Positioned(
                  left: corner.dx + 6,
                  top: corner.dy + 6,
                  child: IgnorePointer(
                    child: Text(
                      box.contentLabelAt(ResizeHandle.values[i * 2]),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
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

class _BoxPainter extends CustomPainter {
  _BoxPainter({required this.corners, required this.color});

  final List<Offset> corners;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(corners[0].dx, corners[0].dy)
        ..lineTo(corners[1].dx, corners[1].dy)
        ..lineTo(corners[2].dx, corners[2].dy)
        ..lineTo(corners[3].dx, corners[3].dy)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Handle extends StatelessWidget {
  const _Handle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}
