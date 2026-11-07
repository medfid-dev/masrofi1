import 'package:flutter_test/flutter_test.dart';
import 'package:masrofi/models.dart';
import 'package:masrofi/notif_reader.dart';
import 'package:masrofi/store.dart';

Tx tx(String id, bool income, double amount, String cat, DateTime at, {double? lat, double? lng}) =>
    Tx(id: id, income: income, amount: amount, cat: cat, at: at, lat: lat, lng: lng);

void main() {
  final now = DateTime(2026, 11, 7, 12);

  group('إشعارات البنك', () {
    test('خصم', () {
      final d = parseBankText('تم خصم 2,500.00 DZD من حسابك عند شراء', now, 'x')!;
      expect(d.income, false);
      expect(d.amount, 2500);
    });
    test('إيداع بالفرنسية', () {
      final d = parseBankText('Versement de 15 000 DA sur votre compte', now, 'x')!;
      expect(d.income, true);
      expect(d.amount, 15000);
    });
    test('بلا عملة أو كلمة مالية يُهمَل', () {
      expect(parseBankText('رمز التحقق 123456', now, 'x'), isNull);
      expect(parseBankText('تم دفع الطلب رقم 55', now, 'x'), isNull);
    });
  });

  group('التحديات', () {
    final from = DateTime(2026, 11, 1);
    Challenge ch(String kind, {String cat = '', double limit = 0}) => Challenge(
        id: '1', code: 'ABC234', title: 't', kind: kind, cat: cat, limit: limit, days: 3, from: from);

    test('يوم بلا مصروف', () {
      final txs = [tx('1', false, 100, 'طعام', DateTime(2026, 11, 2, 10))];
      expect(challengeOkDays(ch('no_spend'), txs, DateTime(2026, 11, 3)), 2); // اليوم 1 و3 نجحا
    });
    test('بلا فئة', () {
      final txs = [tx('1', false, 100, 'طعام', DateTime(2026, 11, 1, 9)), tx('2', false, 50, 'مواصلات', DateTime(2026, 11, 2, 9))];
      expect(challengeOkDays(ch('no_cat', cat: 'طعام'), txs, DateTime(2026, 11, 3)), 2);
    });
    test('سقف يومي ولا يتجاوز عدد الأيام', () {
      final txs = [tx('1', false, 300, 'طعام', DateTime(2026, 11, 1, 9))];
      expect(challengeOkDays(ch('limit', limit: 200), txs, DateTime(2026, 11, 20)), 2);
    });
  });

  group('المزامنة والأماكن', () {
    test('دمج السحابة يتحدّ ويحترم المحذوف', () async {
      final s = AppStore();
      await s.add(tx('a', false, 100, 'طعام', now));
      await s.add(tx('b', false, 200, 'طعام', now));
      await s.remove('b');
      await s.mergeRemote({
        'txs': [tx('b', false, 200, 'طعام', now).toJson(), tx('c', false, 300, 'طعام', now).toJson()],
        'deleted': <String>[],
        'updatedAt': 0,
      });
      expect(s.txs.map((t) => t.id).toSet(), {'a', 'c'});
    });

    test('إحصاءات الأماكن تجمع القريب', () async {
      final s = AppStore();
      await s.add(tx('1', false, 100, 'طعام', now, lat: 36.7500, lng: 3.0500));
      await s.add(tx('2', false, 300, 'طعام', now, lat: 36.7501, lng: 3.0501));
      await s.add(tx('3', false, 50, 'ترفيه', now, lat: 35.0, lng: 4.0));
      final st = s.placeStats;
      expect(st.length, 2);
      expect(st.first.total, 400);
      expect(st.first.topCat, 'طعام');
    });

    test('قبول عملية مكتشفة', () async {
      final s = AppStore();
      await s.addDetected([Detected(id: '9', income: false, amount: 700, note: 'n', at: now)]);
      expect(s.detected.length, 1);
      await s.acceptDetected(s.detected.first, 'طعام');
      expect(s.detected, isEmpty);
      expect(s.monthSpent >= 0, true);
      expect(s.txs.single.id, 'n9');
    });
  });
}
