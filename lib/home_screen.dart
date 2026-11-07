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
    final streakText = s.totalBudget > 0 ? 'سلسلة الالتزام: ${s.streak} يوم 🔥' : 'حدّد ميزانية لتبدأ سلسلة الالتزام';

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
        padding: const EdgeInsets.all(16),
        children: [
          Sheet(children: [
            Center(child: Text('${s.treeEmoji}${s.treeBadge}', style: const TextStyle(fontSize: 56))),
            Center(child: Text(s.treeMsg)),
            const SizedBox(height: 6),
            Center(child: Text(s.hi, style: const TextStyle(fontWeight: FontWeight.bold))),
            Center(child: Text(streakText, style: TextStyle(color: cs.outline))),
          ]),
          Sheet(children: [
            Text('الرصيد الحالي', style: TextStyle(color: cs.outline)),
            Text(fm(bal),
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: bal < 0 ? cs.error : null)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _stat('الدخل', fm(s.totalIncome), Colors.green.shade700)),
              const SizedBox(width: 8),
              Expanded(child: _stat('مصاريف الشهر', fm(s.monthSpent), cs.error)),
            ]),
          ]),
          for (final a in s.alerts)
            Card(
              color: cs.errorContainer,
              child: ListTile(leading: const Icon(Icons.warning_amber_rounded), title: Text(a)),
            ),
          if (s.detected.isNotEmpty)
            Sheet(title: 'عمليات اكتُشفت من إشعاراتك', children: [
              for (final d in s.detected)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${d.income ? '+' : '−'}${fm(d.amount)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(d.note, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'تسجيل',
                      icon: const Icon(Icons.check_circle_outline),
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
          if (s.pendingRegrets.isNotEmpty)
            Sheet(title: 'مؤشر الندم', children: [
              for (final t in s.pendingRegrets)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('هل أنت نادم على «${t.note.isEmpty ? t.cat : t.note}»؟'),
                  subtitle: Text(fm(t.amount)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton(onPressed: () {
                      s.markRegret(t.id, true);
                      cancelRegret(t.id);
                    }, child: const Text('نادم 😞')),
                    TextButton(onPressed: () {
                      s.markRegret(t.id, false);
                      cancelRegret(t.id);
                    }, child: const Text('لا 😊')),
                  ]),
                ),
            ]),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PanicScreen(store: s))),
              icon: const Icon(Icons.emergency_outlined),
              label: const Text('زر الطوارئ المالي'),
            ),
          ),
          Sheet(title: 'آخر العمليات', children: [
            if (s.txs.isEmpty) const Text('لم تسجّل أي عملية بعد.'),
            for (final t in s.txs.take(8)) TxTile(t: t),
          ]),
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
          content: DropdownButton<String>(
            value: cat,
            isExpanded: true,
            items: [for (final c in options) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setS(() => cat = v ?? cat),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسجيل')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final t = await store.acceptDetected(d, cat);
      if (t != null) scheduleRegret(t);
    }
  }

  Widget _stat(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ]),
      );
}
