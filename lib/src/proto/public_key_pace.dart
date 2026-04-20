//  Created by Nejc Skerjanc, copyright © 2023 ZeroPass. All rights reserved.

import 'dart:typed_data';
import 'package:vcmrtd/extensions.dart';
import 'package:pointycastle/ecc/api.dart';

import '../lds/asn1ObjectIdentifiers.dart';
import '../utils.dart';

abstract class PublicKeyPACE {
  TOKEN_AGREEMENT_ALGO algo;

  TOKEN_AGREEMENT_ALGO get agreementAlgorithm => algo;

  PublicKeyPACE({required this.algo});

  Uint8List toBytes();

  Uint8List toRelavantBytes();

  @override
  String toString();
}

class PublicKeyPACEeCDH extends PublicKeyPACE {
  final BigInt _x;
  final BigInt _y;
  // Coordinate byte length for the curve (0 = no padding). Must be set for
  // terminal-generated keys so coordinates are padded to the curve field size.
  final int _coordLen;

  PublicKeyPACEeCDH({required BigInt x, required BigInt y, int coordLen = 0})
    : _x = x,
      _y = y,
      _coordLen = coordLen,
      super(algo: TOKEN_AGREEMENT_ALGO.ECDH);

  PublicKeyPACEeCDH.fromECPoint({required ECPoint public})
    : _x = public.x!.toBigInteger()!,
      _y = public.y!.toBigInteger()!,
      _coordLen = 0,
      super(algo: TOKEN_AGREEMENT_ALGO.ECDH);

  BigInt get x => _x;
  BigInt get y => _y;

  Uint8List _paddedCoord(BigInt coord) {
    final raw = Utils.bigIntToUint8List(bigInt: coord);
    if (_coordLen <= 0 || raw.length >= _coordLen) return raw;
    final padded = Uint8List(_coordLen);
    padded.setRange(_coordLen - raw.length, _coordLen, raw);
    return padded;
  }

  Uint8List get xBytes => _paddedCoord(_x);
  Uint8List get yBytes => _paddedCoord(_y);

  @override
  Uint8List toBytes() {
    return Uint8List.fromList([...xBytes, ...yBytes]);
  }

  PublicKeyPACEeCDH.fromHex({required Uint8List hexKey})
    : _x = Utils.uint8ListToBigInt(hexKey.sublist(0, hexKey.length ~/ 2)),
      _y = Utils.uint8ListToBigInt(hexKey.sublist(hexKey.length ~/ 2)),
      _coordLen = 0,
      super(algo: TOKEN_AGREEMENT_ALGO.ECDH);

  @override
  Uint8List toRelavantBytes() {
    return xBytes;
  }

  @override
  String toString() {
    return "X: ${xBytes.hex()}\nY: ${yBytes.hex()}";
  }
}

class PublicKeyPACEdH extends PublicKeyPACE {
  final Uint8List _pub;
  PublicKeyPACEdH({required Uint8List pub}) : _pub = pub, super(algo: TOKEN_AGREEMENT_ALGO.DH);

  Uint8List get pub => _pub;

  @override
  Uint8List toBytes() {
    return _pub;
  }

  @override
  Uint8List toRelavantBytes() {
    return _pub;
  }

  @override
  String toString() {
    return _pub.hex();
  }
}
