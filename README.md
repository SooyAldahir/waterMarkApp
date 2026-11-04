# Marca

App móvil en Flutter para agregar a tus fotos una marca de agua con los datos de la cámara (modelo del celular, focal, apertura, velocidad e ISO) y editarlas con ajustes básicos. Interfaz minimalista en modo oscuro.

Todo se procesa en el teléfono: no hay backend, funciona sin internet y las fotos nunca salen del dispositivo.

## Funciones

**Marca de agua**

- Lee los datos EXIF de la foto: marca, modelo, focal (equivalente a 35 mm), apertura, velocidad de obturación e ISO.
- Dos formatos de texto:
  - `Shot on Samsung Galaxy S25 Ultra`. La marca solo se antepone cuando hace falta: un iPhone queda como `Shot on iPhone 15 Pro`.
  - `Galaxy S25 Ultra | SAMSUNG`, con la marca escrita como en su logotipo.
- Tres estilos, cada uno en blanco o negro:
  - **Inferior:** franja debajo de la foto.
  - **Marco:** borde alrededor, más ancho abajo.
  - **Desenfoque:** la misma foto desenfocada de fondo y la foto al centro con el texto debajo.
- El nombre del modelo se puede editar a mano. Samsung guarda en la foto un código (`SM-S938B`), no el nombre comercial; la app lo traduce con una tabla en `lib/brands.dart`, y si un modelo no está ahí, lo escribes tú.

**Ajustes de edición**

Exposición, Contraste, Luces, Sombras, Blancos, Negros, Saturación, Intensidad, Temperatura, Matiz, Nitidez y Viñeta.

- Se calculan en la GPU con un shader (`shaders/adjust.frag`), así que la vista previa responde al instante.
- Se aplican antes de la marca, de modo que el texto y el marco no se alteran.
- Tocar el número junto al control lo regresa a 0. "Restablecer" quita todos los ajustes.
- Mantén presionada la foto para ver el original.

**Guardar:** la imagen se vuelve a calcular a resolución completa (hasta 4096 px por el lado mayor) y se guarda como PNG en Fotos o en la galería.

## Estructura

| Archivo | Qué hace |
|---|---|
| `lib/main.dart` | App, editor y controles (pestañas Marca y Ajustes) |
| `lib/intro.dart` | Animación de apertura |
| `lib/photo_info.dart` | Lectura del EXIF y nombres que se muestran |
| `lib/brands.dart` | Marcas, tabla de modelos Samsung y fuentes opcionales |
| `lib/renderer.dart` | Dibujo de los tres estilos de marca |
| `lib/adjust.dart` | Lista de ajustes y aplicación del shader |
| `shaders/adjust.frag` | Shader GLSL de los ajustes |
| `assets/fonts/` | Fuentes de marca opcionales (ver `LEEME.txt`) |
| `assets/img/` | Icono de la app |

## Fuentes de marca (opcional)

En el formato `Modelo | MARCA`, la marca se dibuja por defecto con la fuente del sistema, en negritas y espaciada. Si tienes licencia de la fuente de una marca, colócala en `assets/fonts/` con el nombre de la marca en minúsculas (`samsung.ttf`, `apple.otf`…) y la app la usará automáticamente.

## Requisitos

- Flutter 3.38 o superior (Dart 3.10)
- iOS o Android

Identificador: `com.aldahirballina.watermarkapp`

## Desarrollo

Instalar dependencias:

```bash
flutter pub get
```

Correr en un simulador o dispositivo:

```bash
flutter run
```

Pruebas:

```bash
flutter test
```

Regenerar el icono y la pantalla de arranque después de cambiar `assets/img/icon_launcher.png`:

```bash
dart run flutter_launcher_icons && dart run flutter_native_splash:create
```

## Dependencias

- [`image_picker`](https://pub.dev/packages/image_picker): elegir la foto
- [`exif`](https://pub.dev/packages/exif): leer los datos de la cámara
- [`gal`](https://pub.dev/packages/gal): guardar en Fotos o en la galería
- [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons) y [`flutter_native_splash`](https://pub.dev/packages/flutter_native_splash) (desarrollo): icono y arranque
