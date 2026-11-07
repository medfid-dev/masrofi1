import 'package:flutter/material.dart';
import 'store.dart';
import 'home_screen.dart';
import 'add_screen.dart';
import 'budget_screen.dart';
import 'report_screen.dart';
import 'quick_add.dart';
import 'community_screen.dart';
import 'cloud.dart';
import 'notif_reader.dart';
import 'places.dart';
import 'updater.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(MasrofiApp(store: store));
  Future(() async {
    await initQuickAdd(store); // إشعار الإضافة السريعة والتذكيرات
    await Cloud.init();
    await drainNotifications(store);
    await Cloud.sync(store);
    await syncPlaceAlerts(store);
  });
}

class MasrofiApp extends StatelessWidget {
  final AppStore store;
  const MasrofiApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F8F6B);
    ThemeData theme(Brightness b) {
      final cs = ColorScheme.fromSeed(seedColor: seed, brightness: b);
      return ThemeData(
        colorScheme: cs,
        useMaterial3: true,
        scaffoldBackgroundColor: cs.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: cs.surfaceContainerLow,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cs.surfaceContainerHigh,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 66,
          backgroundColor: cs.surfaceContainer,
          indicatorColor: cs.primaryContainer,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        ),
      );
    }

    return MaterialApp(
      title: 'مصروفي',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: ThemeMode.system,
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Shell(store: store),
    );
  }
}

class Shell extends StatefulWidget {
  final AppStore store;
  const Shell({super.key, required this.store});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) promptUpdate(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await widget.store.reload();
    await drainNotifications(widget.store);
    await Cloud.sync(widget.store);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        body: IndexedStack(
          index: i,
          children: [
            HomeScreen(store: s),
            AddScreen(store: s, onSaved: () => setState(() => i = 0)),
            BudgetScreen(store: s),
            ReportScreen(store: s),
            i == 4 ? CommunityScreen(store: s) : const SizedBox.shrink(), // تحميل كسول
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (n) => setState(() => i = n),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'إضافة'),
            NavigationDestination(icon: Icon(Icons.track_changes_outlined), selectedIcon: Icon(Icons.track_changes), label: 'الميزانية'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'التقارير'),
            NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'المجتمع'),
          ],
        ),
      ),
    );
  }
}
