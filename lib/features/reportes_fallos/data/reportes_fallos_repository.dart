import '../../../core/data/rpc_client.dart';
import 'reporte_fallo_model.dart';

class ReportesFallosRepository {
  Future<List<ReporteFalloModel>> listar({String? estado}) async {
    final res = await RpcClient.call('listar_reportes_fallos', {'p_estado': estado});
    return (res as List).map((e) => ReporteFalloModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> crear({required String clienteId, String? sistemaClienteId, required String descripcion}) {
    return RpcClient.call('crear_reporte_fallo', {
      'p_cliente_id': clienteId,
      'p_sistema_cliente_id': sistemaClienteId,
      'p_descripcion': descripcion,
    });
  }

  Future<void> actualizar({
    required String id,
    String? estado,
    bool? cobrado,
    double? montoCobrado,
  }) {
    return RpcClient.call('actualizar_reporte_fallo', {
      'p_id': id,
      'p_estado': estado,
      'p_cobrado': cobrado,
      'p_monto_cobrado': montoCobrado,
    });
  }

  Future<void> convertirEnTrabajo({required String reporteId, required double monto, bool esCredito = false}) {
    return RpcClient.call('convertir_reporte_en_trabajo', {
      'p_reporte_id': reporteId,
      'p_monto': monto,
      'p_es_credito': esCredito,
    });
  }
}
