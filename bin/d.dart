import 'package:cli/secp256k1.dart';
import 'dart:io';

void main(List<String> arguments) {
  // Используем константы из библиотеки
  final BigInt p = Secp256k1Constants.p;
  final BigInt a = Secp256k1Constants.a;
  final BigInt b = Secp256k1Constants.b;

  // Точка G (Генератор)
  final List<BigInt> G = Secp256k1Constants.G;

  // Проверяем наличие аргументов
  if (arguments.isEmpty) {
    print("Использование: dart bin/d.dart <Qx_hex_or_decimal>");
    print("Примеры:");
    print(
      " dart bin/d.dart 63CED202E36FAE63E37EB3400A22C17A9AD1F102800D6D83C2D3139D3320939",
    );
    print(
      "  dart bin/d.dart 0x63CED202E36FAE63E37EB3400A22C17A9AD1F102800D6D83C2D33139D3320939",
    );
    print(
      "  dart bin/d.dart 44918248685693471414986855264870096580343778075882633323981452268188744655097",
    );
    exit(1);
  }

  // Получаем Qx из параметров командной строки
  // ignore: non_constant_identifier_names
  BigInt Qx;
  String input = arguments[0];
  if (input.startsWith('0x') || input.startsWith('0X')) {
    // Входное значение в HEX формате
    Qx = BigInt.parse(input.substring(2), radix: 16);
    print("Используем Qx из параметра (HEX): ${input}");
  } else {
    try {
      // Проверяем, является ли входное значение числом
      int radix = 10;
      
      // Проверяем, содержит ли строка только цифры (десятичное число)
      if (input.contains(RegExp(r'^[0-9]+$'))) {
        radix = 10;
      } else if (input.contains(RegExp(r'^[0-9A-Fa-f]+$'))) {
        // Если содержит только шестнадцатеричные символы
        try {
          BigInt.parse(input, radix: 16);
          radix = 16;
          print("Используем Qx из параметра (HEX без 0x): ${input}");
        } catch (e) {
          // Если не получилось распарсить как hex, используем как десятичное
          radix = 10;
        }
      }

      Qx = BigInt.parse(input, radix: radix);
      if (radix == 16) {
        print("Используем Qx из параметра (HEX): ${input}");
      } else {
        print("Используем Qx из параметра (DEC): ${input}");
      }
    } catch (e) {
      print("Ошибка при парсинге Qx: $e");
      print("Форматы: <десятичное_число> или 0x<шестнадцатеричное_число>");
      exit(1);
    }
  }

  // Вычисляем возможные значения Qy
  List<BigInt>? QyValues = getYCoordinate(Qx, p, a, b);
  if (QyValues == null) {
    print("Не удалось найти координату Y для заданного X");
    return;
  }

  // Создаем обе возможные точки Q
  List<List<BigInt>> QPoints = [
    [Qx, QyValues[0]],
    [Qx, QyValues[1]],
  ];

  print("=== Система VPA: Анализ в поле secp256k1 ===");
  print("Qx (hex): ${Qx.toRadixString(16).toUpperCase()}");
  print("Qx (dec): $Qx");
  print("Возможные Qy:");
  print("  Qy1: ${QyValues[0]}");
  print("  Qy2: ${QyValues[1]}");

  // Проверяем обе возможные точки Q
  for (int i = 0; i < QPoints.length; i++) {
    List<BigInt> Q = QPoints[i];

    print("\n--- Проверка точки Q${i + 1} ---");

    // 2. Проверка принадлежности одной кривой
    BigInt bG = b;
    BigInt bQ =
        (Q[1].modPow(BigInt.two, p) -
            (Q[0].modPow(BigInt.from(3), p) + a * Q[0])) %
        p;
    if (bQ < BigInt.zero) bQ += p;

    print("b для точки G: $bG");
    print("b для точки Q: $bQ");

    if (bG != bQ) {
      print("\n[ВНИМАНИЕ] Точки на разных кривых! d не может быть найден.");
    } else {
      print("[OK] Точки на одной кривой (b = $bG).");

      print("\nНачинаем поиск ключа d...");
      BigInt? d = crackDiscreteLog(G, Q, p, a);

      if (d != null) {
        print("\n[УСПЕХ] d найден: $d");
        break; // Нашли ключ, выходим
      } else {
        print(
          "\n[КОНЕЦ] Ключ не найден в диапазоне 100,000 для точки Q${i + 1}.",
        );
      }
    }
  }
}

/// Поиск дискретного логарифма
BigInt? crackDiscreteLog(
  List<BigInt> G,
  List<BigInt> target,
  BigInt p,
  BigInt a,
) {
  List<BigInt> currentPoint = List.from(G);

  for (int d = 1; d <= 1000000; d++) {
    if (currentPoint[0] == target[0] && currentPoint[1] == target[1]) {
      return BigInt.from(d);
    }

    currentPoint = addPoint(currentPoint, G, p, a);

    if (d % 100000 == 0) {
      print("Шаг $d...");
    }

    if (currentPoint[0] == BigInt.zero && currentPoint[1] == BigInt.zero) {
      print("Достигнута бесконечность на шаге $d.");
      break;
    }
  }
  return null;
}
