import '../../../core/data/rpc_client.dart';
import 'cobro_model.dart';

String _fechaSql(DateTime f) => DateTime(f.year, f.month, f.day).toIso8601String().split('T').first;

class CobrosRepository {
  Future<List<CobroModel>> listar() async {
    final res = await RpcClient.call('listar_cobros');
    return (res as List).map((e) => CobroModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> registrarPago(
    CobroModel cobro, {
    required double monto,
    String? metodoPago,
    String? numeroRecibo,
    required DateTime fecha,
  }) {
    if (cobro.esSuscripcion) {
      return RpcClient.call('registrar_pago_suscripcion', {
        'p_sistema_cliente_id': cobro.referenciaId,
        'p_monto': monto,
        'p_metodo_pago': metodoPago,
        'p_numero_recibo': numeroRecibo,
        'p_fecha': fecha.toIso8601String(),
      });
    }
    return RpcClient.call('registrar_abono', {
      'p_credito_id': cobro.creditoId,
      'p_monto_abonado': monto,
      'p_interes': 0,
      'p_metodo_pago': metodoPago,
      'p_numero_recibo': numeroRecibo,
      'p_fecha': fecha.toIso8601String(),
    });
  }

  Future<void> cambiarFecha(CobroModel cobro, DateTime fecha, {bool moverSiguientes = true}) {
    if (cobro.esSuscripcion) {
      return RpcClient.call('cambiar_fecha_cobro_suscripcion', {
        'p_sistema_cliente_id': cobro.referenciaId,
        'p_fecha': _fechaSql(fecha),
      });
    }
    return RpcClient.call('cambiar_fecha_cuota', {
      'p_cuota_id': cobro.referenciaId,
      'p_fecha': _fechaSql(fecha),
      'p_mover_siguientes': moverSiguientes,
    });
  }
}
