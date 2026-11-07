"""يطبّق إعدادات أندرويد المطلوبة على مشروع Flutter المُنشأ (بيان التطبيق وgradle)."""
import re, sys, pathlib

app = pathlib.Path(sys.argv[1])  # مجلد المشروع

# ---- AndroidManifest.xml ----
mf = app / 'android/app/src/main/AndroidManifest.xml'
m = mf.read_text(encoding='utf-8')
perms = ''.join(
    f'    <uses-permission android:name="android.permission.{p}"/>\n'
    for p in ('POST_NOTIFICATIONS', 'RECEIVE_BOOT_COMPLETED', 'INTERNET', 'ACCESS_FINE_LOCATION',
              'ACCESS_COARSE_LOCATION', 'FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_LOCATION')
    if p not in m
)
m = m.replace('<application', perms + '    <application', 1) if perms else m
recv = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''
svc = '''
        <service android:name=".MasrofiListener" android:exported="true" android:label="مصروفي"
            android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
            <intent-filter>
                <action android:name="android.service.notification.NotificationListenerService"/>
            </intent-filter>
        </service>
'''
if 'MasrofiListener' not in m:
    m = m.replace('</application>', svc + '    </application>', 1)
if 'ActionBroadcastReceiver' not in m:
    m = m.replace('</application>', recv + '    </application>', 1)
mf.write_text(m, encoding='utf-8')

# ---- build.gradle(.kts) ----
for name in ('build.gradle.kts', 'build.gradle'):
    g = app / 'android/app' / name
    if g.exists():
        break
t = g.read_text(encoding='utf-8')
kts = name.endswith('.kts')
if kts:
    t = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', t, count=1)
    t += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
else:
    t = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        coreLibraryDesugaringEnabled true', t, count=1)
    t += '\ndependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"\n}\n'
g.write_text(t, encoding='utf-8')
print('patched', mf, g)

# ---- Kotlin: قراءة الإشعارات ----
import glob
main = glob.glob(str(app / 'android/app/src/main/kotlin/**/MainActivity.kt'), recursive=True)[0]
pkg = re.search(r'^package\s+([\w.]+)', pathlib.Path(main).read_text(encoding='utf-8'), re.M).group(1)
d = pathlib.Path(main).parent
(d / 'MainActivity.kt').write_text(f'''package {pkg}

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {{
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "masrofi/notifs").setMethodCallHandler {{ call, result ->
            when (call.method) {{
                "isEnabled" -> {{
                    val s = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: ""
                    result.success(s.contains(packageName))
                }}
                "openSettings" -> {{
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }}
                "drain" -> result.success(MasrofiListener.drain(this))
                else -> result.notImplemented()
            }}
        }}
    }}
}}
''', encoding='utf-8')
(d / 'MasrofiListener.kt').write_text(f'''package {pkg}

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

class MasrofiListener : NotificationListenerService() {{
    override fun onNotificationPosted(sbn: StatusBarNotification) {{
        if (sbn.packageName == packageName) return
        val e = sbn.notification.extras ?: return
        val title = e.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = (e.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: e.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: ""
        val full = "$title $text".trim()
        if (full.isEmpty() || !full.any {{ it.isDigit() }}) return
        if (!CURRENCY.containsMatchIn(full)) return // نلتقط ما فيه عملة فقط
        val key = sbn.packageName + "|" + full.hashCode()
        synchronized(LOCK) {{
            if (seen.contains(key)) return
            seen.add(key)
            if (seen.size > 60) seen.remove(seen.first())
            val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val arr = JSONArray(prefs.getString("pending", "[]"))
            val o = JSONObject()
            o.put("text", full)
            o.put("at", sbn.postTime)
            arr.put(o)
            val trimmed = JSONArray()
            for (i in maxOf(0, arr.length() - 50) until arr.length()) trimmed.put(arr.get(i))
            prefs.edit().putString("pending", trimmed.toString()).apply()
        }}
    }}

    companion object {{
        private const val PREFS = "masrofi_notifs"
        private val LOCK = Any()
        private val seen = LinkedHashSet<String>()
        private val CURRENCY = Regex("(?i)(dzd|\\\\bda\\\\b|د\\\\.ج|دج|دينار)")

        fun drain(ctx: Context): String = synchronized(LOCK) {{
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val s = prefs.getString("pending", "[]") ?: "[]"
            prefs.edit().putString("pending", "[]").apply()
            s
        }}
    }}
}}
''', encoding='utf-8')
print('kotlin written in', d)
