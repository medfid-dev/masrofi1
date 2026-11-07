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

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عملية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
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
          const SizedBox(height: 16),
          TextField(
            controller: amt,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'المبلغ', suffixText: 'د.ج', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          if (!income && h > 0 && a != null && a > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('≈ ${(a / h).toStringAsFixed(1)} ساعة من عملك'),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selected,
            decoration: InputDecoration(labelText: income ? 'مصدر الدخل' : 'الفئة', border: const OutlineInputBorder()),
            items: [for (final c in options) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => cat = v),
          ),
          if (!income)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(onPressed: newCat, icon: const Icon(Icons.add), label: const Text('فئة جديدة')),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: pickDate,
              icon: const Icon(Icons.event),
              label: Text(_isToday ? 'التاريخ: اليوم' : 'التاريخ: ${at.year}-${p2(at.month)}-${p2(at.day)}'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'الوصف (اختياري)', border: OutlineInputBorder()),
          ),
          if (!income)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('اشتراك متكرر'),
              value: sub,
              onChanged: (v) => setState(() => sub = v),
            ),
          const SizedBox(height: 8),
          FilledButton(onPressed: save, child: Text(income ? 'حفظ الدخل' : 'حفظ المصروف')),
        ],
      ),
    );
  }
}
