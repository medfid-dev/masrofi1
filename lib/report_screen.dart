import 'package:flutter/material.dart';
import 'store.dart';
import 'widgets.dart';
import 'quick_add.dart';

class ReportScreen extends StatefulWidget {
  final AppStore store;
  const ReportScreen({super.key, required this.store});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int period = 2; // 0 يوم، 1 أسبوع، 2 شهر

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final cs = Theme.of(context).colorScheme;
    final days = [1, 7, 30][period];
    final from = DateTime.now().subtract(Duration(days: days));
    final by = <String, double>{};
    var total = 0.0;
    for (final t in s.txs.where((t) => !t.income && t.at.isAfter(from))) {
      by[t.cat] = (by[t.cat] ?? 0) + t.amount;
      total += t.amount;
    }
    final cats = by.keys.toList()..sort((a, b) => by[b]!.compareTo(by[a]!));

    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('اليوم')),
              ButtonSegment(value: 1, label: Text('الأسبوع')),
              ButtonSegment(value: 2, label: Text('الشهر')),
            ],
            selected: {period},
            onSelectionChanged: (v) => setState(() => period = v.first),
          ),
          const SizedBox(height: 12),
          Sheet(title: 'إجمالي الإنفاق', children: [
            Text(fm(total), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: cs.error)),
            const SizedBox(height: 8),
            if (cats.isEmpty) const Text('لا توجد مصاريف في هذه الفترة.'),
            for (final c in cats)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('$c — ${(by[c]! / total * 100).round()}%'),
                    Text(fm(by[c]!), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: by[c]! / total, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                ]),
              ),
          ]),
          Sheet(title: 'مؤشر الندم هذا الشهر', children: [
            Text('${s.regretPercent.round()}%',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: cs.error)),
            Text('ندمت على ${fm(s.regretAmount)} من إنفاقك'
                '${s.topRegretCat != null ? '، وأكثرها في «${s.topRegretCat}»' : ''}.'),
          ]),
          if (s.placeStats.isNotEmpty)
            Sheet(title: 'أكثر الأماكن إنفاقاً', children: [
              for (final (i, p) in s.placeStats.take(5).indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(fm(p.total)),
                  subtitle: Text('${p.count} عملية — غالباً «${p.topCat}»'),
                ),
            ]),
          Sheet(title: 'كل العمليات', children: [
            if (s.txs.isEmpty) const Text('لا توجد عمليات.'),
            for (final t in s.txs) TxTile(t: t, onDelete: () {
              s.remove(t.id);
              cancelRegret(t.id);
            }),
          ]),
        ],
      ),
    );
  }
}
