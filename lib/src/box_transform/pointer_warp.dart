import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'pointer_warp_stub.dart' if (dart.library.io) 'pointer_warp_native.dart'
    as platform;

typedef PointerWarpDelegate = Future<void> Function(Offset normalizedPosition);

@visibleForTesting
PointerWarpDelegate? debugPointerWarpDelegate;

Future<void> warpPointerInWindow(Offset position, Size windowSize) async {
  if (windowSize.isEmpty || !position.dx.isFinite || !position.dy.isFinite) {
    return;
  }
  final normalized = Offset(
    (position.dx / windowSize.width).clamp(0.0, 1.0).toDouble(),
    (position.dy / windowSize.height).clamp(0.0, 1.0).toDouble(),
  );
  await (debugPointerWarpDelegate ?? platform.warpPointer)(normalized);
}
