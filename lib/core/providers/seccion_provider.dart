import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/seccion.dart';

final seccionActivaProvider = NotifierProvider<SeccionActivaNotifier, Seccion>(SeccionActivaNotifier.new);

class SeccionActivaNotifier extends Notifier<Seccion> {
  @override
  Seccion build() => Seccion.dashboard;

  void seleccionar(Seccion s) => state = s;
}
