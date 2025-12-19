import 'dart:convert';
import 'dart:io';
import 'package:cli/elliptic_curve.dart';

/// Генерирует открытые ключи для заданного диапазона закрытых ключей
List<Map<String, dynamic>> generatePublicKeyRange(
  BigInt startPrivateKey,
  BigInt endPrivateKey,
  BigInt p,
  BigInt a,
  List<BigInt> G,
) {
  List<Map<String, dynamic>> publicKeyData = [];

  for (BigInt privateKey = startPrivateKey; privateKey <= endPrivateKey; privateKey = privateKey + BigInt.one) {
    // Вычисляем открытый ключ как Q = privateKey * G
    List<BigInt>? publicKey = scalarMultiply(G, privateKey, p, a);

    if (publicKey != null) {
      String hexX = publicKey[0].toRadixString(16).padLeft(64, '0');
      String hexY = publicKey[1].toRadixString(16).padLeft(64, '0');
      
      Map<String, dynamic> keyInfo = {
        'private_key': privateKey.toString(),
        'public_key': {
          'x': hexX,
          'y': hexY,
          'compressed': '02' + hexX, // Если y четный, иначе '03'
          'uncompressed': '04' + hexX + hexY,
        },
        'decimal': {
          'x': publicKey[0].toString(),
          'y': publicKey[1].toString(),
        }
      };

      publicKeyData.add(keyInfo);
    }
  }

  return publicKeyData;
}

/// Сохраняет данные открытых ключей в JSON файл
Future<void> savePublicKeyDataToFile(List<Map<String, dynamic>> data, String filePath) async {
  // Создаем директорию data, если она не существует
  final dir = Directory('data');
  if (!await dir.exists()) {
    await dir.create();
  }
  
  // Если путь к файлу не начинается с 'data/', добавляем 'data/' к пути
  if (!filePath.startsWith('data/')) {
    filePath = 'data/$filePath';
  }
  
  final jsonString = JsonEncoder.withIndent('  ').convert(data);
  await File(filePath).writeAsString(jsonString);
}