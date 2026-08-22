import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/sistema_cliente_model.dart';
import '../../providers/sistemas_provider.dart';
import '../widgets/nuevo_sistema_dialog.dart';
import '../widgets/sistema_cliente_form_dialog.dart';

final _moneda = NumberFormat.currency(locale: 'en_US', symbol: 'L.');

class SistemasScreen extends ConsumerWidget {
  const SistemasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendidosAsync = ref.watch(sistemasClienteProvider(null));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final creado = await showDialog<bool>(context: context, builder: (_) => const SistemaClienteFormDialog());
          if (creado == true) ref.invalidate(sistemasClienteProvider(null));
        },
        icon: const Icon(Icons.add),
        label: const Text('VENDER SISTEMA'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                const Text('CATÁLOGO', style: TextStyle(color: AppColors.textoTerciario, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await showDialog<bool>(context: context, builder: (_) => const NuevoSistemaDialog());
                  },
                  icon: const Icon(Icons.add_business_rounded, size: 16),
                  label: const Text('NUEVO SISTEMA', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.acento),
                ),
              ],
            ),
          ),
          Expanded(child: _ListaVendidos(vendidosAsync: vendidosAsync)),
        ],
      ),
    );
  }
}

class _ListaVendidos extends StatelessWidget {
  final AsyncValue<List<SistemaClienteModel>> vendidosAsync;
  const _ListaVendidos({required this.vendidosAsync});

  @override
  Widget build(BuildContext context) {
    return vendidosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
        data: (lista) {
          if (lista.isEmpty) {
            return const Center(child: Text('SIN SISTEMAS VENDIDOS AÚN', style: TextStyle(color: AppColors.textoSecundario)));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: lista.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final sc = lista[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(sc.sistemaNombre.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                          _ChipVersion(slug: sc.sistemaSlug),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${sc.tipoVenta == 'contado' ? 'CONTADO' : 'MENSUALIDADES'} · ${_moneda.format(sc.montoTotal)}'
                        '${sc.numeroCuotas != null ? ' · ${sc.numeroCuotas} CUOTAS' : ''}',
                        style: const TextStyle(color: AppColors.textoSecundario, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
  }
}

class _ChipVersion extends ConsumerWidget {
  final String slug;
  const _ChipVersion({required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogoAsync = ref.watch(catalogoSistemasProvider);
    return catalogoAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (catalogo) {
        final coincidencias = catalogo.where((s) => s.slug == slug);
        if (coincidencias.isEmpty) return const SizedBox.shrink();
        final sistema = coincidencias.first;
        final versionAsync = ref.watch(versionSistemaProvider(sistema));
        return versionAsync.when(
          loading: () => const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, _) => const SizedBox.shrink(),
          data: (version) => version == null
              ? const SizedBox.shrink()
              : Chip(label: Text(version), backgroundColor: AppColors.acento.withValues(alpha: 0.15)),
        );
      },
    );
  }
}
