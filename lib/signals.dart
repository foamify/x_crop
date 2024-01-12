part of 'main.dart';

final initialQuad = ValueSignal(Quad());
final initialQuad2 = ValueSignal(Quad());
final initialPos = ValueSignal(Offset.zero);

final innerQuad = ValueSignal(QuadUtils.fromRect(Rect.fromCenter(
  center: const Offset(400, 400),
  width: 100,
  height: 150,
)));
final outerQuad = ValueSignal(QuadUtils.fromRect(Rect.fromCenter(
  center: const Offset(400, 400),
  width: 150,
  height: 250,
)));

final debugPoints = listSignal(<Vector3>[]);
