import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:cli/secp256k1.dart';

void main(List<String> arguments) async {
  // Используем константы из библиотеки
  final BigInt p = Secp256k1Constants.p;
  final BigInt a = Secp256k1Constants.a;
  final List<BigInt> G = Secp256k1Constants.G;
  
  // Проверяем, что переданы аргументы для точки Q
  if (arguments.length < 2) {
    print('Использование: dart run bin/bsgs.dart <Qx> <Qy> [fileName] [m]');
    print('Где Qx и Qy - координаты целевой точки Q в hex формате');
    return;
  }
  
  // Целевая точка Q из аргументов командной строки
  final List<BigInt> Q = [
    BigInt.parse(arguments[0], radix: 16),
    BigInt.parse(arguments[1], radix: 16)
  ];
  
  final String fileName = arguments.length > 2 ? arguments[2] : "data/baby_steps.bin";
  final int m = arguments.length > 3 ? int.parse(arguments[3]) : 1000;

  print("=== Система VPA: Дисковый BSGS (2025, оптимизированный) ===");


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

  for (int j = 0; j <= m; j++) {
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
          BigInt finalD = BigInt.from(j) * BigInt.from(m) + BigInt.from(pos + k) + BigInt.one;
          print("\n[УСПЕХ] Ключ d найден: $finalD");
          await file.close();
          return;
        }
      }
    }

    currentGiant = addPoint(currentGiant, negMG, p, a);
    if (j % 10000 == 0 && j > 0) {
      print("Проверено гигантских шагов: $j (Диапазон: ${BigInt.from(j) * BigInt.from(m)})");
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
