import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x_crop/src/box_transform/modifier_state.dart';

void pressModifier(HardwareKeyboard keyboard, PhysicalKeyboardKey physical,
    LogicalKeyboardKey logical) {
  keyboard.handleKeyEvent(KeyDownEvent(
    physicalKey: physical,
    logicalKey: logical,
    timeStamp: const Duration(),
  ));
}

void main() {
  tearDown(() {
    debugPlatformModifierStateReader = null;
  });

  test('platform state takes precedence over a supplied keyboard', () {
    final keyboard = HardwareKeyboard();
    pressModifier(
        keyboard, PhysicalKeyboardKey.altLeft, LogicalKeyboardKey.altLeft);
    debugPlatformModifierStateReader =
        () => (shiftPressed: true, altPressed: false);
    final modifiers = readTransformModifiers(keyboard: keyboard);
    expect(modifiers.scale, isTrue);
    expect(modifiers.mirrored, isFalse);
  });

  test('null platform state falls back to the supplied keyboard', () {
    final keyboard = HardwareKeyboard();
    pressModifier(
        keyboard, PhysicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftLeft);
    pressModifier(
        keyboard, PhysicalKeyboardKey.altRight, LogicalKeyboardKey.altRight);
    debugPlatformModifierStateReader = () => null;
    final modifiers = readTransformModifiers(keyboard: keyboard);
    expect(modifiers.scale, isTrue);
    expect(modifiers.mirrored, isTrue);
  });

  test('platform false/false overrides stale keyboard true/true', () {
    final keyboard = HardwareKeyboard();
    pressModifier(
        keyboard, PhysicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftLeft);
    pressModifier(
        keyboard, PhysicalKeyboardKey.altLeft, LogicalKeyboardKey.altLeft);
    debugPlatformModifierStateReader =
        () => (shiftPressed: false, altPressed: false);
    final modifiers = readTransformModifiers(keyboard: keyboard);
    expect(modifiers.scale, isFalse);
    expect(modifiers.mirrored, isFalse);
  });
}
