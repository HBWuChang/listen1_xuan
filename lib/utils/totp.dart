import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class TotpAccount {
  final List<int> secret;
  final String name;
  final String algorithm;
  final int digits;
  final int period;
  TotpAccount(
    this.secret, {
    this.name = '',
    this.algorithm = 'SHA1',
    this.digits = 6,
    this.period = 30,
  }) {
    if (secret.isEmpty ||
        !['SHA1', 'SHA256', 'SHA512'].contains(algorithm) ||
        ![6, 8].contains(digits) ||
        period <= 0) {
      throw const FormatException('不支持的 TOTP 参数');
    }
  }
  String encode() => jsonEncode({
    'secret': base64Encode(secret),
    'name': name,
    'algorithm': algorithm,
    'digits': digits,
    'period': period,
  });
  factory TotpAccount.decode(String value) {
    final m = jsonDecode(value);
    return TotpAccount(
      base64Decode(m['secret']),
      name: m['name'],
      algorithm: m['algorithm'],
      digits: m['digits'],
      period: m['period'],
    );
  }
  String code({DateTime? time}) {
    final counter =
        (time ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000 ~/ period;
    final data = ByteData(8)..setUint64(0, counter);
    final hash = {'SHA1': sha1, 'SHA256': sha256, 'SHA512': sha512}[algorithm]!;
    final digest = Hmac(hash, secret).convert(data.buffer.asUint8List()).bytes;
    final offset = digest.last & 15;
    final number =
        ((digest[offset] & 127) << 24) |
        (digest[offset + 1] << 16) |
        (digest[offset + 2] << 8) |
        digest[offset + 3];
    return (number % (digits == 8 ? 100000000 : 1000000)).toString().padLeft(
      digits,
      '0',
    );
  }
}

List<int> _base32(String value) {
  final s = value
      .toUpperCase()
      .replaceAll(RegExp(r'\s'), '')
      .replaceFirst(RegExp(r'=+$'), '');
  if (s.isEmpty ||
      !RegExp(r'^[A-Z2-7]+$').hasMatch(s) ||
      ![0, 2, 4, 5, 7].contains(s.length % 8)) {
    throw const FormatException('无效的 Base32 密钥');
  }
  var bits = 0, buffer = 0;
  final bytes = <int>[];
  for (final c in s.codeUnits) {
    buffer =
        (buffer << 5) |
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'.indexOf(String.fromCharCode(c));
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      bytes.add((buffer >> bits) & 255);
      buffer &= (1 << bits) - 1;
    }
  }
  if (buffer != 0) throw const FormatException('无效的 Base32 密钥');
  return bytes;
}

// Only the protobuf wire types used by Authenticator's migration payload.
Map<int, List<dynamic>> _fields(List<int> bytes) {
  var pos = 0;
  int integer() {
    var result = 0;
    for (var shift = 0; shift < 64 && pos < bytes.length; shift += 7) {
      final b = bytes[pos++];
      result |= (b & 127) << shift;
      if (b < 128) return result;
    }
    throw const FormatException('无效的迁移数据');
  }

  final result = <int, List<dynamic>>{};
  while (pos < bytes.length) {
    final tag = integer();
    if (tag >> 3 == 0) throw const FormatException('无效的迁移数据');
    dynamic value;
    if (tag & 7 == 0) {
      value = integer();
    } else if (tag & 7 == 2) {
      final length = integer();
      if (length < 0 || pos + length > bytes.length) {
        throw const FormatException('迁移数据不完整');
      }
      value = bytes.sublist(pos, pos + length);
      pos += length;
    } else {
      throw const FormatException('不支持的迁移数据');
    }
    result.putIfAbsent(tag >> 3, () => []).add(value);
  }
  return result;
}

List<TotpAccount> parseTotpInput(String input) {
  final text = input.trim();
  if (!text.contains('://')) return [TotpAccount(_base32(text))];
  final uri = Uri.parse(text);
  if (uri.scheme == 'otpauth' && uri.host == 'totp') {
    final p = uri.queryParameters;
    return [
      TotpAccount(
        _base32(p['secret'] ?? ''),
        name: uri.pathSegments.join('/'),
        algorithm: (p['algorithm'] ?? 'SHA1').toUpperCase(),
        digits: int.parse(p['digits'] ?? '6'),
        period: int.parse(p['period'] ?? '30'),
      ),
    ];
  }
  if (uri.scheme == 'otpauth-migration' && uri.host == 'offline') {
    final payload = _fields(
      base64Decode(
        base64.normalize(
          (uri.queryParameters['data'] ?? '').replaceAll(' ', '+'),
        ),
      ),
    );
    final accounts = <TotpAccount>[];
    for (final raw in payload[1] ?? []) {
      final f = _fields(List<int>.from(raw));
      dynamic first(int key, dynamic fallback) => f[key]?.first ?? fallback;
      if (first(6, 0) != 2) continue; // HOTP is not time based.
      final algorithm = {1: 'SHA1', 2: 'SHA256', 3: 'SHA512'}[first(4, 0)];
      final digits = {1: 6, 2: 8}[first(5, 0)];
      if (algorithm == null || digits == null) {
        throw const FormatException('迁移码包含不支持的算法或位数');
      }
      accounts.add(
        TotpAccount(
          List<int>.from(first(1, <int>[])),
          name: utf8.decode(List<int>.from(first(2, <int>[]))),
          algorithm: algorithm,
          digits: digits,
        ),
      );
    }
    if (accounts.isEmpty) throw const FormatException('迁移码中没有 TOTP 账户');
    return accounts;
  }
  throw const FormatException('请输入 Base32 密钥或 TOTP 二维码内容');
}
