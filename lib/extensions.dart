part of 'main.dart';

extension OffsetEx on Offset {
  Vector3 toVector3() => Vector3(dx, dy, 0);
}

extension Vector3Ex on Vector3 {
  Offset toOffset() => Offset(x, y);
}

extension QuadEx on Quad {
  Vector3 get centerVec3 => (point0 + point1 + point2 + point3) / 4;
  Offset get center => centerVec3.toOffset();
  double get angle => getAngleFromPointsVec3(point0, point1);
  Quad get copy => Quad.points(point0, point1, point2, point3);
  Size get size => Size(point0.distanceTo(point1), point0.distanceTo(point3));

  bool contains(Vector3 vec) {
    final vecRot = rotateVector(vec, centerVec3, -angle);
    return rect.contains(vecRot.toOffset());
  }

  Rect get rect {
    if (angle == 0) {
      return Rect.fromPoints(
        point0.toOffset(),
        point2.toOffset(),
      );
    } else {
      return Rect.fromPoints(
        rotateVector(point0, centerVec3, -angle).toOffset(),
        rotateVector(point2, centerVec3, -angle).toOffset(),
      );
    }
  }

  List<Vector3> get points => [point0, point1, point2, point3];

  double get left => points.fold(double.infinity,
      (value, element) => value < element.x ? value : element.x);

  double get top => points.fold(double.infinity,
      (value, element) => value < element.y ? value : element.y);

  double get right => points.fold(double.negativeInfinity,
      (value, element) => value > element.x ? value : element.x);

  double get bottom => points.fold(double.negativeInfinity,
      (value, element) => value > element.y ? value : element.y);

  Quad innerQuad(Quad quad) {
    return rotateQuad(quad, -angle, centerVec3.toOffset());
  }

  Vector3 moveDeltaInnerQuad(Quad quad) {
    var intersectPoint = Vector3.zero();
    final inner = innerQuad(quad);

    // debugPoints.value = [
    //   ...inner.points,
    //   rect.topLeft.toVector3(),
    //   rect.topRight.toVector3(),
    //   rect.bottomRight.toVector3(),
    //   rect.bottomLeft.toVector3(),
    // ];

    final topLeft = rect.topLeft;
    final bottomRight = rect.bottomRight;

    final deltaLeft = inner.left - rect.left;
    final deltaTop = inner.top - rect.top;
    final deltaRight = inner.right - rect.right;
    final deltaBottom = inner.bottom - rect.bottom;

    if (topLeft.dx > inner.left && bottomRight.dx > inner.right) {
      intersectPoint.x = deltaLeft;
    } else if (bottomRight.dx < inner.right && topLeft.dx < inner.left) {
      intersectPoint.x = deltaRight;
    }

    if (topLeft.dy > inner.top && bottomRight.dy > inner.bottom) {
      intersectPoint.y = deltaTop;
    } else if (bottomRight.dy < inner.bottom && topLeft.dy < inner.top) {
      intersectPoint.y = deltaBottom;
    }

    return rotateVector(intersectPoint, Vector3.zero(), angle);
  }

  Sides intersectInnerQuad(Quad quad) {
    final inner = innerQuad(quad);

    // debugPoints.value = [
    //   ...inner.points,
    //   rect.topLeft.toVector3(),
    //   rect.topRight.toVector3(),
    //   rect.bottomRight.toVector3(),
    //   rect.bottomLeft.toVector3(),
    // ];

    final topLeft = rect.topLeft;
    final bottomRight = rect.bottomRight;

    var deltaLeft = 0.0;
    var deltaTop = 0.0;
    var deltaRight = 0.0;
    var deltaBottom = 0.0;

    if (topLeft.dx > inner.left && bottomRight.dx > inner.right) {
      deltaLeft = inner.left - rect.left;
    } else if (bottomRight.dx < inner.right && topLeft.dx < inner.left) {
      deltaRight = inner.right - rect.right;
    } else if (topLeft.dx > inner.left && bottomRight.dx < inner.right) {
      deltaLeft = inner.left - rect.left;
      deltaRight = inner.right - rect.right;
    }

    if (topLeft.dy > inner.top && bottomRight.dy > inner.bottom) {
      deltaTop = inner.top - rect.top;
    } else if (bottomRight.dy < inner.bottom && topLeft.dy < inner.top) {
      deltaBottom = inner.bottom - rect.bottom;
    } else if (topLeft.dy > inner.top && bottomRight.dy < inner.bottom) {
      deltaTop = inner.top - rect.top;
      deltaBottom = inner.bottom - rect.bottom;
    }

    return (
      left: deltaLeft,
      top: deltaTop,
      right: deltaRight,
      bottom: deltaBottom
    );
  }
}

typedef Sides = ({double bottom, double left, double right, double top});

extension SidesEx on Sides {
  bool get isAllZero => bottom == 0 && left == 0 && right == 0 && top == 0;
  Sides get onlyBiggest {
    final biggest = max(
        max(bottom.abs(), left.abs()),
        max(
          right.abs(),
          top.abs(),
        ));
    if (biggest == bottom.abs()) {
      return (bottom: bottom, left: 0, right: 0, top: 0);
    } else if (biggest == left.abs()) {
      return (
        bottom: 0,
        left: left,
        right: 0,
        top: 0,
      );
    } else if (biggest == right.abs()) {
      return (
        bottom: 0,
        left: 0,
        right: right,
        top: 0,
      );
    } else {
      return (
        bottom: 0,
        left: 0,
        right: 0,
        top: top,
      );
    }
  }

  Sides get onlySmallest {
    final smallest = min(
        min(bottom.abs() != 0 ? bottom.abs() : double.infinity,
            left.abs() != 0 ? left.abs() : double.infinity),
        min(right.abs() != 0 ? right.abs() : double.infinity,
            top.abs() != 0 ? top.abs() : double.infinity));
    if (smallest == bottom.abs()) {
      return (bottom: bottom, left: 0, right: 0, top: 0);
    } else if (smallest == left.abs()) {
      return (bottom: 0, left: left, right: 0, top: 0);
    } else if (smallest == right.abs()) {
      return (bottom: 0, left: 0, right: right, top: 0);
    } else {
      return (bottom: 0, left: 0, right: 0, top: top);
    }
  }
}
