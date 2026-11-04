import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watermark_app/main.dart';

void main() {
  testWidgets('la animación de apertura lleva al editor', (tester) async {
    await tester.pumpWidget(const WatermarkApp());
    expect(find.text('Elegir foto'), findsNothing);

    // La carga del icono es asíncrona; luego corre la animación.
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Elegir foto'), findsOneWidget);
  });
}
