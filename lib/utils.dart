/// Вспомогательные утилиты для работы с эллиптической кривой secp256k1
library utils;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Преобразование BigInt в массив байтов (32 байта)
Uint8List bigIntTo32Bytes(BigInt n) {
  Uint8List bytes = Uint8List(32);
  BigInt temp = n;
  for (int i = 31; i >= 0; i--) {
    bytes[i] = (temp & BigInt.from(0xFF)).toInt();
    temp = temp >> 8;
    if (temp == BigInt.zero) break;
  }
  return bytes;
}

/// Преобразование массива байтов в BigInt
BigInt bytesToBigInt(Uint8List bytes) {
  BigInt result = BigInt.zero;
  for (int i = 0; i < bytes.length && i < 32; i++) {
    result = (result << 8) | BigInt.from(bytes[i]);
  }
  return result;
}

/// Получение 80-битного префикса из BigInt
BigInt get80bitPrefix(BigInt x) {
  Uint8List bytes = bigIntTo32Bytes(x);
  return bytesToBigInt(bytes.sublist(0, 10)); // Первые 10 байт = 80 бит
}

/// Проверка корректности размера файла
bool isValidFileSize(String fileName, int m) {
  try {
    int fileSize = File(fileName).lengthSync();
    return fileSize == m * 32;
  } catch (e) {
    return false;
  }
}