import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'model.dart';
import 'modifier_state_stub.dart'
    if (dart.library.io) 'modifier_state_native.dart' as platform;

typedef PlatformModifierState = ({bool shiftPressed, bool altPressed});
typedef PlatformModifierStateReader = PlatformModifierState? Function();

@visibleForTesting
PlatformModifierStateReader? debugPlatformModifierStateReader;

TransformModifiers readTransformModifiers({HardwareKeyboard? keyboard}) {
  final native = (debugPlatformModifierStateReader ??
      platform.readPlatformModifierState)();
  if (native != null) {
    return TransformModifiers(
      scale: native.shiftPressed,
      mirrored: native.altPressed,
    );
  }
  final fallback = keyboard ?? HardwareKeyboard.instance;
  return TransformModifiers(
    scale: fallback.isShiftPressed,
    mirrored: fallback.isAltPressed,
  );
}
