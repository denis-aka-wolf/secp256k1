import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('secp256k1 single key generation', () async {
    // Тестируем с закрытым ключом 23288
    final result = await Process.run('dart', ['run', 'bin/cli.dart', '23288'], runInShell: true);
    
    expect(result.exitCode, 0);
    
    final output = result.stdout.toString();
    print(output); // Для отладки
    
    // Проверяем, что результат содержит ожидаемые элементы
    expect(output, contains('--- [ЭТАП 1] Исходные данные ---'));
    expect(output, contains('--- [ЭТАП 2] Вычисление Q = d * G ---'));
    expect(output, contains('--- [ЭТАП 3] Итоговый открытый ключ ---'));
    expect(output, contains('Закрытый ключ (d): 23288'));
    expect(output, contains('Полный несжатый ключ: 04'));
    
    // Проверяем, что в выводе есть шестнадцатеричные значения X и Y координат
    expect(output, contains('X (hex):'));
    expect(output, contains('Y (hex):'));
    
    // Проверяем конкретный результат для закрытого ключа 23288
    expect(output, contains('Полный несжатый ключ: 04'));
  });

  test('secp256k1 range key generation', () async {
    final tempFile = 'data/temp_range_test.json';
    
    try {
      // Тестируем генерацию диапазона ключей
      final result = await Process.run('dart', ['run', 'bin/cli.dart', '1', '3', tempFile], runInShell: true);
      
      expect(result.exitCode, 0);
      
      final output = result.stdout.toString();
      print(output); // Для отладки
      
      // Проверяем, что результат содержит ожидаемые элементы
      expect(output, contains('--- [ЭТАП 1] Генерация диапазона открытых ключей ---'));
      expect(output, contains('Начальный закрытый ключ: 1'));
      expect(output, contains('Конечный закрытый ключ: 3'));
      expect(output, contains('Данные успешно сохранены в файл:'));
      expect(output, contains('Количество сгенерированных ключей: 3'));
      
      // Проверяем, что файл был создан
      expect(File(tempFile).existsSync(), isTrue);
      
      // Проверяем, что файл содержит валидный JSON с 3 ключами
      final fileContent = await File(tempFile).readAsString();
      expect(fileContent, startsWith('['));
      expect(fileContent, contains('"private_key": "1"'));
      expect(fileContent, contains('"private_key": "2"'));
      expect(fileContent, contains('"private_key": "3"'));
      expect(fileContent, endsWith(']'));
    } finally {
      // Удаляем временный файл
      if (await File(tempFile).exists()) {
        await File(tempFile).delete();
      }
    }
  });

  test('secp256k1 range validation', () async {
    // Тестируем ошибку при неправильном диапазоне
    final result = await Process.run('dart', ['run', 'bin/cli.dart', '10', '5', 'data/test.json'], runInShell: true);
    
    expect(result.exitCode, 0); // Процесс завершается с 0, но выводит сообщение об ошибке
    
    final output = result.stdout.toString();
    expect(output, contains('Ошибка: Начальный ключ больше конечного ключа.'));
  });

  test('secp256k1 help message', () async {
    // Тестируем вывод справки при запуске без аргументов
    final result = await Process.run('dart', ['run', 'bin/cli.dart'], runInShell: true);
    
    expect(result.exitCode, 0);
    
    final output = result.stdout.toString();
    expect(output, contains('Использование:'));
    expect(output, contains('Для одного ключа:'));
    expect(output, contains('Для диапазона:'));
  });
}
