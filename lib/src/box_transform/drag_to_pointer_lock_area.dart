import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pointer_lock/pointer_lock.dart';

typedef PointerLockSessionFactory = Stream<PointerLockMoveEvent> Function({
  required bool unlockOnPointerUp,
});

class DragToPointerLockArea extends StatefulWidget {
  const DragToPointerLockArea({
    super.key,
    required this.child,
    required this.onLock,
    required this.onMove,
    required this.onUnlock,
    this.dragThreshold = 4,
    this.createSession,
  });

  final Widget child;
  final VoidCallback onLock;
  final ValueChanged<Offset> onMove;
  final VoidCallback onUnlock;
  final double dragThreshold;
  final PointerLockSessionFactory? createSession;

  @override
  State<DragToPointerLockArea> createState() => _DragToPointerLockAreaState();
}

class _DragToPointerLockAreaState extends State<DragToPointerLockArea> {
  int? _trackedPointer;
  Offset? _startPosition;
  bool _locked = false;
  bool _automaticUnlock = false;
  StreamSubscription<PointerLockMoveEvent>? _subscription;
  bool _finished = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _finished = true;
    final subscription = _subscription;
    _subscription = null;
    subscription?.cancel();
    _resetTracking();
    super.dispose();
  }

  void _resetTracking() {
    _trackedPointer = null;
    _startPosition = null;
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    final subscription = _subscription;
    _subscription = null;
    subscription?.cancel();
    _locked = false;
    _resetTracking();
    if (!_disposed) {
      widget.onUnlock();
    }
  }

  void _startLock() {
    if (_disposed) return;
    _locked = true;
    _finished = false;
    _automaticUnlock = !pointerLock.reportsPointerUpDownEventsReliably(
      windowsMode: PointerLockWindowsMode.capture,
    );
    final stream = widget.createSession != null
        ? widget.createSession!(unlockOnPointerUp: _automaticUnlock)
        : pointerLock.createSession(
            windowsMode: PointerLockWindowsMode.capture,
            cursor: PointerLockCursor.hidden,
            unlockOnPointerUp: _automaticUnlock,
          );
    _subscription = stream.listen(
      (event) {
        if (!_disposed) widget.onMove(event.delta);
      },
      onDone: _finish,
      onError: (_, __) => _finish(),
      cancelOnError: true,
    );
    widget.onLock();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton || _trackedPointer != null) return;
    _trackedPointer = event.pointer;
    _startPosition = event.position;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _trackedPointer || _locked) return;
    final start = _startPosition;
    if (start == null) return;
    if ((event.position - start).distance >= widget.dragThreshold) {
      _startLock();
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _trackedPointer) return;
    if (_locked && !_automaticUnlock) {
      _finish();
    } else if (!_locked) {
      _resetTracking();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: widget.child,
    );
  }
}
