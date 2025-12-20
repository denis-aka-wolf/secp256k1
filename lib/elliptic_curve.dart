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

/// Вычисление квадратного корня по модулю p (для простого p)
BigInt? modularSqrt(BigInt n, BigInt p) {
  // Проверяем, является ли n квадратичным остатком по модулю p
  BigInt legendre = n.modPow((p - BigInt.one) ~/ BigInt.two, p);
  if (legendre != BigInt.one) {
    return null; // n не является квадратичным остатком
  }

  // Алгоритм Тонелли-Шенкса для вычисления квадратного корня
  if (p % BigInt.from(4) == BigInt.from(3)) {
    return n.modPow((p + BigInt.one) ~/ BigInt.from(4), p);
  }

  // Для других случаев используем общий алгоритм (упрощенная версия)
  BigInt s = p - BigInt.one;
  int r = 0;
  while (s.isEven) {
    s = s ~/ BigInt.two;
    r++;
  }

  BigInt z = BigInt.two;
  while (z.modPow((p - BigInt.one) ~/ BigInt.two, p) == BigInt.one) {
    z = z + BigInt.one;
  }

  BigInt m = BigInt.from(r);
  BigInt c = z.modPow(s, p);
  BigInt t = n.modPow(s, p);
  BigInt result = n.modPow((s + BigInt.one) ~/ BigInt.two, p);

  while (t != BigInt.zero && t != BigInt.one) {
    BigInt i = BigInt.zero;
    BigInt t_pow = t;
    while (t_pow != BigInt.one) {
      t_pow = t_pow.modPow(BigInt.two, p);
      i = i + BigInt.one;
    }

    if (i == m) {
      return null; // Не удалось найти квадратный корень
    }

    BigInt b = c.modPow(BigInt.two.modPow(m - i - BigInt.one, p - BigInt.one), p);
    m = i;
    c = b.modPow(BigInt.two, p);
    t = (t * c) % p;
    result = (result * b) % p;
  }

  return result;
}

/// Вычисление координаты Y по X на эллиптической кривой y^2 = x^3 + ax + b
List<BigInt>? getYCoordinate(BigInt x, BigInt p, BigInt a, BigInt b) {
  // y^2 = x^3 + ax + b
  BigInt rightSide = (x.modPow(BigInt.from(3), p) + a * x + b) % p;
  
  BigInt? y = modularSqrt(rightSide, p);
  if (y == null) {
    return null; // Не существует точки с такой координатой X
  }

  // Возвращаем обе возможные координаты Y: y и p-y
  BigInt y2 = (p - y) % p;
  return [y, y2];
}