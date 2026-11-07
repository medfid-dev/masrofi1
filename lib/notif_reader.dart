import 'dart:convert';
import 'package:flutter/services.dart';
import 'models.dart';
import 'parse_entry.dart';
import 'store.dart';

const MethodChannel _ch = MethodChannel('masrofi/notifs');

Future<bool> notifAccessEnabled() async {
  try {
    return (await _ch.invokeMethod<bool>('isEnabled')) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> openNotifAccessSettings() async {
  try {
    await _ch.invokeMethod('openSettings');
  } catch (_) {}
}

const _incomeWords = [
  'إيداع', 'ايداع', 'استلمت', 'تم استلام', 'تحويل وارد', 'تم تحويل إلى حسابك', 'crédit', 'credit', 'versement',
  'reçu', 'received', 'credited', 'deposit',
];
const _expenseWords = [
  'خصم', 'سحب', 'شراء', 'دفع', 'سداد', 'تحويل صادر', 'paiement', 'retrait', 'débit', 'debit', 'purchase', 'payment',
  'achat', 'withdrawal', 'debited',
];

double? _toNumber(String raw) {
  var s = raw.replaceAll(RegExp(r'\s'), '');
  final lastDot = s.lastIndexOf('.');
  final lastCom = s.lastIndexOf(',');
  if (lastDot >= 0 && lastCom >= 0) {
    final dec = lastDot > lastCom ? '.' : ',';
    final thou = dec == '.' ? ',' : '.';
    s = s.replaceAll(thou, '').replaceAll(dec, '.');
  } else if (lastCom >= 0 || lastDot >= 0) {
    final sep = lastCom >= 0 ? ',' : '.';
    final idx = s.lastIndexOf(sep);
    final after = s.length - idx - 1;
    final count = sep.allMatches(s).length;
    if (count > 1 || after == 3) {
      s = s.replaceAll(sep, ''); // فاصل آلاف
    } else {
      s = s.replaceAll(sep, '.'); // فاصلة عشرية
    }
  }
  return double.tryParse(s);
}

/// يحلل نص إشعار بنكي. يشترط وجود مبلغ مقترن بعملة (DZD/DA/دج) لتقليل الخطأ.
Detected? parseBankText(String text, DateTime at, String id) {
  final t = normalizeDigits(text);
  final low = t.toLowerCase();
  final isIncome = _incomeWords.any((w) => low.contains(w));
  final isExpense = _expenseWords.any((w) => low.contains(w));
  if (!isIncome && !isExpense) return null;
  final m = RegExp(r'(\d[\d\s.,]*\d|\d)\s*(?:dzd|da|د\.ج|دج|دينار)', caseSensitive: false).firstMatch(low);
  if (m == null) return null;
  final amount = _toNumber(m.group(1)!);
  if (amount == null || amount <= 0) return null;
  // إن وُجد المعنيان فالأول ظهوراً هو الغالب
  var income = isIncome && !isExpense;
  if (isIncome && isExpense) {
    int first(List<String> ws) =>
        ws.map((w) => low.indexOf(w)).where((i) => i >= 0).fold<int>(1 << 30, (a, b) => a < b ? a : b);
    income = first(_incomeWords) < first(_expenseWords);
  }
  final note = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return Detected(
    id: id,
    income: income,
    amount: amount,
    note: note.length > 60 ? note.substring(0, 60) : note,
    at: at,
  );
}

/// يسحب الإشعارات التي التقطتها الخدمة الأصلية. إن كانت الميزة معطّلة تُهمَل.
Future<void> drainNotifications(AppStore s) async {
  String raw;
  try {
    raw = (await _ch.invokeMethod<String>('drain')) ?? '[]';
  } catch (_) {
    return;
  }
  if (!s.notifRead) return;
  final out = <Detected>[];
  try {
    for (final e in jsonDecode(raw) as List) {
      final m = e as Map;
      final text = m['text'] as String;
      final ms = (m['at'] as num).toInt();
      final d = parseBankText(text, DateTime.fromMillisecondsSinceEpoch(ms), '$ms${text.hashCode.abs()}');
      if (d != null) out.add(d);
    }
  } catch (_) {
    return;
  }
  if (out.isNotEmpty) await s.addDetected(out);
}
