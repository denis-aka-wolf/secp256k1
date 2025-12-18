import 'package:test/test.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  group('Тестирование d.dart', () {
    test('Проверка корректности выполнения скрипта d.dart', () async {
      // Запуск скрипта d.dart и захват вывода
      ProcessResult result = await Process.run(
        'dart',
        ['bin/d.dart'],
        runInShell: Platform.isWindows,
      );

      // Проверка кода завершения
      expect(result.exitCode, 0);

      // Проверка основных частей вывода
      String output = result.stdout.toString();
      
      // Проверяем, что вывод содержит ожидаемые строки
      expect(output.contains('=== Система VPA: Анализ в поле secp256k1 ==='), isTrue);
      expect(output.contains('b для точки G:'), isTrue);
      expect(output.contains('b для точки Q:'), isTrue);
      expect(output.contains('[OK] Точки на одной кривой'), isTrue);
      expect(output.contains('Начинаем поиск ключа d...'), isTrue);
      
      // Выводим весь результат для отладки
      print(output);
    });

    test('Проверка функции сложения точек', () {
      // Импортируем нужные функции напрямую из файла
      // Так как это тестовый файл, мы не можем напрямую импортировать исполняемый файл,
      // но можем протестировать логику вручную
      
      // Тестовые значения для сложения точек
      BigInt p = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', radix: 16);
      BigInt a = BigInt.zero;

      // Точка G
      List<BigInt> G = [
        BigInt.parse("55066263022277343669578718895168534326250603453777594175500187360389116729240"),
        BigInt.parse("32670510020758816978083085130507043184471273380659243275938904335757337482424")
      ];

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

/// Копия функции addPoint из d.dart для тестирования
List<BigInt> addPoint(List<BigInt> p1, List<BigInt> p2, BigInt p, BigInt a) {
  if (p1[0] == BigInt.zero && p1[1] == BigInt.zero) return p2;
  if (p2[0] == BigInt.zero && p2[1] == BigInt.zero) return p1;

  BigInt x1 = p1[0], y1 = p1[1];
  BigInt x2 = p2[0], y2 = p2[1];
  BigInt lambda;

  try {
    if (x1 == x2 && y1 == y2) {
      BigInt num = (BigInt.from(3) * x1.modPow(BigInt.two, p) + a) % p;
      BigInt den = (BigInt.two * y1) % p;
      lambda = (num * den.modInverse(p)) % p;
    } else {
      BigInt num = (y2 - y1) % p;
      BigInt den = (x2 - x1) % p;
      lambda = (num * den.modInverse(p)) % p;
    }

    BigInt x3 = (lambda.modPow(BigInt.two, p) - x1 - x2) % p;
    BigInt y3 = (lambda * (x1 - x3) - y1) % p;

    return [
      x3 < BigInt.zero ? x3 + p : x3,
      y3 < BigInt.zero ? y3 + p : y3
    ];
  } catch (e) {
    return [BigInt.zero, BigInt.zero];
  }
}