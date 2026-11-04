import 'package:flutter/services.dart';

/// Marca normalizada a partir del campo EXIF "Make".
String brandKey(String? make) {
  final m = (make ?? '').trim().toLowerCase();
  if (m.isEmpty) return '';
  for (final k in _brandNames.keys) {
    if (m.startsWith(k)) return k;
  }
  return m;
}

/// "Samsung", "Apple"... para usar en texto corrido.
String brandName(String key) {
  if (key.isEmpty) return '';
  return _brandNames[key]?.$1 ?? key[0].toUpperCase() + key.substring(1);
}

/// Cómo escribe la marca su propio logotipo: "SAMSUNG", "Apple", "vivo"...
String brandMark(String key) {
  if (key.isEmpty) return '';
  return _brandNames[key]?.$2 ?? key.toUpperCase();
}

const _brandNames = {
  'samsung': ('Samsung', 'SAMSUNG'),
  'apple': ('Apple', 'Apple'),
  'google': ('Google', 'Google'),
  'xiaomi': ('Xiaomi', 'Xiaomi'),
  'redmi': ('Redmi', 'Redmi'),
  'poco': ('POCO', 'POCO'),
  'oneplus': ('OnePlus', 'OnePlus'),
  'huawei': ('Huawei', 'HUAWEI'),
  'honor': ('Honor', 'HONOR'),
  'motorola': ('Motorola', 'motorola'),
  'sony': ('Sony', 'SONY'),
  'oppo': ('OPPO', 'OPPO'),
  'vivo': ('vivo', 'vivo'),
  'nothing': ('Nothing', 'Nothing'),
  'realme': ('realme', 'realme'),
};

/// Nombre comercial del modelo, sin la marca: "Galaxy S25 Ultra", "iPhone 15 Pro".
String marketingModel(String key, String? model) {
  var m = (model ?? '').trim();
  if (m.isEmpty) return '';
  if (key == 'samsung') {
    final code = RegExp(r'^SM-([A-Z]\d{3})').firstMatch(m.toUpperCase());
    final name = code == null ? null : _samsung[code.group(1)];
    if (name != null) return name;
  }
  // Quita la marca si el modelo la repite ("Xiaomi 13 Pro" -> "13 Pro").
  final b = brandName(key);
  if (b.isNotEmpty && m.toLowerCase().startsWith('${b.toLowerCase()} ')) {
    m = m.substring(b.length + 1);
  }
  return m;
}

/// Samsung guarda en EXIF el código (SM-S938B), no el nombre comercial.
const _samsung = {
  'S942': 'Galaxy S26',
  'S947': 'Galaxy S26+',
  'S948': 'Galaxy S26 Ultra',
  'S931': 'Galaxy S25',
  'S936': 'Galaxy S25+',
  'S937': 'Galaxy S25 Edge',
  'S938': 'Galaxy S25 Ultra',
  'S731': 'Galaxy S25 FE',
  'S921': 'Galaxy S24',
  'S926': 'Galaxy S24+',
  'S928': 'Galaxy S24 Ultra',
  'S721': 'Galaxy S24 FE',
  'S911': 'Galaxy S23',
  'S916': 'Galaxy S23+',
  'S918': 'Galaxy S23 Ultra',
  'S711': 'Galaxy S23 FE',
  'S901': 'Galaxy S22',
  'S906': 'Galaxy S22+',
  'S908': 'Galaxy S22 Ultra',
  'G990': 'Galaxy S21 FE',
  'G991': 'Galaxy S21',
  'G996': 'Galaxy S21+',
  'G998': 'Galaxy S21 Ultra',
  'G980': 'Galaxy S20',
  'G981': 'Galaxy S20',
  'G985': 'Galaxy S20+',
  'G986': 'Galaxy S20+',
  'G988': 'Galaxy S20 Ultra',
  'G780': 'Galaxy S20 FE',
  'G781': 'Galaxy S20 FE',
  'N981': 'Galaxy Note20',
  'N985': 'Galaxy Note20 Ultra',
  'N986': 'Galaxy Note20 Ultra',
  'F966': 'Galaxy Z Fold7',
  'F766': 'Galaxy Z Flip7',
  'F761': 'Galaxy Z Flip7 FE',
  'F956': 'Galaxy Z Fold6',
  'F741': 'Galaxy Z Flip6',
  'F946': 'Galaxy Z Fold5',
  'F731': 'Galaxy Z Flip5',
  'F936': 'Galaxy Z Fold4',
  'F721': 'Galaxy Z Flip4',
  'A566': 'Galaxy A56',
  'A366': 'Galaxy A36',
  'A266': 'Galaxy A26',
  'A165': 'Galaxy A16',
  'A166': 'Galaxy A16 5G',
  'A556': 'Galaxy A55',
  'A356': 'Galaxy A35',
  'A256': 'Galaxy A25',
  'A155': 'Galaxy A15',
  'A156': 'Galaxy A15 5G',
  'A546': 'Galaxy A54',
  'A346': 'Galaxy A34',
  'A245': 'Galaxy A24',
  'A145': 'Galaxy A14',
  'A146': 'Galaxy A14 5G',
  'A536': 'Galaxy A53',
  'A336': 'Galaxy A33',
};

final _loadedFonts = <String>{};

/// Fuente propia de la marca, si se agregó en assets/fonts/{marca}.ttf|.otf.
String? brandFont(String key) =>
    _loadedFonts.contains(key) ? 'brand_$key' : null;

/// Carga las fuentes de marca que existan en assets/fonts/.
Future<void> loadBrandFonts() async {
  for (final key in _brandNames.keys) {
    for (final ext in ['ttf', 'otf']) {
      try {
        final data = await rootBundle.load('assets/fonts/$key.$ext');
        await (FontLoader('brand_$key')..addFont(Future.value(data))).load();
        _loadedFonts.add(key);
        break;
      } catch (_) {
        // No hay fuente para esta marca: se usa la del sistema.
      }
    }
  }
}
