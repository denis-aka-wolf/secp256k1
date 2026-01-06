import 'package:cli/secp256k1.dart';

void main() {
  // Используем константы из библиотеки
  final BigInt p = Secp256k1Constants.p;
  final BigInt a = Secp256k1Constants.a;
  final List<BigInt> G = Secp256k1Constants.G;

  // Создадим точку Q = 100*G для тестирования
  BigInt secretKey = BigInt.from(100);
  List<BigInt> Q = multiplyPointOptimized(G, secretKey, p, a);

  print("Точка Q = 100*G:");
  print("Qx: ${Q[0].toRadixString(16)}");
  print("Qy: ${Q[1].toRadixString(16)}");

  // Теперь попробуем найти этот ключ с помощью простого перебора
  List<BigInt> currentPoint = List.from(G);
  for (int d = 1; d <= 200; d++) {
    if (currentPoint[0] == Q[0] && currentPoint[1] == Q[1]) {
      print("Найден ключ: $d");
      break;
    }
    currentPoint = addPoint(currentPoint, G, p, a);
    if (d % 50 == 0) {
      print("Проверено: $d");
    }
  }
}