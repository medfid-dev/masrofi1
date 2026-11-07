import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'models.dart';
import 'store.dart';

class BoardRow {
  final String name;
  final int streak;
  final int? usedPct;
  final bool me;
  const BoardRow(this.name, this.streak, this.usedPct, this.me);
}

class Member {
  final String name;
  final int okDays;
  final bool me;
  const Member(this.name, this.okDays, this.me);
}

class MyChallenge {
  final Challenge c;
  final List<Member> members;
  const MyChallenge(this.c, this.members);
}

class Cloud {
  static bool ready = false;
  static String? lastError;

  static SupabaseClient get _c => Supabase.instance.client;
  static bool get signedIn => ready && _c.auth.currentUser != null;
  static String? get email => signedIn ? _c.auth.currentUser!.email : null;
  static String? get uid => signedIn ? _c.auth.currentUser!.id : null;

  static Future<void> init() async {
    if (!cloudConfigured || ready) return;
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      ready = true;
      if (_c.auth.currentSession == null) await _c.auth.signInAnonymously();
    } catch (e) {
      lastError = '$e';
    }
  }

  // ---------- الحساب ----------
  static Future<String?> signUp(String email, String pass) async {
    try {
      // إن كنت داخلاً كمجهول نرقّي الحساب للحفاظ على بياناتك
      if (signedIn && _c.auth.currentUser!.isAnonymous) {
        await _c.auth.updateUser(UserAttributes(email: email, password: pass));
      } else {
        await _c.auth.signUp(email: email, password: pass);
      }
      return null;
    } catch (e) {
      return '$e';
    }
  }

  static Future<String?> signIn(String email, String pass) async {
    try {
      await _c.auth.signInWithPassword(email: email, password: pass);
      return null;
    } catch (e) {
      return '$e';
    }
  }

  static Future<void> signOut() async {
    try {
      await _c.auth.signOut();
      await _c.auth.signInAnonymously();
    } catch (_) {}
  }

  // ---------- المزامنة ----------
  /// يرجع null عند النجاح أو نص الخطأ
  static Future<String?> sync(AppStore s) async {
    if (!cloudConfigured) return 'لم تُضبط بيانات Supabase في config.dart';
    await init();
    if (!signedIn) return 'تعذّر تسجيل الدخول للسحابة${lastError != null ? ': $lastError' : ''}';
    try {
      final id = uid!;
      final row = await _c.from('user_data').select().eq('user_id', id).maybeSingle();
      if (row != null && row['data'] is Map) {
        await s.mergeRemote(Map<String, dynamic>.from(row['data'] as Map));
      }
      await _c.from('user_data').upsert({
        'user_id': id,
        'data': s.toSync(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _pushProfile(s);
      await updateProgress(s);
      return null;
    } catch (e) {
      return '$e';
    }
  }

  static Future<void> _pushProfile(AppStore s) async {
    final id = uid!;
    if (s.shareBoard && s.name.isNotEmpty) {
      await _c.from('profiles').upsert({
        'user_id': id,
        'name': s.name,
        'streak': s.streak,
        'used_pct': s.usedPercent,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } else {
      await _c.from('profiles').delete().eq('user_id', id);
    }
  }

  // ---------- الترتيب العام ----------
  static Future<List<BoardRow>> leaderboard() async {
    final rows = await _c.from('profiles').select('user_id,name,streak,used_pct').order('streak', ascending: false).limit(50);
    return [
      for (final r in rows)
        BoardRow(r['name'] as String, (r['streak'] as num).toInt(), (r['used_pct'] as num?)?.toInt(), r['user_id'] == uid)
    ];
  }

  // ---------- التحديات ----------
  static String _code() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Challenge _fromRow(Map<String, dynamic> c, String joinedOn) => Challenge(
        id: c['id'] as String,
        code: c['code'] as String,
        title: c['title'] as String,
        kind: c['kind'] as String,
        cat: (c['cat'] as String?) ?? '',
        limit: ((c['limit_amount'] as num?) ?? 0).toDouble(),
        days: (c['days'] as num).toInt(),
        from: DateTime.parse(joinedOn),
      );

  static Future<String?> createChallenge(AppStore s,
      {required String title, required String kind, String cat = '', double limit = 0, required int days}) async {
    if (!signedIn) return 'غير متصل بالسحابة';
    try {
      final row = await _c
          .from('challenges')
          .insert({
            'code': _code(),
            'title': title,
            'kind': kind,
            'cat': cat,
            'limit_amount': limit,
            'days': days,
            'creator': uid,
          })
          .select()
          .single();
      await _join(s, row['id'] as String);
      return null;
    } catch (e) {
      return '$e';
    }
  }

  static Future<String?> joinByCode(AppStore s, String code) async {
    if (!signedIn) return 'غير متصل بالسحابة';
    try {
      final row = await _c.from('challenges').select().eq('code', code.trim().toUpperCase()).maybeSingle();
      if (row == null) return 'لا يوجد تحدٍّ بهذا الرمز';
      await _join(s, row['id'] as String);
      return null;
    } catch (e) {
      return '$e';
    }
  }

  static Future<void> _join(AppStore s, String challengeId) async {
    await _c.from('challenge_members').upsert({
      'challenge_id': challengeId,
      'user_id': uid,
      'name': s.name.isEmpty ? 'مستخدم' : s.name,
      'ok_days': 0,
      'joined_on': _day(DateTime.now()),
    }, onConflict: 'challenge_id,user_id', ignoreDuplicates: true);
  }

  static Future<List<MyChallenge>> myChallenges() async {
    final rows = await _c.from('challenge_members').select('joined_on, challenges(*)').eq('user_id', uid!);
    final out = <MyChallenge>[];
    for (final r in rows) {
      final cm = r['challenges'];
      if (cm is! Map) continue;
      final c = _fromRow(Map<String, dynamic>.from(cm), r['joined_on'] as String);
      final ms = await _c.from('challenge_members').select('user_id,name,ok_days').eq('challenge_id', c.id);
      final members = [
        for (final m in ms) Member(m['name'] as String, (m['ok_days'] as num).toInt(), m['user_id'] == uid)
      ]..sort((a, b) => b.okDays.compareTo(a.okDays));
      out.add(MyChallenge(c, members));
    }
    return out;
  }

  /// يحسب تقدمك محلياً ويرفعه (الأرقام فقط: عدد الأيام الناجحة، لا مبالغ)
  static Future<void> updateProgress(AppStore s) async {
    if (!signedIn) return;
    final mine = await myChallenges();
    for (final m in mine) {
      final ok = challengeOkDays(m.c, s.txs, DateTime.now());
      await _c
          .from('challenge_members')
          .update({'ok_days': ok, 'name': s.name.isEmpty ? 'مستخدم' : s.name})
          .eq('challenge_id', m.c.id)
          .eq('user_id', uid!);
    }
  }
}
