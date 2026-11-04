import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'photo_info.dart';

/// bottom: franja inferior. frame: marco. blur: foto sobre su fondo
/// desenfocado. card: marco centrado sobre el fondo desenfocado.
enum MarkStyle { bottom, frame, blur, card }

enum MarkColor { white, black }

/// "Shot on Samsung Galaxy S25 Ultra", "Galaxy S25 Ultra | SAMSUNG" o
/// "SAMSUNG | Galaxy S25 Ultra".
enum MarkText { shotOn, modelBrand, brandModel }

class _Palette {
  final Color bg;
  final Color primary;
  final Color secondary;
  const _Palette(this.bg, this.primary, this.secondary);

  static _Palette of(MarkColor c) => c == MarkColor.white
      ? const _Palette(Color(0xFFFFFFFF), Color(0xFF111111), Color(0xFF8C8C8C))
      : const _Palette(Color(0xFF000000), Color(0xFFF2F2F2), Color(0xFF8A8A8A));
}

/// Decodifica la foto limitando su lado mayor a [maxSide] px.
Future<ui.Image> decodeImage(Uint8List bytes, int maxSide) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (w, h) {
      if (math.max(w, h) <= maxSide) return ui.TargetImageSize();
      return w >= h
          ? ui.TargetImageSize(width: maxSide)
          : ui.TargetImageSize(height: maxSide);
    },
  );
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// Compone la foto con la marca de agua y devuelve la imagen final.
Future<ui.Image> renderMark({
  required ui.Image photo,
  required PhotoInfo info,
  required MarkStyle style,
  required MarkColor color,
  required MarkText text,
}) async {
  final p = _Palette.of(color);
  final w = photo.width.toDouble();
  final h = photo.height.toDouble();
  final short = math.min(w, h);
  final barH = short * 0.13;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final src = Rect.fromLTWH(0, 0, w, h);
  final hq = Paint()..filterQuality = FilterQuality.high;
  late final Size out;

  switch (style) {
    case MarkStyle.bottom:
      out = Size(w, h + barH);
      canvas.drawRect(Offset.zero & out, Paint()..color = p.bg);
      canvas.drawImage(photo, Offset.zero, hq);
      _drawBar(
        canvas,
        Rect.fromLTWH(0, h, w, barH),
        info,
        p,
        text,
        short * 0.05,
      );

    case MarkStyle.frame:
      final b = short * 0.04;
      out = Size(w + b * 2, h + b + barH);
      canvas.drawRect(Offset.zero & out, Paint()..color = p.bg);
      canvas.drawImage(photo, Offset(b, b), hq);
      _drawBar(
        canvas,
        Rect.fromLTWH(0, b + h, out.width, barH),
        info,
        p,
        text,
        b,
      );

    case MarkStyle.blur:
      out = Size(w, h);
      _blurBackground(canvas, photo, out, p, short);

      // Foto centrada con texto debajo.
      final pad = short * 0.05;
      final textH = short * 0.17;
      final scale = math.min((w - pad * 2) / w, (h - pad * 2 - textH) / h);
      final pw = w * scale, ph = h * scale;
      final top = (h - ph - textH) / 2;
      final dst = Rect.fromLTWH((w - pw) / 2, top, pw, ph);
      final rr = RRect.fromRectAndRadius(dst, Radius.circular(short * 0.015));
      _shadow(canvas, rr, short);
      canvas.save();
      canvas.clipRRect(rr);
      canvas.drawImageRect(photo, src, dst, hq);
      canvas.restore();
      _drawCentered(
        canvas,
        Rect.fromLTWH(0, dst.bottom, w, textH),
        info,
        p,
        text,
        short,
      );

    case MarkStyle.card:
      out = Size(w, h);
      _blurBackground(canvas, photo, out, p, short);

      // Tarjeta: borde fino y zona inferior para el texto, a escala.
      final b = short * 0.03;
      final barH = short * 0.13;
      final cw = w + b * 2, ch = h + b + barH;
      final pad = short * 0.08;
      final s = math.min((w - pad * 2) / cw, (h - pad * 2) / ch);
      final card = Rect.fromCenter(
        center: Offset(w / 2, h / 2),
        width: cw * s,
        height: ch * s,
      );
      final rr = RRect.fromRectAndRadius(card, Radius.circular(short * 0.004));
      _shadow(canvas, rr, short);
      canvas.drawRRect(rr, Paint()..color = p.bg);
      final dst = Rect.fromLTWH(
        card.left + b * s,
        card.top + b * s,
        w * s,
        h * s,
      );
      canvas.drawImageRect(photo, src, dst, hq);
      _drawCentered(
        canvas,
        Rect.fromLTRB(card.left, dst.bottom, card.right, card.bottom),
        info,
        p,
        text,
        short * s * 0.7,
      );
  }

  final picture = recorder.endRecording();
  return picture.toImage(out.width.round(), out.height.round());
}

/// La misma foto, ampliada y desenfocada, cubriendo todo el lienzo.
void _blurBackground(
  Canvas canvas,
  ui.Image photo,
  Size out,
  _Palette p,
  double short,
) {
  final src = Rect.fromLTWH(
    0,
    0,
    photo.width.toDouble(),
    photo.height.toDouble(),
  );
  final sigma = short * 0.06;
  canvas.save();
  canvas.clipRect(Offset.zero & out);
  canvas.saveLayer(
    Offset.zero & out,
    Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.clamp,
      ),
  );
  canvas.drawImageRect(
    photo,
    src,
    (Offset.zero & out).inflate(sigma * 2),
    Paint()..filterQuality = FilterQuality.medium,
  );
  canvas.restore();
  canvas.drawRect(
    Offset.zero & out,
    Paint()..color = p.bg.withValues(alpha: 0.25),
  );
  canvas.restore();
}

void _shadow(Canvas canvas, RRect rr, double short) {
  canvas.drawRRect(
    rr.shift(Offset(0, short * 0.008)),
    Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, short * 0.02),
  );
}

Future<Uint8List> encodePng(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Barra inferior: título a la izquierda, ajustes a la derecha.
void _drawBar(
  Canvas canvas,
  Rect r,
  PhotoInfo info,
  _Palette p,
  MarkText text,
  double hPad,
) {
  final big = r.height * 0.19;
  final gap = r.height * 0.06;
  final inner = r.width - hPad * 2;

  final rLines = [
    if (info.settings.isNotEmpty)
      _text(info.settings, big * 0.8, p.primary, FontWeight.w500, inner * 0.45),
  ];
  final rightW = rLines.fold<double>(0, (m, t) => math.max(m, t.width));
  final rightH =
      rLines.fold<double>(0, (s, t) => s + t.height) +
      gap * (rLines.length - 1);
  var y = r.top + (r.height - rightH) / 2;
  for (final t in rLines) {
    t.paint(canvas, Offset(r.right - hPad - t.width, y));
    y += t.height + gap;
  }

  final leftW = inner - rightW - (rightW > 0 ? hPad : 0);
  final title = _title(info, text, big, p, leftW);
  title.paint(
    canvas,
    Offset(r.left + hPad, r.top + (r.height - title.height) / 2),
  );
}

/// Texto centrado bajo la foto (desenfoque y tarjeta). [unit] escala el texto.
void _drawCentered(
  Canvas canvas,
  Rect r,
  PhotoInfo info,
  _Palette p,
  MarkText text,
  double unit,
) {
  final maxW = r.width * 0.9;
  final lines = [
    _title(info, text, unit * 0.03, p, maxW),
    if (info.settings.isNotEmpty)
      _text(info.settings, unit * 0.021, p.primary, FontWeight.w400, maxW),
  ];
  final gap = unit * 0.008;
  final total =
      lines.fold<double>(0, (s, t) => s + t.height) + gap * (lines.length - 1);
  var y = r.top + (r.height - total) / 2;
  for (final t in lines) {
    t.paint(canvas, Offset(r.left + (r.width - t.width) / 2, y));
    y += t.height + gap;
  }
}

/// Línea principal en el formato elegido.
TextPainter _title(
  PhotoInfo info,
  MarkText text,
  double size,
  _Palette p,
  double maxW,
) {
  TextStyle style(FontWeight weight, [Color? color]) => TextStyle(
    fontSize: size,
    color: color ?? p.primary,
    fontWeight: weight,
    letterSpacing: size * 0.02,
    height: 1.15,
  );

  final List<InlineSpan> spans;
  switch (text) {
    case MarkText.shotOn:
      spans = [
        TextSpan(text: 'Shot on ', style: style(FontWeight.w300)),
        TextSpan(text: info.fullName, style: style(FontWeight.w600)),
      ];
    case MarkText.modelBrand:
    case MarkText.brandModel:
      final markText = info.brandMarkText;
      final modelText = info.modelName;
      final brandStyle = TextStyle(
        fontSize: size,
        color: p.primary,
        fontFamily: info.brandFontFamily,
        // Sin fuente propia, imita un logotipo: grueso y espaciado.
        fontWeight: info.brandFontFamily == null
            ? FontWeight.w800
            : FontWeight.w400,
        letterSpacing: info.brandFontFamily == null ? size * 0.16 : 0,
        height: 1.15,
      );
      final mark = markText.isEmpty
          ? null
          : TextSpan(text: markText, style: brandStyle);
      final model = modelText.isEmpty || modelText == info.brand
          ? null
          : TextSpan(text: modelText, style: style(FontWeight.w500));
      final parts = text == MarkText.modelBrand ? [model, mark] : [mark, model];
      final present = parts.whereType<TextSpan>().toList();
      spans = present.isEmpty
          ? [TextSpan(text: info.fullName, style: style(FontWeight.w500))]
          : [
              present.first,
              if (present.length > 1) ...[
                TextSpan(
                  text: '  |  ',
                  style: style(FontWeight.w200, p.secondary),
                ),
                present.last,
              ],
            ];
  }
  return TextPainter(
    text: TextSpan(children: spans),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxW);
}

TextPainter _text(
  String s,
  double size,
  Color color,
  FontWeight weight,
  double maxW,
) {
  return TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: size * 0.02,
        height: 1.15,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxW);
}
