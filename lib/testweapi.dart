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

Uint8List _aesEncrypt2(String text, String secKey, String algo) {
  final key = utf8.encode(secKey);
  final encrypter = ECBBlockCipher(AESEngine())
    ..init(true, KeyParameter(Uint8List.fromList(key)));
  final paddedText = _pad2(utf8.encode(text), encrypter.blockSize);
  final encrypted = Uint8List(paddedText.length);
  var offset = 0;
  while (offset < paddedText.length) {
    offset += encrypter.processBlock(paddedText, offset, encrypted, offset);
  }
  return encrypted;
}

Uint8List _pad2(Uint8List data, int blockSize) {
  final padLength = blockSize - (data.length % blockSize);
  return Uint8List.fromList(data + List.filled(padLength, padLength));
}



String _bytesToHex(Uint8List bytes) {
  final buffer = StringBuffer();
  for (var byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

Map<String, dynamic> eapi(String url, dynamic object) {
  const eapiKey = 'e82ckenh8dichen8';
  final text = object is Map ? jsonEncode(object) : object;
  final message = 'nobody' + url + 'use' + text + 'md5forencrypt';
  final digest = md5.convert(utf8.encode(message)).toString();
  final data = '$url-36cd479b6b5-$text-36cd479b6b5-$digest';
  final encrypted = _aesEncrypt2(data, eapiKey, 'AES-ECB');
  final hexString = _bytesToHex(encrypted).toUpperCase();
  return {
    'params': hexString,
  };
}

void main() async {
  const eapiUrl = '/api/song/enhance/player/url';
  dynamic d = {
    // 'csrf_token': await get_csrf(),
    'ids': "[1906277944]",
    'br': 999000,
  };
  final result = eapi(eapiUrl, d);
  print(result);
  // "FA90B329E9614F79E79598F37DC2EDB430F8378D2A2796338F0BFDEAEF824A22975CDA9D96D79E6DC4A59218CDB8199FBB90671B126E519ED511D196BD71EAB84959DDD5294E9C48DBF5C8992F45F3D55033E9565E01F668772DB24D1C29651D30793194BECF1D21FD945543406D63561D090DE1154B7CBCBEB27BCDE2058500"
  //     FA90B329E9614F79E79598F37DC2EDB430F8378D2A2796338F0BFDEAEF824A22975CDA9D96D79E6DC4A59218CDB8199FB49E3889B82954F188A5D34B1CCA702EEF76993CE719CB12D323CEEC3778C9550EB2CD1084446E47AFD36CB89938294A410AAE9363B1FB64330E5458AED260591ABE01640FBEDD24E35DCB6EA9840207
  // NQPZTZFVEUM7F+9AS+GDJKG9ILGR+5BGPP9IW1ZYGVGS+DP8HBVQKKETTR+BIX2NPCQ/4WLPMK5O2XATREK0JIBARXFIWYKWXRO87YHXK4U6V16WVFMS3LE84ZLW/U2WXEW61A8Q0S4MHJPI3MNASZYXHU3F4J7HTE7WMNUDD3I=
}
