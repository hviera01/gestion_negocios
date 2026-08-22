import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/seccion.dart';
import '../models/tab_item.dart';
import '../widgets/seccion_body.dart';

class TabsState {
  final List<TabAbierta> abiertas;
  final String activaId;

  const TabsState({required this.abiertas, required this.activaId});
}

/// Pestañas abribles/cerrables tipo navegador, igual que en variedades_lopsi.
/// El Dashboard siempre queda como pestaña inicial; el resto se abre desde el menú.
class TabsNotifier extends Notifier<TabsState> {
  @override
  TabsState build() {
    final inicial = _tabParaSeccion(Seccion.dashboard);
    return TabsState(abiertas: [inicial], activaId: inicial.id);
  }

  TabAbierta _tabParaSeccion(Seccion s) => TabAbierta(id: s.name, seccion: s, contenido: construirBodySeccion(s));

  void abrir(Seccion s) {
    final existe = state.abiertas.any((t) => t.id == s.name);
    if (existe) {
      state = TabsState(abiertas: state.abiertas, activaId: s.name);
    } else {
      state = TabsState(abiertas: [...state.abiertas, _tabParaSeccion(s)], activaId: s.name);
    }
  }

  void activar(String id) => state = TabsState(abiertas: state.abiertas, activaId: id);

  void cerrar(String id) {
    final restantes = state.abiertas.where((t) => t.id != id).toList();
    if (restantes.isEmpty) {
      final dash = _tabParaSeccion(Seccion.dashboard);
      state = TabsState(abiertas: [dash], activaId: dash.id);
      return;
    }
    final nuevaActiva = state.activaId == id ? restantes.last.id : state.activaId;
    state = TabsState(abiertas: restantes, activaId: nuevaActiva);
  }
}

final tabsProvider = NotifierProvider<TabsNotifier, TabsState>(TabsNotifier.new);
