import 'package:flutter/material.dart';
import 'store.dart';
import 'widgets.dart';
import 'quick_add.dart';
import 'cloud.dart';
import 'config.dart';
import 'notif_reader.dart';
import 'places.dart';

class SettingsScreen extends StatelessWidget {
  final AppStore store;
  const SettingsScreen({super.key, required this.store});


  void _snack(BuildContext context, String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _editName(BuildContext context) async {
    final ctl = TextEditingController(text: store.name);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اسمي في المجتمع'),
        content: TextField(controller: ctl, autofocus: true, maxLength: 20),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('حفظ')),
        ],
      ),
    );
    if (v != null) store.setFlags(name: v);
  }

  Future<void> _account(BuildContext context) async {
    if (Cloud.email != null) {
      await Cloud.signOut();
      if (context.mounted) _snack(context, 'تم الخروج');
      store.reload();
      return;
    }
    final mail = TextEditingController();
    final pass = TextEditingController();
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حسابي'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: mail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد')),
          TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة السر (6 أحرف فأكثر)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          OutlinedButton(onPressed: () => Navigator.pop(ctx, 'in'), child: const Text('دخول')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'up'), child: const Text('إنشاء حساب')),
        ],
      ),
    );
    if (mode == null) return;
    final e = mail.text.trim(), p = pass.text;
    final err = mode == 'up' ? await Cloud.signUp(e, p) : await Cloud.signIn(e, p);
    if (err == null) await Cloud.sync(store);
    if (context.mounted) _snack(context, err ?? (mode == 'up' ? 'تم. إن طُلب تأكيد البريد فافتح رسالة التأكيد' : 'تم الدخول ✓'));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Sheet(title: 'شخصية المساعد', children: [
              SegmentedButton<int>(
                segments: [
                  for (var i = 0; i < 3; i++) ButtonSegment(value: i, label: Text(AppStore.personaNames[i])),
                ],
                selected: {store.persona},
                onSelectionChanged: (v) => store.setPersona(v.first),
              ),
              const SizedBox(height: 8),
              const Text('تتغير بها نبرة التنبيهات في الشاشة الرئيسية.'),
            ]),
            Sheet(title: 'الإضافة السريعة', children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إشعار الإضافة السريعة'),
                subtitle: const Text('اكتب «2500 قهوة» من شريط الإشعارات دون فتح التطبيق'),
                value: store.quickAdd,
                onChanged: (v) {
                  store.setQuickAdd(v);
                  v ? showQuickAdd() : cancelQuickAdd();
                },
              ),
            ]),
            Sheet(title: 'تذكير كل ساعتين', children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ذكّرني بتسجيل مصاريفي'),
                subtitle: const Text('يظهر إشعار منبثق تكتب فيه ما صرفته دون فتح التطبيق'),
                value: store.remind,
                onChanged: (v) {
                  store.setReminder(on: v);
                  scheduleReminders(store);
                },
              ),
              if (store.remind)
                Row(children: [
                  const Text('من'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: store.remindFrom,
                    items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text('$h:00'))],
                    onChanged: (v) {
                      if (v == null) return;
                      store.setReminder(from: v);
                      scheduleReminders(store);
                    },
                  ),
                  const SizedBox(width: 16),
                  const Text('إلى'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: store.remindTo,
                    items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text('$h:00'))],
                    onChanged: (v) {
                      if (v == null) return;
                      store.setReminder(to: v);
                      scheduleReminders(store);
                    },
                  ),
                ]),
            ]),
            Sheet(title: 'الموقع', children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('حفظ مكان كل مصروف'),
                subtitle: const Text('يُخزَّن على جهازك ويُرفع مع مزامنتك فقط؛ يظهر في التقارير أكثر الأماكن إنفاقاً'),
                value: store.saveLoc,
                onChanged: (v) async {
                  if (v && !await ensureLocationPermission()) {
                    if (context.mounted) _snack(context, 'لم يُمنح إذن الموقع');
                    return;
                  }
                  store.setFlags(saveLoc: v);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تنبيه عند الوصول لمكان صرفت فيه كثيراً'),
                subtitle: const Text('يعمل بإشعار دائم ويستهلك بطارية أكثر. يحتاج وجود 3 مصاريف مسجّلة بمواقعها في المكان نفسه'),
                value: store.placeAlerts,
                onChanged: (v) async {
                  if (v && !await ensureLocationPermission()) {
                    if (context.mounted) _snack(context, 'لم يُمنح إذن الموقع');
                    return;
                  }
                  await store.setFlags(placeAlerts: v, saveLoc: v ? true : null);
                  syncPlaceAlerts(store);
                },
              ),
            ]),
            Sheet(title: 'قراءة إشعارات البنك', children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('اكتشاف العمليات من الإشعارات'),
                subtitle: const Text('يلتقط فقط إشعارات فيها مبلغ بالدينار وكلمة دفع/سحب/إيداع، ويعرضها لك لتوافق عليها قبل التسجيل. لا يُرسل شيء خارج جهازك'),
                value: store.notifRead,
                onChanged: (v) => store.setFlags(notifRead: v),
              ),
              if (store.notifRead)
                FutureBuilder<bool>(
                  future: notifAccessEnabled(),
                  builder: (context, snap) => Row(children: [
                    Expanded(child: Text(snap.data == true ? 'إذن الوصول للإشعارات: مفعّل ✓' : 'إذن الوصول للإشعارات: غير مفعّل')),
                    OutlinedButton(onPressed: openNotifAccessSettings, child: const Text('فتح الإعدادات')),
                  ]),
                ),
            ]),
            Sheet(title: 'السحابة والمجتمع', children: [
              if (!cloudConfigured)
                const Text('لم تُضبط بيانات Supabase بعد (ملف lib/config.dart)، فالمزامنة والمجتمع معطّلان.'),
              if (cloudConfigured) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('اسمي في المجتمع'),
                  subtitle: Text(store.name.isEmpty ? 'غير محدد' : store.name),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editName(context),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('المشاركة في الترتيب العام'),
                  subtitle: const Text('يظهر اسمك وأيام التزامك ونسبة استهلاك ميزانيتك فقط'),
                  value: store.shareBoard,
                  onChanged: (v) {
                    if (v && store.name.isEmpty) {
                      _snack(context, 'اختر اسماً أولاً');
                      return;
                    }
                    store.setFlags(shareBoard: v);
                  },
                ),
                Text(Cloud.email != null ? 'الحساب: ${Cloud.email}' : 'الحساب: مجهول (بياناتك مرتبطة بهذا التثبيت فقط)'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.sync),
                    label: const Text('مزامنة الآن'),
                    onPressed: () async {
                      final err = await Cloud.sync(store);
                      if (context.mounted) _snack(context, err ?? 'تمت المزامنة ✓');
                    },
                  ),
                  OutlinedButton(onPressed: () => _account(context), child: Text(Cloud.email != null ? 'خروج' : 'إنشاء حساب / دخول')),
                ]),
              ],
            ]),
            Sheet(title: 'بياناتك', children: [
              const Text('بياناتك محفوظة على هذا الجهاز فقط في هذه النسخة.'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('حذف كل البيانات'),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('حذف كل البيانات؟'),
                      content: const Text('لا يمكن التراجع عن هذا الإجراء.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                      ],
                    ),
                  );
                  if (ok == true) store.clearAll();
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
