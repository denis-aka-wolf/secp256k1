void main() {
  // Параметры поля (p) и параметра кривой (a)
  final BigInt p = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', radix: 16);
  final BigInt a = BigInt.zero; 

  // Точка G (Генератор)
  final List<BigInt> G = [
    BigInt.parse("55066263022277343669578718895168534326250603453777594175500187360389116729240"),
    BigInt.parse("32670510020758816978083085130507043184471273380659243275938904335757337482424")
  ];

  // Целевая точка Q
  final List<BigInt> Q = [
    BigInt.parse("109921230969093388853966210058315145860213412726202766573229810929488554311270"),
    BigInt.parse("114165137965800236389958514164212573551292041563212191306350325126693608044427")
  ];

  print("Начинаем обратное преобразование VPA (версия 2025)...");
  
  // Вычисляем B для проверки: b = (y^2 - x^3) % p
  BigInt b = (G[1].modPow(BigInt.two, p) - G[0].modPow(BigInt.from(3), p)) % p;
  if (b < BigInt.zero) b += p;
  print("Параметр B кривой: $b");

  BigInt? d = crackDiscreteLog(G, Q, p, a);

  if (d != null) {
    print("\n[УСПЕХ] Закрытый ключ d найден: $d");
  } else {
    print("\n[ОШИБКА] Ключ не найден в диапазоне 100,000.");
  }
}

/// Твоя корректная функция сложения с нормализацией остатков
List<BigInt> addPoint(List<BigInt> p1, List<BigInt> p2, BigInt p, BigInt a) {
  // Обработка точки на бесконечности (если координаты [0, 0])
  if (p1[0] == BigInt.zero && p1[1] == BigInt.zero) return p2;
  if (p2[0] == BigInt.zero && p2[1] == BigInt.zero) return p1;

  BigInt x1 = p1[0], y1 = p1[1];
  BigInt x2 = p2[0], y2 = p2[1];
  BigInt lambda;

  try {
    if (x1 == x2 && y1 == y2) {
      // Удвоение: lambda = (3*x1^2 + a) / (2*y1)
      BigInt num = (BigInt.from(3) * x1.modPow(BigInt.two, p) + a) % p;
      BigInt den = (BigInt.two * y1) % p;
      lambda = (num * den.modInverse(p)) % p;
    } else {
      // Сложение: lambda = (y2 - y1) / (x2 - x1)
      BigInt num = (y2 - y1) % p;
      BigInt den = (x2 - x1) % p;
      lambda = (num * den.modInverse(p)) % p;
    }

    BigInt x3 = (lambda.modPow(BigInt.two, p) - x1 - x2) % p;
    BigInt y3 = (lambda * (x1 - x3) - y1) % p;

    // Нормализация: Dart возвращает отрицательный остаток для отрицательных чисел
    return [
      x3 < BigInt.zero ? x3 + p : x3, 
      y3 < BigInt.zero ? y3 + p : y3
    ];
  } catch (e) {
    // Если den.modInverse(p) невозможен (GCD(den, p) != 1) или y=0
    return [BigInt.zero, BigInt.zero];
  }
}

/// Функция поиска d (дискретный логарифм перебором)
BigInt? crackDiscreteLog(List<BigInt> G, List<BigInt> target, BigInt p, BigInt a) {
  List<BigInt> currentPoint = G; // Это d = 1

  for (int d = 1; d <= 100000; d++) {
    // Проверка совпадения
    if (currentPoint[0] == target[0] && currentPoint[1] == target[1]) {
      return BigInt.from(d);
    }

    // Итерация сложения: d*G + G
    currentPoint = addPoint(currentPoint, G, p, a);

    if (d % 10000 == 0) {
      print("Проверено $d итераций...");
    }

    // Защита от зацикливания в точке на бесконечности
    if (currentPoint[0] == BigInt.zero && currentPoint[1] == BigInt.zero) {
      print("Точка ушла в бесконечность на шаге $d.");
      break;
    }
  }
  return null;
}
