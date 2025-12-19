/// Математические операции для эллиптической кривой secp256k1
library elliptic_curve;

import 'dart:typed_data';

/// Скалярное умножение точки на число (Double-and-Add)
List<BigInt>? scalarMultiply(List<BigInt> point, BigInt scalar, BigInt p, BigInt a) {
  List<BigInt>? result;
  List<BigInt>? addend = point;

  String binary = scalar.toRadixString(2);

  for (int i = binary.length - 1; i >= 0; i--) {
    if (binary[i] == '1') {
      result = (result == null) ? addend : addPoint(result!, addend!, p, a);
    }
    if (i > 0) {
      addend = addPoint(addend!, addend!, p, a); // Удвоение точки
    }
  }
  return result;
}

/// Сложение двух точек на эллиптической кривой (включая случай удвоения)
List<BigInt> addPoint(List<BigInt> p1, List<BigInt> p2, BigInt p, BigInt a) {
  BigInt x1 = p1[0], y1 = p1[1];
  BigInt x2 = p2[0], y2 = p2[1];

  // Проверка на нулевые точки (точки на бесконечности)
  if (x1 == BigInt.zero && y1 == BigInt.zero) return p2;
  if (x2 == BigInt.zero && y2 == BigInt.zero) return p1;

  BigInt lambda;

  if (x1 == x2) {
    if (y1 == y2) {
      // Случай удвоения точки: lambda = (3*x1^2 + a) / (2*y1)
      if (y1 == BigInt.zero) {
        // Если y1 = 0, то это точка порядка 2, результат - точка на бесконечности
        return [BigInt.zero, BigInt.zero];
      }
      BigInt num = (BigInt.from(3) * x1.modPow(BigInt.two, p) + a) % p;
      BigInt den = (BigInt.two * y1) % p;
      // Проверяем, что знаменатель не равен нулю по модулю p
      if (den == BigInt.zero) {
        return [BigInt.zero, BigInt.zero];
      }
      try {
        lambda = (num * den.modInverse(p)) % p;
      } catch (e) {
        // Если не удается найти обратный элемент, возвращаем точку на бесконечности
        return [BigInt.zero, BigInt.zero];
      }
    } else {
      // Противоположные точки: P + (-P) = O
      return [BigInt.zero, BigInt.zero];
    }
  } else {
    // Случай сложения разных точек: lambda = (y2 - y1) / (x2 - x1)
    BigInt num = (y2 - y1) % p;
    BigInt den = (x2 - x1) % p;
    try {
      lambda = (num * den.modInverse(p)) % p;
    } catch (e) {
      // Если не удается найти обратный элемент, возвращаем точку на бесконечности
      return [BigInt.zero, BigInt.zero];
    }
  }

  BigInt x3 = (lambda.modPow(BigInt.two, p) - x1 - x2) % p;
  BigInt y3 = (lambda * (x1 - x3) - y1) % p;

  // Нормализация отрицательных значений
  if (x3 < BigInt.zero) x3 += p;
  if (y3 < BigInt.zero) y3 += p;

  return [x3, y3];
}

/// Скалярное умножение точки на число (оптимизированное)
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

/// Расширенный алгоритм Евклида для вычисления обратного элемента
BigInt modInverseOptimized(BigInt a, BigInt m) {
  BigInt m0 = m, x0 = BigInt.zero, x1 = BigInt.one;

  if (m == BigInt.one) return BigInt.one;

  while (a > BigInt.one) {
    BigInt q = a ~/ m;
    BigInt t = m;
    m = a % m;
    a = t;
    t = x0;
    x0 = x1 - q * x0;
    x1 = t;
  }

  if (x1 < BigInt.zero) x1 += m0;
  return x1;
}