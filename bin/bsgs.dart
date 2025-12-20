import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:cli/secp256k1.dart';

void main(List<String> arguments) async {
  // Используем константы из библиотеки
  final BigInt p = Secp256k1Constants.p;
  final BigInt a = Secp256k1Constants.a;
  final List<BigInt> G = Secp256k1Constants.G;
  
  // Парсинг именованных аргументов
  BigInt? startX, endX, qX, qY;
  String fileName = "data/baby_steps.bin";
  int m = 1000;
  
  for (int i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--start' && i + 1 < arguments.length) {
      startX = BigInt.parse(arguments[++i], radix: 16);
    } else if (arguments[i] == '--end' && i + 1 < arguments.length) {
      endX = BigInt.parse(arguments[++i], radix: 16);
    } else if (arguments[i] == '--x' && i + 1 < arguments.length) {
      qX = BigInt.parse(arguments[++i], radix: 16);
    } else if (arguments[i] == '--y' && i + 1 < arguments.length) {
      qY = BigInt.parse(arguments[++i], radix: 16);
    } else if (arguments[i] == '--file' && i + 1 < arguments.length) {
      fileName = arguments[++i];
    } else if (arguments[i] == '--m' && i + 1 < arguments.length) {
      m = int.parse(arguments[++i]);
    } else if (arguments[i].startsWith('--')) {
      print('Неизвестный параметр: ${arguments[i]}');
      print('Использование: dart run bin/bsgs.dart --x <Qx> --y <Qy> [--start <start>] [--end <end>] [--file <fileName>] [--m <m>]');
      return;
    }
  }
  
  // Проверяем, что обязательные параметры x и y заданы
  if (qX == null || qY == null) {
    print('Обязательные параметры --x и --y не заданы');
    print('Использование: dart run bin/bsgs.dart --x <Qx> --y <Qy> [--start <start>] [--end <end>] [--file <fileName>] [--m <m>]');
    return;
  }
  
  // Целевая точка Q из аргументов командной строки
  final List<BigInt> Q = [qX!, qY!];
  
  // Если заданы start и/или end, вычисляем соответствующие значения m
  if (startX != null || endX != null) {
    BigInt start = startX ?? BigInt.zero;
    BigInt end = endX ?? (BigInt.from(m) * BigInt.from(m)); // по умолчанию до m^2
    
    // Обновляем m так, чтобы охватить нужный диапазон
    BigInt range = end - start;
    BigInt sqrtRange = sqrtBigInt(range ~/ BigInt.from(2));
        
    m = max(m, sqrtRange.toInt());
  }

  print("=== Система VPA: Дисковый BSGS (2025, оптимизированный) ===");
  print("Диапазон поиска: ${startX?.toRadixString(16) ?? '0'} - ${endX?.toRadixString(16) ?? (BigInt.from(m) * BigInt.from(m)).toRadixString(16)}");

  // 1. Генерация baby-steps
  if (!File(fileName).existsSync() || !isValidFileSize(fileName, m)) {
    print("Файл $fileName не найден или некорректен, генерируем...");
    await generateBabyStepsParallel(fileName, G, p, a, m);
  } else {
    print("Файл $fileName найден и валиден, используем его.");
  }

  // 2. Индексация (80-битный префикс)
  print("Индексация данных (80 бит)...");
  final Map<BigInt, int> index = await buildIndex80bit(fileName, m);

  // 3. Подготовка giant-steps
  print("Подготовка giant-steps...");
  List<BigInt> mG = multiplyPointOptimized(G, BigInt.from(m), p, a);
  List<BigInt> negMG = [mG[0], (p - mG[1]) % p];

  // 4. Поиск
  print("Запуск поиска...");
  List<BigInt> currentGiant = List.from(Q);
  final file = await File(fileName).open();

  // Определяем начальный и конечный индекс для поиска
  BigInt startIndex = startX != null ? startX ~/ BigInt.from(m) : BigInt.zero;
  BigInt endIndex = endX != null ? endX ~/ BigInt.from(m) : BigInt.from(m);

  for (BigInt j = startIndex; j <= endIndex && j <= BigInt.from(m); j = j + BigInt.one) {
    BigInt prefix = get80bitPrefix(currentGiant[0]);

    if (index.containsKey(prefix)) {
      int pos = index[prefix]!;
      await file.setPosition(pos * 32);
      Uint8List block = await file.read(32 * 1000); // Читаем блок 1000 точек

      for (int k = 0; k < 1000; k++) {
        if (pos + k >= m) break;
        Uint8List pointBytes = block.sublist(k * 32, k * 32 + 32);
        BigInt foundX = bytesToBigInt(pointBytes);

        if (foundX == currentGiant[0]) {
          BigInt finalD = j * BigInt.from(m) + BigInt.from(pos + k) + BigInt.one;
          
          // Проверяем, находится ли результат в заданном диапазоне
          if ((startX == null || finalD >= startX) && (endX == null || finalD <= endX)) {
            print("\n[УСПЕХ] Ключ d найден: ${finalD.toRadixString(16)} (${finalD})");
            await file.close();
            return;
          }
        }
      }
    }

    currentGiant = addPoint(currentGiant, negMG, p, a);
    int jValue = j.toInt();
    if (jValue % 10000 == 0 && jValue > 0) {
      print("Проверено гигантских шагов: $jValue (Диапазон: ${BigInt.from(jValue) * BigInt.from(m)})");
    }
  }

  print("\n[КОНЕЦ] Ключ не найден в заданном диапазоне.");
  await file.close();
}

// --- ОПТИМИЗИРОВАННЫЕ ФУНКЦИИ ---


Future<void> generateBabyStepsParallel(String name, List<BigInt> G, BigInt p, BigInt a, int m) async {
  // Создаем директорию data, если она не существует
  final dir = Directory('data');
  if (!await dir.exists()) {
    await dir.create();
  }
  
  final file = File(name);
  await file.create();

  const chunkSize = 100000;
  final totalChunks = (m + chunkSize - 1) ~/ chunkSize;


  await Future.wait([
    for (int chunk = 0; chunk < totalChunks; chunk++)
      _generateChunk(file, G, p, a, chunk, chunkSize, m)
  ]);
}

Future<void> _generateChunk(File file, List<BigInt> G, BigInt p, BigInt a,
    int chunk, int chunkSize, int m) async {
  int start = chunk * chunkSize + 1;
  int end = min(start + chunkSize - 1, m);
  List<BigInt> current = multiplyPointOptimized(G, BigInt.from(start - 1), p, a);
 final output = file.openWrite(mode: FileMode.append);

  for (int i = start; i <= end; i++) {
    current = addPoint(current, G, p, a);
    output.add(bigIntTo32Bytes(current[0]));
  }
  await output.flush();
  await output.close();
}

Future<Map<BigInt, int>> buildIndex80bit(String name, int m) async {
  final Map<BigInt, int> index = {};
  final file = File(name);
  final reader = file.openSync();

  try {
    for (int i = 0; i < m; i++) {
      Uint8List pointBytes = reader.readSync(32); // Читаем полную точку (32 байта)
      if (pointBytes.length != 32) break;

      BigInt prefix = bytesToBigInt(pointBytes.sublist(0, 10)); // Первые 10 байт = 80 бит

      // Сохраняем все позиции для этого префикса
      if (!index.containsKey(prefix)) {
        index[prefix] = i;
      }

      if (i % 50000 == 0 && i > 0) {
        print("Индексировано $i записей...");
      }
    }
 } finally {
    reader.closeSync();
 }
  print("Индекс построен, размер: ${index.length} уникальных префиксов");
  return index;
}

BigInt get80bitPrefix(BigInt x) {
  Uint8List bytes = bigIntTo32Bytes(x);
  return bytesToBigInt(bytes.sublist(0, 10)); // Первые 10 байт = 80 бит
}

List<BigInt> multiplyPointOptimized(List<BigInt> point, BigInt scalar, BigInt p, BigInt a) {
  if (scalar == BigInt.zero) return [BigInt.zero, BigInt.zero];
  if (scalar == BigInt.one) return List.from(point);

 List<BigInt> result = [BigInt.zero, BigInt.zero];
 List<BigInt> base = List.from(point);

  while (scalar > BigInt.zero) {
    if (scalar.isOdd) {
      result = addPoint(result, base, p, a);
    }
    base = addPoint(base, base, p, a);
    scalar = scalar >> 1;
  }
  return result;
}

// --- БАЗОВЫЕ ФУНКЦИИ (без изменений, для полноты) ---

List<BigInt> addPoint(List<BigInt> p1, List<BigInt> p2, BigInt p, BigInt a) {
  if (p1[0] == BigInt.zero && p1[1] == BigInt.zero) return p2;
  if (p2[0] == BigInt.zero && p2[1] == BigInt.zero) return p1;

  BigInt x1 = p1[0], y1 = p1[1];
  BigInt x2 = p2[0], y2 = p2[1];
  BigInt lambda;

  try {
    if (x1 == x2) {
      if (y1 == y2) {
        // Удвоение точки (x₁ = x₂, y₁ = y₂)
        if (y1 == BigInt.zero) {
          return [BigInt.zero, BigInt.zero]; // Точка на бесконечности
        }
        BigInt num = (BigInt.from(3) * x1 * x1 + a) % p;
        BigInt den = (BigInt.two * y1) % p;
        lambda = (num * modInverseOptimized(den, p)) % p;
      } else {
        // Противоположные точки: P + (−P) = O
        return [BigInt.zero, BigInt.zero];
      }
    } else {
      // Сложение различных точек (x₁ ≠ x₂)
      BigInt num = (y2 - y1) % p;
      BigInt den = (x2 - x1) % p;
      lambda = (num * modInverseOptimized(den, p)) % p;
    }

    BigInt x3 = (lambda * lambda - x1 - x2) % p;
    BigInt y3 = (lambda * (x1 - x3) - y1) % p;

    // Нормализация отрицательных значений
    if (x3 < BigInt.zero) x3 += p;
    if (y3 < BigInt.zero) y3 += p;

    return [x3, y3];
  } catch (e) {
    // В случае ошибки (например, modInverse не существует) — точка на бесконечности
    return [BigInt.zero, BigInt.zero];
  }
}

// --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---

bool isValidFileSize(String fileName, int m) {
  try {
    int fileSize = File(fileName).lengthSync();
    return fileSize == m * 32;
  } catch (e) {
    return false;
 }
}

// Функция для вычисления квадратного корня из BigInt
BigInt sqrtBigInt(BigInt n) {
  if (n < BigInt.zero) throw ArgumentError('Квадратный корень из отрицательного числа');
  if (n == BigInt.zero) return BigInt.zero;
  
  BigInt x = n;
  BigInt y = (x + BigInt.one) ~/ BigInt.two;
  
  while (y < x) {
    x = y;
    y = (x + (n ~/ x)) ~/ BigInt.two;
  }
  
  return x;
}
