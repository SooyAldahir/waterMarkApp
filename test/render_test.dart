import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watermark_app/photo_info.dart';
import 'package:watermark_app/renderer.dart';

Future<ui.Image> _sample(int w, int h) {
  final r = ui.PictureRecorder();
  final c = Canvas(r);
  c.drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2E5E8C), Color(0xFFE0A050)],
      ).createShader(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble())),
  );
  c.drawCircle(Offset(w / 2, h / 2), w / 5, Paint()..color = Colors.white);
  return r.endRecording().toImage(w, h);
}

void main() {
  const info = PhotoInfo(
    make: 'Apple',
    model: 'iPhone 15 Pro',
    iso: '80',
    aperture: 'f/1.8',
    shutter: '1/120s',
    focal: '24mm',
  );

  test('device name', () {
    expect(info.fullName, 'iPhone 15 Pro');
    expect(info.modelName, 'iPhone 15 Pro');
    expect(info.brandMarkText, 'Apple');

    const s25 = PhotoInfo(make: 'samsung', model: 'SM-S938B');
    expect(s25.fullName, 'Samsung Galaxy S25 Ultra');
    expect(s25.modelName, 'Galaxy S25 Ultra');
    expect(s25.brandMarkText, 'SAMSUNG');

    const unknown = PhotoInfo(make: 'samsung', model: 'SM-X999');
    expect(unknown.fullName, 'Samsung SM-X999');
    expect(unknown.withModelName('Galaxy Tab').fullName, 'Samsung Galaxy Tab');

    const pixel = PhotoInfo(make: 'Google', model: 'Pixel 9 Pro');
    expect(pixel.fullName, 'Google Pixel 9 Pro');
    expect(info.settings, '24mm   f/1.8   1/120s   ISO 80');
  });

  test('renders every style', () async {
    const shot = PhotoInfo(
      make: 'samsung',
      model: 'SM-S938B',
      iso: '50',
      aperture: 'f/1.7',
      shutter: '1/250s',
      focal: '23mm',
    );
    final dir = Platform.environment['RENDER_OUT'];
    for (final size in [(1200, 900), (900, 1200)]) {
      final photo = await _sample(size.$1, size.$2);
      for (final style in MarkStyle.values) {
        for (final color in MarkColor.values) {
          for (final text in MarkText.values) {
            final out = await renderMark(
              photo: photo,
              info: shot,
              style: style,
              color: color,
              text: text,
            );
            expect(out.width, greaterThan(0));
            if (dir != null) {
              await File(
                '$dir/${style.name}_${color.name}_${text.name}_${size.$1}x${size.$2}.png',
              ).writeAsBytes(await encodePng(out));
            }
          }
        }
      }
    }
  });
}
