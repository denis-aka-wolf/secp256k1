/// Основная библиотека для работы с эллиптической кривой secp256k1
library secp256k1;

export 'elliptic_curve.dart';
export 'key_generator.dart';
export 'utils.dart';

/// Константы кривой secp256k1
class Secp256k1Constants {
  /// Поле F_p
  static final BigInt p = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', radix: 16);
  
  /// Параметр a уравнения y^2 = x^3 + ax + b
  static final BigInt a = BigInt.zero;
  
  /// Параметр b уравнения y^2 = x^3 + ax + b
  static final BigInt b = BigInt.from(7);
  
  /// Базовая точка G
  static final List<BigInt> G = [
    BigInt.parse('79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798', radix: 16),
    BigInt.parse('483ADA7726A3C4655DA4FBFC0E1108A8FD17B48A68554199C47D08FFB10D4B8', radix: 16)
  ];
}