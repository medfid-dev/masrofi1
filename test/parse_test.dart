import 'package:flutter_test/flutter_test.dart';
import 'package:masrofi/parse_entry.dart';

void main() {
  test('مبلغ ثم وصف', () {
    final e = parseQuickEntry('2500 قهوة')!;
    expect(e.amount, 2500);
    expect(e.cat, 'طعام');
    expect(e.income, false);
    expect(e.note, 'قهوة');
  });

  test('وصف ثم مبلغ', () {
    final e = parseQuickEntry('تاكسي 300')!;
    expect(e.amount, 300);
    expect(e.cat, 'مواصلات');
  });

  test('دخل بالأرقام العربية', () {
    final e = parseQuickEntry('+٥٠٠٠٠ راتب')!;
    expect(e.amount, 50000);
    expect(e.income, true);
    expect(e.cat, 'راتب');
  });

  test('فاصلة الآلاف', () {
    expect(parseQuickEntry('1,500 خبز')!.amount, 1500);
  });

  test('بدون رقم', () {
    expect(parseQuickEntry('قهوة'), isNull);
  });

  test('فئة مخصصة', () {
    final e = parseQuickEntry('800 قطط', knownCats: ['قطط'])!;
    expect(e.cat, 'قطط');
  });
}
