# مصروفي: Flutter (المرحلة 1، أندرويد)

لم يُجرَّب هذا الكود على جهاز أو محاكٍ. قد تحتاج لإصلاح أخطاء صغيرة عند أول تشغيل.

## التشغيل
1. ثبّت Flutter: https://docs.flutter.dev/get-started/install
2. أنشئ مشروعاً جديداً بنفس الاسم تماماً:
   flutter create --org com.example --project-name masrofi --platforms=android masrofi_app
3. ادخل المجلد وأضف الاعتماديات:
   cd masrofi_app
   flutter pub add shared_preferences
   flutter pub add flutter_local_notifications:^18.0.1
   flutter pub add timezone
4. احذف lib/main.dart وtest/widget_test.dart الافتراضيين، ثم انسخ مجلدي lib/ وtest/ من هذا الأرشيف فوقها.
5. وصّل هاتفك (تصحيح USB) أو شغّل محاكياً، ثم:
   flutter run
6. الاختبارات: flutter test
7. ملف APK للتثبيت: flutter build apk --release
   (الناتج في build/app/outputs/flutter-apk/app-release.apk)

## ما فيه
الدخل والمصاريف، الفئات (مع فئات مخصصة)، الميزانية لكل فئة مع تنبيهات 80%، تقارير يومية/أسبوعية/شهرية،
شجرة الثروة وسلسلة الالتزام، مؤشر الندم (بعد 24 ساعة)، حاسبة ساعات العمل، زر الطوارئ، شخصيات المساعد.
التخزين محلي (shared_preferences) ويعمل بدون إنترنت.

## ليس فيه بعد (المراحل التالية)
المزامنة مع Supabase، قراءة الإشعارات، إشعارات الندم الفعلية، الموقع الجغرافي، المجتمع والتحديات.

## الإضافة السريعة من الإشعار (بدون فتح التطبيق)
يظهر إشعار دائم في شريط الإشعارات فيه زر «سجّل مصروفاً». تضغطه وتكتب مثلاً:
  2500 قهوة      -> مصروف 2500 د.ج في فئة طعام
  تاكسي 300      -> مواصلات
  +50000 راتب    -> دخل
بعد الإرسال يتغير نص الإشعار إلى تأكيد التسجيل. يمكن إيقافه من الإعدادات.

### إعداد أندرويد (مطلوب مرة واحدة)
1) في android/app/src/main/AndroidManifest.xml
   - فوق وسم <application> أضف:
       <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   - داخل وسم <application> أضف:
       <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
2) في android/app/build.gradle.kts (أو build.gradle):
   android { compileOptions { isCoreLibraryDesugaringEnabled = true } }
   dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }
3) عند أول تشغيل اسمح بالإشعارات.

### قيود معروفة
- بعد إعادة تشغيل الهاتف لا يظهر الإشعار حتى تفتح التطبيق مرة واحدة.
- بعض الأجهزة (شاومي، سامسونغ...) تقيّد التطبيقات في الخلفية: استثنِ التطبيق من توفير البطارية.
- إن تعطل الإصدار النهائي (release)، جرّب تعطيل التصغير: isMinifyEnabled = false.

## التذكير كل ساعتين
إشعار منبثق (heads-up) كل ساعتين بين ساعتين تختارهما من الإعدادات (الافتراضي 10:00 إلى 22:00)،
فيه خانة كتابة مباشرة وزر «لم أصرف شيئاً». يتكرر يومياً ويُعاد جدولته بعد إعادة تشغيل الهاتف.
التوقيت تقريبي (قد يتأخر دقائق) لأنه لا يستخدم إذن المنبّه الدقيق.

### إضافات مطلوبة في AndroidManifest.xml
فوق وسم <application>:
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
داخل وسم <application> (بجوار ActionBroadcastReceiver):
    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
      <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
      </intent-filter>
    </receiver>

## بناء APK دون تثبيت أي برنامج (عبر GitHub)
1. أنشئ مستودعاً خاصاً على github.com وارفع محتويات هذا المجلد (زر Add file ← Upload files).
2. تبويب Actions ← build-apk ← Run workflow، وانتظر نحو 5–10 دقائق.
3. افتح التشغيل المكتمل ونزّل الملف masrofi-apk من قسم Artifacts، فكّ ضغطه، ثم ثبّت app-release.apk على هاتفك (اسمح بالتثبيت من مصدر غير معروف).
هذه الخطوات تُجري إعدادات أندرويد أعلاه تلقائياً (سكربت tool/patch_android.py).


## الميزات الجديدة (المرحلة 2)
- **سؤال الندم بإشعار:** بعد 24 ساعة من كل مصروف يصلك إشعار بزرّين «نادم/لا».
- **تاريخ قديم:** زر التاريخ في شاشة الإضافة.
- **قراءة إشعارات البنك:** من الإعدادات فعّل الخيار ثم امنح «الوصول إلى الإشعارات». تظهر العمليات المكتشفة في الرئيسية لتوافق عليها أو تتجاهلها (تُلتقط فقط إشعارات فيها مبلغ بالدينار وكلمة دفع/سحب/إيداع).
- **الموقع:** حفظ مكان كل مصروف + تقرير «أكثر الأماكن إنفاقاً» + تنبيه عند الوصول لمكان صرفت فيه 3 مرات فأكثر (يعمل بإشعار دائم).
- **السحابة والمجتمع (Supabase):** مزامنة بين أجهزتك، ترتيب عام (اسم + أيام التزام فقط)، وتحديات مع الأصدقاء برمز من 6 أحرف.

### تفعيل السحابة (مرة واحدة)
1. في Supabase: SQL Editor ← الصق محتوى supabase/schema.sql ← Run.
2. Authentication ← Providers ← فعّل Anonymous Sign-Ins (وعطّل Confirm email للتجربة السهلة).
3. ضع الرابط ومفتاح anon في lib/config.dart.
بدون ذلك يعمل التطبيق محلياً كما كان وتُعطَّل شاشة المجتمع فقط.

### ملاحظات
- لم يُجرَّب هذا الكود على جهاز؛ سكربت tool/patch_android.py يضيف أيضاً كود Kotlin لقراءة الإشعارات وأذونات الموقع والإنترنت.
- حذف العملية على جهاز يُحذفها من بقية أجهزتك عند المزامنة. الإعدادات تُدمج بالأحدث.
