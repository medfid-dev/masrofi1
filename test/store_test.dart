import 'package:flutter_test/flutter_test.dart';
import 'package:masrofi/models.dart';
import 'package:masrofi/store.dart';

Tx tx(String id, bool income, double amount, String cat, {DateTime? at}) =>
    Tx(id: id, income: income, amount: amount, cat: cat, at: at ?? DateTime.now());

void main() {
  test('الرصيد ومصاريف الشهر', () {
    final s = AppStore();
    s.add(tx('1', true, 100000, 'راتب'));
    s.add(tx('2', false, 2500, 'طعام'));
    expect(s.balance, 97500);
    expect(s.monthSpent, 2500);
  });

  test('نسبة الندم', () {
    final s = AppStore();
    s.add(tx('1', false, 1000, 'ترفيه'));
    s.add(tx('2', false, 3000, 'طعام'));
    s.markRegret('1', true);
    expect(s.regretPercent, 25);
    expect(s.topRegretCat, 'ترفيه');
  });

  test('الحد اليومي لا يكون سالباً عند تجاوز الميزانية', () {
    final s = AppStore();
    s.setBudget('طعام', 1000);
    s.add(tx('1', false, 2000, 'طعام'));
    expect(s.remaining, -1000);
    expect(s.dailyLimit, 0);
  });

  test('سؤال الندم يظهر بعد 24 ساعة فقط', () {
    final s = AppStore();
    s.add(tx('1', false, 500, 'طعام', at: DateTime.now().subtract(const Duration(hours: 30))));
    s.add(tx('2', false, 500, 'طعام'));
    expect(s.pendingRegrets.map((t) => t.id), ['1']);
  });

  test('تنسيق المبلغ', () {
    expect(fm(1234567), '1,234,567 د.ج');
  });
}
