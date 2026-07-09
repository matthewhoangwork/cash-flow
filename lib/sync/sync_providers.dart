import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// Overridden in main() with the box opened before runApp().
final pendingDeletesBoxProvider = Provider<Box<Map>>((ref) {
  throw UnimplementedError('pendingDeletesBoxProvider must be overridden in main()');
});
