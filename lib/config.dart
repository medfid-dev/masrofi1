// ضع هنا بيانات مشروع Supabase (Project Settings ← API).
// مفتاح anon مصمَّم ليكون علنياً؛ الحماية تأتي من سياسات RLS في ملف supabase/schema.sql.
const String supabaseUrl = 'https://uhlktsguzjiebpqvvqal.supabase.co';
const String supabaseAnonKey = 'sb_publishable_rBAA93t-arOynsM4vP4XAw_W-5BjEjL';

bool get cloudConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

// مستودع GitHub الذي تُنشر فيه النسخ (يجب أن يكون عاماً لتعمل التحديثات من داخل التطبيق)
const String updateRepo = 'medfid-dev/masrofi1';
const int buildNumber = int.fromEnvironment('BUILD', defaultValue: 0);
