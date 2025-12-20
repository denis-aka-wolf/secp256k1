import 'dart:convert';
import 'dart:io';
import 'package:cli/secp256k1.dart';
import 'package:test/test.dart';

void main() {
  group('Key Generator Tests', () {
    // Константы кривой secp256k1
    final BigInt p = Secp256k1Constants.p;
    final BigInt a = Secp256k1Constants.a;
    
    // Базовая точка G
    final List<BigInt> G = Secp256k1Constants.G;

    test('generatePublicKeyRange should generate keys for a range', () {
      final result = generatePublicKeyRange(BigInt.one, BigInt.from(5), p, a, G);
      
      expect(result, isNotNull);
      expect(result.length, 5);
      
      // Проверяем, что каждый элемент содержит ожидаемые поля
      for (int i = 0; i < result.length; i++) {
        final keyInfo = result[i];
        expect(keyInfo['private_key'], isNotNull);
        expect(keyInfo['public_key'], isNotNull);
        expect(keyInfo['decimal'], isNotNull);
        
        // Проверяем, что закрытый ключ в правильном диапазоне
        final privateKey = BigInt.parse(keyInfo['private_key']);
        expect(privateKey, equals(BigInt.from(i + 1)));
        
        // Проверяем, что публичный ключ содержит ожидаемые поля
        final publicKey = keyInfo['public_key'];
        expect(publicKey['x'], isNotNull);
        expect(publicKey['y'], isNotNull);
        expect(publicKey['compressed'], isNotNull);
        expect(publicKey['uncompressed'], isNotNull);
        
        // Проверяем длину шестнадцатеричных строк
        expect(publicKey['x'].length, 64);
        expect(publicKey['y'].length, 64);
        expect(publicKey['compressed'].length, 66);
        expect(publicKey['uncompressed'].length, 130);
      }
    });

    test('generatePublicKeyRange should handle single key', () {
      final result = generatePublicKeyRange(BigInt.from(10), BigInt.from(10), p, a, G);
      
      expect(result, isNotNull);
      expect(result.length, 1);
      
      final keyInfo = result[0];
      expect(keyInfo['private_key'], '10');
    });

    test('generatePublicKeyRange should handle edge case with private key 1', () {
      final result = generatePublicKeyRange(BigInt.one, BigInt.one, p, a, G);
      
      expect(result, isNotNull);
      expect(result.length, 1);
      
      final keyInfo = result[0];
      expect(keyInfo['private_key'], '1');
      
      // При закрытом ключе 1, открытым ключом должна быть базовая точка G
      final publicKey = keyInfo['public_key'];
      expect(publicKey['x'], '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798');
      expect(publicKey['y'], '0483ada7726a3c4655da4fbfc0e1108a8fd17b48a68554199c47d08ffb10d4b8');
    });

    test('savePublicKeyDataToFile should create a valid JSON file', () async {
      final data = generatePublicKeyRange(BigInt.from(1), BigInt.from(3), p, a, G);
      final tempFile = 'data/temp_test_keys.json';
      
      await savePublicKeyDataToFile(data, tempFile);
      
      // Проверяем, что файл существует
      expect(File(tempFile).existsSync(), isTrue);
      
      // Проверяем, что файл содержит валидный JSON
      final fileContent = await File(tempFile).readAsString();
      expect(fileContent, startsWith('['));
      expect(fileContent, endsWith(']'));
      
      // Проверяем, что JSON можно распарсить
      final parsedData = json.decode(fileContent) as List;
      expect(parsedData.length, 3);
      
      // Удаляем временный файл
      await File(tempFile).delete();
    });

    test('scalarMultiply should work correctly for known values', () {
      // Проверяем, что умножение точки G на 1 дает саму точку G
      final result = scalarMultiply(G, BigInt.one, p, a);
      
      expect(result, isNotNull);
      expect(result![0], equals(G[0]));
      expect(result[1], equals(G[1]));
      
      // Проверяем умножение на 2
      final result2 = scalarMultiply(G, BigInt.from(2), p, a);
      expect(result2, isNotNull);
      
      // Результат не должен быть равен исходной точке
      expect(result2![0], isNot(equals(G[0])));
      expect(result2[1], isNot(equals(G[1])));
    });
  });
}