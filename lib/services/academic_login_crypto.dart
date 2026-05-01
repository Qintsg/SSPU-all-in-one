/*
 * OA/CAS 登录加密工具 — RSA PKCS#1 v1.5 与 DER 公钥解析
 * @Project : SSPU-all-in-one
 * @File : academic_login_crypto.dart
 * @Author : Qintsg
 * @Date : 2026-05-01
 */

part of 'academic_login_validation_service.dart';

class _RsaPkcs1Encryptor {
  static String encryptToBase64(String plainText, String publicKeyPem) {
    final publicKey = _RsaPublicKey.fromPem(publicKeyPem);
    final message = Uint8List.fromList(utf8.encode(plainText));
    final keyLength = (publicKey.modulus.bitLength + 7) ~/ 8;
    if (message.length > keyLength - 11) {
      throw StateError('OA 密码长度超过 CAS RSA 公钥可加密范围');
    }

    final block = Uint8List(keyLength);
    final random = Random.secure();
    final paddingLength = keyLength - message.length - 3;
    block[0] = 0x00;
    block[1] = 0x02;
    for (var index = 0; index < paddingLength; index++) {
      var randomByte = 0;
      while (randomByte == 0) {
        randomByte = random.nextInt(256);
      }
      block[index + 2] = randomByte;
    }
    block[paddingLength + 2] = 0x00;
    block.setRange(paddingLength + 3, keyLength, message);

    final encrypted = _bytesToBigInt(
      block,
    ).modPow(publicKey.exponent, publicKey.modulus);
    return base64Encode(_bigIntToFixedBytes(encrypted, keyLength));
  }

  static BigInt _bytesToBigInt(List<int> bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  static Uint8List _bigIntToFixedBytes(BigInt value, int length) {
    final output = Uint8List(length);
    var remaining = value;
    for (var index = length - 1; index >= 0; index--) {
      output[index] = (remaining & BigInt.from(0xff)).toInt();
      remaining = remaining >> 8;
    }
    return output;
  }
}

class _RsaPublicKey {
  const _RsaPublicKey({required this.modulus, required this.exponent});

  final BigInt modulus;
  final BigInt exponent;

  factory _RsaPublicKey.fromPem(String pem) {
    final normalized = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll(RegExp(r'\s+'), '');
    final der = Uint8List.fromList(base64Decode(normalized));
    final topLevel = _DerReader(der).readConstructed(0x30);
    topLevel.readConstructed(0x30);
    final bitString = topLevel.readValue(0x03);
    if (bitString.isEmpty || bitString.first != 0x00) {
      throw const FormatException('CAS RSA 公钥 BIT STRING 格式异常');
    }

    final keySequence = _DerReader(
      Uint8List.fromList(bitString.sublist(1)),
    ).readConstructed(0x30);
    return _RsaPublicKey(
      modulus: _stripLeadingZeroAndReadInteger(keySequence.readValue(0x02)),
      exponent: _stripLeadingZeroAndReadInteger(keySequence.readValue(0x02)),
    );
  }

  static BigInt _stripLeadingZeroAndReadInteger(List<int> bytes) {
    var startIndex = 0;
    while (startIndex < bytes.length - 1 && bytes[startIndex] == 0) {
      startIndex++;
    }
    return _RsaPkcs1Encryptor._bytesToBigInt(bytes.sublist(startIndex));
  }
}

class _DerReader {
  _DerReader(this.bytes);

  final Uint8List bytes;
  int _offset = 0;

  _DerReader readConstructed(int expectedTag) {
    return _DerReader(readValue(expectedTag));
  }

  Uint8List readValue(int expectedTag) {
    if (_offset >= bytes.length || bytes[_offset] != expectedTag) {
      throw FormatException('ASN.1 标签不匹配：期望 $expectedTag');
    }
    _offset++;
    final length = _readLength();
    if (_offset + length > bytes.length) {
      throw const FormatException('ASN.1 长度超出数据范围');
    }
    final value = Uint8List.sublistView(bytes, _offset, _offset + length);
    _offset += length;
    return value;
  }

  int _readLength() {
    if (_offset >= bytes.length) {
      throw const FormatException('ASN.1 长度缺失');
    }
    final first = bytes[_offset++];
    if (first < 0x80) return first;

    final byteCount = first & 0x7f;
    if (byteCount == 0 || byteCount > 4 || _offset + byteCount > bytes.length) {
      throw const FormatException('ASN.1 长度格式异常');
    }
    var length = 0;
    for (var index = 0; index < byteCount; index++) {
      length = (length << 8) | bytes[_offset++];
    }
    return length;
  }
}
