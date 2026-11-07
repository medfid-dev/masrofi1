import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'config.dart';

class UpdateInfo {
  final int build;
  final String url;
  const UpdateInfo(this.build, this.url);
}

/// يفحص آخر إصدار منشور؛ يرجع null إن لم يوجد أحدث أو تعذّر الفحص
Future<UpdateInfo?> checkUpdate() async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await c.getUrl(Uri.parse('https://api.github.com/repos/$updateRepo/releases/latest'));
    req.headers.set('Accept', 'application/vnd.github+json');
    final res = await req.close().timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
    final n = int.tryParse(((j['tag_name'] as String?) ?? '').replaceAll('build-', ''));
    if (n == null || n <= buildNumber) return null;
    for (final a in (j['assets'] as List? ?? [])) {
      final m = a as Map<String, dynamic>;
      if ((m['name'] as String?)?.endsWith('.apk') ?? false) {
        return UpdateInfo(n, m['browser_download_url'] as String);
      }
    }
  } catch (_) {
  } finally {
    c.close();
  }
  return null;
}

Future<void> _downloadAndInstall(UpdateInfo u, ValueNotifier<double?> progress) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/masrofi-update.apk');
  final c = HttpClient();
  try {
    final req = await c.getUrl(Uri.parse(u.url));
    final res = await req.close();
    final total = res.contentLength;
    var got = 0;
    final sink = f.openWrite();
    await for (final chunk in res) {
      sink.add(chunk);
      got += chunk.length;
      if (total > 0) progress.value = got / total;
    }
    await sink.close();
  } finally {
    c.close();
  }
  await OpenFilex.open(f.path, type: 'application/vnd.android.package-archive');
}

bool _askedThisLaunch = false;

/// يعرض نافذة التحديث إن وُجد إصدار أحدث. manual=true يُظهر رسالة حتى لو لا تحديث.
Future<void> promptUpdate(BuildContext context, {bool manual = false}) async {
  if (!manual) {
    if (_askedThisLaunch) return;
    _askedThisLaunch = true;
  }
  final u = await checkUpdate();
  if (!context.mounted) return;
  if (u == null) {
    if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أنت على آخر إصدار')));
    }
    return;
  }
  final progress = ValueNotifier<double?>(null);
  var busy = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('يوجد تحديث جديد'),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [
            Text(busy ? 'جارٍ التنزيل…' : 'نسخة ${u.build} جاهزة. بياناتك تبقى كما هي.'),
            if (busy) ...[const SizedBox(height: 12), LinearProgressIndicator(value: v)],
          ]),
        ),
        actions: [
          if (!busy) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لاحقاً')),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setS(() => busy = true);
                    try {
                      await _downloadAndInstall(u, progress);
                    } catch (_) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تعذّر التنزيل')));
                      }
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
            child: const Text('تحديث'),
          ),
        ],
      ),
    ),
  );
}
