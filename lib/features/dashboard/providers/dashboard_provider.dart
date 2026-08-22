import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/rpc_client.dart';

final resumenDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await RpcClient.call('resumen_dashboard');
  return res as Map<String, dynamic>;
});
