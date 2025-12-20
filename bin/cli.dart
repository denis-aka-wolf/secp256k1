import 'package:cli/secp256k1.dart';

void main(List<String> arguments) {
  // Используем константы из библиотеки
  final BigInt p = Secp256k1Constants.p;
  final BigInt a = Secp256k1Constants.a;
  final List<BigInt> G = Secp256k1Constants.G;
  
  final BigInt gx = G[0];
  final BigInt gy = G[1];

  // Обработка аргументов командной строки
  if (arguments.isEmpty) {
    print('Использование:');
    print(' Для одного ключа: dart run bin/cli.dart <закрытый_ключ>');
    print(' Для диапазона: dart run bin/cli.dart <начальный_ключ> <конечный_ключ> [файл_вывода]');
    print('Примеры:');
    print('  dart run bin/cli.dart 2328');
    print('  dart run bin/cli.dart 1 100 keys.json');
    return;
  }
  
  // Если передан один аргумент - обработка как в оригинале
  if (arguments.length == 1) {
    BigInt privateKey;
    try {
      privateKey = BigInt.parse(arguments[0]);
    } catch (e) {
      print('Ошибка: Неверный формат закрытого ключа. Ожидается целое число.');
      return;
    }
    
    print('--- [ЭТАП 1] Исходные данные ---');
    print('Закрытый ключ (d): $privateKey');
    print('Поле (p): $p');
    print('Точка G_x: $gx');
    print('Точка G_y: $gy\n');

    // Вычисление открытого ключа методом Double-and-Add
    print('--- [ЭТАП 2] Вычисление Q = d * G ---');
    List<BigInt>? resultPoint = scalarMultiply(G, privateKey, p, a);

    // Вывод результата
    print('\n--- [ЭТАП 3] Итоговый открытый ключ ---');
    String hexX = resultPoint![0].toRadixString(16).padLeft(64, '0');
    String hexY = resultPoint[1].toRadixString(16).padLeft(64, '0');
    print('X (hex): $hexX');
    print('Y (hex): $hexY');
    print('Полный несжатый ключ: 04$hexX$hexY');
    
    // Вывод координат X и Y в десятичной системе
    print('\n--- [ДОПОЛНИТЕЛЬНО] Координаты в десятичной системе ---');
    print('X (dec): ${resultPoint[0]}');
    print('Y (dec): ${resultPoint[1]}');
  }
  // Если передано 2 или 3 аргумента - обработка диапазона
  else if (arguments.length >= 2) {
    BigInt startPrivateKey, endPrivateKey;
    String outputFile = 'data/keys.json'; // файл вывода по умолчанию
    
    try {
      startPrivateKey = BigInt.parse(arguments[0]);
      endPrivateKey = BigInt.parse(arguments[1]);
      
      if (arguments.length == 3) {
        outputFile = arguments[2];
      }
    } catch (e) {
      print('Ошибка: Неверный формат закрытого ключа. Ожидается целое число.');
      return;
    }
    
    if (startPrivateKey > endPrivateKey) {
      print('Ошибка: Начальный ключ больше конечного ключа.');
      return;
    }
    
    print('--- [ЭТАП 1] Генерация диапазона открытых ключей ---');
    print('Начальный закрытый ключ: $startPrivateKey');
    print('Конечный закрытый ключ: $endPrivateKey');
    print('Файл вывода: $outputFile');
    print('Поле (p): $p');
    print('Точка G_x: $gx');
    print('Точка G_y: $gy\n');

    // 3. Генерация диапазона открытых ключей
    print('--- [ЭТАП 2] Вычисление Q = d * G для каждого d в диапазоне ---');
    List<Map<String, dynamic>> publicKeyData = generatePublicKeyRange(
      startPrivateKey,
      endPrivateKey,
      p,
      a,
      G
    );
    
    // 4. Сохранение в файл
    print('\n--- [ЭТАП 3] Сохранение данных в файл ---');
    savePublicKeyDataToFile(publicKeyData, outputFile).then((_) {
      print('Данные успешно сохранены в файл: $outputFile');
      print('Количество сгенерированных ключей: ${publicKeyData.length}');
    }).catchError((error) {
      print('Ошибка при сохранении файла: $error');
    });
  }
}
