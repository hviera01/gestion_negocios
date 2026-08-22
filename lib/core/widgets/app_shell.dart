import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../constants/app_colors.dart';
import '../models/seccion.dart';
import '../providers/tabs_provider.dart';

/// Shell de escritorio: barra de pestañas abribles/cerrables tipo navegador,
/// igual que en variedades_lopsi — se abren desde el menú y se cierran con la X.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(tabsProvider);

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppColors.fondoElevado,
              border: Border(bottom: BorderSide(color: AppColors.borde)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      const Icon(Icons.workspaces_rounded, color: AppColors.acento, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'GESTIÓN NEGOCIOS',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1),
                      ),
                      const SizedBox(width: 16),
                      _MenuAbrirSeccion(tabsAbiertas: tabs.abiertas.map((t) => t.id).toSet()),
                      const Spacer(),
                      IconButton(
                        onPressed: () => ref.read(authProvider.notifier).cerrarSesion(),
                        icon: const Icon(Icons.logout_rounded, color: AppColors.textoSecundario, size: 20),
                        tooltip: 'Cerrar sesión',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: tabs.abiertas.map((t) => _Pestana(id: t.id, seccion: t.seccion, activa: t.id == tabs.activaId)).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: tabs.abiertas.indexWhere((t) => t.id == tabs.activaId).clamp(0, tabs.abiertas.length - 1),
              children: tabs.abiertas.map((t) => t.contenido).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuAbrirSeccion extends ConsumerWidget {
  final Set<String> tabsAbiertas;
  const _MenuAbrirSeccion({required this.tabsAbiertas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<Seccion>(
      tooltip: 'Abrir sección',
      color: AppColors.superficieAlta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (s) => ref.read(tabsProvider.notifier).abrir(s),
      itemBuilder: (context) => Seccion.values
          .map((s) => PopupMenuItem(
                value: s,
                child: Row(
                  children: [
                    Icon(s.icono, size: 16, color: AppColors.textoSecundario),
                    const SizedBox(width: 10),
                    Text(s.label, style: const TextStyle(fontSize: 13)),
                    if (tabsAbiertas.contains(s.name)) ...[
                      const Spacer(),
                      const Icon(Icons.check, size: 14, color: AppColors.acento),
                    ],
                  ],
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.superficieAlta,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 15, color: AppColors.textoSecundario),
            SizedBox(width: 4),
            Text('ABRIR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textoSecundario)),
          ],
        ),
      ),
    );
  }
}

class _Pestana extends ConsumerWidget {
  final String id;
  final Seccion seccion;
  final bool activa;
  const _Pestana({required this.id, required this.seccion, required this.activa});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => ref.read(tabsProvider.notifier).activar(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.only(left: 14, right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: activa ? AppColors.superficie : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: activa ? AppColors.acento.withValues(alpha: 0.4) : Colors.transparent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(seccion.icono, size: 14, color: activa ? AppColors.acento : AppColors.textoSecundario),
                const SizedBox(width: 8),
                Text(
                  seccion.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: activa ? AppColors.acento : AppColors.textoSecundario,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => ref.read(tabsProvider.notifier).cerrar(id),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(Icons.close_rounded, size: 13, color: AppColors.textoTerciario),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
