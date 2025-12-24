import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

class SupabaseApiService implements IApiService {
  final SupabaseClient _client;

  SupabaseApiService(this._client);

  @override
  Future<Map<String, dynamic>> push(String collection, Map<String, dynamic> data) async {
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('localId'); 

    // Map 'serverId' -> 'id' for Supabase
    if (cleanData.containsKey('serverId')) {
      final sId = cleanData['serverId'];
      cleanData.remove('serverId');
      if (sId != null) {
        cleanData['id'] = sId;
      }
    }

    final response = await _client.from(collection).upsert(cleanData).select().single();
    return response;
  }

  @override
  Future<void> delete(String collection, String id) async {
    await _client.from(collection).delete().eq('id', id);
  }

  @override
  Future<List<Map<String, dynamic>>> pull(String collection, DateTime? since) async {
    var query = _client.from(collection).select();
    
    if (since != null) {
      query = query.gt('updated_at', since.toIso8601String());
    }
    
    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }
}
