class Tx {
  final String id;
  final bool income;
  final double amount;
  final String cat;
  final String note;
  final DateTime at;
  final bool sub;
  bool? regret; // null = لم يُجب بعد
  final double? lat;
  final double? lng;

  Tx({
    required this.id,
    required this.income,
    required this.amount,
    required this.cat,
    this.note = '',
    required this.at,
    this.sub = false,
    this.regret,
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'income': income,
        'amount': amount,
        'cat': cat,
        'note': note,
        'at': at.toIso8601String(),
        'sub': sub,
        'regret': regret,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };

  factory Tx.fromJson(Map<String, dynamic> j) => Tx(
        id: j['id'] as String,
        income: j['income'] as bool,
        amount: (j['amount'] as num).toDouble(),
        cat: j['cat'] as String,
        note: (j['note'] as String?) ?? '',
        at: DateTime.parse(j['at'] as String),
        sub: (j['sub'] as bool?) ?? false,
        regret: j['regret'] as bool?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );
}

/// عملية اكتُشفت من إشعار بنكي وتنتظر موافقتك
class Detected {
  final String id;
  final bool income;
  final double amount;
  final String note;
  final DateTime at;
  const Detected({required this.id, required this.income, required this.amount, required this.note, required this.at});

  Map<String, dynamic> toJson() =>
      {'id': id, 'income': income, 'amount': amount, 'note': note, 'at': at.toIso8601String()};

  factory Detected.fromJson(Map<String, dynamic> j) => Detected(
        id: j['id'] as String,
        income: j['income'] as bool,
        amount: (j['amount'] as num).toDouble(),
        note: (j['note'] as String?) ?? '',
        at: DateTime.parse(j['at'] as String),
      );
}

/// تحدٍّ مع الأصدقاء. kind: no_spend | no_cat | limit
class Challenge {
  final String id;
  final String code;
  final String title;
  final String kind;
  final String cat;
  final double limit;
  final int days;
  final DateTime from; // يوم انضمامي
  const Challenge({
    required this.id,
    required this.code,
    required this.title,
    required this.kind,
    required this.cat,
    required this.limit,
    required this.days,
    required this.from,
  });

  String get rule {
    switch (kind) {
      case 'no_cat':
        return 'بلا إنفاق على «$cat»';
      case 'limit':
        return 'إنفاق يومي لا يتجاوز ${limit.round()} د.ج';
      default:
        return 'يوم بلا أي مصروف';
    }
  }
}

/// عدد أيام التحدي الناجحة حتى اليوم (اليوم الحالي مؤقت حتى ينتهي)
int challengeOkDays(Challenge c, List<Tx> txs, DateTime today) {
  final start = DateTime(c.from.year, c.from.month, c.from.day);
  var ok = 0;
  for (var i = 0; i < c.days; i++) {
    final d = DateTime(start.year, start.month, start.day + i);
    if (d.isAfter(DateTime(today.year, today.month, today.day))) break;
    final day = txs.where((t) => !t.income && t.at.year == d.year && t.at.month == d.month && t.at.day == d.day);
    bool good;
    if (c.kind == 'no_cat') {
      good = !day.any((t) => t.cat == c.cat);
    } else if (c.kind == 'limit') {
      good = day.fold<double>(0, (a, t) => a + t.amount) <= c.limit;
    } else {
      good = day.isEmpty;
    }
    if (good) ok++;
  }
  return ok;
}

class PlaceStat {
  final int count;
  final double total;
  final String topCat;
  const PlaceStat(this.count, this.total, this.topCat);
}
