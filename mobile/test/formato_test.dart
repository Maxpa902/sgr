import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/formato.dart';

void main() {
  final ahora = DateTime(2026, 10, 17, 12);

  test('describes how long ago something happened', () {
    expect(
      haceCuanto(ahora.subtract(const Duration(seconds: 20)), ahora: ahora),
      'recién',
    );
    expect(
      haceCuanto(ahora.subtract(const Duration(minutes: 1)), ahora: ahora),
      'hace 1 minuto',
    );
    expect(
      haceCuanto(ahora.subtract(const Duration(hours: 3)), ahora: ahora),
      'hace 3 horas',
    );
    expect(
      haceCuanto(ahora.subtract(const Duration(days: 2)), ahora: ahora),
      'hace 2 días',
    );
  });

  test('shows the date when it was more than a month ago', () {
    expect(haceCuanto(DateTime(2026, 8, 5), ahora: ahora), 'el 05/08/2026');
  });
}
