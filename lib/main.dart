import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signals/signals_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

part 'extensions.dart';
part 'utils.dart';
part 'signals.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Watch.builder(
              builder: (context) {
                return CustomPaint(
                  painter: QuadPainter(
                    quad: outerQuad(),
                    color: Colors.deepPurple,
                  ),
                );
              },
            ),
            Watch.builder(
              builder: (context) {
                return Positioned.fill(
                  child: ClipPath(
                    clipper: QuadClipper(quad: outerQuad()),
                    child: GestureDetector(
                      onPanStart: (details) {
                        initialPos.value = details.globalPosition;
                        initialQuad.value = outerQuad();
                      },
                      onPanUpdate: (details) {
                        final delta = details.delta;
                        var newQuad = outerQuad().copy
                          ..translate(
                            delta.toVector3(),
                          );

                        newQuad = newQuad.copy
                          ..translate(newQuad.moveDeltaInnerQuad(innerQuad()));
                        outerQuad.forceUpdate(
                          newQuad,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            Watch.builder(
              builder: (context) {
                return Positioned.fill(
                  child: ClipPath(
                    clipper: QuadClipper(quad: innerQuad()),
                    child: MouseRegion(
                      child: CustomPaint(
                        painter: QuadPainter(
                          quad: innerQuad(),
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Watch.builder(builder: (context) {
              final inner = innerQuad();
              final outer = outerQuad();
              return Stack(
                children: [
                  ...[
                    inner.point0,
                    inner.point1,
                    inner.point2,
                    inner.point3,
                  ].mapIndexed(
                    (i, e) => Positioned(
                      left: e.x - 5,
                      top: e.y - 5,
                      child: GestureDetector(
                        onPanStart: (details) {
                          initialPos.value = details.globalPosition;
                          initialQuad.value = inner;
                          initialQuad2.value = outer;
                        },
                        onPanUpdate: (details) {
                          final delta = details.globalPosition - initialPos();

                          var point0 = initialQuad().point0;
                          var point1 = initialQuad().point1;
                          var point2 = initialQuad().point2;
                          var point3 = initialQuad().point3;

                          switch (i) {
                            case 0:
                              point0 = snapPointToLine(
                                  initialQuad().point0,
                                  initialQuad().point2,
                                  point0 + delta.toVector3());
                            case 1:
                              point1 = snapPointToLine(
                                  initialQuad().point1,
                                  initialQuad().point3,
                                  point1 + delta.toVector3());
                            case 2:
                              point2 = snapPointToLine(
                                  initialQuad().point2,
                                  initialQuad().point0,
                                  point2 + delta.toVector3());
                            case 3:
                              point3 = snapPointToLine(
                                  initialQuad().point3,
                                  initialQuad().point1,
                                  point3 + delta.toVector3());
                          }

                          var newQuad = i == 0 || i == 2
                              ? QuadUtils.fromPoints02(
                                  point0,
                                  point2,
                                  initialQuad().rect.center.toVector3(),
                                  initialQuad().angle,
                                )
                              : QuadUtils.fromPoints13(
                                  point1,
                                  point3,
                                  initialQuad().rect.center.toVector3(),
                                  initialQuad().angle,
                                );

                          final outInner = outer.innerQuad(newQuad);

                          final outs = newQuad.points.indexed
                              .where((element) =>
                                  element.$1 != (i + 2) % 4 &&
                                  !outer.contains(element.$2))
                              .toList();

                          // print('outs: $outs');

                          if (outs.isEmpty) {
                            innerQuad.value = newQuad;
                            return;
                          }

                          outerQuad.value = QuadUtils.fromPointsExpanded02(
                            outer.copy.point0,
                            outer.copy.point2,
                            outer.copy.centerVec3,
                            outer.copy.angle,
                            outer.copy.angle,
                            outer.copy.intersectInnerQuad(inner),
                            outer.copy.size.aspectRatio,
                          );

                          innerQuad.value = newQuad;
                        },
                        child: const DebugPoint(),
                      ),
                    ),
                  ),
                  // Rotation
                  ...[
                    (inner.point0 + inner.point1) / 2 -
                        rotateVector(
                            Vector3(0, 24, 0), Vector3.zero(), inner.angle),
                  ].map(
                    (e) => Positioned(
                      left: e.x - 5,
                      top: e.y - 5,
                      child: GestureDetector(
                        onPanStart: (detalis) {
                          initialQuad.value = inner;
                          initialQuad2.value = outer;
                        },
                        onPanUpdate: (details) {
                          final newQuad = rotateQuad(
                            initialQuad(),
                            getAngleFromPoints(
                                  details.globalPosition,
                                  initialQuad().center,
                                ) -
                                pi / 2 -
                                initialQuad().angle,
                            initialQuad().center,
                          );
                          innerQuad.value = newQuad;

                          final newOuter = QuadUtils.fromPointsExpanded02(
                            initialQuad2().point0,
                            initialQuad2().point2,
                            initialQuad2().centerVec3,
                            initialQuad2().angle,
                            initialQuad2().angle,
                            initialQuad2().intersectInnerQuad(newQuad),
                            initialQuad2().size.aspectRatio,
                          );
                          outerQuad.value = newOuter;
                        },
                        child: const DebugPoint(),
                      ),
                    ),
                  ),
                  ...[
                    outer.point0,
                    outer.point1,
                    outer.point2,
                    outer.point3,
                  ].mapIndexed(
                    (i, e) => Positioned(
                      left: e.x - 5,
                      top: e.y - 5,
                      child: GestureDetector(

                        onPanStart: (details) {
                          initialPos.value = details.globalPosition;
                          initialQuad.value = outer;
                        },
                        onPanUpdate: (details) {
                          final delta = details.globalPosition - initialPos();

                          var point0 = initialQuad().point0;
                          var point1 = initialQuad().point1;
                          var point2 = initialQuad().point2;
                          var point3 = initialQuad().point3;

                          switch (i) {
                            case 0:
                              point0 = snapPointToLine(
                                  initialQuad().point0,
                                  initialQuad().point2,
                                  point0 + delta.toVector3());
                            case 1:
                              point1 = snapPointToLine(
                                  initialQuad().point1,
                                  initialQuad().point3,
                                  point1 + delta.toVector3());
                            case 2:
                              point2 = snapPointToLine(
                                  initialQuad().point2,
                                  initialQuad().point0,
                                  point2 + delta.toVector3());
                            case 3:
                              point3 = snapPointToLine(
                                  initialQuad().point3,
                                  initialQuad().point1,
                                  point3 + delta.toVector3());
                          }

                          var newQuad = i == 0 || i == 2
                              ? QuadUtils.fromPoints02(
                                  point0,
                                  point2,
                                  initialQuad().rect.center.toVector3(),
                                  initialQuad().angle,
                                )
                              : QuadUtils.fromPoints13(
                                  point1,
                                  point3,
                                  initialQuad().rect.center.toVector3(),
                                  initialQuad().angle,
                                );

                          var intersectInnerQuad = newQuad.intersectInnerQuad(inner);
                          outerQuad.value = QuadUtils.fromPointsExpanded02SingleSide(
                            newQuad.point0,
                            newQuad.point2,
                            initialQuad().centerVec3,
                            newQuad.angle,
                            newQuad.angle,
                            intersectInnerQuad,
                            newQuad.size.aspectRatio,
                            inner.angle,
                            i,
                          );

                        },
                        child: const DebugPoint(),
                      ),
                    ),
                  ),
                  // Rotation
                  ...[
                    (outer.point0 + outer.point1) / 2 -
                        rotateVector(
                            Vector3(0, 24, 0), Vector3.zero(), outer.angle),
                  ].map(
                    (e) => Positioned(
                      left: e.x - 5,
                      top: e.y - 5,
                      child: GestureDetector(
                        onPanStart: (detalis) => initialQuad.value = outer,
                        onPanUpdate: (details) {
                          var newQuad = rotateQuad(
                            initialQuad(),
                            getAngleFromPoints(
                                  details.globalPosition,
                                  initialQuad().center,
                                ) -
                                pi / 2 -
                                initialQuad().angle,
                            initialQuad().center,
                          );

                          newQuad = QuadUtils.fromPointsExpanded02(
                            initialQuad().point0,
                            initialQuad().point2,
                            initialQuad().centerVec3,
                            initialQuad().angle,
                            newQuad.angle,
                            newQuad.intersectInnerQuad(inner),
                            initialQuad().size.aspectRatio,
                          );
                          outerQuad.value = newQuad;
                        },
                        child: const DebugPoint(),
                      ),
                    ),
                  ),
                ],
              );
            }),
            Watch.builder(
              builder: (context) => Stack(
                children: debugPoints()
                    .map(
                      (e) => Positioned(
                          left: e.x - 5,
                          top: e.y - 5,
                          child: const IgnorePointer(
                            child: DebugPoint(
                              color: Colors.teal,
                            ),
                          )),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuadClipper extends CustomClipper<Path> {
  QuadClipper({super.reclip, required this.quad});
  final Quad quad;

  @override
  Path getClip(Size size) {
    return Path()
      //
      ..moveTo(quad.point0.x, quad.point0.y)
      ..lineTo(quad.point1.x, quad.point1.y)
      ..lineTo(quad.point2.x, quad.point2.y)
      ..lineTo(quad.point3.x, quad.point3.y)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

class QuadPainter extends CustomPainter {
  QuadPainter({super.repaint, required this.quad, required this.color});

  final Quad quad;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        //
        ..moveTo(quad.point0.x, quad.point0.y)
        ..lineTo(quad.point1.x, quad.point1.y)
        ..lineTo(quad.point2.x, quad.point2.y)
        ..lineTo(quad.point3.x, quad.point3.y)
        ..close()
      //
      ,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DebugPoint extends StatelessWidget {
  const DebugPoint({super.key, this.color});

  final MaterialColor? color;

  @override
  Widget build(BuildContext context) {
    return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          border: Border.all(
              width: 3,
              color: color?.shade900 ?? Colors.red.shade900.withOpacity(.5),
              strokeAlign: BorderSide.strokeAlignCenter),
          shape: BoxShape.circle,
        ),
        foregroundDecoration: BoxDecoration(
          border: Border.all(
              color: color?.shade100 ?? Colors.red.shade100.withOpacity(.5)),
          shape: BoxShape.circle,
        ));
  }
}
