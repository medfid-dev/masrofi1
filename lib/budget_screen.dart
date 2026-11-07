import 'package:flutter/material.dart';
import 'store.dart';
import 'widgets.dart';

class BudgetScreen extends StatelessWidget {
  final AppStore store;
  const BudgetScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final by = s.spentByCat;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('الميزانية الشهرية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Sheet(children: [
            TextFormField(
              key: const ValueKey('income'),
              initialValue: s.monthlyIncome > 0 ? s.monthlyIncome.round().toString() : '',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'دخلي الشهري (لحساب ساعة العمل)',
                suffixText: 'د.ج',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => s.setIncome(double.tryParse(v) ?? 0),
            ),
          ]),
          for (final c in s.cats)
            Builder(builder: (_) {
              final spent = by[c] ?? 0;
              final lim = s.budgets[c] ?? 0;
              return Sheet(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(c, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(lim > 0 ? '${fm(spent)} / ${fm(lim)}' : fm(spent)),
                ]),
                if (lim > 0) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: (spent / lim).clamp(0.0, 1.0).toDouble(),
                    color: spent > lim ? cs.error : null,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  key: ValueKey('b_$c'),
                  initialValue: lim > 0 ? lim.round().toString() : '',
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'سقف $c', suffixText: 'د.ج', border: const OutlineInputBorder()),
                  onChanged: (v) => s.setBudget(c, double.tryParse(v) ?? 0),
                ),
              ]);
            }),
          const Text('تظهر تنبيهات في الرئيسية عند بلوغ 80% من السقف.'),
        ],
      ),
    );
  }
}
