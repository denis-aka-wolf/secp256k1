import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:cli/secp256k1.dart';

void main() {
  group('Integration Tests', () {
    test('generate 100 keys and find private keys with bsgs', () async {
      // Используем константы из библиотеки
      final BigInt p = Secp256k1Constants.p;
      final BigInt a = Secp256k1Constants.a;
      final List<BigInt> G = Secp256k1Constants.G;
      
      // Генерируем 100 ключей с 1 до 100
      final result = generatePublicKeyRange(BigInt.one, BigInt.from(100), p, a, G);
      
      expect(result, isNotNull);
      expect(result.length, 100);
      
      // Для каждого сгенерированного ключа проверяем, что можем найти его с помощью BSGS
      for (int i = 0; i < result.length; i++) {
        final keyInfo = result[i];
        final privateKey = BigInt.parse(keyInfo['private_key']);
        final publicKey = keyInfo['public_key'];
        final BigInt qx = BigInt.parse(publicKey['x'], radix: 16);
        final BigInt qy = BigInt.parse(publicKey['y'], radix: 16);
        
        // Запускаем BSGS для поиска закрытого ключа
        final process = await Process.start('dart', [
          'run',
          'bin/bsgs.dart',
          qx.toRadixString(16),
          qy.toRadixString(16),
          'data/test_bsgs_keys.bin',
          '150' // Увеличиваем диапазон для поиска
        ]);
        
        String output = await process.stdout.transform(utf8.decoder).join();
        process.stderr.listen((data) => print('STDERR: ${String.fromCharCodes(data)}'));
        
        // Проверяем, что ключ был найден
        expect(output, contains('Ключ d найден'));
        
        // Извлекаем найденный ключ из вывода
        RegExp regExp = RegExp(r'Ключ d найден: (\d+)');
        Match? match = regExp.firstMatch(output);
        if (match != null) {
          BigInt foundPrivateKey = BigInt.parse(match.group(1)!);
          print('Найденный закрытый ключ: $foundPrivateKey');
          print('Ожидаемый закрытый ключ: $privateKey');
          expect(foundPrivateKey, equals(privateKey));
        } else {
          print('Вывод BSGS: $output');
          fail('Не удалось извлечь найденный закрытый ключ из вывода BSGS');
        }
      }
    }, timeout: Timeout(Duration(minutes: 20))); // Увеличиваем таймаут для теста
  });
}