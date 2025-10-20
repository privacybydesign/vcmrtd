//  Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
import 'dart:typed_data';
import 'package:logging/logging.dart';
import '../extension/logging_apis.dart';

class ComProviderError implements Exception {
  final String message;
  const ComProviderError([this.message = ""]);
  @override
  String toString() => 'ComProviderError: $message';
}


/// Abstract interface for communicating with ICC.
abstract class ComProvider {
  // ignore: unused_field
  final Logger _log;
  ComProvider(Logger log) : _log = log;

  /// Callback invoked when connection is successfully established.
  /// Can be used to reset state or perform initialization after connection.
  void Function()? onConnected;

  /// Callback invoked when connection is lost or disconnected.
  /// Can be used to clean up resources or reset state.
  void Function()? onDisconnected;

  //// Can throw [ComProviderError].
  Future<void> connect();

  //// Can throw [ComProviderError].
  Future<void> disconnect();

  bool isConnected();

  /// Can throw [ComProviderError].
  Future<Uint8List> transceive(final Uint8List data);

  /// Notifies listeners that connection was established.
  void notifyConnected() {
    _log.debug("Connection established");
    onConnected?.call();
  }

  /// Notifies listeners that connection was lost or disconnected.
  void notifyDisconnected() {
    _log.debug("Connection terminated");
    onDisconnected?.call();
  }
}