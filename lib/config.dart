// ضع هنا بيانات مشروع Supabase (Project Settings ← API).
// مفتاح anon مصمَّم ليكون علنياً؛ الحماية تأتي من سياسات RLS في ملف supabase/schema.sql.
const String supabaseUrl = '';
const String supabaseAnonKey = '';

bool get cloudConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
