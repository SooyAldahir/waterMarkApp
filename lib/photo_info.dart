import 'package:exif/exif.dart';

import 'brands.dart';

/// Datos de cámara extraídos del EXIF de la foto.
class PhotoInfo {
  final String? make;
  final String? model;
  final String? iso;
  final String? aperture;
  final String? shutter;
  final String? focal;
  final String? lens;

  /// Nombre del modelo escrito a mano por el usuario.
  final String? customModel;

  const PhotoInfo({
    this.make,
    this.model,
    this.iso,
    this.aperture,
    this.shutter,
    this.focal,
    this.lens,
    this.customModel,
  });

  String get _key => brandKey(make);

  /// "Samsung", "Apple"...
  String get brand => brandName(_key);

  /// La marca como la escribe su logotipo: "SAMSUNG", "Apple"...
  String get brandMarkText => brandMark(_key);

  /// Modelo comercial sin la marca: "Galaxy S25 Ultra", "iPhone 15 Pro".
  String get modelName {
    final custom = customModel?.trim() ?? '';
    if (custom.isNotEmpty) return custom;
    final m = marketingModel(_key, model);
    return m.isEmpty ? brand : m;
  }

  /// Nombre completo para "Shot on ...": la marca solo se antepone si el
  /// modelo no la lleva implícita ("iPhone 15 Pro", "Samsung Galaxy S25 Ultra").
  String get fullName {
    final m = modelName;
    if (m.isEmpty) return 'Unknown device';
    if (brand.isEmpty ||
        _key == 'apple' ||
        m.toLowerCase().startsWith(brand.toLowerCase())) {
      return m;
    }
    return '$brand $m';
  }

  String? get brandFontFamily => brandFont(_key);

  PhotoInfo withModelName(String? name) => PhotoInfo(
    make: make,
    model: model,
    iso: iso,
    aperture: aperture,
    shutter: shutter,
    focal: focal,
    lens: lens,
    customModel: name,
  );

  /// "24mm  f/1.8  1/120s  ISO 100"
  String get settings => [
    focal,
    aperture,
    shutter,
    if (iso != null) 'ISO $iso',
  ].whereType<String>().join('   ');

  static Future<PhotoInfo> fromBytes(List<int> bytes) async {
    final Map<String, IfdTag> t;
    try {
      t = await readExifFromBytes(bytes);
    } catch (_) {
      return const PhotoInfo();
    }

    String? str(String key) {
      final v = t[key]?.printable.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    double? num(String key) {
      final values = t[key]?.values.toList();
      if (values == null || values.isEmpty) return null;
      final v = values.first;
      if (v is Ratio) return v.denominator == 0 ? null : v.toDouble();
      if (v is int) return v.toDouble();
      return null;
    }

    String? aperture;
    final f = num('EXIF FNumber');
    if (f != null && f > 0) aperture = 'f/${_trim(f)}';

    String? shutter;
    final s = num('EXIF ExposureTime');
    if (s != null && s > 0) {
      shutter = s >= 1 ? '${_trim(s)}s' : '1/${(1 / s).round()}s';
    }

    String? focal;
    final f35 = num('EXIF FocalLengthIn35mmFilm');
    final fl = (f35 != null && f35 > 0) ? f35 : num('EXIF FocalLength');
    if (fl != null && fl > 0) focal = '${fl.round()}mm';

    return PhotoInfo(
      make: str('Image Make'),
      model: str('Image Model'),
      iso: str('EXIF ISOSpeedRatings') ?? str('EXIF PhotographicSensitivity'),
      aperture: aperture,
      shutter: shutter,
      focal: focal,
      lens: str('EXIF LensModel'),
    );
  }

  static String _trim(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}
