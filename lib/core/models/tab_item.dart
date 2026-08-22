import 'package:flutter/widgets.dart';

import 'seccion.dart';

class TabAbierta {
  final String id;
  final Seccion seccion;
  final Widget contenido;

  const TabAbierta({required this.id, required this.seccion, required this.contenido});
}
