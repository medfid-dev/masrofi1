/// تحليل نص الإدخال السريع، مثل: "2500 قهوة" أو "تاكسي 300" أو "+50000 راتب"
class ParsedEntry {
  final double amount;
  final String note;
  final String cat;
  final bool income;
  const ParsedEntry(this.amount, this.note, this.cat, this.income);
}

const Map<String, List<String>> _keywords = {
  'طعام': ['قهوة', 'اكل', 'أكل', 'مطعم', 'خبز', 'حليب', 'غداء', 'عشاء', 'فطور', 'بيتزا', 'خضر', 'لحم', 'سندويش', 'عصير'],
  'مواصلات': ['تاكسي', 'بنزين', 'وقود', 'حافلة', 'مترو', 'ترام', 'نقل', 'طاكسي'],
  'فواتير': ['فاتورة', 'كهرباء', 'غاز', 'ماء', 'انترنت', 'إنترنت', 'رصيد', 'جازي', 'موبيليس', 'اوريدو'],
  'ترفيه': ['سينما', 'لعبة', 'العاب', 'ألعاب', 'رحلة', 'نادي'],
  'تسوق': ['ملابس', 'حذاء', 'تسوق', 'هدية'],
  'صحة': ['دواء', 'صيدلية', 'طبيب', 'دكتور', 'عيادة'],
  'اشتراكات': ['اشتراك', 'نتفليكس', 'سبوتيفاي'],
};

String _digits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  var o = s;
  for (var i = 0; i < 10; i++) {
    o = o.replaceAll(ar[i], '$i').replaceAll(fa[i], '$i');
  }
  return o.replaceAll('٫', '.').replaceAll('٬', '');
}

/// تحويل الأرقام العربية/الفارسية إلى لاتينية
String normalizeDigits(String s) => _digits(s);

ParsedEntry? parseQuickEntry(String raw, {List<String> knownCats = const []}) {
  final text = _digits(raw.trim());
  final m = RegExp(r'(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:[.,]\d+)?)').firstMatch(text);
  if (m == null) return null;
  final g = m.group(1)!;
  final isThousands = RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(g);
  final amount = double.tryParse(isThousands ? g.replaceAll(',', '') : g.replaceAll(',', '.'));
  if (amount == null || amount <= 0) return null;

  final income = text.startsWith('+');
  final note = ('${text.substring(0, m.start)} ${text.substring(m.end)}')
      .replaceAll('+', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (income) {
    final cat = note.contains('راتب') ? 'راتب' : (note.contains('عمل') ? 'عمل حر' : 'أخرى');
    return ParsedEntry(amount, note, cat, true);
  }

  String cat = 'أخرى';
  var found = false;
  for (final c in knownCats) {
    if (c != 'أخرى' && note.contains(c)) {
      cat = c;
      found = true;
      break;
    }
  }
  if (!found) {
    for (final e in _keywords.entries) {
      if (e.value.any((k) => note.contains(k))) {
        cat = e.key;
        break;
      }
    }
  }
  return ParsedEntry(amount, note, cat, false);
}
