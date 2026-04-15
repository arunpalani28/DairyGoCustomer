import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';
import '../models/models.dart';
import '../widgets/theme.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onCartUpdate;
  final Function(int index)? onNavigate;
  const HomeScreen({super.key, required this.onCartUpdate,
  this.onNavigate});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile? _profile;
  List<DeliveryDay> _weekDeliveries = [];
  List<Product> _products = [];
  List<RecentOrder> _recentOrders = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final now = DateTime.now();
      final from = _fmt(now);
      final to = _fmt(now.add(const Duration(days: 6)));
      final results = await Future.wait([
        ApiClient.get('/customer/profile'),
        ApiClient.get('/customer/calendar?from=$from&to=$to'),
        ApiClient.get('/customer/products'),
        ApiClient.get('/customer/orders'),
      ]);
      setState(() {
        _profile = UserProfile.fromJson(results[0]['data']);
        _weekDeliveries = (results[1]['data'] as List).map((e) => DeliveryDay.fromJson(e)).toList();
        _products = (results[2]['data'] as List).map((e) => Product.fromJson(e)).toList();
        _recentOrders = (results[3]['data'] as List).map((e) => RecentOrder.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: kBg, body: Center(child: CircularProgressIndicator(color: kPrimary)));
    if (_error != null) return Scaffold(backgroundColor: kBg, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off_rounded, size: 48, color: kTextLight), const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: kTextMid, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _load, style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white), child: const Text('Retry')),
    ])));
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        _buildHeader(),
        Expanded(child: RefreshIndicator(onRefresh: _load, color: kPrimary,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            KSectionTitle(title: 'Quick Actions'), const SizedBox(height: 10),
            _quickActions(),
            const SizedBox(height: 18),
            KSectionTitle(title: "Today's Delivery"), const SizedBox(height: 10),
            _todayCard(),
            const SizedBox(height: 18),
            KSectionTitle(title: 'This Week', link: 'Full calendar →',onLink: () {
    widget.onNavigate?.call(1); // Calendar tab
  }), const SizedBox(height: 10),
            _weekStrip(),
            const SizedBox(height: 18),
            KSectionTitle(title: 'Quick Order', link: 'See all →',onLink: () {
    widget.onNavigate?.call(2); // Shop tab
  },), const SizedBox(height: 10),
            _miniProductRow(),
            if (_recentOrders.isNotEmpty) ...[
              const SizedBox(height: 18),
              KSectionTitle(title: 'Recent Orders'), const SizedBox(height: 10),
              _recentOrdersSection(),
            ],
            const SizedBox(height: 12),
          ]),
        )),
      ]),
    );
  }

  Widget _buildHeader() => Container(
    color: kPrimary,
    child: SafeArea(bottom: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(children: [
        Row(children: [
          KAvatar(initials: _profile?.initials ?? 'RK'), const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_profile?.name ?? 'Welcome!', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            Text(_profile?.zone ?? 'DairyGo Madurai', style: const TextStyle(fontSize: 11, color: Color(0xFF90CAF9))),
          ])),
          const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
        ]),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('LIVE WALLET', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF5C8FCB), letterSpacing: 0.6)),
              const SizedBox(height: 3),
              Text('₹${_profile?.walletBalance.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kPrimary)),
              const Text('Available credits', style: TextStyle(fontSize: 9, color: kTextLight)),
              const SizedBox(height: 5),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: kPrimaryLt, borderRadius: BorderRadius.circular(20)),
                child: const Text('Auto-recharge ON', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kPrimary))),
            ])),
            Container(width: 1, height: 72, color: kPrimaryLt, margin: const EdgeInsets.symmetric(horizontal: 14)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('KYC STATUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF5C8FCB), letterSpacing: 0.6)),
              const SizedBox(height: 3),
              Row(children: [
                Icon(_profile?.kycStatus == 'VERIFIED' ? Icons.verified_rounded : Icons.pending_rounded,
                    size: 18, color: _profile?.kycStatus == 'VERIFIED' ? kGreen : kOrange),
                const SizedBox(width: 5),
                Text(_profile?.kycStatus ?? '—', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: _profile?.kycStatus == 'VERIFIED' ? kGreen : kOrange)),
              ]),
              const SizedBox(height: 4),
              if (_profile?.zone != null && _profile!.zone.isNotEmpty)
                Text(_profile!.zone, style: const TextStyle(fontSize: 9, color: kTextLight)),
            ])),
          ]),
        ),
      ]),
    )),
  );

 Widget _quickActions() {
  final items = [
    (Icons.calendar_month_rounded, 'Schedule', kPrimaryLt, kPrimary, 1),
    (Icons.shopping_cart_rounded, 'Shop', kGreenLt, kGreen, 2),
    (Icons.receipt_long_rounded, 'Bills', kOrangeLt, kOrange, 3),
    (Icons.headset_mic_rounded, 'Support', const Color(0xFFF3E5F5),
        const Color(0xFF7B1FA2), -1), // special case
  ];

  return Row(
    children: items.map((it) {
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (it.$5 == -1) {
              // Support → open phone dialer or bottom sheet
              launchUrl(Uri.parse('tel:+916384472802'));
            } else {
              widget.onNavigate?.call(it.$5);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: it.$3,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(it.$1, color: it.$4, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  it.$2,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: kTextMid,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList(),
  );
}

 Widget _todayCard() {
    final today = _weekDeliveries.isNotEmpty ? _weekDeliveries.first : null;
    final status = today?.status ?? 'PENDING';
    final statusColor = status == 'DELIVERED' ? kGreen : status == 'PAUSED' ? kOrange : kPrimary;
    final statusBg = status == 'DELIVERED' ? kGreenLt : status == 'PAUSED' ? kOrangeLt : kPrimaryLt;
    return KCard(child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: kPrimaryLt, borderRadius: BorderRadius.circular(13)), child: const Center(child: Text('🥛', style: TextStyle(fontSize: 24)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Full Cream Milk — ${today?.quantityMl ?? 500}ml', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 2),
        const Text('Expected 6:30 AM · Assigned to Ravi', style: TextStyle(fontSize: 10, color: kTextMid)),
        const SizedBox(height: 6),
        KStatusBadge(label: status, color: statusColor, bg: statusBg),
      ])),
    ]));
  }

  Widget _weekStrip() {
    final now = DateTime.now();
    final days = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    return SizedBox(height: 84, child: ListView.builder(
      scrollDirection: Axis.horizontal, itemCount: 7,
      itemBuilder: (ctx, i) {
        final d = now.add(Duration(days: i));
        final isToday = i == 0;
        final locked = i == 1 && now.hour >= 16;
        final dd = i < _weekDeliveries.length ? _weekDeliveries[i] : null;
        return Container(width: 55, margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isToday ? kPrimaryLt : locked ? const Color(0xFFF5F7FA) : kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isToday ? kPrimary : kBorder, width: isToday ? 2 : 1)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(days[d.weekday % 7], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: kTextLight)),
            const SizedBox(height: 2),
            Text('${d.day}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark)),
            const SizedBox(height: 4),
            locked ? const Icon(Icons.lock_rounded, color: kTextLight, size: 13)
                : dd?.status == 'DELIVERED' ? const Icon(Icons.check_circle_rounded, color: kGreen, size: 15)
                : dd?.status == 'PAUSED' ? const Icon(Icons.pause_circle_rounded, color: kOrange, size: 15)
                : const Text('🥛', style: TextStyle(fontSize: 14)),
          ]),
        );
      },
    ));
  }

  Widget _miniProductRow() => SizedBox(height: 122, child: ListView.builder(
    scrollDirection: Axis.horizontal, itemCount: _products.length,
    itemBuilder: (ctx, i) => _MiniProductCard(product: _products[i], onAdd: () => widget.onCartUpdate(1)),
  ));

  Widget _recentOrdersSection() => Column(children: _recentOrders.take(3).map((order) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: KCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Order #${order.id}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextDark)),
        KStatusBadge(
          label: order.status,
          color: order.status == 'DELIVERED' ? kGreen : order.status == 'CANCELLED' ? kRed : kOrange,
          bg: order.status == 'DELIVERED' ? kGreenLt : order.status == 'CANCELLED' ? kRedLt : kOrangeLt,
        ),
      ]),
      const SizedBox(height: 8),
      ...order.items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Text(item.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text('${item.name} × ${item.qty}', style: const TextStyle(fontSize: 11, color: kTextMid))),
          Text('₹${(item.unitPrice * item.qty).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextDark)),
        ]),
      )),
      const Divider(color: kBorder, height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Items: ₹${order.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: kTextMid)),
          if (order.deliveryCharge > 0)
            Text('Delivery: ₹${order.deliveryCharge.toStringAsFixed(0)} (${order.distanceKm.toStringAsFixed(1)}km)', style: const TextStyle(fontSize: 10, color: kOrange, fontWeight: FontWeight.w600)),
        ]),
        Text('Total: ₹${(order.totalAmount + order.deliveryCharge).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary)),
      ]),
      const SizedBox(height: 4),
      Text(order.createdAt.length >= 10 ? order.createdAt.substring(0, 10) : order.createdAt, style: const TextStyle(fontSize: 9, color: kTextLight)),
    ])),
  )).toList());
}

class _MiniProductCard extends StatefulWidget {
  final Product product; final VoidCallback onAdd;
  const _MiniProductCard({required this.product, required this.onAdd});
  @override State<_MiniProductCard> createState() => _MiniProductCardState();
}
class _MiniProductCardState extends State<_MiniProductCard> {
  bool _added = false;
  @override Widget build(BuildContext ctx) => Container(
    width: 94, margin: const EdgeInsets.only(right: 9), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
    child: Column(children: [
      Text(widget.product.emoji, style: const TextStyle(fontSize: 24)),
      const SizedBox(height: 3),
      Text(widget.product.name, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: kTextDark), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
      Text('₹${widget.product.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimary)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () { setState(() => _added = true); widget.onAdd(); Future.delayed(const Duration(seconds: 1), () { if (mounted) setState(() => _added = false); }); },
        child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(color: _added ? kGreen : kPrimary, borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(_added ? '✓' : 'Add', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)))),
      ),
    ]),
  );
}
