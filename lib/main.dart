import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

import 'adjust.dart';
import 'brands.dart';
import 'intro.dart';
import 'photo_info.dart';
import 'renderer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadBrandFonts();
  await loadAdjustShader();
  runApp(const WatermarkApp());
}

class WatermarkApp extends StatelessWidget {
  const WatermarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marca',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Color(0xFF111111),
        ),
        useMaterial3: true,
      ),
      home: const _Root(),
    );
  }
}

/// Muestra la animación de apertura y luego pasa al editor con un fundido.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      child: _ready
          ? const EditorPage()
          : Intro(onDone: () => setState(() => _ready = true)),
    );
  }
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  static const _previewSide = 1600;
  static const _exportSide = 4096;

  Uint8List? _bytes;
  PhotoInfo _info = const PhotoInfo();
  ui.Image? _source;
  ui.Image? _preview;
  MarkStyle _style = MarkStyle.bottom;
  MarkColor _color = MarkColor.white;
  MarkText _text = MarkText.shotOn;
  // Cada parte de la marca se activa por separado; sin ninguna queda solo
  // el marco.
  bool _showModel = true;
  bool _showSettings = true;
  bool _busy = false;

  int _tab = 0; // 0: marca, 1: ajustes
  Adjustments _adjust = {};
  Adjust _selected = Adjust.exposure;
  bool _showOriginal = false;

  bool _rendering = false;
  bool _dirty = false;

  Future<void> _pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: true,
    );
    if (file == null) return;
    setState(() => _busy = true);
    final bytes = await file.readAsBytes();
    final info = await PhotoInfo.fromBytes(bytes);
    final source = await decodeImage(bytes, _previewSide);
    // Si hay un render en curso todavía usa la imagen anterior.
    if (!_rendering) _source?.dispose();
    _bytes = bytes;
    _info = info;
    _source = source;
    _adjust = {};
    await _refresh();
  }

  /// Ajustes + marca de agua sobre [photo].
  Future<ui.Image> _compose(ui.Image photo) async {
    final adjusted = await applyAdjustments(photo, _adjust);
    final out = await renderMark(
      photo: adjusted,
      info: _info,
      style: _style,
      color: _color,
      text: _text,
      showModel: _showModel,
      showSettings: _showSettings,
    );
    if (!identical(adjusted, photo)) adjusted.dispose();
    return out;
  }

  /// Rehace la vista previa. Mientras se arrastra un slider, los cambios que
  /// llegan durante un render se juntan en un solo render siguiente.
  Future<void> _refresh() async {
    if (_source == null) return;
    if (_rendering) {
      _dirty = true;
      return;
    }
    _rendering = true;
    try {
      do {
        _dirty = false;
        final img = await _compose(_source!);
        if (!mounted) {
          img.dispose();
          return;
        }
        setState(() {
          _preview?.dispose();
          _preview = img;
          _busy = false;
        });
      } while (_dirty);
    } finally {
      _rendering = false;
    }
  }

  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        throw 'Sin permiso para guardar en Fotos';
      }
      final full = await decodeImage(bytes, _exportSide);
      final out = await _compose(full);
      final png = await encodePng(out);
      full.dispose();
      out.dispose();
      await Gal.putImageBytes(
        png,
        name: 'marca_${DateTime.now().millisecondsSinceEpoch}',
      );
      _toast('Guardada');
    } catch (e) {
      _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _set({
    MarkStyle? style,
    MarkColor? color,
    MarkText? text,
    bool? showModel,
    bool? showSettings,
  }) {
    setState(() {
      _style = style ?? _style;
      _color = color ?? _color;
      _text = text ?? _text;
      _showModel = showModel ?? _showModel;
      _showSettings = showSettings ?? _showSettings;
    });
    _refresh();
  }

  void _setAdjust(Adjust a, double v) {
    setState(() => _adjust = {..._adjust, a: v});
    _refresh();
  }

  Future<void> _editModel() async {
    final ctrl = TextEditingController(text: _info.modelName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text('Modelo', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Galaxy S25 Ultra'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text(
              'Restablecer',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null) return;
    _info = _info.withModelName(name.trim().isEmpty ? null : name);
    _refresh();
  }

  static const _styleLabels = {
    MarkStyle.bottom: 'Inferior',
    MarkStyle.frame: 'Marco',
    MarkStyle.blur: 'Desenfoque',
    MarkStyle.card: 'Tarjeta',
  };

  static const _textLabels = {
    MarkText.shotOn: 'Shot on',
    MarkText.modelBrand: 'Modelo | Marca',
    MarkText.brandModel: 'Marca | Modelo',
  };

  /// Fila con opciones que se deslizan y un control fijo a la derecha.
  Widget _scrollRow(List<Widget> options, Widget trailing) => SizedBox(
    height: 40,
    child: Row(
      children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            children: options,
          ),
        ),
        const SizedBox(width: 8),
        trailing,
        const SizedBox(width: 20),
      ],
    ),
  );

  List<Widget> _markPanel() => [
    _scrollRow(
      [
        _Toggle('Modelo', _showModel, () => _set(showModel: !_showModel)),
        _Toggle(
          'Parámetros',
          _showSettings,
          () => _set(showSettings: !_showSettings),
        ),
        const Padding(
          padding: EdgeInsets.only(right: 18),
          child: VerticalDivider(
            width: 1,
            indent: 12,
            endIndent: 12,
            color: Colors.white24,
          ),
        ),
        // El formato del texto solo aplica cuando se muestra el modelo.
        for (final e in _textLabels.entries)
          _Disabled(
            !_showModel,
            _Option(e.value, _text == e.key, () => _set(text: e.key)),
          ),
      ],
      _Disabled(
        !_showModel,
        GestureDetector(
          onTap: _busy ? null : _editModel,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _info.modelName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.white38),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    _scrollRow(
      [
        for (final e in _styleLabels.entries)
          _Option(e.value, _style == e.key, () => _set(style: e.key)),
      ],
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Swatch(
            Colors.white,
            _color == MarkColor.white,
            () => _set(color: MarkColor.white),
          ),
          const SizedBox(width: 12),
          _Swatch(
            Colors.black,
            _color == MarkColor.black,
            () => _set(color: MarkColor.black),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _adjustPanel() {
    final value = _adjust[_selected] ?? 0;
    final pct = (value * 100).round();
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                ),
                child: Slider(
                  value: value,
                  min: _selected.min,
                  max: 1,
                  onChanged: (v) => _setAdjust(_selected, v),
                ),
              ),
            ),
            // Tocar el valor lo regresa a 0.
            GestureDetector(
              onTap: () => _setAdjust(_selected, 0),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 44,
                child: Text(
                  pct > 0 && _selected.bipolar ? '+$pct' : '$pct',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    color: pct == 0 ? Colors.white38 : Colors.white,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            for (final a in Adjust.values)
              _Option(
                a.label,
                a == _selected,
                () => setState(() => _selected = a),
                modified: (_adjust[a] ?? 0) != 0,
              ),
            if (!isNeutral(_adjust))
              _Option('Restablecer', false, () {
                setState(() => _adjust = {});
                _refresh();
              }),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _source != null;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  const Text(
                    'Marca',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (hasPhoto) ...[
                    IconButton(
                      tooltip: 'Otra foto',
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                    IconButton(
                      tooltip: 'Guardar',
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.download_outlined),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _preview != null
                      ? GestureDetector(
                          onLongPressStart: (_) =>
                              setState(() => _showOriginal = true),
                          onLongPressEnd: (_) =>
                              setState(() => _showOriginal = false),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              RawImage(
                                image: _showOriginal ? _source : _preview,
                                fit: BoxFit.contain,
                              ),
                              if (_busy)
                                const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                        )
                      : _busy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : OutlinedButton(
                          onPressed: _pick,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 16,
                            ),
                          ),
                          child: const Text('Elegir foto'),
                        ),
                ),
              ),
            ),
            if (hasPhoto) ...[
              if (_tab == 0) ..._markPanel() else ..._adjustPanel(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Option('Marca', _tab == 0, () => setState(() => _tab = 0)),
                    _Option(
                      'Ajustes',
                      _tab == 1,
                      () => setState(() => _tab = 1),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Ajuste con un valor distinto de 0: se resalta un poco.
  final bool modified;
  const _Option(this.label, this.selected, this.onTap, {this.modified = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, top: 8, bottom: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: selected
                ? Colors.white
                : modified
                ? Colors.white70
                : Colors.white38,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Interruptor de una parte de la marca (modelo, parámetros).
class _Toggle extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _Toggle(this.label, this.on, this.onTap);

  @override
  Widget build(BuildContext context) {
    final color = on ? Colors.white : Colors.white38;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, top: 8, bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.check_circle : Icons.circle_outlined,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Atenúa y bloquea un control que no aplica en la configuración actual.
class _Disabled extends StatelessWidget {
  final bool disabled;
  final Widget child;
  const _Disabled(this.disabled, this.child);

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: disabled,
    child: Opacity(opacity: disabled ? 0.35 : 1, child: child),
  );
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch(this.color, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}
