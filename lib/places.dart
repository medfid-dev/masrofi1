import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'models.dart';
import 'quick_add.dart';
import 'store.dart';

Future<bool> ensureLocationPermission() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  } catch (_) {
    return false;
  }
}

/// موقع حالي أو آخر موقع معروف، أو null
Future<Position?> currentPos() async {
  try {
    if (!await ensureLocationPermission()) return null;
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 6)),
    );
  } catch (_) {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}

StreamSubscription<Position>? _sub;
final Map<String, DateTime> _cool = {};

/// يشغّل/يوقف مراقبة الأماكن حسب الإعداد (تعمل بإشعار دائم لأن أندرويد يشترط ذلك)
Future<void> syncPlaceAlerts(AppStore s) async {
  await _sub?.cancel();
  _sub = null;
  if (!s.placeAlerts) return;
  if (!await ensureLocationPermission()) return;
  _sub = Geolocator.getPositionStream(
    locationSettings: AndroidSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 60,
      intervalDuration: const Duration(minutes: 1),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'مصروفي',
        notificationText: 'تنبيهات الأماكن مفعّلة',
        setOngoing: true,
      ),
    ),
  ).listen((p) => _check(s, p), onError: (_) {});
}

void _check(AppStore s, Position p) {
  final near = s.txs.where((Tx t) =>
      !t.income &&
      t.lat != null &&
      t.lng != null &&
      Geolocator.distanceBetween(p.latitude, p.longitude, t.lat!, t.lng!) < 120);
  final list = near.toList();
  if (list.length < 3) return;
  final key = '${(p.latitude * 500).round()}_${(p.longitude * 500).round()}';
  final last = _cool[key];
  if (last != null && DateTime.now().difference(last) < const Duration(hours: 3)) return;
  _cool[key] = DateTime.now();
  final sum = list.fold<double>(0, (a, t) => a + t.amount);
  showPlaceAlert('صرفت هنا ${list.length} مرات بمجموع ${fm(sum)}. هل تحتاج الشراء فعلاً؟');
}
