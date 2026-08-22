import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import 'app_shell.dart';
import 'mobile_shell.dart';

class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    return esEscritorio(context) ? const AppShell() : const MobileShell();
  }
}
