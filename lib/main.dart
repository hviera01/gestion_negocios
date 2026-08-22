import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/data/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/root_shell.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseClientInit.init();
  runApp(const ProviderScope(child: GestionNegociosApp()));
}

class GestionNegociosApp extends StatelessWidget {
  const GestionNegociosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GESTIÓN NEGOCIOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const _RaizAuth(),
    );
  }
}

class _RaizAuth extends ConsumerWidget {
  const _RaizAuth();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    switch (auth.estado) {
      case EstadoAuth.cargando:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case EstadoAuth.requiereConfiguracion:
      case EstadoAuth.noAutenticado:
        return const LoginScreen();
      case EstadoAuth.autenticado:
        return const RootShell();
    }
  }
}
