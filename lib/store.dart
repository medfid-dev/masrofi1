import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

String fm(double n) {
  final s = n.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  final sign = n < 0 ? '-' : '';
  return '$sign${b.toString()} د.ج';
}

class AppStore extends ChangeNotifier {
  static const defaultCats = ['طعام', 'فواتير', 'مواصلات', 'ترفيه', 'تسوق', 'صحة', 'اشتراكات', 'أخرى'];
  static const incomeCats = ['راتب', 'عمل حر', 'هدية', 'أخرى'];
  static const personaNames = ['المدرب المحفز', 'الصديق البخيل', 'المحاسب الجاد'];

  List<Tx> txs = [];
  Map<String, double> budgets = {};
  List<String> customCats = [];
  double monthlyIncome = 0;
  int persona = 0;
  bool quickAdd = true;
  bool remind = true;
  int remindFrom = 10;
  int remindTo = 22;
  bool saveLoc = false;
  bool placeAlerts = false;
  bool shareBoard = false;
  bool notifRead = false;
  String name = '';
  List<String> deleted = [];
  List<Detected> detected = [];
  int updatedAt = 0;
  SharedPreferences? _p;

  List<String> get cats => [...defaultCats, ...customCats];

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    await _p!.reload(); // لقراءة ما كُتب من العملية الخلفية
    final raw = _p!.getString('data');
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        txs = (j['txs'] as List).map((e) => Tx.fromJson(e as Map<String, dynamic>)).toList();
        budgets = (j['budgets'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
        customCats = List<String>.from(j['customCats'] ?? []);
        monthlyIncome = ((j['income'] as num?) ?? 0).toDouble();
        persona = (j['persona'] as int?) ?? 0;
        quickAdd = (j['quickAdd'] as bool?) ?? true;
        remind = (j['remind'] as bool?) ?? true;
        remindFrom = (j['remindFrom'] as int?) ?? 10;
        remindTo = (j['remindTo'] as int?) ?? 22;
        saveLoc = (j['saveLoc'] as bool?) ?? false;
        placeAlerts = (j['placeAlerts'] as bool?) ?? false;
        shareBoard = (j['shareBoard'] as bool?) ?? false;
        notifRead = (j['notifRead'] as bool?) ?? false;
        name = (j['name'] as String?) ?? '';
        deleted = List<String>.from(j['deleted'] ?? []);
        detected = ((j['detected'] as List?) ?? []).map((e) => Detected.fromJson(e as Map<String, dynamic>)).toList();
        updatedAt = (j['updatedAt'] as int?) ?? 0;
      } catch (_) {}
    }
    txs.sort((a, b) => b.at.compareTo(a.at));
  }

  Future<void> _save() async {
    final data = jsonEncode({
      'txs': txs.map((t) => t.toJson()).toList(),
      'budgets': budgets,
      'customCats': customCats,
      'income': monthlyIncome,
      'persona': persona,
      'quickAdd': quickAdd,
      'remind': remind,
      'remindFrom': remindFrom,
      'remindTo': remindTo,
      'saveLoc': saveLoc,
      'placeAlerts': placeAlerts,
      'shareBoard': shareBoard,
      'notifRead': notifRead,
      'name': name,
      'deleted': deleted,
      'detected': detected.map((d) => d.toJson()).toList(),
      'updatedAt': updatedAt,
    });
    notifyListeners();
    await _p?.setString('data', data);
  }

  /// يقرأ آخر نسخة محفوظة (قد تكون كتبتها العملية الخلفية) ثم يطبّق التعديل ويحفظ،
  /// حتى لا نمحو ما سُجّل من الإشعار. بدون تخزين (في الاختبارات) يعمل بشكل متزامن.
  Future<void> _edit(void Function() fn, {bool touch = true}) async {
    if (_p != null) await load();
    fn();
    if (touch) updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _save();
  }

  // ---------- العمليات ----------
  Future<void> add(Tx t) => _edit(() {
        txs.add(t);
        txs.sort((a, b) => b.at.compareTo(a.at));
      });

  Future<void> remove(String id) => _edit(() {
        txs.removeWhere((t) => t.id == id);
        if (!deleted.contains(id)) deleted.add(id);
      });

  Future<void> setBudget(String cat, double v) => _edit(() {
        if (v <= 0) {
          budgets.remove(cat);
        } else {
          budgets[cat] = v;
        }
      });

  Future<void> addCat(String c) => _edit(() {
        final name = c.trim();
        if (name.isEmpty || cats.contains(name)) return;
        customCats.add(name);
      });

  Future<void> setIncome(double v) => _edit(() => monthlyIncome = v);

  Future<void> setPersona(int p) => _edit(() => persona = p);

  Future<void> setReminder({bool? on, int? from, int? to}) => _edit(() {
        if (on != null) remind = on;
        if (from != null) {
          remindFrom = from;
          if (remindTo < from) remindTo = from;
        }
        if (to != null) {
          remindTo = to;
          if (remindFrom > to) remindFrom = to;
        }
      });

  Future<void> setQuickAdd(bool v) => _edit(() => quickAdd = v);

  Future<void> setFlags({bool? saveLoc, bool? placeAlerts, bool? shareBoard, bool? notifRead, String? name}) =>
      _edit(() {
        if (saveLoc != null) this.saveLoc = saveLoc;
        if (placeAlerts != null) this.placeAlerts = placeAlerts;
        if (shareBoard != null) this.shareBoard = shareBoard;
        if (notifRead != null) this.notifRead = notifRead;
        if (name != null) this.name = name.trim();
      });

  // ---------- عمليات مكتشفة من الإشعارات ----------
  Future<void> addDetected(List<Detected> list) => _edit(() {
        for (final d in list) {
          if (detected.any((x) => x.id == d.id)) continue;
          if (txs.any((t) => t.id == 'n${d.id}')) continue;
          detected.add(d);
        }
        if (detected.length > 30) detected = detected.sublist(detected.length - 30);
      }, touch: false);

  Future<void> dismissDetected(String id) => _edit(() => detected.removeWhere((d) => d.id == id), touch: false);

  Future<Tx?> acceptDetected(Detected d, String cat) async {
    final t = Tx(id: 'n${d.id}', income: d.income, amount: d.amount, cat: cat, note: d.note, at: d.at);
    await _edit(() {
      detected.removeWhere((x) => x.id == d.id);
      txs.add(t);
      txs.sort((a, b) => b.at.compareTo(a.at));
    });
    return t;
  }

  // ---------- المزامنة ----------
  Map<String, dynamic> toSync() => {
        'txs': txs.map((t) => t.toJson()).toList(),
        'deleted': deleted,
        'budgets': budgets,
        'customCats': customCats,
        'income': monthlyIncome,
        'persona': persona,
        'name': name,
        'shareBoard': shareBoard,
        'updatedAt': updatedAt,
      };

  /// دمج نسخة السحابة: اتحاد العمليات (مع احترام المحذوف)، والإعدادات للأحدث
  Future<void> mergeRemote(Map<String, dynamic> r) => _edit(() {
        final remoteDeleted = List<String>.from(r['deleted'] ?? []);
        deleted = {...deleted, ...remoteDeleted}.toList();
        final byId = {for (final t in txs) t.id: t};
        for (final e in (r['txs'] as List? ?? [])) {
          final t = Tx.fromJson(Map<String, dynamic>.from(e as Map));
          final mine = byId[t.id];
          if (mine == null) {
            byId[t.id] = t;
          } else if (mine.regret == null && t.regret != null) {
            mine.regret = t.regret;
          }
        }
        txs = byId.values.where((t) => !deleted.contains(t.id)).toList()..sort((a, b) => b.at.compareTo(a.at));
        customCats = {...customCats, ...List<String>.from(r['customCats'] ?? [])}.toList();
        final ru = (r['updatedAt'] as num?)?.toInt() ?? 0;
        if (ru > updatedAt) {
          budgets = ((r['budgets'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
          monthlyIncome = ((r['income'] as num?) ?? 0).toDouble();
          persona = (r['persona'] as int?) ?? persona;
          name = (r['name'] as String?) ?? name;
          shareBoard = (r['shareBoard'] as bool?) ?? shareBoard;
          updatedAt = ru;
        }
      }, touch: false);

  // ---------- إحصاءات الأماكن ----------
  String _cell(Tx t) => '${(t.lat! * 700).round()}_${(t.lng! * 700).round()}';

  /// أكثر الأماكن إنفاقاً (تجميع تقريبي في خلايا بحجم ~150 متراً)
  List<PlaceStat> get placeStats {
    final g = <String, List<Tx>>{};
    for (final t in txs.where((t) => !t.income && t.lat != null && t.lng != null)) {
      g.putIfAbsent(_cell(t), () => []).add(t);
    }
    final out = <PlaceStat>[];
    for (final l in g.values) {
      final byCat = <String, int>{};
      for (final t in l) {
        byCat[t.cat] = (byCat[t.cat] ?? 0) + 1;
      }
      final top = (byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
      out.add(PlaceStat(l.length, l.fold<double>(0, (a, t) => a + t.amount), top));
    }
    out.sort((a, b) => b.total.compareTo(a.total));
    return out;
  }

  /// نسبة استهلاك الميزانية (للترتيب العام) أو null
  int? get usedPercent => totalBudget > 0 ? (monthSpent / totalBudget * 100).round() : null;

  Future<void> reload() async {
    await load();
    notifyListeners();
  }

  Future<void> markRegret(String id, bool v) => _edit(() {
        for (final t in txs) {
          if (t.id == id) t.regret = v;
        }
      });

  Future<void> clearAll() => _edit(() {
        deleted = {...deleted, ...txs.map((t) => t.id)}.toList();
        detected = [];
        txs = [];
        budgets = {};
        customCats = [];
        monthlyIncome = 0;
      });

  // ---------- الحسابات ----------
  DateTime get now => DateTime.now();

  Iterable<Tx> get monthTx => txs.where((t) => t.at.year == now.year && t.at.month == now.month);

  double get totalIncome => txs.where((t) => t.income).fold<double>(0, (a, t) => a + t.amount);
  double get totalExpense => txs.where((t) => !t.income).fold<double>(0, (a, t) => a + t.amount);
  double get balance => totalIncome - totalExpense;
  double get monthSpent => monthTx.where((t) => !t.income).fold<double>(0, (a, t) => a + t.amount);

  Map<String, double> get spentByCat {
    final m = <String, double>{};
    for (final t in monthTx.where((t) => !t.income)) {
      m[t.cat] = (m[t.cat] ?? 0) + t.amount;
    }
    return m;
  }

  double get totalBudget => budgets.values.fold<double>(0, (a, b) => a + b);

  /// قيمة ساعة العمل (176 ساعة شهرياً)
  double get hourly {
    var inc = monthlyIncome;
    if (inc <= 0) {
      inc = monthTx.where((t) => t.income).fold<double>(0, (a, t) => a + t.amount);
    }
    return inc > 0 ? inc / 176 : 0;
  }

  // ---------- شجرة الثروة ----------
  int get streak {
    if (totalBudget <= 0 || txs.isEmpty) return 0;
    final lim = totalBudget / 30;
    final first = txs
        .map((t) => DateTime(t.at.year, t.at.month, t.at.day))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    var n = 0;
    for (var o = 0; o < 90; o++) {
      final d = DateTime(now.year, now.month, now.day - o);
      if (d.isBefore(first)) break;
      final sp = txs
          .where((t) => !t.income && t.at.year == d.year && t.at.month == d.month && t.at.day == d.day)
          .fold<double>(0, (a, t) => a + t.amount);
      if (sp > lim) break;
      n++;
    }
    return n;
  }

  double get _ratio => totalBudget > 0 ? monthSpent / totalBudget : 0;

  String get treeEmoji {
    if (totalBudget <= 0) return '🌱';
    final r = _ratio;
    if (r < .6) return '🌳🌸';
    if (r < .85) return '🌿';
    if (r <= 1) return '🌱';
    return '🥀';
  }

  String get treeBadge => streak >= 30 ? '🍎✨' : (streak >= 14 ? '✨' : '');

  String get treeMsg {
    if (totalBudget <= 0) return 'حدّد ميزانيتك لتنمو شجرتك.';
    final r = _ratio;
    if (r < .6) return 'شجرتك مزدهرة! أنت ملتزم.';
    if (r < .85) return 'تنمو جيداً، انتبه قليلاً.';
    if (r <= 1) return 'شجرتك عطشى، اقتربت من السقف.';
    return 'ذبلت الشجرة بعد تجاوز الميزانية.';
  }

  // ---------- شخصية المساعد ----------
  String get hi => [
        'كل دينار تدّخره خطوة نحو حلمك 💪',
        'أبكي كلما اشتريت قهوة غالية ☕😭',
        'الانضباط هو أساس الثروة.',
      ][persona];

  String _over(String c) => [
        'تجاوزت «$c»، لا بأس! خطوة صغيرة اليوم تصلح الشهر 💪',
        'يا رجل! «$c» انفجرت! هل تظن أن المال ينبت في الأشجار؟ 🙄',
        'تنبيه: تجاوزت ميزانية «$c». يلزم مراجعة الإنفاق فوراً.',
      ][persona];

  String _near(String c, int p) => [
        '«$c» عند $p%، أنت قريب من الهدف، أكمل بقوة 💪',
        '«$c» عند $p%… حتى جيبي بدأ يرتجف 😬',
        '«$c» بلغت $p% من السقف المحدد.',
      ][persona];

  List<String> get alerts {
    final out = <String>[];
    final by = spentByCat;
    budgets.forEach((c, lim) {
      final u = by[c] ?? 0;
      if (lim <= 0) return;
      if (u >= lim) {
        out.add(_over(c));
      } else if (u >= .8 * lim) {
        out.add(_near(c, (u / lim * 100).round()));
      }
    });
    return out;
  }

  // ---------- مؤشر الندم ----------
  List<Tx> get pendingRegrets => txs
      .where((t) => !t.income && t.regret == null && now.difference(t.at).inHours >= 24)
      .take(3)
      .toList();

  double get regretAmount =>
      monthTx.where((t) => !t.income && t.regret == true).fold<double>(0, (a, t) => a + t.amount);

  double get regretPercent => monthSpent <= 0 ? 0 : regretAmount / monthSpent * 100;

  String? get topRegretCat {
    final m = <String, double>{};
    for (final t in monthTx.where((t) => !t.income && t.regret == true)) {
      m[t.cat] = (m[t.cat] ?? 0) + t.amount;
    }
    if (m.isEmpty) return null;
    return (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }

  // ---------- زر الطوارئ المالي ----------
  int get daysLeft => DateTime(now.year, now.month + 1, 0).day - now.day + 1;

  double get remaining => (totalBudget > 0 ? totalBudget : monthlyIncome) - monthSpent;

  double get dailyLimit => remaining <= 0 ? 0 : remaining / daysLeft;

  /// أكبر فئة غير ثابتة، والمبلغ الذي توفّره بتقليلها 15% في بقية الشهر
  MapEntry<String, double>? get panicTip {
    const fixed = {'فواتير', 'صحة'};
    final by = Map<String, double>.from(spentByCat)..removeWhere((k, v) => fixed.contains(k));
    if (by.isEmpty) return null;
    final top = (by.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;
    final saving = top.value / now.day * daysLeft * 0.15;
    return MapEntry(top.key, saving);
  }
}
