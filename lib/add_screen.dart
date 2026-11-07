import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';
import 'places.dart';
import 'quick_add.dart';

class AddScreen extends StatefulWidget {
  final AppStore store;
  final VoidCallback onSaved;
  const AddScreen({super.key, required this.store, required this.onSaved});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  bool income = false;
  String? cat;
  bool sub = false;
  DateTime at = DateTime.now();
  final amt = TextEditingController();
  final note = TextEditingController();

  List<String> get options => income ? AppStore.incomeCats : widget.store.cats;
  double? get amount => double.tryParse(amt.text.replaceAll(',', '.'));

  @override
  void dispose() {
    amt.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: at,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => at = DateTime(d.year, d.month, d.day, DateTime.now().hour, DateTime.now().minute));
  }

  bool get _isToday {
    final n = DateTime.now();
    return at.year == n.year && at.month == n.month && at.day == n.day;
  }

  Future<void> save() async {
    final a = amount;
    if (a == null || a <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل مبلغاً صحيحاً')));
      return;
    }
    final c = options.contains(cat) ? cat! : options.first;
    // الموقع فقط للمصروف الجديد (اليوم)، وإن كان الحفظ مفعّلاً
    final pos = (!income && _isToday && widget.store.saveLoc) ? await currentPos() : null;
    final when = _isToday ? DateTime.now() : at;
    final t = Tx(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      income: income,
      amount: a,
      cat: c,
      note: note.text.trim(),
      at: when,
      sub: !income && sub,
      lat: pos?.latitude,
      lng: pos?.longitude,
    );
    await widget.store.add(t);
    if (_isToday) scheduleRegret(t);
    if (!mounted) return;
    amt.clear();
    note.clear();
    setState(() {
      sub = false;
      at = DateTime.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
    widget.onSaved();
  }

  Future<void> newCat() async {
    final ctl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('فئة جديدة'),
        content: TextField(controller: ctl, autofocus: true, decoration: const InputDecoration(hintText: 'اسم الفئة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('إضافة')),
        ],
      ),
    );
    if (v != null) {
      widget.store.addCat(v);
      setState(() => cat = v.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.store.hourly;
    final a = amount;
    final selected = options.contains(cat) ? cat! : options.first;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عملية')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('مصروف')),
              ButtonSegment(value: true, label: Text('دخل')),
            ],
            selected: {income},
            onSelectionChanged: (s) => setState(() {
              income = s.first;
              cat = null;
            }),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: amt,
            autofocus: false,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: income ? Colors.green.shade700 : cs.error),
            decoration: const InputDecoration(hintText: '0', suffixText: 'د.ج'),
            onChanged: (_) => setState(() {}),
          ),
          if (!income && h > 0 && a != null && a > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(child: Text('≈ ${(a / h).toStringAsFixed(1)} ساعة من عملك', style: TextStyle(color: cs.outline))),
            ),
          const SizedBox(height: 20),
          Text(income ? 'المصدر' : 'الفئة', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final c in options)
              ChoiceChip(
                label: Text('${catEmoji(c)} $c'),
                selected: selected == c,
                onSelected: (_) => setState(() => cat = c),
              ),
            if (!income) ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('فئة'), onPressed: newCat),
          ]),
          const SizedBox(height: 18),
          TextField(
            controller: note,
            decoration: const InputDecoration(hintText: 'ملاحظة (اختياري)'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: pickDate,
                icon: const Icon(Icons.event, size: 18),
                label: Text(_isToday ? 'اليوم' : '${at.year}-${p2(at.month)}-${p2(at.day)}'),
              ),
            ),
            if (!income) ...[
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('اشتراك متكرر'),
                selected: sub,
                onSelected: (v) => setState(() => sub = v),
              ),
            ],
          ]),
          const SizedBox(height: 22),
          FilledButton(onPressed: save, child: Text(income ? 'حفظ الدخل' : 'حفظ المصروف')),
        ],
      ),
    );
  }
}
