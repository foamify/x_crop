part of 'main.dart';

abstract class QuadUtils {
  static Quad fromRect(Rect rect) {
    return Quad.points(
      Vector3(rect.left, rect.top, 0),
      Vector3(rect.right, rect.top, 0),
      Vector3(rect.right, rect.bottom, 0),
      Vector3(rect.left, rect.bottom, 0),
    );
  }

  static Quad fromPoints02(
    Vector3 p0,
    Vector3 p2,
    Vector3 origin,
    double angle,
  ) {
    final p0Rotated = rotateVector(p0, origin, -angle);
    final p2Rotated = rotateVector(p2, origin, -angle);
    final p1Rotated = Vector3(p2Rotated.x, p0Rotated.y, 0);
    final p3Rotated = Vector3(p0Rotated.x, p2Rotated.y, 0);
    return rotateQuad(
      Quad.points(p0Rotated, p1Rotated, p2Rotated, p3Rotated),
      angle,
      origin.toOffset(),
    );
  }

  static Quad fromPoints13(
    Vector3 p1,
    Vector3 p3,
    Vector3 origin,
    double angle,
  ) {
    final p1Rotated = rotateVector(p1, origin, -angle);
    final p3Rotated = rotateVector(p3, origin, -angle);
    final p0Rotated = Vector3(p3Rotated.x, p1Rotated.y, 0);
    final p2Rotated = Vector3(p1Rotated.x, p3Rotated.y, 0);
    return rotateQuad(
      Quad.points(p0Rotated, p1Rotated, p2Rotated, p3Rotated),
      angle,
      origin.toOffset(),
    );
  }

  static Quad fromPointsExpanded02(
    Vector3 p0,
    Vector3 p2,
    Vector3 origin,
    double oldAngle,
    double newAngle,
    Sides expand,
    double ratio,
  ) {
    final p0Rotated = rotateVector(p0, origin, -oldAngle);
    final p2Rotated = rotateVector(p2, origin, -oldAngle);
    if (expand.left != 0) {
      p0Rotated.add(Vector3(expand.left, 0, 0));

      final y = expand.left / ratio / 2;

      p0Rotated.add(Vector3(0.0, y, 0));
      p2Rotated.add(Vector3(0.0, -y, 0));
    }
    if (expand.right != 0) {
      p2Rotated.add(Vector3(expand.right, 0, 0));

      final y = -expand.right / ratio / 2;

      p0Rotated.add(Vector3(0.0, y, 0));
      p2Rotated.add(Vector3(0.0, -y, 0));
    }
    if (expand.top != 0) {
      p0Rotated.add(Vector3(0, expand.top, 0));

      final x = expand.top * ratio / 2;

      p0Rotated.add(Vector3(x, 0, 0));
      p2Rotated.add(Vector3(-x, 0, 0));
    }
    if (expand.bottom != 0) {
      p2Rotated.add(Vector3(0, expand.bottom, 0));

      final x = -expand.bottom * ratio / 2;

      p0Rotated.add(Vector3(x, 0, 0));
      p2Rotated.add(Vector3(-x, 0, 0));
    }
    final p1Rotated = Vector3(p2Rotated.x, p0Rotated.y, 0);
    final p3Rotated = Vector3(p0Rotated.x, p2Rotated.y, 0);

    return rotateQuad(Quad.points(p0Rotated, p1Rotated, p2Rotated, p3Rotated),
        newAngle, origin.toOffset());
  }
}

double getAngleFromPoints(Offset point1, Offset point2) {
  return atan2(point2.dy - point1.dy, point2.dx - point1.dx);
}

double getAngleFromPointsVec3(Vector3 point1, Vector3 point2) {
  return atan2(point2.y - point1.y, point2.x - point1.x);
}

/// Rotate a point around an origin by an angle
Offset rotatePoint(Offset point, Offset origin, double angle) {
  final cosTheta = cos(angle);
  final sinTheta = sin(angle);

  final oPoint = point - origin;
  final x = oPoint.dx;
  final y = oPoint.dy;

  final newX = x * cosTheta - y * sinTheta;
  final newY = x * sinTheta + y * cosTheta;

  return Offset(newX, newY) + origin;
}

Vector3 rotateVector(Vector3 point, Vector3 origin, double angle) {
  final cosTheta = cos(angle);
  final sinTheta = sin(angle);

  final oPoint = point - origin;
  final x = oPoint.x;
  final y = oPoint.y;

  final newX = x * cosTheta - y * sinTheta;
  final newY = x * sinTheta + y * cosTheta;

  return Vector3(newX, newY, 0) + origin;
}

Quad rotateQuad(Quad quad, double angle, Offset origin) {
  final originVec3 = origin.toVector3();
  final point0 = rotateVector(quad.point0, originVec3, angle);
  final point1 = rotateVector(quad.point1, originVec3, angle);
  final point2 = rotateVector(quad.point2, originVec3, angle);
  final point3 = rotateVector(quad.point3, originVec3, angle);

  return Quad.points(point0, point1, point2, point3);
}

Vector3 snapPointToLine(Vector3 end1, Vector3 end2, Vector3 point) {
  final angle1 = getAngleFromPoints(end1.toOffset(), end2.toOffset()) + pi;
  final angle2 = getAngleFromPoints(point.toOffset(), end2.toOffset()) + pi;
  final end1IsLeft = end1.x < end2.x;
  final end1IsTop = end1.y < end2.y;
  final pointSnap = getTriangleFromLineAndTwoAngle(
    end2,
    point,
    angle1,
    switch ((end1IsLeft, end1IsTop)) {
      (false, true) || (true, false) => angle1 > angle2,
      _ => angle1 < angle2,
    },
  );

  // debugPoints.value = [
  //   // end1,
  //   // end2,
  //   pointSnap,
  // ];
  return pointSnap;
}

/// Calculate the third point of the triangle from two points and two angles
/// https://math.stackexchange.com/questions/1725790/calculate-third-point-of-triangle-from-two-points-and-angles
Vector3 getTriangleFromLineAndTwoAngle(
  Vector3 end2,
  Vector3 end1,
  double angle,
  bool isYOutOfBound,
) {
  const e = 1e-6;

  final x1 = end2.x;
  final y1 = end2.y;
  final x2 = !isYOutOfBound ? end1.x : end2.x;
  final y2 = !isYOutOfBound ? end2.y : end1.y;
  final alp1 = !isYOutOfBound ? angle : angle + pi / 2;
  const alp2 = pi / 2;
  final u = x2 - x1;
  final v = y2 - y1;
  final a3 = sqrt(pow(u, 2) + pow(v, 2));

  final alp3 = pi - alp1 - alp2;

  final a2 = a3 * sin(alp2) / (sin(alp3) + e);

  final RHS1 = x1 * u + y1 * v + a2 * a3 * cos(alp1);

  final RHS2 = y2 * u - x2 * v - a2 * a3 * sin(alp1);

  var x3 = (1 / (pow(a3, 2) + e)) * (u * RHS1 - v * RHS2);
  x3 = isYOutOfBound ? x1 + x2 - x3 : x3;

  var y3 = (1 / (pow(a3, 2) + e)) * (v * RHS1 + u * RHS2);
  y3 = !isYOutOfBound ? y1 + y2 - y3 : y3;

  // debugPoints.value = [
  //   Vector3(x1, y1, 0),
  //   Vector3(x2, y2, 0),
  //   Vector3(x3, y3, 0),
  // ];

  return Vector3(x3, y3, 0);
}
