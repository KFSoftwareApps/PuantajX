import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String _url = 'https://zfptxccotqqehgkpysbq.supabase.co';
  static const String _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmcHR4Y2NvdHFxZWhna3B5c2JxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxNjY0NTQsImV4cCI6MjA4MDc0MjQ1NH0.rkxEevYTqtZdjOwueqeqHGj2zxUw6PddHiDsqHY4iDg';

  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  Future<void> init() async {
    await Supabase.initialize(
      url: _url,
      anonKey: _anonKey,
    );
  }

  SupabaseClient get client => Supabase.instance.client;
}
