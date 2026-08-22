import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  late final AnimationController _fondoCtrl;
  late final AnimationController _shakeCtrl;
  late final AnimationController _biometriaCtrl;

  final _codigoCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  final _codigoFocus = FocusNode();
  final _claveFocus = FocusNode();

  bool _exito = false;
  bool _verificando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fondoCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _biometriaCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _fondoCtrl.dispose();
    _shakeCtrl.dispose();
    _biometriaCtrl.dispose();
    _codigoCtrl.dispose();
    _claveCtrl.dispose();
    _codigoFocus.dispose();
    _claveFocus.dispose();
    super.dispose();
  }

  bool get _modoConfiguracion => ref.read(authProvider).estado == EstadoAuth.requiereConfiguracion;

  Future<void> _entrar() async {
    final codigo = _codigoCtrl.text.trim();
    final clave = _claveCtrl.text.trim();
    if (codigo.isEmpty || clave.isEmpty) {
      _mostrarError('Completá los dos campos');
      return;
    }
    setState(() {
      _verificando = true;
      _error = null;
    });

    final ok = _modoConfiguracion
        ? await ref.read(authProvider.notifier).configurarUsuario(codigo, clave)
        : await ref.read(authProvider.notifier).iniciarSesion(codigo, clave);

    if (!mounted) return;
    if (ok) {
      setState(() {
        _exito = true;
        _verificando = false;
      });
    } else {
      _mostrarError(ref.read(authProvider).error ?? 'Código o clave incorrectos');
      setState(() => _verificando = false);
    }
  }

  void _mostrarError(String mensaje) {
    setState(() => _error = mensaje);
    HapticFeedback.heavyImpact();
    _shakeCtrl.forward(from: 0);
  }

  Future<void> _intentarBiometria() async {
    HapticFeedback.mediumImpact();
    final ok = await ref.read(authProvider.notifier).desbloquearConBiometria();
    if (ok && mounted) setState(() => _exito = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;
    final anchoTarjeta = math.min(420.0, size.width - 48);

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _FondoMesh(controller: _fondoCtrl),
          Align(
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _shakeCtrl,
              builder: (context, child) {
                final t = _shakeCtrl.value;
                final dx = (t == 0) ? 0.0 : (8 * (1 - t)) * ((t * 40).floor().isEven ? 1 : -1);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: _TarjetaVidrio(
                ancho: anchoTarjeta,
                child: _exito
                    ? const _CheckExito()
                    : _FormularioLogin(
                        modoConfiguracion: _modoConfiguracion,
                        codigoCtrl: _codigoCtrl,
                        claveCtrl: _claveCtrl,
                        codigoFocus: _codigoFocus,
                        claveFocus: _claveFocus,
                        error: _error,
                        verificando: _verificando,
                        onSubmit: _entrar,
                        mostrarBiometria: auth.puedeOfrecerBiometria,
                        biometriaCtrl: _biometriaCtrl,
                        onBiometria: _intentarBiometria,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormularioLogin extends StatelessWidget {
  final bool modoConfiguracion;
  final TextEditingController codigoCtrl;
  final TextEditingController claveCtrl;
  final FocusNode codigoFocus;
  final FocusNode claveFocus;
  final String? error;
  final bool verificando;
  final VoidCallback onSubmit;
  final bool mostrarBiometria;
  final AnimationController biometriaCtrl;
  final VoidCallback onBiometria;

  const _FormularioLogin({
    required this.modoConfiguracion,
    required this.codigoCtrl,
    required this.claveCtrl,
    required this.codigoFocus,
    required this.claveFocus,
    required this.error,
    required this.verificando,
    required this.onSubmit,
    required this.mostrarBiometria,
    required this.biometriaCtrl,
    required this.onBiometria,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'GESTIÓN NEGOCIOS',
                  style: TextStyle(color: AppColors.textoTerciario, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600),
                ),
              ),
              if (mostrarBiometria) _BotonBiometria(controller: biometriaCtrl, onTap: onBiometria),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            modoConfiguracion ? 'CONFIGURÁ TU ACCESO' : 'INGRESÁ TU ACCESO',
            textAlign: TextAlign.left,
            style: const TextStyle(color: AppColors.textoPrimario, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          const _EtiquetaCampo('CÓDIGO DE ACCESO'),
          const SizedBox(height: 6),
          _CampoNumerico(controller: codigoCtrl, focusNode: codigoFocus, autofocus: true, onSubmit: () => claveFocus.requestFocus()),
          const SizedBox(height: 16),
          const _EtiquetaCampo('CLAVE'),
          const SizedBox(height: 6),
          _CampoNumerico(controller: claveCtrl, focusNode: claveFocus, obscure: true, onSubmit: onSubmit),
          if (error != null) ...[
            const SizedBox(height: 14),
            Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ] else
            const SizedBox(height: 14 + 15),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: verificando ? null : onSubmit,
              child: verificando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00201C)))
                  : Text(modoConfiguracion ? 'CREAR ACCESO' : 'ENTRAR'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EtiquetaCampo extends StatelessWidget {
  final String texto;
  const _EtiquetaCampo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(texto, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12.5, fontWeight: FontWeight.w600));
  }
}

class _CampoNumerico extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscure;
  final bool autofocus;
  final VoidCallback onSubmit;

  const _CampoNumerico({
    required this.controller,
    required this.focusNode,
    this.obscure = false,
    this.autofocus = false,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: AppColors.textoPrimario, fontSize: 17, letterSpacing: 3, fontWeight: FontWeight.w600),
      decoration: const InputDecoration(hintText: '••••'),
      onSubmitted: (_) => onSubmit(),
    );
  }
}

class _BotonBiometria extends StatelessWidget {
  final AnimationController controller;
  final VoidCallback onTap;
  const _BotonBiometria({required this.controller, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final glow = 0.25 + 0.35 * controller.value;
          return Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.acentoVioleta.withValues(alpha: 0.12),
              boxShadow: [BoxShadow(color: AppColors.acentoVioleta.withValues(alpha: glow), blurRadius: 12)],
              border: Border.all(color: AppColors.acentoVioleta.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.fingerprint, color: AppColors.acentoVioleta, size: 18),
          );
        },
      ),
    );
  }
}

class _CheckExito extends StatelessWidget {
  const _CheckExito();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 48),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.elasticOut,
        builder: (context, t, child) => Transform.scale(scale: t, child: child),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.exito.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.exito, width: 2),
          ),
          child: const Icon(Icons.check_rounded, color: AppColors.exito, size: 44),
        ),
      ),
    );
  }
}

class _TarjetaVidrio extends StatelessWidget {
  final double ancho;
  final Widget child;
  const _TarjetaVidrio({required this.ancho, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.superficie.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 20)),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _FondoMesh extends StatelessWidget {
  final AnimationController controller;
  const _FondoMesh({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value * 6.28318;
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.fondo),
            _blob(context: context, dx: 0.20 + 0.10 * math.sin(t), dy: 0.18 + 0.08 * math.cos(t * 0.8), color: AppColors.acentoVioleta, size: 420),
            _blob(context: context, dx: 0.78 + 0.08 * math.cos(t * 0.6), dy: 0.30 + 0.10 * math.sin(t * 1.1), color: AppColors.acento, size: 360),
            _blob(context: context, dx: 0.55 + 0.12 * math.sin(t * 0.5), dy: 0.85 + 0.06 * math.cos(t * 0.9), color: const Color(0xFF2D3A66), size: 480),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Container(color: Colors.transparent),
            ),
          ],
        );
      },
    );
  }

  Widget _blob({required BuildContext context, required double dx, required double dy, required Color color, required double size}) {
    final s = MediaQuery.of(context).size;
    return Positioned(
      left: s.width * dx - size / 2,
      top: s.height * dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.22)),
      ),
    );
  }
}
