# Rules

- Decorative elements (badges, icons, overlays) go **around** existing
  widgets, never inside them. Don't touch a working layout subtree; hoist
  the overlay higher until the diff is purely additive.
- Verify with `fvm flutter analyze && fvm flutter test` (plain `flutter`
  isn't on PATH).
- Native code uses dart:ffi, not method channels. Never commit `run.sh`.
