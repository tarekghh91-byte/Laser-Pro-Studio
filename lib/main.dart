import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cloud_config.dart';
import 'cloud_auth.dart';
import 'cloud_sync.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: studioSupabaseUrl,
    anonKey: studioSupabasePublishableKey,
  );
  runApp(const LaserProApp());
}

const ink = Color(0xFF17191F);
const gold = Color(0xFFDAAF69);
const panel = Color(0xFF232630);

// Editable later in Settings. This is the current project estimate.
const double laserWatts = 216;
const double electricityPerKwh = 0.90;
double laserElectricity(double minutes) =>
    minutes * laserWatts / 1000 / 60 * electricityPerKwh;

class UsedMaterial {
  UsedMaterial({required this.id, required this.name, required this.unit,
    required this.category, required this.amount, required this.unitCost,
    this.widthCm, this.heightCm});
  final String id, name, unit, category;
  final double amount, unitCost;
  final double? widthCm, heightCm;
  double get cost => amount * unitCost;
  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'unit': unit, 'category': category,
    'amount': amount, 'unitCost': unitCost,
    'widthCm': widthCm, 'heightCm': heightCm,
  };
  factory UsedMaterial.fromJson(Map<String, dynamic> j) => UsedMaterial(
    id: j['id'] as String? ?? '', name: j['name'] as String? ?? '',
    unit: j['unit'] as String? ?? 'قطعة',
    category: j['category'] as String? ?? 'مواد',
    amount: (j['amount'] as num? ?? 0).toDouble(),
    unitCost: (j['unitCost'] as num? ?? 0).toDouble(),
    widthCm: (j['widthCm'] as num?)?.toDouble(),
    heightCm: (j['heightCm'] as num?)?.toDouble(),
  );
}

class Order {
  Order({required this.id, required this.customer, required this.product,
    required this.dueDate, required this.price, required this.paid,
    required this.materialCost, required this.status, required this.createdAt,
    this.notes = '', this.phone = '', this.address = '', this.quantity = 1,
    DateTime? orderDate, List<UsedMaterial>? usedMaterials,
    this.laserMinutes = 0, this.electricCost = 0, this.inventoryDeducted = false})
      : orderDate = orderDate ?? createdAt, usedMaterials = usedMaterials ?? [];
  final String id;
  String customer;
  String product;
  DateTime dueDate;
  double price;
  double paid;
  double materialCost;
  String status;
  DateTime createdAt;
  String notes;
  String phone;
  String address;
  int quantity;
  DateTime orderDate;
  List<UsedMaterial> usedMaterials;
  double laserMinutes;
  double electricCost;
  bool inventoryDeducted;
  double get outstanding => price - paid;
  double get totalCost => materialCost + electricCost;
  double get grossMargin => price - totalCost;
  Map<String, dynamic> toJson() => {
    'id': id, 'customer': customer, 'product': product,
    'dueDate': dueDate.toIso8601String(), 'price': price, 'paid': paid,
    'materialCost': materialCost, 'status': status,
    'createdAt': createdAt.toIso8601String(), 'notes': notes,
    'phone': phone, 'address': address, 'quantity': quantity,
    'orderDate': orderDate.toIso8601String(),
    'usedMaterials': usedMaterials.map((e) => e.toJson()).toList(),
    'laserMinutes': laserMinutes, 'electricCost': electricCost,
    'inventoryDeducted': inventoryDeducted,
  };
  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'] as String, customer: j['customer'] as String,
    product: j['product'] as String,
    dueDate: DateTime.parse(j['dueDate'] as String),
    price: (j['price'] as num).toDouble(),
    paid: (j['paid'] as num).toDouble(),
    materialCost: (j['materialCost'] as num? ?? 0).toDouble(),
    status: j['status'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    notes: j['notes'] as String? ?? '',
    phone: j['phone'] as String? ?? '', address: j['address'] as String? ?? '',
    quantity: (j['quantity'] as num? ?? 1).toInt(),
    orderDate: DateTime.tryParse(j['orderDate'] as String? ?? '') ?? DateTime.parse(j['createdAt'] as String),
    usedMaterials: (j['usedMaterials'] as List<dynamic>? ?? [])
      .map((e) => UsedMaterial.fromJson(e as Map<String, dynamic>)).toList(),
    laserMinutes: (j['laserMinutes'] as num? ?? 0).toDouble(),
    electricCost: (j['electricCost'] as num? ?? 0).toDouble(),
    inventoryDeducted: j['inventoryDeducted'] as bool? ?? false,
  );
}

class Material {
  Material({required this.id, required this.name, required this.quantity,
    required this.unit, required this.reorderLevel, required this.unitCost,
    this.category = 'مواد', this.packUnits = 1});
  final String id;
  String name;
  double quantity;
  String unit;
  double reorderLevel;
  double unitCost;
  String category;
  double packUnits;
  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'quantity': quantity, 'unit': unit,
    'reorderLevel': reorderLevel, 'unitCost': unitCost, 'category': category,
    'packUnits': packUnits,
  };
  factory Material.fromJson(Map<String, dynamic> j) => Material(
    id: j['id'] as String, name: j['name'] as String,
    quantity: (j['quantity'] as num).toDouble(), unit: j['unit'] as String,
    reorderLevel: (j['reorderLevel'] as num).toDouble(),
    unitCost: (j['unitCost'] as num).toDouble(),
    category: j['category'] as String? ?? 'مواد',
    packUnits: (j['packUnits'] as num? ?? 1).toDouble(),
  );
}

class StudioStore extends ChangeNotifier {
  StudioStore({required this.ownerId}) : _cloud = CloudSync(ownerId);
  final String ownerId;
  final CloudSync _cloud;
  final List<Order> orders = [];
  final List<Material> materials = [];
  final Set<String> _pendingOrders = {};
  final Set<String> _pendingMaterials = {};
  final Set<String> _deletedOrders = {};
  final Set<String> _deletedMaterials = {};
  final Map<String, int> _orderVersions = {};
  final Map<String, int> _materialVersions = {};
  Timer? _syncTimer;
  bool loading = true;
  bool syncing = false;
  bool _disposed = false;
  String? error;
  String syncStatus = 'بانتظار المزامنة';
  File? _file;
  Future<void> _writeChain = Future<void>.value();

  bool get hasPendingWrites => _pendingOrders.isNotEmpty || _pendingMaterials.isNotEmpty;
  void _notify() { if (!_disposed) notifyListeners(); }

  Future<void> load() async {
    try {
      final folder = await getApplicationSupportDirectory();
      // Intentionally separate from the old unsynced local test data.
      _file = File('${folder.path}${Platform.pathSeparator}laser_pro_cloud_$ownerId.json');
      if (await _file!.exists()) {
        final raw = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        orders.addAll((raw['orders'] as List<dynamic>? ?? []).map(
          (e) => Order.fromJson(Map<String, dynamic>.from(e as Map))));
        materials.addAll((raw['materials'] as List<dynamic>? ?? []).map(
          (e) => Material.fromJson(Map<String, dynamic>.from(e as Map))));
        _pendingOrders.addAll(List<String>.from(raw['pendingOrders'] as List? ?? []));
        _pendingMaterials.addAll(List<String>.from(raw['pendingMaterials'] as List? ?? []));
        _deletedOrders.addAll(List<String>.from(raw['deletedOrders'] as List? ?? []));
        _deletedMaterials.addAll(List<String>.from(raw['deletedMaterials'] as List? ?? []));
        for (final entry in (raw['orderVersions'] as Map<String, dynamic>? ?? {}).entries) {
          _orderVersions[entry.key] = (entry.value as num).toInt();
        }
        for (final entry in (raw['materialVersions'] as Map<String, dynamic>? ?? {}).entries) {
          _materialVersions[entry.key] = (entry.value as num).toInt();
        }
      }
    } catch (e) {
      error = 'تعذّر قراءة البيانات المحلية الخاصة بالحساب: $e';
    } finally {
      loading = false;
      _notify();
    }
    if (error == null) {
      _syncTimer = Timer.periodic(const Duration(seconds: 25), (_) => unawaited(syncNow()));
      unawaited(syncNow());
    }
  }

  Future<void> _saveLocal() {
    final content = jsonEncode({
      'schemaVersion': 3,
      'orders': orders.map((e) => e.toJson()).toList(),
      'materials': materials.map((e) => e.toJson()).toList(),
      'pendingOrders': _pendingOrders.toList(),
      'pendingMaterials': _pendingMaterials.toList(),
      'deletedOrders': _deletedOrders.toList(),
      'deletedMaterials': _deletedMaterials.toList(),
      'orderVersions': _orderVersions,
      'materialVersions': _materialVersions,
    });
    final next = _writeChain.then((_) async {
      if (_file == null) throw StateError('التخزين المحلي غير متاح');
      final temp = File('${_file!.path}.tmp');
      await temp.writeAsString(content, flush: true);
      if (await _file!.exists()) {
        await _file!.copy('${_file!.path}.bak');
        await _file!.delete();
      }
      await temp.rename(_file!.path);
    });
    _writeChain = next.catchError((Object _) {});
    return next;
  }

  Future<void> _save({String? orderId, String? materialId, Iterable<String> otherMaterials = const []}) async {
    if (orderId != null) _pendingOrders.add(orderId);
    if (materialId != null) _pendingMaterials.add(materialId);
    _pendingMaterials.addAll(otherMaterials);
    await _saveLocal();
    _notify();
    unawaited(syncNow());
  }

  Future<void> addOrder(Order o) async { orders.add(o); await _save(orderId: o.id); }
  Future<void> updateOrder(Order o) async => _save(orderId: o.id);
  Future<void> addMaterial(Material m) async { materials.add(m); await _save(materialId: m.id); }
  Future<void> updateMaterial(Material m) async => _save(materialId: m.id);

  /// Soft-delete cloud records with tombstones so they do not reappear on another device.
  Future<void> deleteOrder(Order order) async {
    if (order.inventoryDeducted) {
      for (final line in order.usedMaterials) {
        final found = materials.where((m) => m.id == line.id);
        if (found.isNotEmpty) found.first.quantity += line.amount;
      }
      order.inventoryDeducted = false;
      for (final line in order.usedMaterials) {
        if (materials.any((m) => m.id == line.id)) _pendingMaterials.add(line.id);
      }
    }
    orders.removeWhere((o) => o.id == order.id);
    _pendingOrders.remove(order.id);
    _deletedOrders.add(order.id);
    await _saveLocal();
    _notify();
    unawaited(syncNow());
  }

  Future<void> deleteMaterial(Material material) async {
    materials.removeWhere((m) => m.id == material.id);
    _pendingMaterials.remove(material.id);
    _deletedMaterials.add(material.id);
    await _saveLocal();
    _notify();
    unawaited(syncNow());
  }

  /// Push locally edited records, then pull changes from the other device.
  /// Optimistic versions prevent the same item being silently overwritten.
  Future<void> syncNow() async {
    if (syncing || loading || _disposed || error != null) return;
    syncing = true;
    syncStatus = 'جارٍ المزامنة...';
    _notify();
    var conflict = false;
    try {
      for (final id in _deletedMaterials.toList()) {
        final version = await _cloud.put('materials', id, {'id': id, '_deleted': true}, _materialVersions[id] ?? 0);
        _materialVersions[id] = version;
        _deletedMaterials.remove(id);
      }
      for (final id in _deletedOrders.toList()) {
        final version = await _cloud.put('orders', id, {'id': id, '_deleted': true}, _orderVersions[id] ?? 0);
        _orderVersions[id] = version;
        _deletedOrders.remove(id);
      }
      for (final id in _pendingMaterials.toList()) {
        final matches = materials.where((m) => m.id == id);
        if (matches.isEmpty) continue;
        final material = matches.first;
        final payload = material.toJson();
        try {
          final version = await _cloud.put('materials', id, payload, _materialVersions[id] ?? 0);
          _materialVersions[id] = version;
          if (jsonEncode(material.toJson()) == jsonEncode(payload)) _pendingMaterials.remove(id);
        } catch (e) {
          if (e.toString().contains('SYNC_CONFLICT')) { conflict = true; continue; }
          rethrow;
        }
      }
      for (final id in _pendingOrders.toList()) {
        final matches = orders.where((o) => o.id == id);
        if (matches.isEmpty) continue;
        final order = matches.first;
        final payload = order.toJson();
        try {
          final version = await _cloud.put('orders', id, payload, _orderVersions[id] ?? 0);
          _orderVersions[id] = version;
          if (jsonEncode(order.toJson()) == jsonEncode(payload)) _pendingOrders.remove(id);
        } catch (e) {
          if (e.toString().contains('SYNC_CONFLICT')) { conflict = true; continue; }
          rethrow;
        }
      }
      final remoteMaterials = await _cloud.list('materials');
      for (final r in remoteMaterials) {
        if (r.payload['_deleted'] == true) { materials.removeWhere((m) => m.id == r.id); continue; }
        if (_pendingMaterials.contains(r.id) || _deletedMaterials.contains(r.id)) continue;
        final idx = materials.indexWhere((m) => m.id == r.id);
        final item = Material.fromJson(r.payload);
        if (idx == -1) { materials.add(item); } else { materials[idx] = item; }
        _materialVersions[r.id] = r.version;
      }
      final remoteOrders = await _cloud.list('orders');
      for (final r in remoteOrders) {
        if (r.payload['_deleted'] == true) { orders.removeWhere((o) => o.id == r.id); continue; }
        if (_pendingOrders.contains(r.id) || _deletedOrders.contains(r.id)) continue;
        final idx = orders.indexWhere((o) => o.id == r.id);
        final item = Order.fromJson(r.payload);
        if (idx == -1) { orders.add(item); } else { orders[idx] = item; }
        _orderVersions[r.id] = r.version;
      }
      await _saveLocal();
      syncStatus = conflict ? 'تعارض تعديل: تأكّد من البيانات قبل المتابعة'
        : hasPendingWrites ? 'بانتظار إرسال تغييرات محلية' : 'متزامن مع الحساب';
    } catch (_) {
      syncStatus = 'غير متصل — تغييراتك محفوظة محلياً';
    } finally {
      syncing = false;
      _notify();
    }
  }

  Future<String?> confirmMaterialUsage(Order o) async {
    if (o.inventoryDeducted) return 'المواد مخصومة مسبقاً';
    if (o.usedMaterials.isEmpty) return 'ما في مواد مسجّلة';
    final needed = <String, double>{};
    for (final line in o.usedMaterials) {
      needed[line.id] = (needed[line.id] ?? 0) + line.amount;
    }
    for (final entry in needed.entries) {
      final found = materials.where((m) => m.id == entry.key);
      if (found.isEmpty) return 'في مادة مش موجودة بالمخزون';
      if (found.first.quantity + 1e-8 < entry.value) return 'ما في كمية كافية من ${found.first.name}';
    }
    for (final entry in needed.entries) {
      materials.firstWhere((m) => m.id == entry.key).quantity -= entry.value;
    }
    o.inventoryDeducted = true;
    try {
      await _save(orderId: o.id, otherMaterials: needed.keys);
    } catch (_) {
      for (final entry in needed.entries) {
        materials.firstWhere((m) => m.id == entry.key).quantity += entry.value;
      }
      o.inventoryDeducted = false;
      rethrow;
    }
    return null;
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _disposed = true;
    super.dispose();
  }
}

class LaserProApp extends StatefulWidget {
  const LaserProApp({super.key});
  @override State<LaserProApp> createState() => _LaserProAppState();
}
class _LaserProAppState extends State<LaserProApp> with WidgetsBindingObserver {
  String? _uid;
  StudioStore? store;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _uid = Supabase.instance.client.auth.currentUser?.id;
    if (_uid != null) store = StudioStore(ownerId: _uid!)..load();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      final next = state.session?.user.id;
      if (_uid == next || !mounted) return;
      store?.dispose();
      setState(() {
        _uid = next;
        store = next == null ? null : StudioStore(ownerId: next);
      });
      if (store != null) unawaited(store!.load());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(store?.syncNow() ?? Future<void>.value());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Laser Pro Studio',
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark,
      scaffoldBackgroundColor: ink, colorSchemeSeed: gold,
      cardTheme: CardThemeData(color: panel, shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16))),
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12)))),
    home: store == null ? const CloudAuthScreen()
      : Directionality(textDirection: TextDirection.rtl,
        child: AnimatedBuilder(animation: store!,
          builder: (_, __) => StudioShell(store: store!))),
  );
}

class StudioShell extends StatefulWidget {
  const StudioShell({super.key, required this.store});
  final StudioStore store;
  @override State<StudioShell> createState() => _StudioShellState();
}
class _StudioShellState extends State<StudioShell> {
  int tab = 0;
  static const labels = ['الرئيسية', 'طلباتي', 'المخزون', 'الحسابات'];
  static const icons = [Icons.dashboard_outlined, Icons.receipt_long_outlined,
    Icons.inventory_2_outlined, Icons.bar_chart_outlined];
  @override Widget build(BuildContext context) {
    final store = widget.store;
    if (store.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (store.error != null) return Scaffold(body: Center(child: Padding(
      padding: const EdgeInsets.all(24), child: Text(store.error!))));
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final pages = [HomePage(store: store, newOrder: () => showOrderForm(context, store)),
      OrdersPage(store: store, newOrder: () => showOrderForm(context, store)),
      InventoryPage(store: store), AccountsPage(store: store)];
    return Scaffold(
      appBar: AppBar(backgroundColor: ink,
        title: Text(isWide ? 'LASER PRO / STUDIO' : 'LASER PRO', overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: gold)),
        actions: [
          IconButton(icon: Icon(store.syncStatus == 'متزامن مع الحساب'
            ? Icons.cloud_done_outlined : Icons.cloud_sync_outlined),
            tooltip: store.syncStatus, onPressed: () async {
              await store.syncNow();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(store.syncStatus)));
            }),
          IconButton(icon: const Icon(Icons.logout, size: 20), tooltip: 'تسجيل خروج',
            onPressed: () async => Supabase.instance.client.auth.signOut()),
        ],
      ),
      body: Row(children: [
        if (isWide) NavigationRail(
          backgroundColor: panel, selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          labelType: NavigationRailLabelType.all,
          destinations: [for (var i = 0; i < labels.length; i++)
            NavigationRailDestination(icon: Icon(icons[i]), label: Text(labels[i]))]),
        Expanded(child: pages[tab]),
      ]),
      bottomNavigationBar: isWide ? null : NavigationBar(
        selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v),
        destinations: [for (var i = 0; i < labels.length; i++)
          NavigationDestination(icon: Icon(icons[i]), label: labels[i])]),
      floatingActionButton: tab <= 1 ? FloatingActionButton.extended(
        onPressed: () => showOrderForm(context, store),
        icon: const Icon(Icons.add), label: const Text('طلب جديد')) : null,
    );
  }
}

String money(num value) => '\$${value.toStringAsFixed(2)}';
String date(DateTime value) => '${value.day}/${value.month}/${value.year}';
Widget section(String title, Widget child) => Column(
  crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))), child]);
Widget content(List<Widget> children) => ListView(padding: const EdgeInsets.all(20), children: children);

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store, required this.newOrder});
  final StudioStore store;
  final VoidCallback newOrder;
  @override Widget build(BuildContext context) {
    final open = store.orders.where((o) => o.status != 'تم التسليم').toList();
    final due = open.where((o) => !o.dueDate.isAfter(DateTime.now().add(const Duration(days: 1)))).toList();
    final need = store.materials.where((m) => m.quantity <= m.reorderLevel).toList();
    final debt = store.orders.fold<double>(0, (sum, o) => sum + (o.outstanding > 0 ? o.outstanding : 0));
    return content([
      const Text('مساعد اليوم', style: TextStyle(color: gold, fontSize: 25, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('كل شغلك بمكان واحد — من غير عجقة.'),
      const SizedBox(height: 18),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _metric('قيد التنفيذ', '${open.length}', Icons.handyman_outlined),
        _metric('لازم تسلّم', '${due.length}', Icons.local_shipping_outlined),
        _metric('لازم تقبض', money(debt), Icons.payments_outlined),
        _metric('لازم تشتري', '${need.length}', Icons.shopping_cart_outlined),
      ]),
      const SizedBox(height: 28),
      section('قيد التنفيذ · افتح الطلب', open.isEmpty
        ? const Text('ما في طلبات قيد التنفيذ حالياً.')
        : Column(children: open.map((o) => OrderTile(order: o, store: store)).toList())),
      const SizedBox(height: 20),
      section('شو لازم تشتري؟', need.isEmpty
        ? const Text('ما في نواقص مسجّلة بالمخزون.')
        : Column(children: need.map((m) => ListTile(
            title: Text(m.name), subtitle: Text('${m.quantity} ${m.unit} متبقّي'))).toList())),
    ]);
  }
  Widget _metric(String title, String value, IconData icon) => SizedBox(width: 165,
    child: Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: gold), const SizedBox(height: 14),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(title, style: const TextStyle(fontSize: 12)),
      ]))));
}

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key, required this.store, required this.newOrder});
  final StudioStore store;
  final VoidCallback newOrder;
  @override Widget build(BuildContext context) {
    final active = store.orders.where((o) => o.status == 'جديد' || o.status == 'قيد التنفيذ').toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final ready = store.orders.where((o) => o.status == 'جاهز').toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final delivered = store.orders.where((o) => o.status == 'تم التسليم').toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return content([
      Row(children: [Expanded(child: Text('مركز الطلبات · ${store.orders.length}',
        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold))),
        FilledButton.icon(onPressed: newOrder, icon: const Icon(Icons.add), label: const Text('طلب جديد'))]),
      const SizedBox(height: 15),
      section('قيد التحضير والتنفيذ · ${active.length}', active.isEmpty
        ? const Text('لا توجد طلبات في هذه المرحلة.')
        : Column(children: active.map((o) => OrderTile(order: o, store: store)).toList())),
      const SizedBox(height: 16),
      section('جاهزة بانتظار التسليم · ${ready.length}', ready.isEmpty
        ? const Text('لا توجد طلبات جاهزة حالياً.')
        : Column(children: ready.map((o) => OrderTile(order: o, store: store)).toList())),
      const SizedBox(height: 16),
      section('تم التسليم · ${delivered.length}', delivered.isEmpty
        ? const Text('لا توجد طلبات مسلّمة بعد.')
        : Column(children: delivered.map((o) => OrderTile(order: o, store: store)).toList())),
    ]);
  }
}
class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, required this.store});
  final Order order;
  final StudioStore store;
  @override Widget build(BuildContext context) => Card(child: ListTile(
    title: Text('${order.product} — ${order.customer}'),
    subtitle: Text('التسليم: ${date(order.dueDate)}  •  ${order.status}  •  باقي ${money(order.outstanding)}'),
    trailing: const Icon(Icons.open_in_new, color: gold),
    onTap: () => showDialog<void>(context: context, builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(title: Text('طلب ${order.customer}'), content: SizedBox(
        width: 450, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المنتج: ${order.product} · الكمية: ${order.quantity}'),
            if (order.phone.isNotEmpty) Text('الهاتف: ${order.phone}'),
            if (order.address.isNotEmpty) Text('العنوان: ${order.address}'),
            Text('تاريخ الطلب: ${date(order.orderDate)}'),
            Text('التسليم: ${date(order.dueDate)}'),
            Text('السعر: ${money(order.price)}'),
            Text('المقبوض: ${money(order.paid)}'),
            Text('الباقي: ${money(order.outstanding)}'),
            const Divider(),
            const Text('تفاصيل تكلفة الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final line in order.usedMaterials)
              costLine('${line.name} (${line.amount.toStringAsFixed(2)} ${line.unit})', line.cost),
            if (order.usedMaterials.isEmpty)
              const Text('هيدا طلب قديم، تكلفته المسجّلة محفوظة.'),
            costLine('المواد والتغليف', order.materialCost),
            costLine('كهرباء الليزر (${order.laserMinutes.toStringAsFixed(0)} دقيقة)', order.electricCost),
            const Divider(),
            costLine('مجموع التكلفة', order.totalCost, bold: true),
            costLine('الربح بعد التكاليف المباشرة', order.grossMargin, bold: true),
            Text(order.inventoryDeducted ? 'المواد انخصمت من المخزون' : 'المواد مش مخصومة من المخزون بعد',
              style: TextStyle(color: order.inventoryDeducted ? Colors.greenAccent : Colors.orangeAccent)),
            if (order.notes.isNotEmpty) Text('ملاحظات: ${order.notes}'),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () { Navigator.pop(context); showOrderForm(context, store, existing: order); },
              icon: const Icon(Icons.edit_outlined), label: const Text('تعديل بيانات الطلب')),
            OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('حذف الطلب؟'),
                  content: const Text('سيُحذف من قائمة العمل. إذا كانت مواده قد خُصمت، سيُعاد رصيدها للمخزون. سيُسجّل الحذف للمزامنة مع أجهزتك.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد الحذف'))]));
                if (ok == true) { await store.deleteOrder(order); if (context.mounted) Navigator.pop(context); }
              }, icon: const Icon(Icons.delete_outline), label: const Text('حذف الطلب')),
            const SizedBox(height: 15),
            if (!order.inventoryDeducted && order.usedMaterials.isNotEmpty)
              FilledButton.tonalIcon(icon: const Icon(Icons.inventory_outlined),
                label: const Text('تأكيد استهلاك المواد وخصمها'),
                onPressed: () async {
                  final message = await store.confirmMaterialUsage(order);
                  if (!context.mounted) return;
                  if (message != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                  } else {
                    Navigator.pop(context);
                  }
                }),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(value: order.status,
              decoration: const InputDecoration(labelText: 'حالة الطلب'),
              items: ['جديد', 'قيد التنفيذ', 'جاهز', 'تم التسليم']
                .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) async { if (v != null) { order.status = v; await store.updateOrder(order); } }),
            const SizedBox(height: 10),
            FilledButton(onPressed: () async {
              final controller = TextEditingController(text: order.paid.toStringAsFixed(2));
              final result = await showDialog<String>(context: context,
                builder: (ctx) => AlertDialog(title: const Text('المبلغ المقبوض الإجمالي'),
                  content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('حفظ'))]));
              final n = double.tryParse(result ?? '');
              if (n != null && n >= 0 && n <= order.price) { order.paid = n; await store.updateOrder(order); }
            }, child: const Text('تحديث المقبوض')),
          ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))])))));
}

// The user enters only quantities/measurements, never a guessed dollar cost.
Future<UsedMaterial?> chooseUsedMaterial(BuildContext context, StudioStore store) async {
  if (store.materials.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('ضيف المواد وأسعارها بالمخزون أولاً')));
    return null;
  }
  var chosenId = store.materials.first.id;
  final amount = TextEditingController();
  final width = TextEditingController();
  final height = TextEditingController();
  final chosen = await showDialog<UsedMaterial>(context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) {
      final material = store.materials.firstWhere((m) => m.id == chosenId);
      final area = material.unit == 'سم²';
      final q = area
          ? (double.tryParse(width.text) ?? 0) * (double.tryParse(height.text) ?? 0)
          : double.tryParse(amount.text) ?? 0;
      return Directionality(textDirection: TextDirection.rtl,
        child: AlertDialog(title: const Text('شو استعملت من المواد؟'),
          content: SizedBox(width: 420, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(value: chosenId, isExpanded: true,
                decoration: const InputDecoration(labelText: 'اختر المادة من المخزون'),
                items: store.materials.map((m) => DropdownMenuItem(
                  value: m.id, child: Text('${m.name} — ${m.unit}', overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) { if (v != null) refresh(() {
                  chosenId = v; amount.clear(); width.clear(); height.clear();
                }); }),
              const SizedBox(height: 10),
              if (area) ...[
                TextField(controller: width, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'طول الخشب المستخدم (سم)'),
                  onChanged: (_) => refresh(() {})),
                const SizedBox(height: 10),
                TextField(controller: height, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'عرض الخشب المستخدم (سم)'),
                  onChanged: (_) => refresh(() {})),
              ] else TextField(controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'الكمية المستخدمة (${material.unit})'),
                onChanged: (_) => refresh(() {})),
              const SizedBox(height: 14),
              Text('المتوفر: ${material.quantity.toStringAsFixed(2)} ${material.unit}'),
              Text('التكلفة المحسوبة: ${money(q * material.unitCost)}',
                style: const TextStyle(color: gold, fontWeight: FontWeight.bold)),
              if (q > material.quantity)
                const Text('تنبيه: الاستهلاك أكبر من الكمية المتوفرة',
                  style: TextStyle(color: Colors.orangeAccent)),
            ]))),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () {
              if (q <= 0 || !q.isFinite) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('أدخل قياس أو كمية صحيحة')));
                return;
              }
              Navigator.pop(ctx, UsedMaterial(id: material.id, name: material.name,
                unit: material.unit, category: material.category, amount: q,
                unitCost: material.unitCost,
                widthCm: area ? double.tryParse(width.text) : null,
                heightCm: area ? double.tryParse(height.text) : null));
            }, child: const Text('إضافة المادة'))],
        ));
    }));
  amount.dispose(); width.dispose(); height.dispose();
  return chosen;
}

Widget costLine(String title, double value, {bool bold = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
    Expanded(child: Text(title, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal))),
    Text(money(value), style: TextStyle(color: gold,
      fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
  ]));

Future<void> showOrderForm(BuildContext context, StudioStore store, {Order? existing}) async {
  final customer = TextEditingController(text: existing?.customer ?? '');
  final phone = TextEditingController(text: existing?.phone ?? '');
  final address = TextEditingController(text: existing?.address ?? '');
  final quantity = TextEditingController(text: existing?.quantity.toString() ?? '1');
  final product = TextEditingController(text: existing?.product ?? '');
  final price = TextEditingController(text: existing?.price.toStringAsFixed(2) ?? '');
  final paid = TextEditingController(text: existing?.paid.toStringAsFixed(2) ?? '0');
  final laserMinutes = TextEditingController(text: existing?.laserMinutes.toStringAsFixed(0) ?? '0');
  final used = List<UsedMaterial>.of(existing?.usedMaterials ?? const <UsedMaterial>[]);
  final notes = TextEditingController(text: existing?.notes ?? '');
  DateTime due = existing?.dueDate ?? DateTime.now().add(const Duration(days: 3));
  DateTime orderDate = existing?.orderDate ?? DateTime.now();
  final key = GlobalKey<FormState>();
  await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(
    builder: (ctx, setForm) {
      final materialCost = used.fold<double>(0, (sum, item) => sum + item.cost);
      final minutes = double.tryParse(laserMinutes.text) ?? 0;
      final electricity = laserElectricity(minutes);
      final priceValue = double.tryParse(price.text) ?? 0;
      return Directionality(textDirection: TextDirection.rtl,
      child: AlertDialog(title: Text(existing == null ? 'طلب جديد' : 'تعديل الطلب ${existing.id}'), content: SizedBox(width: 480,
        child: Form(key: key, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            _field('اسم الزبون', customer, required: true),
            _field('رقم الهاتف', phone, numeric: false),
            _field('العنوان', address),
            _field('نوع الطلب / المنتج', product, required: true),
            _field('الكمية', quantity, numeric: true, required: true),
            ListTile(title: const Text('تاريخ الطلب'), subtitle: Text(date(orderDate)),
              trailing: const Icon(Icons.event), onTap: () async {
                final value = await showDatePicker(context: ctx, initialDate: orderDate,
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (value != null) setForm(() => orderDate = value);
              }),
            TextFormField(controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'سعر البيع بالدولار'),
              validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'أدخل سعر بيع صحيح' : null,
              onChanged: (_) => setForm(() {})),
            const SizedBox(height: 10),
            _field('الدفعة المقبوضة', paid, numeric: true),
            const SizedBox(height: 12),
            const Text('المواد المستخدمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            if (used.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('اختار الخشب أو الأكريليك أو التغليف من مخزونك.')),
            ...used.asMap().entries.map((e) => ListTile(dense: true,
              title: Text(e.value.name),
              subtitle: Text('${e.value.amount.toStringAsFixed(2)} ${e.value.unit}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(money(e.value.cost), style: const TextStyle(color: gold)),
                IconButton(tooltip: 'حذف المادة', icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setForm(() => used.removeAt(e.key))),
              ]))),
            OutlinedButton.icon(icon: const Icon(Icons.add),
              label: const Text('إضافة مادة من المخزون'),
              onPressed: () async {
                final line = await chooseUsedMaterial(ctx, store);
                if (line != null) setForm(() => used.add(line));
              }),
            const SizedBox(height: 12),
            TextFormField(controller: laserMinutes,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'دقائق تشغيل الليزر فقط'),
              onChanged: (_) => setForm(() {})),
            const Padding(padding: EdgeInsets.symmetric(vertical: 7),
              child: Text('تقدير الكهرباء: 216 واط × 0.90 دولار/كيلوواط ساعة. بلا حساب وقت شغلك.',
                style: TextStyle(fontSize: 11, color: Colors.white70))),
            Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
              costLine('المواد والتغليف', materialCost),
              costLine('كهرباء الليزر', electricity),
              const Divider(),
              costLine('إجمالي تكلفة الطلب', materialCost + electricity, bold: true),
              costLine('ربح الطلب بعد التكاليف المباشرة', priceValue - materialCost - electricity, bold: true),
            ]))),
            const SizedBox(height: 10),
            _field('ملاحظات', notes),
            ListTile(title: const Text('موعد التسليم'), subtitle: Text(date(due)),
              trailing: const Icon(Icons.event), onTap: () async {
                final value = await showDatePicker(context: ctx, initialDate: due,
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (value != null) setForm(() => due = value);
              }),
          ])))), actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () async {
              if (!key.currentState!.validate()) return;
              final p = double.tryParse(price.text) ?? -1;
              final a = double.tryParse(paid.text) ?? -1;
              final duration = double.tryParse(laserMinutes.text) ?? -1;
              final qty = int.tryParse(quantity.text) ?? 0;
              if (p < 0 || a < 0 || a > p || duration < 0 || !duration.isFinite || qty < 1 || used.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('راجع السعر والدفعة ودقائق الليزر، ولازم تختار مادة على الأقل')));
                return;
              }
              try {
                if (existing == null) {
                  await store.addOrder(Order(id: const Uuid().v4(),
                    customer: customer.text.trim(), product: product.text.trim(),
                    phone: phone.text.trim(), address: address.text.trim(), quantity: qty, orderDate: orderDate,
                    dueDate: due, price: p, paid: a, materialCost: materialCost,
                    usedMaterials: List.of(used), laserMinutes: duration,
                    electricCost: laserElectricity(duration),
                    status: 'جديد', createdAt: DateTime.now(), notes: notes.text.trim()));
                } else {
                  existing.customer = customer.text.trim();
                  existing.phone = phone.text.trim(); existing.address = address.text.trim();
                  existing.quantity = qty; existing.orderDate = orderDate;
                  existing.product = product.text.trim();
                  existing.dueDate = due;
                  existing.price = p;
                  existing.paid = a;
                  existing.materialCost = materialCost;
                  existing.usedMaterials = List.of(used);
                  existing.laserMinutes = duration;
                  existing.electricCost = laserElectricity(duration);
                  existing.notes = notes.text.trim();
                  await store.updateOrder(existing);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) { if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e'))); }
            }, child: const Text('حفظ الطلب')),
          ]));
    }));
  for (final c in [customer, phone, address, quantity, product, price, paid, laserMinutes, notes]) { c.dispose(); }
}
Widget _field(String label, TextEditingController controller,
    {bool numeric = false, bool required = false}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TextFormField(controller: controller,
    keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
    decoration: InputDecoration(labelText: label),
    validator: (value) => required && (value == null || value.trim().isEmpty)
      ? 'هالخانة مطلوبة' : numeric && value != null && value.isNotEmpty && double.tryParse(value) == null
      ? 'اكتب رقم صحيح' : null));

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key, required this.store});
  final StudioStore store;
  @override Widget build(BuildContext context) => content([
    Row(children: [const Expanded(child: Text('المخزون', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold))),
      FilledButton.icon(onPressed: () => _addMaterial(context), icon: const Icon(Icons.add), label: const Text('مادة جديدة'))]),
    const SizedBox(height: 12),
    if (store.materials.isEmpty) const Text('بعد ما أضفت مواد. ابدأ بالخشب، الأكريليك، والتغليف.'),
    ...store.materials.map((m) => Card(child: ListTile(
      title: Text(m.name),
      subtitle: Text('${m.category} • ${m.quantity.toStringAsFixed(2)} ${m.unit} • سعر ${m.unit} ${m.unitCost.toStringAsFixed(6)} دولار'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (m.quantity <= m.reorderLevel) const Icon(Icons.warning_amber, color: gold, size: 19),
        IconButton(tooltip: 'حذف المادة', icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () async {
            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              title: const Text('حذف المادة من المخزون؟'),
              content: Text('سيتم إخفاء «${m.name}» من قائمة المواد. تفاصيل استخدامها السابقة ستبقى محفوظة داخل الطلبات.'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))]));
            if (ok == true) await store.deleteMaterial(m);
          }),
      ]),
      onTap: () async {
        final name = TextEditingController(text: m.name);
        final input = TextEditingController(text: m.quantity.toString());
        final limit = TextEditingController(text: m.reorderLevel.toString());
        final price = TextEditingController(text: (m.unitCost * m.packUnits).toStringAsFixed(3));
        final value = await showDialog<List<String>>(context: context,
          builder: (ctx) => AlertDialog(title: Text('تفاصيل وتعديل · ${m.name}'),
            content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              _field('اسم المادة', name, required: true),
              _field('الكمية الحالية (${m.unit})', input, numeric: true),
              _field('حد تنبيه النقص (${m.unit})', limit, numeric: true),
              _field('سعر اللوح/الرول/العبوة', price, numeric: true),
              Align(alignment: Alignment.centerRight, child: Text('التصنيف: ${m.category} · وحدة القياس: ${m.unit}',
                style: const TextStyle(color: Colors.white70, fontSize: 12))),
            ]))),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(onPressed: () {
                final n = double.tryParse(input.text), l = double.tryParse(limit.text), c = double.tryParse(price.text);
                if (name.text.trim().isNotEmpty && n != null && l != null && c != null &&
                    n.isFinite && l.isFinite && c.isFinite && n >= 0 && l >= 0 && c >= 0) {
                  Navigator.pop(ctx, [name.text.trim(), n.toString(), l.toString(), c.toString()]);
                }
              }, child: const Text('حفظ التعديلات'))]));
        if (value != null) {
          m.name = value[0];
          m.quantity = double.parse(value[1]);
          m.reorderLevel = double.parse(value[2]);
          m.unitCost = double.parse(value[3]) / m.packUnits;
          await store.updateMaterial(m);
        }
        name.dispose(); input.dispose(); limit.dispose(); price.dispose();
      }))),
    const SizedBox(height: 18),
    const Text('بتختار المواد داخل الطلب. عند تأكيد استهلاكها بتنخصم من المخزون مرة واحدة فقط.',
      style: TextStyle(color: Colors.white70)),
  ]);
  Future<void> _addMaterial(BuildContext context) async {
    final name = TextEditingController(); final qty = TextEditingController(text: '0');
    final limit = TextEditingController(text: '0');
    final packCount = TextEditingController(text: '1');
    final lengthCm = TextEditingController(text: '120');
    final widthCm = TextEditingController(text: '80');
    final rollMeters = TextEditingController(text: '10');
    final packCost = TextEditingController(text: '0');
    var unit = 'قطعة';
    var category = 'خشب';
    final key = GlobalKey<FormState>();
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => Directionality(textDirection: TextDirection.rtl,
      child: AlertDialog(title: const Text('مادة جديدة'), content: SizedBox(width: 440,
      child: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _field('اسم المادة (مثل خشب MDF 3mm)', name, required: true),
        DropdownButtonFormField<String>(value: category,
          decoration: const InputDecoration(labelText: 'نوع المادة'),
          items: ['خشب', 'أكريليك', 'تغليف', 'لاصق', 'دهان', 'أخرى']
            .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) { if (v != null) update(() => category = v); }),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: unit,
          decoration: const InputDecoration(labelText: 'وحدة حساب الاستخدام'),
          items: ['قطعة', 'سم²', 'سم', 'متر', 'غرام', 'مل']
            .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) { if (v != null) update(() => unit = v); }),
        const SizedBox(height: 10),
        _field('عدد الألواح أو الرولات أو العبوات الموجودة', qty, numeric: true, required: true),
        _field('حد تنبيه النقص ($unit)', limit, numeric: true, required: true),
        if (unit == 'سم²') ...[
          _field('طول اللوح (سم)', lengthCm, numeric: true, required: true),
          _field('عرض اللوح (سم)', widthCm, numeric: true, required: true),
        ] else if (unit == 'سم')
          _field('طول الرول (متر)', rollMeters, numeric: true, required: true)
        else _field('كم $unit بالعبوة الواحدة؟', packCount, numeric: true, required: true),
        _field('سعر اللوح أو الرول أو العبوة بالدولار', packCost, numeric: true, required: true),
        const Text('البرنامج بيحوّل قياس اللوح للمساحة، وطول الرول للسنتيمتر، وبيحسب تكلفة الجزء المستخدم تلقائياً.',
          style: TextStyle(fontSize: 12, color: Colors.white70)),
      ])))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: () async {
          if (!key.currentState!.validate()) return;
          final packs = double.tryParse(qty.text) ?? -1;
          final l = double.tryParse(limit.text) ?? -1;
          final c = double.tryParse(packCost.text) ?? -1;
          final count = unit == 'سم²'
              ? (double.tryParse(lengthCm.text) ?? 0) * (double.tryParse(widthCm.text) ?? 0)
              : unit == 'سم' ? (double.tryParse(rollMeters.text) ?? 0) * 100
              : double.tryParse(packCount.text) ?? -1;
          if (packs < 0 || l < 0 || c < 0 || count <= 0 ||
              !packs.isFinite || !l.isFinite || !c.isFinite || !count.isFinite) {
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('راجع القياسات والكمية والسعر')));
            return;
          }
          try {
            await store.addMaterial(Material(id: const Uuid().v4(),
              name: name.text.trim(), quantity: packs * count, unit: unit, category: category,
              reorderLevel: l, unitCost: c / count, packUnits: count));
            if (ctx.mounted) Navigator.pop(ctx);
          } catch (e) { if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'))); }
        }, child: const Text('حفظ المادة'))]))));
    for (final c in [name, qty, limit, packCount, packCost, lengthCm, widthCm, rollMeters]) { c.dispose(); }
  }
}

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key, required this.store});
  final StudioStore store;
  @override Widget build(BuildContext context) {
    // Only completed handoffs count as realized sales and profit.
    final completed = store.orders.where((o) => o.status == 'تم التسليم').toList();
    final sales = completed.fold<double>(0, (v, o) => v + o.price);
    final paid = completed.fold<double>(0, (v, o) => v + o.paid);
    final costs = completed.fold<double>(0, (v, o) => v + o.totalCost);
    return content([
      const Text('الحسابات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 18),
      _accountCard('إجمالي المبيعات', sales), _accountCard('المقبوض', paid),
      _accountCard('المتبقّي للقبض', sales - paid),
      _accountCard('المواد والتغليف وكهرباء الليزر', costs),
      _accountCard('ربح الطلبات بعد التكاليف المباشرة', sales - costs),
      const SizedBox(height: 15),
      Text('المحتسب هنا فقط الطلبات التي حالتها «تم التسليم» (${completed.length} طلب). الربح بعد المواد والتغليف وكهرباء الليزر، وقبل المصاريف العامة وأجرة وقت العمل.',
        style: TextStyle(color: Colors.white70)),
    ]);
  }
  Widget _accountCard(String name, double value) => Card(child: ListTile(
    title: Text(name), trailing: Text(money(value),
      style: const TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.bold))));
}