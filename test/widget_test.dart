import 'package:flutter_test/flutter_test.dart';
import 'package:guarda_ambiental_ret/main.dart';

void main() {
  testWidgets('Aplicativo RET Ambiental inicia', (WidgetTester tester) async {
    await tester.pumpWidget(const PlantaoRET());

    expect(find.byType(PlantaoRET), findsOneWidget);
  });
}