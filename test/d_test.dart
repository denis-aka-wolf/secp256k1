import 'package:test/test.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cli/secp256k1.dart';

void main() {
  group('Тестирование d.dart', () {
    test('Проверка корректности выполнения скрипта d.dart', () async {
      // Запуск скрипта d.dart с аргументом и захват вывода
      // Устанавливаем короткий таймаут, так как скрипт может работать долго
      final process = await Process.start('dart', ['bin/d.dart', '424474cde218c2a7600156687eea9f0f90ab0424a088da0d27d92040c520e8db']);
      
      // Ждем 5 секунд, затем завершаем процесс
      await Future.delayed(Duration(seconds: 5));
      process.kill();
      
      // Читаем вывод
      String output = await process.stdout.transform(utf8.decoder).join();
      
      // Проверяем, что начало выполнения корректно
      expect(output.contains('=== Система VPA: Анализ в поле secp256k1 ==='), isTrue);
      expect(output.contains('b для точки G:'), isTrue);
      expect(output.contains('b для точки Q:'), isTrue);
      
      // Выводим начало результата для отладки
      print('Output (first part): ${output.substring(0, output.length < 500 ? output.length : 500)}...');
    });

    test('Проверка функции сложения точек', () {
      // Используем константы из библиотеки
      BigInt p = Secp256k1Constants.p;
      BigInt a = Secp256k1Constants.a;

      // Точка G из библиотеки
      List<BigInt> G = Secp256k1Constants.G;

      // Сложение точки с собой же (удвоение)
      List<BigInt> result = addPoint(G, G, p, a);

      // Проверяем, что результат - действительная точка на кривой
      BigInt bResult = (result[1].modPow(BigInt.two, p) - (result[0].modPow(BigInt.from(3), p) + a * result[0])) % p;
      if (bResult < BigInt.zero) bResult += p;

      BigInt bG = (G[1].modPow(BigInt.two, p) - (G[0].modPow(BigInt.from(3), p) + a * G[0])) % p;
      if (bG < BigInt.zero) bG += p;

      expect(bResult, equals(bG));
    });
  });
}