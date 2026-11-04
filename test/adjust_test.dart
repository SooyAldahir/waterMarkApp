import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watermark_app/adjust.dart';

Future<ui.Image> _gray(int v) {
  final r = ui.PictureRecorder();
  Canvas(r).drawRect(
    const Rect.fromLTWH(0, 0, 64, 64),
    Paint()..color = Color.fromARGB(255, v, v, v),
  );
  return r.endRecording().toImage(64, 64);
}

Future<int> _red(ui.Image img) async {
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.getUint8((32 * 64 + 32) * 4);
}

void main() {
  test('sin ajustes devuelve la misma imagen', () async {
    final img = await _gray(128);
    expect(identical(await applyAdjustments(img, {}), img), isTrue);
    expect(
      identical(await applyAdjustments(img, {Adjust.exposure: 0}), img),
      isTrue,
    );
  });

  test('exposición y sombras cambian el brillo', () async {
    final img = await _gray(100);
    final base = await _red(img);
    final up = await _red(await applyAdjustments(img, {Adjust.exposure: 0.5}));
    final down = await _red(
      await applyAdjustments(img, {Adjust.exposure: -0.5}),
    );
    final shadows = await _red(
      await applyAdjustments(await _gray(30), {Adjust.shadows: 1}),
    );
    expect(up, greaterThan(base));
    expect(down, lessThan(base));
    expect(shadows, greaterThan(30));
  });
}
