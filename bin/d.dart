void main() {
  // 1. Модуль P для кривой secp256k1
  final BigInt p = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', radix: 16);
  final BigInt a = BigInt.zero; 

  // Точка G (Генератор)
  final List<BigInt> G = [
    BigInt.parse("55066263022277343669578718895168534326250603453777594175500187360389116729240"),
    BigInt.parse("32670510020758816978083085130507043184471273380659243275938904335757337482424")
  ];

  // Целевая точка Q
  final List<BigInt> Q = [
    BigInt.parse("69874757311306172767032656227267399159598975785131679881629970068417157508982"),
    BigInt.parse("82307116114001638795922891179745376142088021306855438143719624270381202173533")
  ];

  print("=== Система VPA: Анализ в поле secp256k1 ===");

  // 2. Проверка принадлежности одной кривой
  BigInt bG = (G[1].modPow(BigInt.two, p) - (G[0].modPow(BigInt.from(3), p) + a * G[0])) % p;
  if (bG < BigInt.zero) bG += p;

  BigInt bQ = (Q[1].modPow(BigInt.two, p) - (Q[0].modPow(BigInt.from(3), p) + a * Q[0])) % p;
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
    } else {
      print("\n[КОНЕЦ] Ключ не найден в диапазоне 100,000.");
    }
  }
}

/// Сложение точек (ваша версия с исправлениями Dart %)
List<BigInt> addPoint(List<BigInt> p1, List<BigInt> p2, BigInt p, BigInt a) {
  if (p1[0] == BigInt.zero && p1[1] == BigInt.zero) return p2;
  if (p2[0] == BigInt.zero && p2[1] == BigInt.zero) return p1;

  BigInt x1 = p1[0], y1 = p1[1];
  BigInt x2 = p2[0], y2 = p2[1];
  BigInt lambda;

  try {
    if (x1 == x2 && y1 == y2) {
      BigInt num = (BigInt.from(3) * x1.modPow(BigInt.two, p) + a) % p;
      BigInt den = (BigInt.two * y1) % p;
      lambda = (num * den.modInverse(p)) % p;
    } else {
      BigInt num = (y2 - y1) % p;
      BigInt den = (x2 - x1) % p;
      lambda = (num * den.modInverse(p)) % p;
    }

    BigInt x3 = (lambda.modPow(BigInt.two, p) - x1 - x2) % p;
    BigInt y3 = (lambda * (x1 - x3) - y1) % p;

    return [
      x3 < BigInt.zero ? x3 + p : x3,
      y3 < BigInt.zero ? y3 + p : y3
    ];
  } catch (e) {
    return [BigInt.zero, BigInt.zero];
  }
}

/// Поиск дискретного логарифма
BigInt? crackDiscreteLog(List<BigInt> G, List<BigInt> target, BigInt p, BigInt a) {
  List<BigInt> currentPoint = List.from(G);

  for (int d = 1; d <= 1000000000000000; d++) {
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
