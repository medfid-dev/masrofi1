import 'package:flutter/material.dart';
import 'cloud.dart';
import 'config.dart';
import 'store.dart';
import 'widgets.dart';

class CommunityScreen extends StatefulWidget {
  final AppStore store;
  const CommunityScreen({super.key, required this.store});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  Future<_Data>? _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  Future<_Data> _load() async {
    if (!cloudConfigured) return _Data(error: 'لم تُضبط بيانات Supabase في config.dart');
    await Cloud.init();
    if (!Cloud.signedIn) return _Data(error: 'تعذّر الاتصال بالسحابة. تحقق من الإنترنت وتفعيل الدخول المجهول.');
    try {
      final err = await Cloud.sync(widget.store); // يحدّث ملفك وتقدّمك أولاً
      final board = await Cloud.leaderboard();
      final mine = await Cloud.myChallenges();
      return _Data(board: board, mine: mine, error: err);
    } catch (e) {
      return _Data(error: '$e');
    }
  }

  void _reload() => setState(() => _f = _load());

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _join() async {
    final ctl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الانضمام لتحدٍّ'),
        content: TextField(controller: ctl, autofocus: true, decoration: const InputDecoration(hintText: 'رمز التحدي (6 أحرف)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('انضمام')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    final err = await Cloud.joinByCode(widget.store, code);
    if (!mounted) return;
    if (err != null) _msg(err);
    _reload();
  }

  Future<void> _create() async {
    final title = TextEditingController();
    final limit = TextEditingController();
    var kind = 'no_spend';
    var cat = widget.store.cats.first;
    var days = 7;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('تحدٍّ جديد'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'اسم التحدي، مثال: أسبوع بلا قهوة')),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: kind,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'no_spend', child: Text('يوم بلا أي مصروف')),
                  DropdownMenuItem(value: 'no_cat', child: Text('بلا إنفاق على فئة')),
                  DropdownMenuItem(value: 'limit', child: Text('سقف يومي')),
                ],
                onChanged: (v) => setS(() => kind = v ?? kind),
              ),
              if (kind == 'no_cat')
                DropdownButton<String>(
                  value: cat,
                  isExpanded: true,
                  items: [for (final c in widget.store.cats) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (v) => setS(() => cat = v ?? cat),
                ),
              if (kind == 'limit')
                TextField(
                  controller: limit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'السقف اليومي', suffixText: 'د.ج'),
                ),
              DropdownButton<int>(
                value: days,
                isExpanded: true,
                items: [for (final d in [3, 7, 14, 30]) DropdownMenuItem(value: d, child: Text('$d أيام'))],
                onChanged: (v) => setS(() => days = v ?? days),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final lim = double.tryParse(limit.text) ?? 0;
    if (kind == 'limit' && lim <= 0) {
      _msg('أدخل سقفاً صحيحاً');
      return;
    }
    final name = title.text.trim().isEmpty ? 'تحدٍّ جديد' : title.text.trim();
    final err = await Cloud.createChallenge(widget.store, title: name, kind: kind, cat: kind == 'no_cat' ? cat : '', limit: lim, days: days);
    if (!mounted) return;
    if (err != null) _msg(err);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المجتمع'),
          actions: [IconButton(tooltip: 'تحديث', icon: const Icon(Icons.refresh), onPressed: _reload)],
          bottom: const TabBar(tabs: [Tab(text: 'الترتيب العام'), Tab(text: 'تحدياتي')]),
        ),
        body: FutureBuilder<_Data>(
          future: _f,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final d = snap.data ?? _Data(error: 'خطأ غير متوقع');
            if (d.board == null) {
              return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(d.error ?? '', textAlign: TextAlign.center)));
            }
            return TabBarView(children: [
              ListView(padding: const EdgeInsets.all(16), children: [
                if (!s.shareBoard || s.name.isEmpty)
                  const Sheet(children: [
                    Text('للظهور في الترتيب: من الإعدادات اختر اسماً وفعّل «المشاركة في الترتيب العام». يُنشر اسمك وأيام التزامك ونسبة استهلاك ميزانيتك فقط، لا مبالغ ولا عمليات.'),
                  ]),
                Sheet(title: 'الأكثر التزاماً', children: [
                  if (d.board!.isEmpty) const Text('لا أحد في الترتيب بعد.'),
                  for (final (i, r) in d.board!.indexed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(r.name + (r.me ? ' (أنت)' : ''), style: TextStyle(fontWeight: r.me ? FontWeight.bold : null)),
                      subtitle: r.usedPct == null ? null : Text('استهلك ${r.usedPct}% من ميزانيته'),
                      trailing: Text('${r.streak} يوم 🔥'),
                    ),
                ]),
              ]),
              ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  Expanded(child: FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('تحدٍّ جديد'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: _join, icon: const Icon(Icons.group_add_outlined), label: const Text('انضمام برمز'))),
                ]),
                const SizedBox(height: 12),
                if (d.mine!.isEmpty) const Text('لا تشارك في أي تحدٍّ. أنشئ واحداً وشارك رمزه مع أصدقائك.'),
                for (final m in d.mine!)
                  Sheet(title: m.c.title, children: [
                    Text('${m.c.rule} — ${m.c.days} أيام'),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Text('الرمز: '),
                      SelectableText(m.c.code, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ]),
                    const Divider(),
                    for (final (i, mem) in m.members.indexed)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Text('${i + 1}'),
                        title: Text(mem.name + (mem.me ? ' (أنت)' : '')),
                        trailing: Text('${mem.okDays}/${m.c.days} ✓'),
                      ),
                  ]),
              ]),
            ]);
          },
        ),
      ),
    );
  }
}

class _Data {
  final List<BoardRow>? board;
  final List<MyChallenge>? mine;
  final String? error;
  _Data({this.board, this.mine, this.error});
}
