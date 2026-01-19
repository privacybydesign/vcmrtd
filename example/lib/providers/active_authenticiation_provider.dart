import 'package:flutter_riverpod/flutter_riverpod.dart';

class BooleanNotifier extends Notifier<bool> {
  BooleanNotifier(this._initial);
  final bool _initial;

  void set(bool value) => state = value;

  @override
  bool build() {
    return _initial;
  }
}

// can be used to globally enable/disable active authentication
final activeAuthenticationProvider = NotifierProvider(() => BooleanNotifier(true));
