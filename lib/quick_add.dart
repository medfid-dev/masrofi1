import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';
import 'parse_entry.dart';
import 'places.dart';
import 'store.dart';

const int _notifId = 1001;
const String _hint = 'اكتب المبلغ والوصف، مثال: 2500 قهوة (ضع + للدخل)';
final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
const InitializationSettings _initSettings =
    InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));

/// إشعار دائم فيه خانة كتابة: تسجّل المصروف من شريط الإشعارات دون فتح التطبيق
Future<void> showQuickAdd({String body = _hint}) async {
  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      'quick_add',
      'إضافة سريعة',
      channelDescription: 'تسجيل المصاريف من الإشعار دون فتح التطبيق',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'add',
          'سجّل مصروفاً',
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(label: 'مثال: 2500 قهوة'),
          ],
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ],
    ),
  );
  await _plugin.show(_notifId, 'مصروفي', body, details);
}

Future<void> cancelQuickAdd() => _plugin.cancel(_notifId);

/// تأكيد التسجيل: في الإشعار الدائم إن كان مفعّلاً، وإلا إشعار مؤقت يختفي بعد 4 ثوانٍ
Future<void> _notify(AppStore s, String body) async {
  if (s.quickAdd) {
    await showQuickAdd(body: body);
    return;
  }
  final d = NotificationDetails(
    android: AndroidNotificationDetails(
      'confirm',
      'تأكيد التسجيل',
      importance: Importance.low,
      priority: Priority.low,
      timeoutAfter: 4000,
      showWhen: false,
    ),
  );
  await _plugin.show(1002, 'مصروفي', body, d);
}

const int _remindBase = 2000;

/// تذكير كل ساعتين ضمن النافذة المختارة، يتكرر يومياً، وفيه خانة كتابة مباشرة
Future<void> scheduleReminders(AppStore s) async {
  for (var h = 0; h < 24; h++) {
    await _plugin.cancel(_remindBase + h);
  }
  if (!s.remind) return;
  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminder',
      'تذكير بالمصاريف',
      channelDescription: 'تذكير كل ساعتين بتسجيل ما صرفته',
      importance: Importance.high,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'add',
          'سجّل الآن',
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(label: 'مثال: 2500 قهوة'),
          ],
          showsUserInterface: false,
        ),
        AndroidNotificationAction('skip', 'لم أصرف شيئاً', showsUserInterface: false),
      ],
    ),
  );
  final now = DateTime.now();
  for (var h = s.remindFrom; h <= s.remindTo; h += 2) {
    var t = DateTime(now.year, now.month, now.day, h);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      _remindBase + h,
      'هل صرفت شيئاً؟',
      'سجّل ما صرفته في الساعتين الماضيتين، مثال: 2500 قهوة',
      tz.TZDateTime.from(t, tz.UTC),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}

int regretNotifId(String txId) =>
    10000 + (int.tryParse(txId.length > 6 ? txId.substring(txId.length - 6) : txId) ?? 0);

/// إشعار بعد 24 ساعة من المصروف يسأل: هل ندمت؟ (بزرّين، دون فتح التطبيق)
Future<void> scheduleRegret(Tx t) async {
  if (t.income) return;
  try {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'regret',
        'مؤشر الندم',
        channelDescription: 'سؤال بعد 24 ساعة: هل ندمت على المصروف؟',
        importance: Importance.high,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('regret_yes', 'نادم 😞', showsUserInterface: false),
          AndroidNotificationAction('regret_no', 'لا 😊', showsUserInterface: false),
        ],
      ),
    );
    await _plugin.zonedSchedule(
      regretNotifId(t.id),
      'هل ندمت على هذا المصروف؟',
      '${t.note.isEmpty ? t.cat : t.note} — ${fm(t.amount)}',
      tz.TZDateTime.from(t.at.add(const Duration(hours: 24)), tz.UTC),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: t.id,
    );
  } catch (_) {}
}

Future<void> cancelRegret(String txId) async {
  try {
    await _plugin.cancel(regretNotifId(txId));
  } catch (_) {}
}

/// تنبيه مكان صرفت فيه كثيراً
Future<void> showPlaceAlert(String body) async {
  const d = NotificationDetails(
    android: AndroidNotificationDetails(
      'place',
      'تنبيه الأماكن',
      channelDescription: 'تنبيه عند الوصول إلى مكان صرفت فيه كثيراً',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );
  await _plugin.show(1003, 'انتبه لمصروفك 📍', body, d);
}

Future<AppStore> _storeFor(AppStore? store) async {
  if (store != null) return store;
  // نحن في عملية خلفية: نهيّئ الإضافة ونقرأ البيانات المحفوظة
  await _plugin.initialize(_initSettings);
  final s = AppStore();
  await s.load();
  return s;
}

Future<void> handleQuickAdd(NotificationResponse r, {AppStore? store}) async {
  if (r.actionId == 'regret_yes' || r.actionId == 'regret_no') {
    final id = r.payload;
    if (id == null) return;
    final s = await _storeFor(store);
    await s.markRegret(id, r.actionId == 'regret_yes');
    return;
  }
  if (r.actionId != 'add') return;
  final input = (r.input ?? '').trim();
  if (input.isEmpty) return;
  final s = await _storeFor(store);
  final e = parseQuickEntry(input, knownCats: [...AppStore.defaultCats, ...s.customCats]);
  if (e == null) {
    await _notify(s, 'لم أفهم «$input». اكتب مثلاً: 2500 قهوة');
    return;
  }
  final pos = (!e.income && s.saveLoc) ? await currentPos() : null;
  final t = Tx(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    income: e.income,
    amount: e.amount,
    cat: e.cat,
    note: e.note,
    at: DateTime.now(),
    lat: pos?.latitude,
    lng: pos?.longitude,
  );
  await s.add(t);
  await scheduleRegret(t);
  final sign = e.income ? '+' : '−';
  await _notify(s, 'تم تسجيل $sign${fm(e.amount)} — ${e.cat} ✓');
}

@pragma('vm:entry-point')
Future<void> quickAddBackground(NotificationResponse r) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await handleQuickAdd(r);
}

Future<void> initQuickAdd(AppStore store) async {
  tzdata.initializeTimeZones();
  await _plugin.initialize(
    _initSettings,
    onDidReceiveNotificationResponse: (r) => handleQuickAdd(r, store: store),
    onDidReceiveBackgroundNotificationResponse: quickAddBackground,
  );
  await _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  await scheduleReminders(store);
  if (store.quickAdd) {
    await showQuickAdd();
  } else {
    await cancelQuickAdd();
  }
}
