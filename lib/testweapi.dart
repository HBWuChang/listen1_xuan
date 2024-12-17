import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' show parse;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'lowebutil.dart';
import 'settings.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:convert/convert.dart';

Uint8List _pad(Uint8List data, int blockSize) {
  int padLength = blockSize - (data.length % blockSize);
  return Uint8List.fromList(data + List.filled(padLength, padLength));
}

String _createSecretKey(int size) {
  // return '1234567890123456';
  const choice = '012345679abcdef';
  final result = List.generate(size, (index) {
    final randomIndex = (choice.length *
            (new DateTime.now().millisecondsSinceEpoch % 1000) /
            1000)
        .floor();
    return choice[randomIndex];
  });
  return result.join('');
}

Uint8List _aesEncrypt(String text, String secKey, String algo) {
  final key = utf8.encode(secKey);
  final iv = utf8.encode('0102030405060708');
  final encrypter = CBCBlockCipher(AESEngine())
    ..init(true, ParametersWithIV(KeyParameter(Uint8List.fromList(key)), Uint8List.fromList(iv)));
  final paddedText = _pad(utf8.encode(text), encrypter.blockSize);
  final encrypted = Uint8List(paddedText.length);
  var offset = 0;
  while (offset < paddedText.length) {
    offset += encrypter.processBlock(paddedText, offset, encrypted, offset);
  }
  return encrypted;
}

String _rsaEncrypt(String text, String pubKey, String modulus) {
  final reversedText = text.split('').reversed.join('');
  final n = BigInt.parse(modulus, radix: 16);
  final e = BigInt.parse(pubKey, radix: 16);
  final b = BigInt.parse(hex.encode(utf8.encode(reversedText)), radix: 16);
  final enc = b.modPow(e, n).toRadixString(16).padLeft(256, '0');
  return enc;
}

Map<String, String> weapi(Map<String, dynamic> text) {
  final modulus =
      '00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b72'
      '5152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbd'
      'a92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe48'
      '75d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7';
  final nonce = '0CoJUm6Qyw8W8jud';
  final pubKey = '010001';
  final jsonText = jsonEncode(text);
  print(jsonText);
  final secKey = _createSecretKey(16);
  final t1 = _aesEncrypt(jsonText, nonce, 'AES-CBC');
  final t2 = base64.encode(t1);
  print(t2);
  final t3 = _aesEncrypt(t2, secKey, 'AES-CBC');
  final t4 = base64.encode(t3);
  print(t4);
  final encText = t4;
  final encSecKey = _rsaEncrypt(secKey, pubKey, modulus);
  return {
    'params': encText,
    'encSecKey': encSecKey,
  };
}
void main() async {
  dynamic encryptReqData = {
      // 'csrf_token': await get_csrf(),
      'csrf_token': "af3c2b3649aac37f7dd3a32ce1818ffc",
    };
    print(encryptReqData);
    print(jsonEncode(encryptReqData));
    encryptReqData = weapi(encryptReqData);
    print(encryptReqData);
}