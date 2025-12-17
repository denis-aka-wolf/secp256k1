import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('secp256k1 key generation', () async {
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
    expect(output, contains('Полный несжатый ключ: 048b17e2d653426877eb4f5c54e014b8c3defb55c790c2e42aeb887ffa1f50b8ff1b22d8e066a47fe99b6ef827aa4627afcddd00e62dcd99f675b278de5d3e97e5'));
 });
}
