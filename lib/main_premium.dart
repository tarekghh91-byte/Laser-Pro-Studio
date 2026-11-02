import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cloud_auth.dart';
import 'cloud_config.dart';
import 'main.dart' as core;

const bg = Color(0xFF0C0D0F);
const surface = Color(0xFF17191D);
const raised = Color(0xFF202329);
const gold = Color(0xFFD5B36A);
const goldDim = Color(0xFF9E8249);
const muted = Color(0xFF9A9DA5);
const line = Color(0xFF30343B);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: studioSupabaseUrl, anonKey: studioSupabasePublishableKey);
  runApp(const LaserStudioPremiumApp());
}

class LaserStudioPremiumApp extends StatefulWidget {
  const LaserStudioPremiumApp({super.key});
  @override State<LaserStudioPremiumApp> createState() => _LaserStudioPremiumAppState();
}

class _LaserStudioPremiumAppState extends State<LaserStudioPremiumApp> with WidgetsBindingObserver {
  String? uid;
  core.StudioStore? store;
  StreamSubscription<AuthState>? authSub;

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) store = core.StudioStore(ownerId: uid!)..load();
    authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      final next = event.session?.user.id;
      if (!mounted || next == uid) return;
      store?.dispose();
      setState(() { uid = next; store = next == null ? null : core.StudioStore(ownerId: next); });
      if (store != null) unawaited(store!.load());
    });
  }

  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(store?.syncNow() ?? Future<void>.value());
  }

  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    authSub?.cancel();
    store?.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    const scheme = ColorScheme.dark(primary: gold, onPrimary: bg, secondary: goldDim,
      surface: surface, onSurface: Color(0xFFF2F0EA), error: Color(0xFFE47B73));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LASER STUDIO PRO',
      theme: ThemeData(
        useMaterial3: true, brightness: Brightness.dark, colorScheme: scheme,
        scaffoldBackgroundColor: bg, dividerColor: line,
        cardTheme: CardThemeData(color: surface, elevation: 0, margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17),
            side: const BorderSide(color: line))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: raised, hintStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: gold, width: 1.4))),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface, indicatorColor: gold.withValues(alpha: .16)),
      ),
      home: store == null ? const CloudAuthScreen() :
        AnimatedBuilder(animation: store!, builder: (context, _) => PremiumWorkspace(store: store!)),
    );
  }
}

class PremiumWorkspace extends StatefulWidget {
  const PremiumWorkspace({super.key, required this.store});
  final core.StudioStore store;
  @override State<PremiumWorkspace> createState() => _PremiumWorkspaceState();
}

class _PremiumWorkspaceState extends State<PremiumWorkspace> {
  int selected = 0;
  String query = '';
  void go(int index) => setState(() { selected = index; query = ''; });

  @override Widget build(BuildContext context) {
    final s = widget.store;
    if (s.loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: gold)));
    if (s.error != null) return Scaffold(body: Center(child: Padding(
      padding: const EdgeInsets.all(24), child: Text(s.error!, textAlign: TextAlign.center))));
    final desktop = MediaQuery.sizeOf(context).width >= 980;
    final page = query.trim().isNotEmpty
      ? SearchPage(store: s, query: query, onOrders: () => go(1), onInventory: () => go(2))
      : switch (selected) {
          1 => core.OrdersPage(store: s, newOrder: () => core.showOrderForm(context, s)),
          2 => core.InventoryPage(store: s),
          3 => core.AccountsPage(store: s),
          _ => Dashboard(store: s, newOrder: () => core.showOrderForm(context, s), onNavigate: go),
        };
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(child: Row(children: [
          if (desktop) Sidebar(selected: selected, onSelect: go, syncStatus: s.syncStatus),
          Expanded(child: Column(children: [
            WorkspaceHeader(query: query, onSearch: (v) => setState(() => query = v),
              syncStatus: s.syncStatus, onSync: () async {
                await s.syncNow();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.syncStatus)));
              }, onLogout: () => Supabase.instance.client.auth.signOut(), desktop: desktop),
            Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(key: ValueKey('$selected-$query'), child: page))),
          ])),
        ])),
        bottomNavigationBar: desktop ? null : NavigationBar(
          selectedIndex: selected, onDestinationSelected: go,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'الطلبات'),
            NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'المخزون'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_rounded), label: 'الحسابات'),
          ]),
        floatingActionButton: selected <= 1 && query.isEmpty ? FloatingActionButton.extended(
          backgroundColor: gold, foregroundColor: bg,
          onPressed: () => core.showOrderForm(context, s),
          icon: const Icon(Icons.add_rounded), label: const Text('طلب جديد')) : null,
      ),
    );
  }
}

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.selected, required this.onSelect, required this.syncStatus});
  final int selected;
  final ValueChanged<int> onSelect;
  final String syncStatus;

  @override Widget build(BuildContext context) {
    const labels = ['نظرة عامة', 'الطلبات', 'المخزون', 'الحسابات'];
    const icons = [Icons.grid_view_rounded, Icons.receipt_long_rounded,
      Icons.inventory_2_rounded, Icons.account_balance_wallet_rounded];
    return Container(
      width: 252, padding: const EdgeInsets.fromLTRB(17, 24, 17, 17),
      decoration: const BoxDecoration(color: surface, border: Border(left: BorderSide(color: line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(
            color: gold.withValues(alpha: .12), borderRadius: BorderRadius.circular(13),
            border: Border.all(color: goldDim)), child: const Icon(Icons.auto_awesome, color: gold)),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LASER STUDIO', style: TextStyle(color: gold, fontSize: 14,
              letterSpacing: 1.1, fontWeight: FontWeight.w900)),
            Text('PRO WORKSPACE', style: TextStyle(color: muted, fontSize: 9, letterSpacing: 2)),
          ])),
        ]),
        const SizedBox(height: 34),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('مساحة العمل', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700))),
        const SizedBox(height: 9),
        for (var i = 0; i < labels.length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 5), child: Material(
            color: selected == i ? gold.withValues(alpha: .12) : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(borderRadius: BorderRadius.circular(13), onTap: () => onSelect(i),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: selected == i ? gold.withValues(alpha: .38) : Colors.transparent)),
                child: Row(children: [
                  Icon(icons[i], color: selected == i ? gold : muted, size: 19),
                  const SizedBox(width: 12),
                  Expanded(child: Text(labels[i], style: TextStyle(
                    color: selected == i ? gold : const Color(0xFFE5E2DB),
                    fontSize: 13, fontWeight: selected == i ? FontWeight.w800 : FontWeight.w500))),
                  if (selected == i) const Icon(Icons.circle, size: 6, color: gold),
                ])),
            ),
          )),
        const Spacer(),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
          color: raised, borderRadius: BorderRadius.circular(13), border: Border.all(color: line)),
          child: Row(children: [
            const Icon(Icons.cloud_sync_outlined, color: gold, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(syncStatus, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 10))),
          ])),
        const SizedBox(height: 12),
        const Text('DESIGNED FOR MAKERS', textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF666A72), fontSize: 9, letterSpacing: 1.6)),
      ]),
    );
  }
}

class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({super.key, required this.query, required this.onSearch,
    required this.syncStatus, required this.onSync, required this.onLogout, required this.desktop});
  final String query;
  final ValueChanged<String> onSearch;
  final String syncStatus;
  final VoidCallback onSync;
  final VoidCallback onLogout;
  final bool desktop;

  @override Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(desktop ? 28 : 14, 15, desktop ? 28 : 14, 14),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: line))),
    child: Row(children: [
      if (!desktop) const Padding(padding: EdgeInsets.only(left: 8),
        child: Icon(Icons.auto_awesome, color: gold, size: 20)),
      Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 580),
        child: TextField(onChanged: onSearch, textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: 'ابحث عن طلب، زبون، منتج أو مادة...',
            prefixIcon: const Icon(Icons.search_rounded, color: gold),
            suffixIcon: query.isEmpty ? null : IconButton(onPressed: () => onSearch(''),
              icon: const Icon(Icons.close_rounded)),
            contentPadding: const EdgeInsets.symmetric(vertical: 11))))),
      IconButton(tooltip: syncStatus, onPressed: onSync,
        icon: const Icon(Icons.sync_rounded, color: gold)),
      IconButton(tooltip: 'تسجيل الخروج', onPressed: onLogout,
        icon: const Icon(Icons.logout_rounded, color: muted)),
    ]),
  );
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.store, required this.newOrder, required this.onNavigate});
  final core.StudioStore store;
  final VoidCallback newOrder;
  final ValueChanged<int> onNavigate;

  @override Widget build(BuildContext context) {
    final open = store.orders.where((o) => o.status != 'تم التسليم').toList();
    final due = open.where((o) => !o.dueDate.isAfter(DateTime.now().add(const Duration(days: 1)))).toList();
    final low = store.materials.where((m) => m.quantity <= m.reorderLevel).toList();
    final debt = store.orders.fold<double>(0, (sum, o) => sum + (o.outstanding > 0 ? o.outstanding : 0));
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    return ListView(padding: EdgeInsets.fromLTRB(wide ? 28 : 15, 25, wide ? 28 : 15, 100),
      children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مركز القيادة', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
            SizedBox(height: 5),
            Text('كل ما يحتاج انتباهك في مساحة واحدة.', style: TextStyle(color: muted, fontSize: 12)),
          ])),
          if (wide) FilledButton.icon(onPressed: newOrder,
            style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: bg,
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14)),
            icon: const Icon(Icons.add_rounded), label: const Text('طلب جديد')),
        ]),
        const SizedBox(height: 21),
        Container(padding: const EdgeInsets.all(21), decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: [Color(0xFF332A1B), Color(0xFF1B1C20), Color(0xFF141518)]),
          border: Border.all(color: goldDim.withValues(alpha: .7))),
          child: Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('LASER STUDIO PRO', style: TextStyle(color: gold, fontSize: 10,
                fontWeight: FontWeight.w900, letterSpacing: 2)),
              SizedBox(height: 9),
              Text('ورشتك، تحت السيطرة.', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              SizedBox(height: 7),
              Text('إدارة أوضح. خطوات أقل. متابعة أسرع.', style: TextStyle(color: Color(0xFFC8C0AE), fontSize: 11)),
            ])),
            Container(width: 55, height: 55, decoration: BoxDecoration(
              color: gold.withValues(alpha: .12), shape: BoxShape.circle,
              border: Border.all(color: goldDim)),
              child: const Icon(Icons.auto_awesome, color: gold, size: 27)),
          ])),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final columns = c.maxWidth >= 950 ? 4 : 2;
          final items = [
            _Metric('طلبات قيد العمل', '${open.length}', Icons.precision_manufacturing_outlined, 'تحتاج متابعة'),
            _Metric('تسليم قريب', '${due.length}', Icons.event_available_outlined, 'اليوم أو خلال 24 ساعة'),
            _Metric('مبالغ متبقية', core.money(debt), Icons.payments_outlined, 'بحسب الدفعات المسجلة'),
            _Metric('مواد منخفضة', '${low.length}', Icons.inventory_2_outlined, 'تحت حد التنبيه'),
          ];
          return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns, crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: columns == 4 ? 1.75 : 1.6,
            children: items.map((m) => MetricCard(metric: m)).toList());
        }),
        const SizedBox(height: 22),
        const Text('اختصارات العمل', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('أهم المهام من دون التنقل بين صفحات كثيرة.', style: TextStyle(color: muted, fontSize: 11)),
        const SizedBox(height: 11),
        LayoutBuilder(builder: (context, c) {
          final columns = c.maxWidth >= 950 ? 3 : 2;
          final actions = [
            _Action('طلب جديد', 'سجّل طلب زبون', Icons.add_shopping_cart_rounded, newOrder),
            _Action('متابعة الطلبات', 'افتح مراحل العمل', Icons.receipt_long_rounded, () => onNavigate(1)),
            _Action('إدارة المواد', 'الكميات والتكلفة', Icons.inventory_2_rounded, () => onNavigate(2)),
          ];
          return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns, crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: 2.05, children: actions.map((a) => ActionCard(action: a)).toList());
        }),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, c) {
          final left = AttentionCard(title: 'تحتاج انتباهك', subtitle: 'الطلبات الأقرب لموعد التسليم',
            icon: Icons.notifications_active_outlined,
            child: due.isEmpty ? const EmptyState('لا توجد تسليمات قريبة مسجلة.') :
              Column(children: due.take(4).map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 8), child: core.OrderTile(order: o, store: store))).toList()));
          final right = AttentionCard(title: 'مراقبة المخزون', subtitle: 'مواد وصلت إلى حد التنبيه',
            icon: Icons.warning_amber_rounded,
            child: low.isEmpty ? const EmptyState('المواد المسجلة فوق حد التنبيه.') :
              Column(children: low.take(5).map((m) => Container(margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: raised,
                  borderRadius: BorderRadius.circular(11)),
                child: Row(children: [
                  const Icon(Icons.inventory_2_outlined, color: gold, size: 17),
                  const SizedBox(width: 9),
                  Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  Text('${m.quantity.toStringAsFixed(1)} ${m.unit}', style: const TextStyle(color: muted, fontSize: 10)),
                ]))).toList()));
          if (c.maxWidth < 900) return Column(children: [left, const SizedBox(height: 11), right]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: left), const SizedBox(width: 11), Expanded(child: right)]);
        }),
        const SizedBox(height: 14),
        const Text('المؤشرات مبنية على البيانات المسجلة حالياً؛ لا تمثل تنبؤات أو تنفيذ تلقائي.',
          style: TextStyle(color: muted, fontSize: 10)),
      ]);
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon, this.note);
  final String label, value, note;
  final IconData icon;
}
class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.metric});
  final _Metric metric;
  @override Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(metric.icon, color: gold, size: 19),
        Text(metric.value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(metric.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          Text(metric.note, style: const TextStyle(fontSize: 9, color: muted)),
        ]),
      ])));
}

class _Action {
  const _Action(this.title, this.subtitle, this.icon, this.onTap);
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
}
class ActionCard extends StatelessWidget {
  const ActionCard({super.key, required this.action});
  final _Action action;
  @override Widget build(BuildContext context) => Material(
    color: surface, borderRadius: BorderRadius.circular(14),
    child: InkWell(onTap: action.onTap, borderRadius: BorderRadius.circular(14),
      child: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(
            color: gold.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)),
            child: Icon(action.icon, color: gold, size: 18)),
          const SizedBox(width: 9),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(action.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
              const SizedBox(height: 3),
              Text(action.subtitle, style: const TextStyle(color: muted, fontSize: 9)),
            ])),
          const Icon(Icons.arrow_back_ios_new_rounded, color: muted, size: 11),
        ]))));
}

class AttentionCard extends StatelessWidget {
  const AttentionCard({super.key, required this.title, required this.subtitle,
    required this.icon, required this.child});
  final String title, subtitle;
  final IconData icon;
  final Widget child;
  @override Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Icon(icon, color: gold, size: 18), const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)))]),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: muted, fontSize: 10)),
      const SizedBox(height: 12), child,
    ])));
}
class EmptyState extends StatelessWidget {
  const EmptyState(this.label, {super.key});
  final String label;
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: raised, borderRadius: BorderRadius.circular(11)),
    child: Row(children: [const Icon(Icons.check_circle_outline, color: gold, size: 17),
      const SizedBox(width: 8), Expanded(child: Text(label, style: const TextStyle(color: muted, fontSize: 11)))]));
}

String _normalizeArabic(String value) => value.toLowerCase()
  .replaceAll('أ','ا').replaceAll('إ','ا').replaceAll('آ','ا')
  .replaceAll('ة','ه').replaceAll('ى','ي').replaceAll('ؤ','و')
  .replaceAll('ئ','ي').replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '').trim();

class SearchPage extends StatelessWidget {
  const SearchPage({super.key, required this.store, required this.query,
    required this.onOrders, required this.onInventory});
  final core.StudioStore store;
  final String query;
  final VoidCallback onOrders, onInventory;
  @override Widget build(BuildContext context) {
    final q = _normalizeArabic(query).replaceAll(
      RegExp(r'\\b(وين|اعرض|ورجيني|جيبلي|ابحث عن|دور على|الطلب|طلبات|طلب|الزبون|العميل|اسم)\\b'), '').trim();
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final commandReady = q.contains('جاهز') || q.contains('جاهزه');
    final commandActive = q.contains('قيد التنفيذ') || q.contains('عم ينفذ') || q.contains('شغال');
    final commandDelivered = q.contains('تم التسليم') || q.contains('تسلم') || q.contains('مستلم');
    final commandLate = q.contains('متاخر') || q.contains('تاخر');
    final commandDue = q.contains('لازم سلم') || q.contains('تسليم اليوم') || q.contains('موعد') || q == 'اليوم';
    final commandStock = q.contains('مخزون') || q.contains('مواد') || q.contains('ناقص') || q.contains('اشتري');
    final orders = store.orders.where((o) {
      if (commandReady) return o.status == 'جاهز';
      if (commandActive) return o.status == 'قيد التنفيذ' || o.status == 'جديد';
      if (commandDelivered) return o.status == 'تم التسليم';
      if (commandLate) return o.status != 'تم التسليم' && o.dueDate.isBefore(todayOnly);
      if (commandDue) return o.status != 'تم التسليم' && !o.dueDate.isAfter(todayOnly.add(const Duration(days: 1)));
      return _normalizeArabic(o.customer).contains(q) || _normalizeArabic(o.product).contains(q) || o.id.toLowerCase().contains(q);
    }).toList()..sort((a,b) => a.dueDate.compareTo(b.dueDate));
    final materials = store.materials.where((m) => commandStock
      ? (m.quantity <= m.reorderLevel || q.contains('مخزون') || q.contains('مواد'))
      : _normalizeArabic(m.name).contains(q) || _normalizeArabic(m.category).contains(q)).toList();
    final commandLabel = commandReady ? 'الطلبات الجاهزة' : commandActive ? 'الطلبات قيد التنفيذ'
      : commandDelivered ? 'الطلبات المسلّمة' : commandLate ? 'الطلبات المتأخرة'
      : commandDue ? 'التسليمات القريبة' : commandStock ? 'المخزون والمواد' : 'نتائج البحث';
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(commandLabel, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      Text('فهمت طلبك: «$query»', style: const TextStyle(color: muted)),
      const SizedBox(height: 20),
      Text('الطلبات (${orders.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(height: 9),
      if (orders.isEmpty) const EmptyState('لا توجد طلبات مطابقة.'),
      for (final o in orders.take(15)) Padding(padding: const EdgeInsets.only(bottom: 8),
        child: core.OrderTile(order: o, store: store)),
      const SizedBox(height: 16),
      Text('المواد (${materials.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(height: 9),
      if (materials.isEmpty) const EmptyState('لا توجد مواد مطابقة.'),
      for (final m in materials) Card(child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined, color: gold), title: Text(m.name),
        subtitle: Text('${m.category} • ${m.quantity.toStringAsFixed(2)} ${m.unit}'),
        onTap: onInventory)),
      TextButton.icon(onPressed: onOrders, icon: const Icon(Icons.receipt_long_rounded),
        label: const Text('فتح كل الطلبات')),
    ]);
  }
}
