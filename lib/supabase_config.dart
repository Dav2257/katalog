import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Ganti dengan Project URL dari dashboard Supabase Anda
  // (Buka Dashboard Supabase -> Project Settings -> API -> Project URL)
  static const String supabaseUrl = 'https://yakrixngwazvoriwuzoe.supabase.co';

  // Ganti dengan Project API anon/public key dari dashboard Supabase Anda
  // (Buka Dashboard Supabase -> Project Settings -> API -> Project API keys -> anon/public)
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlha3JpeG5nd2F6dm9yaXd1em9lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5MDM3MzMsImV4cCI6MjEwNDQ3OTczM30.8hLICjab92RWriaPJeut35GbtVglkcF5ge2EG-TFbbo';
}

/// Instance global SupabaseClient agar mudah diakses di seluruh aplikasi:
/// Contoh:
/// final data = await supabase.from('produk').select();
final supabase = Supabase.instance.client;
