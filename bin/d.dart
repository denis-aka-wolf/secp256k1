void main() {
  final BigInt p = BigInt.parse("115792089237316195423570985008687907853269984665640564039457584007908834671663");
  final BigInt a = BigInt.zero; // Параметр A для y^2 = x^3 + 7

  // Точка G
  final Point G = Point(
    BigInt.parse("55066263022277343669578718895168534326250603453777594175500187360389116729240"),
    BigInt.parse("32670510020758816978083085130507043184471273380659243275938904335757337482424")
  );

  // Целевая точка Q
  final Point Q = Point(
    BigInt.parse("109921230969093388853966210058315145860213412726202766573229810929488554311270"),
    BigInt.parse("114165137965800236389958514164212573551292041563212191306350325126693608044427")
  );

  print("Начинаем обратное преобразование VPA...");
  
  final BigInt b = mod(G.y * G.y - (G.x * G.x * G.x), p);
  print("Реальный параметр B для этой кривой: $b");

  BigInt? d = crackDiscreteLog(G, Q, p, a);

  if (d != null) {
    print("\nУра! Закрытый ключ d найден: $d");
  } else {
    print("\nКлюч не найден. Проверьте параметры кривой.");
  }
}

class Point {
  final BigInt x, y;
  Point(this.x, this.y);
}

// Правильное взятие остатка для нашей математики (всегда положительное)
BigInt mod(BigInt n, BigInt m) {
  BigInt r = n % m;
  return r < BigInt.zero ? r + m : r;
}

BigInt modInverse(BigInt n, BigInt m) {
  BigInt m0 = m, a = n, x0 = BigInt.zero, x1 = BigInt.one;
  while (a > BigInt.one) {
    BigInt q = a ~/ m;
    BigInt t = m;
    m = a % m;
    a = t;
    t = x0;
    x0 = x1 - q * x0;
    x1 = t;
  }
  return mod(x1, m0);
}

Point addPoints(Point p1, Point p2, BigInt p, BigInt a) {
  BigInt lambda;
  if (p1.x == p2.x && p1.y == p2.y) {
    // Удвоение: lambda = (3x^2 + a) / 2y
    BigInt num = mod(BigInt.from(3) * p1.x * p1.x + a, p);
    BigInt den = mod(BigInt.from(2) * p1.y, p);
    lambda = mod(num * modInverse(den, p), p);
  } else {
    // Сложение: lambda = (y2 - y1) / (x2 - x1)
    BigInt num = mod(p2.y - p1.y, p);
    BigInt den = mod(p2.x - p1.x, p);
    lambda = mod(num * modInverse(den, p), p);
  }

  BigInt x3 = mod(lambda * lambda - p1.x - p2.x, p);
  BigInt y3 = mod(lambda * (p1.x - x3) - p1.y, p);
  return Point(x3, y3);
}

BigInt? crackDiscreteLog(Point G, Point target, BigInt p, BigInt a) {
  Point currentPoint = G;
  // Мы будем проверять и Y и -Y (симметрию кривой)
  for (int d = 1; d <= 30000; d++) {
    // Проверка совпадения X
    if (currentPoint.x == target.x) {
      if (currentPoint.y == target.y) {
        return BigInt.from(d);
      } else {
        // Если X совпал, а Y нет — значит ключ d это (Order - d)
        // или мы нашли отрицательную версию точки
        print("Найдено совпадение по X на шаге $d, но Y зеркален!");
        return BigInt.from(d); 
      }
    }
    
    currentPoint = addPoints(currentPoint, G, p, a);
    
    if (d % 5000 == 0) {
      print("Шаг $d... X: ${currentPoint.x.toString().substring(0, 8)}...");
    }
  }
  return null;
}

