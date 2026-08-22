import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/biometric_service.dart';
import '../../../core/services/session_service.dart';

enum EstadoAuth { cargando, requiereConfiguracion, noAutenticado, autenticado }

class AuthState {
  final EstadoAuth estado;
  final String? error;
  final bool biometriaDisponible;
  final bool sesionLocalExiste;

  const AuthState({
    required this.estado,
    this.error,
    this.biometriaDisponible = false,
    this.sesionLocalExiste = false,
  });

  bool get puedeOfrecerBiometria => biometriaDisponible && sesionLocalExiste;

  AuthState copyWith({
    EstadoAuth? estado,
    String? error,
    bool? biometriaDisponible,
    bool? sesionLocalExiste,
  }) =>
      AuthState(
        estado: estado ?? this.estado,
        error: error,
        biometriaDisponible: biometriaDisponible ?? this.biometriaDisponible,
        sesionLocalExiste: sesionLocalExiste ?? this.sesionLocalExiste,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_inicializar);
    return const AuthState(estado: EstadoAuth.cargando);
  }

  Future<void> _inicializar() async {
    final biometria = await BiometricService.instance.disponible();
    final hayUsuario = await SessionService.instance.hayUsuarioConfigurado();
    if (!hayUsuario) {
      state = AuthState(estado: EstadoAuth.requiereConfiguracion, biometriaDisponible: biometria);
      return;
    }
    // Aunque haya un token guardado, la app arranca bloqueada: la biometría (o el
    // teclado como respaldo) es lo que la desbloquea, nunca se entra automático.
    final haySesion = await SessionService.instance.haySesionGuardada();
    state = AuthState(
      estado: EstadoAuth.noAutenticado,
      biometriaDisponible: biometria,
      sesionLocalExiste: haySesion,
    );
  }

  Future<bool> configurarUsuario(String codigo, String clave) async {
    final creado = await SessionService.instance.crearUsuarioInicial(codigo, clave);
    if (!creado) {
      state = state.copyWith(error: 'Ya existe un usuario configurado');
      return false;
    }
    return iniciarSesion(codigo, clave);
  }

  Future<bool> iniciarSesion(String codigo, String clave) async {
    try {
      await SessionService.instance.iniciarSesion(codigo, clave);
      state = state.copyWith(estado: EstadoAuth.autenticado, error: null, sesionLocalExiste: true);
      return true;
    } catch (_) {
      state = state.copyWith(estado: EstadoAuth.noAutenticado, error: 'Código o clave incorrectos');
      return false;
    }
  }

  Future<bool> desbloquearConBiometria() async {
    final ok = await BiometricService.instance.autenticar();
    if (ok) {
      state = state.copyWith(estado: EstadoAuth.autenticado, error: null);
    }
    return ok;
  }

  Future<void> cerrarSesion() async {
    await SessionService.instance.cerrarSesion();
    state = state.copyWith(estado: EstadoAuth.noAutenticado, sesionLocalExiste: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
