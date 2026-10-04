import 'dart:ffi';
import 'dart:io';

typedef _GetAsyncKeyStateNative = Int16 Function(Int32 vKey);
typedef _GetAsyncKeyStateDart = int Function(int vKey);

const int _vkLShift = 0xA0;
const int _vkRShift = 0xA1;
const int _vkLMenu = 0xA4;
const int _vkRMenu = 0xA5;

_GetAsyncKeyStateDart? _getAsyncKeyState;
bool _resolved = false;

void _resolve() {
  if (_resolved) return;
  _resolved = true;
  if (!Platform.isWindows) return;
  _getAsyncKeyState = DynamicLibrary.open('user32.dll')
      .lookupFunction<_GetAsyncKeyStateNative, _GetAsyncKeyStateDart>(
          'GetAsyncKeyState');
}

bool _down(int vKey) => (_getAsyncKeyState!(vKey) & 0x8000) != 0;

({bool shiftPressed, bool altPressed})? readPlatformModifierState() {
  _resolve();
  if (!Platform.isWindows || _getAsyncKeyState == null) return null;
  return (
    shiftPressed: _down(_vkLShift) || _down(_vkRShift),
    altPressed: _down(_vkLMenu) || _down(_vkRMenu),
  );
}
