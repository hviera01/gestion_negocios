import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../constants/app_colors.dart';
import '../models/seccion.dart';
import '../providers/seccion_provider.dart';
import 'seccion_body.dart';

/// Shell móvil: chrome fijo (app bar + selector de secciones tipo píldora),
/// sin scroll de navegación — solo el contenido de la sección hace scroll.
class MobileShell extends ConsumerWidget {
  const MobileShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activa = ref.watch(seccionActivaProvider);

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Text(activa.label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => ref.read(authProvider.notifier).cerrarSesion(),
                    icon: const Icon(Icons.lock_outline_rounded, color: AppColors.textoSecundario),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: Seccion.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final s = Seccion.values[i];
                  final activaEsta = s == activa;
                  return GestureDetector(
                    onTap: () => ref.read(seccionActivaProvider.notifier).seleccionar(s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: activaEsta ? AppColors.acento : AppColors.superficieAlta,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        children: [
                          Icon(s.icono, size: 15, color: activaEsta ? const Color(0xFF00201C) : AppColors.textoSecundario),
                          const SizedBox(width: 6),
                          Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: activaEsta ? const Color(0xFF00201C) : AppColors.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(key: ValueKey(activa), child: construirBodySeccion(activa)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
