import 'dart:ui' as ui;

/// Ajustes de edición. El orden debe coincidir con los uniforms de
/// shaders/adjust.frag.
enum Adjust {
  exposure('Exposición'),
  contrast('Contraste'),
  highlights('Luces'),
  shadows('Sombras'),
  whites('Blancos'),
  blacks('Negros'),
  saturation('Saturación'),
  vibrance('Intensidad'),
  temperature('Temperatura'),
  tint('Matiz'),
  sharpness('Nitidez', bipolar: false),
  vignette('Viñeta', bipolar: false);

  final String label;

  /// true: -1..1 con 0 al centro. false: 0..1.
  final bool bipolar;

  const Adjust(this.label, {this.bipolar = true});

  double get min => bipolar ? -1 : 0;
}

typedef Adjustments = Map<Adjust, double>;

bool isNeutral(Adjustments a) => a.values.every((v) => v == 0);

ui.FragmentProgram? _program;

Future<void> loadAdjustShader() async {
  _program ??= await ui.FragmentProgram.fromAsset('shaders/adjust.frag');
}

/// Aplica los ajustes a [photo]. Si no hay cambios devuelve la misma imagen.
Future<ui.Image> applyAdjustments(ui.Image photo, Adjustments a) async {
  if (isNeutral(a)) return photo;
  await loadAdjustShader();
  final w = photo.width.toDouble();
  final h = photo.height.toDouble();

  final shader = _program!.fragmentShader()
    ..setFloat(0, w)
    ..setFloat(1, h)
    ..setImageSampler(0, photo);
  for (final adj in Adjust.values) {
    shader.setFloat(2 + adj.index, a[adj] ?? 0);
  }

  final recorder = ui.PictureRecorder();
  ui.Canvas(
    recorder,
  ).drawRect(ui.Rect.fromLTWH(0, 0, w, h), ui.Paint()..shader = shader);
  final out = await recorder.endRecording().toImage(photo.width, photo.height);
  shader.dispose();
  return out;
}
