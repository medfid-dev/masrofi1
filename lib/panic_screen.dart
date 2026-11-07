import 'package:flutter/material.dart';
import 'store.dart';
import 'widgets.dart';

class PanicScreen extends StatelessWidget {
  final AppStore store;
  const PanicScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final cs = Theme.of(context).colorScheme;
    final tip = s.panicTip;
    final rem = s.remaining;

    return Scaffold(
      appBar: AppBar(title: const Text('زر الطوارئ المالي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Sheet(title: 'المتبقي من الميزانية', children: [
            Text(fm(rem), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: rem < 0 ? cs.error : null)),
            const SizedBox(height: 6),
            Text('الأيام المتبقية: ${s.daysLeft}'),
            Text('الحد اليومي الجديد: ${fm(s.dailyLimit)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (s.totalBudget <= 0 && s.monthlyIncome <= 0)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('أدخل دخلك الشهري أو ميزانياتك في تبويب الميزانية لتظهر أرقام دقيقة.'),
              ),
          ]),
          Sheet(title: 'نصائح إنقاذ عاجلة', children: [
            if (tip != null)
              Text('قلّل «${tip.key}» بنسبة 15% في الأيام الـ ${s.daysLeft} القادمة لتوفّر نحو ${fm(tip.value)}.'),
            const SizedBox(height: 8),
            const Text('• أوقف الإنفاق على الترفيه والتسوق حتى نهاية الشهر.'),
            const Text('• راجع اشتراكاتك وألغِ ما لا تستخدمه.'),
            const Text('• اطبخ في البيت وأجّل أي شراء غير ضروري 24 ساعة.'),
          ]),
        ],
      ),
    );
  }
}
