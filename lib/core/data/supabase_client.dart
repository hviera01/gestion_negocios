import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_config.dart';

class SupabaseClientInit {
  static Future<void> init() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }
}

SupabaseClient get supabase => Supabase.instance.client;
