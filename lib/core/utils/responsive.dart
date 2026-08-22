import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

bool esEscritorio(BuildContext context) => MediaQuery.of(context).size.width >= 900;

bool esEscritorioWeb(BuildContext context) => kIsWeb && esEscritorio(context);
