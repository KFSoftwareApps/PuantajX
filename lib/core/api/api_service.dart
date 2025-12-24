import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_api_service.dart';

abstract class IApiService {
  Future<Map<String, dynamic>> push(String collection, Map<String, dynamic> data);
  Future<void> delete(String collection, String id);
  Future<List<Map<String, dynamic>>> pull(String collection, DateTime? since);
}

final apiServiceProvider = Provider<IApiService>((ref) {
  return SupabaseApiService(Supabase.instance.client);
});
