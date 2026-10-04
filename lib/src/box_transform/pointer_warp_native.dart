import 'dart:ffi';
import 'dart:io';
import 'dart:ui';

import 'package:ffi/ffi.dart';

final class _Point extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

final class _Rect extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class _GuiThreadInfo extends Struct {
  @Uint32()
  external int cbSize;
  @Uint32()
  external int flags;
  external Pointer<Void> hwndActive;
  external Pointer<Void> hwndFocus;
  external Pointer<Void> hwndCapture;
  external Pointer<Void> hwndMenuOwner;
  external Pointer<Void> hwndMoveSize;
  external Pointer<Void> hwndCaret;
  external _Rect rcCaret;
}

typedef _GetForegroundWindowNative = Pointer<Void> Function();
typedef _GetForegroundWindowDart = Pointer<Void> Function();
typedef _GetClientRectNative = Int32 Function(
    Pointer<Void> hWnd, Pointer<_Rect> lpRect);
typedef _GetClientRectDart = int Function(
    Pointer<Void> hWnd, Pointer<_Rect> lpRect);
typedef _ClientToScreenNative = Int32 Function(
    Pointer<Void> hWnd, Pointer<_Point> lpPoint);
typedef _ClientToScreenDart = int Function(
    Pointer<Void> hWnd, Pointer<_Point> lpPoint);
typedef _GetWindowThreadProcessIdNative = Uint32 Function(
    Pointer<Void> hWnd, Pointer<Uint32> lpdwProcessId);
typedef _GetWindowThreadProcessIdDart = int Function(
    Pointer<Void> hWnd, Pointer<Uint32> lpdwProcessId);
typedef _GetGuiThreadInfoNative = Int32 Function(
    Uint32 idThread, Pointer<_GuiThreadInfo> pgui);
typedef _GetGuiThreadInfoDart = int Function(
    int idThread, Pointer<_GuiThreadInfo> pgui);
typedef _SetCursorPosNative = Int32 Function(Int32 x, Int32 y);
typedef _SetCursorPosDart = int Function(int x, int y);

_GetForegroundWindowDart? _getForegroundWindow;
_GetClientRectDart? _getClientRect;
_ClientToScreenDart? _clientToScreen;
_GetWindowThreadProcessIdDart? _getWindowThreadProcessId;
_GetGuiThreadInfoDart? _getGuiThreadInfo;
_SetCursorPosDart? _setCursorPos;
bool _resolved = false;

void _resolve() {
  if (_resolved) return;
  _resolved = true;
  if (!Platform.isWindows) return;
  final user32 = DynamicLibrary.open('user32.dll');
  _getForegroundWindow = user32.lookupFunction<_GetForegroundWindowNative,
      _GetForegroundWindowDart>('GetForegroundWindow');
  _getClientRect =
      user32.lookupFunction<_GetClientRectNative, _GetClientRectDart>(
          'GetClientRect');
  _clientToScreen =
      user32.lookupFunction<_ClientToScreenNative, _ClientToScreenDart>(
          'ClientToScreen');
  _getWindowThreadProcessId = user32.lookupFunction<
      _GetWindowThreadProcessIdNative,
      _GetWindowThreadProcessIdDart>('GetWindowThreadProcessId');
  _getGuiThreadInfo =
      user32.lookupFunction<_GetGuiThreadInfoNative, _GetGuiThreadInfoDart>(
          'GetGUIThreadInfo');
  _setCursorPos = user32
      .lookupFunction<_SetCursorPosNative, _SetCursorPosDart>('SetCursorPos');
}

Future<void> warpPointer(Offset normalizedPosition) async {
  _resolve();
  if (!Platform.isWindows) return;
  final getForegroundWindow = _getForegroundWindow;
  final getClientRect = _getClientRect;
  final clientToScreen = _clientToScreen;
  final getWindowThreadProcessId = _getWindowThreadProcessId;
  final getGuiThreadInfo = _getGuiThreadInfo;
  final setCursorPos = _setCursorPos;
  if (getForegroundWindow == null ||
      getClientRect == null ||
      clientToScreen == null ||
      getWindowThreadProcessId == null ||
      getGuiThreadInfo == null ||
      setCursorPos == null) {
    return;
  }
  final hwnd = getForegroundWindow();
  if (hwnd == nullptr) return;
  final windowThreadId = getWindowThreadProcessId(hwnd, nullptr);
  if (windowThreadId == 0) return;
  final rect = calloc<_Rect>();
  final point = calloc<_Point>();
  final guiInfo = calloc<_GuiThreadInfo>();
  try {
    guiInfo.ref.cbSize = sizeOf<_GuiThreadInfo>();
    if (getClientRect(hwnd, rect) == 0) return;
    final width = rect.ref.right - rect.ref.left;
    final height = rect.ref.bottom - rect.ref.top;
    if (width <= 0 || height <= 0) return;
    point.ref.x = rect.ref.left + (normalizedPosition.dx * (width - 1)).round();
    point.ref.y = rect.ref.top + (normalizedPosition.dy * (height - 1)).round();
    if (clientToScreen(hwnd, point) == 0) return;
    final targetX = point.ref.x;
    final targetY = point.ref.y;
    for (var attempt = 0; attempt < 100; attempt++) {
      if (getGuiThreadInfo(windowThreadId, guiInfo) == 0) return;
      if (guiInfo.ref.hwndCapture == nullptr) {
        if (getForegroundWindow() == hwnd) {
          setCursorPos(targetX, targetY);
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  } finally {
    calloc.free(rect);
    calloc.free(point);
    calloc.free(guiInfo);
  }
}
