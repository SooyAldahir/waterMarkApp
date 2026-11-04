import 'package:flutter/material.dart';

/// Animación de apertura: el icono aparece y crece un poco, luego el nombre.
/// Al terminar llama a [onDone].
class Intro extends StatefulWidget {
  final VoidCallback onDone;
  const Intro({super.key, required this.onDone});

  @override
  State<Intro> createState() => _IntroState();
}

class _IntroState extends State<Intro> with SingleTickerProviderStateMixin {
  static const _icon = AssetImage('assets/img/icon_intro.png');

  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  late final _iconIn = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
  );
  late final _textIn = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.3, 0.65, curve: Curves.easeOutCubic),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Espera a que el icono esté cargado para que no aparezca de golpe.
    precacheImage(_icon, context).whenComplete(() {
      if (!mounted) return;
      _c.forward().whenComplete(widget.onDone);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: _iconIn.value,
                child: Transform.scale(
                  scale: 0.82 + 0.18 * _iconIn.value,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: const Image(image: _icon, width: 96, height: 96),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Opacity(
                opacity: _textIn.value,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - _textIn.value)),
                  child: const Text(
                    'Marca',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
