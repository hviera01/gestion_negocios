import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Face ID / Touch ID / Windows Hello nativo. En Web nunca aplica.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  bool get soportaPlataforma => !kIsWeb;

  Future<bool> disponible() async {
    if (!soportaPlataforma) return false;
    try {
      final soportado = await _auth.isDeviceSupported();
      final puedeChequear = await _auth.canCheckBiometrics;
      return soportado && puedeChequear;
    } catch (_) {
      return false;
    }
  }

  Future<bool> autenticar({String razon = 'Confirmá tu identidad para entrar'}) async {
    if (!soportaPlataforma) return false;
    try {
      return await _auth.authenticate(
        localizedReason: razon,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
