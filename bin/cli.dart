void main(List<String> arguments) {
  // 1. Константы кривой secp256k1
  final BigInt p = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', radix: 16);
  final BigInt a = BigInt.zero;
  final BigInt b = BigInt.from(7);
  
  // Базовая точка G
  final BigInt gx = BigInt.parse('79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798', radix: 16);
  final BigInt gy = BigInt.parse('483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8', radix: 16);
  final List<BigInt> G = [gx, gy];

  // 2. Получаем закрытый ключ из аргументов командной строки
  if (arguments.isEmpty) {
    print('Использование: dart run bin/cli.dart <закрытый_ключ>');
    print('Пример: dart run bin/cli.dart 2328');
    return;
  }
  
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

  // 3. Вычисление открытого ключа методом Double-and-Add
  print('--- [ЭТАП 2] Вычисление Q = d * G ---');
  List<BigInt>? resultPoint = scalarMultiply(G, privateKey, p, a);

  // 4. Вывод результата
  print('\n--- [ЭТАП 3] Итоговый открытый ключ ---');
  String hexX = resultPoint![0].toRadixString(16).padLeft(64, '0');
  String hexY = resultPoint[1].toRadixString(16).padLeft(64, '0');
  print('X (hex): $hexX');
  print('Y (hex): $hexY');
  print('Полный несжатый ключ: 04$hexX$hexY');
}

/// Скалярное умножение точки на число (Double-and-Add)
List<BigInt>? scalarMultiply(List<BigInt> point, BigInt scalar, BigInt p, BigInt a) {
  List<BigInt>? result;
  List<BigInt>? addend = point;

  String binary = scalar.toRadixString(2);
  print('Двоичное представление ключа: $binary (${binary.length} бит)');

 for (int i = binary.length - 1; i >= 0; i--) {
    if (binary[i] == '1') {
      print('Бит [${binary.length - 1 - i}]: 1 -> Складываем текущую сумму с точкой');
      result = (result == null) ? addend : addPoint(result, addend!, p, a);
      if (result != null) {
        print('\nПромежуточный результат после сложения: \nX=${result[0]}, \nY=${result[1]}');
      }
    }
    if (i > 0) {
      print('Подготовка к следующему шагу - удвоение точки:');
      print('До удвоения: \nX=${addend![0]}, \nY=${addend[1]}');
      addend = addPoint(addend, addend, p, a); // Удвоение точки
      print('После удвоения: \nX=${addend[0]}, \nY=${addend[1]}');
    }
  }
  return result;
}

/// Сложение двух точек на эллиптической кривой (включая случай удвоения)
List<BigInt> addPoint(List<BigInt> p1, List<BigInt> p2, BigInt p, BigInt a) {
  BigInt x1 = p1[0], y1 = p1[1];
  BigInt x2 = p2[0], y2 = p2[1];
  BigInt lambda;

  if (x1 == x2 && y1 == y2) {
    // Случай удвоения точки: lambda = (3*x1^2 + a) / (2*y1)
    BigInt num = (BigInt.from(3) * x1.modPow(BigInt.two, p) + a) % p;
    BigInt den = (BigInt.two * y1) % p;
    lambda = (num * den.modInverse(p)) % p;
  } else {
    // Случай сложения разных точек: lambda = (y2 - y1) / (x2 - x1)
    BigInt num = (y2 - y1) % p;
    BigInt den = (x2 - x1) % p;
    lambda = (num * den.modInverse(p)) % p;
  }

  BigInt x3 = (lambda.modPow(BigInt.two, p) - x1 - x2) % p;
  BigInt y3 = (lambda * (x1 - x3) - y1) % p;

  return [x3, y3];
}
