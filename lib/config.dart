const String supabaseUrl = 'https://uhlktsguzjiebpqvvqal.supabase.co';
const String supabaseAnonKey = 'sb_publishable_rBAA93t-arOynsM4vP4XAw_W-5BjEjL';

bool get cloudConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
