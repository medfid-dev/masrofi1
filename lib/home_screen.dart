import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';
import 'panic_screen.dart';
import 'settings_screen.dart';
import 'quick_add.dart';

class HomeScreen extends StatelessWidget {
  final AppStore store;
  const HomeScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final cs = Theme.of(context).colorScheme;
    final bal = s.balance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مصروفي'),
        actions: [
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(store: s))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // ---- بطاقة الرصيد ----
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, .55)!],
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('رصيدك الحالي', style: TextStyle(color: cs.onPrimary.withOpacity(.8))),
              const SizedBox(height: 4),
              Text(fm(bal), style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: cs.onPrimary)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _pill('دخل', fm(s.totalIncome), Icons.south_west, cs)),
                const SizedBox(width: 10),
                Expanded(child: _pill('مصروف الشهر', fm(s.monthSpent), Icons.north_east, cs)),
              ]),
            ]),
          ),
          const SizedBox(height: 14),

          // ---- الشجرة والسلسلة بسطر واحد ----
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: [
                Text('${s.treeEmoji}${s.treeBadge}', style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.treeMsg, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      s.totalBudget > 0 ? 'التزام ${s.streak} يوم 🔥' : 'حدّد ميزانية لتبدأ سلسلة الالتزام',
                      style: TextStyle(color: cs.outline, fontSize: 13),
                    ),
                  ]),
                ),
              ]),
            ),
          ),

          // ---- تنبيهات الميزانية ----
          for (final a in s.alerts)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Card(
                color: cs.errorContainer,
                child: ListTile(
                  leading: Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
                  title: Text(a, style: TextStyle(color: cs.onErrorContainer)),
                ),
              ),
            ),

          // ---- عمليات مكتشفة من الإشعارات ----
          if (s.detected.isNotEmpty) ...[
            const SizedBox(height: 14),
            Sheet(title: 'اكتُشفت من إشعاراتك', children: [
              for (final d in s.detected)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${d.income ? '+' : '−'}${fm(d.amount)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(d.note, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton.filledTonal(
                      tooltip: 'تسجيل',
                      icon: const Icon(Icons.check),
                      onPressed: () => _accept(context, d),
                    ),
                    IconButton(
                      tooltip: 'تجاهل',
                      icon: const Icon(Icons.close),
                      onPressed: () => s.dismissDetected(d.id),
                    ),
                  ]),
                ),
            ]),
          ],

          // ---- مؤشر الندم ----
          if (s.pendingRegrets.isNotEmpty) ...[
            const SizedBox(height: 14),
            Sheet(title: 'هل ندمت على هذه؟', children: [
              for (final t in s.pendingRegrets)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.note.isEmpty ? t.cat : t.note),
                  subtitle: Text(fm(t.amount)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton.filledTonal(
                      tooltip: 'نادم',
                      icon: const Text('😞', style: TextStyle(fontSize: 20)),
                      onPressed: () {
                        s.markRegret(t.id, true);
                        cancelRegret(t.id);
                      },
                    ),
                    IconButton.filledTonal(
                      tooltip: 'لا',
                      icon: const Text('😊', style: TextStyle(fontSize: 20)),
                      onPressed: () {
                        s.markRegret(t.id, false);
                        cancelRegret(t.id);
                      },
                    ),
                  ]),
                ),
            ]),
          ],

          // ---- آخر العمليات ----
          const SizedBox(height: 14),
          Sheet(title: 'آخر العمليات', children: [
            if (s.txs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text('لا عمليات بعد.\nاضغط «إضافة» في الأسفل لتسجّل أول مصروف.',
                      textAlign: TextAlign.center, style: TextStyle(color: cs.outline)),
                ),
              ),
            for (final t in s.txs.take(5)) TxTile(t: t),
          ]),

          // ---- الطوارئ: خيار هادئ في الأسفل ----
          const SizedBox(height: 4),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: cs.error),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PanicScreen(store: s))),
            icon: const Icon(Icons.emergency_outlined),
            label: const Text('وصلت للحد؟ زر الطوارئ المالي'),
          ),
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext context, Detected d) async {
    var cat = d.income ? AppStore.incomeCats.first : 'أخرى';
    final options = d.income ? AppStore.incomeCats : store.cats;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('${d.income ? '+' : '−'}${fm(d.amount)}'),
          content: Wrap(spacing: 8, runSpacing: 4, children: [
            for (final c in options)
              ChoiceChip(
                label: Text('${catEmoji(c)} $c'),
                selected: cat == c,
                onSelected: (_) => setS(() => cat = c),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تسجيل'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final t = await store.acceptDetected(d, cat);
      if (t != null) scheduleRegret(t);
    }
  }

  Widget _pill(String label, String value, IconData icon, ColorScheme cs) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: cs.onPrimary.withOpacity(.16), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(icon, size: 18, color: cs.onPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 11, color: cs.onPrimary.withOpacity(.8))),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: cs.onPrimary)),
              ),
            ]),
          ),
        ]),
      );
}
