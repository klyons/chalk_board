class SupabaseConfig {
  /// Enter your Supabase Project URL here:
  /// Found in Supabase Dashboard -> Project Settings -> API -> Project URL
  /// Example: 'https://abcdefghijklm.supabase.co'
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT_ID.supabase.co',
  );

  /// Enter your Supabase Anon (Public) Key here:
  /// Found in Supabase Dashboard -> Project Settings -> API -> Project API Keys -> `anon` / `public`
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl != 'https://YOUR_PROJECT_ID.supabase.co' &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;
}
