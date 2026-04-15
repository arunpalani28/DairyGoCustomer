import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/models.dart';
import '../widgets/theme.dart';

class BillsScreen extends StatefulWidget {
  final Function(int index)? onNavigate;
  const BillsScreen({super.key,
  this.onNavigate});
  @override State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  List<Bill> _bills = [];
  List<WalletTx> _txns = [];
  List<RecentOrder> _orders = [];
  bool _loading = true, _paying = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.get('/customer/bills'),
        ApiClient.get('/customer/transactions'),
        ApiClient.get('/customer/orders'),
      ]);
      setState(() {
        _bills = (results[0]['data'] as List).map((e) => Bill.fromJson(e)).toList();
        _txns  = (results[1]['data'] as List).map((e) => WalletTx.fromJson(e)).toList();
        _orders = (results[2]['data'] as List).map((e) => RecentOrder.fromJson(e)).toList();
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _payBill(Bill bill) async {
    setState(() => _paying = true);
    try {
      await ApiClient.post('/customer/bills/${bill.id}/pay');
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill paid successfully! ✓'), backgroundColor: kGreen));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _paying = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: Column(children: [
      Container(color: kPrimary, child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Row(children: [
          const KAvatar(initials: 'RK'), const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My Bills', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Subscription & orders billing', style: TextStyle(fontSize: 11, color: Color(0xFF90CAF9))),
          ])),
          const Icon(Icons.download_rounded, color: Colors.white, size: 22),
        ]),
      ))),
      if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: kPrimary)))
      else Expanded(child: RefreshIndicator(onRefresh: _load, color: kPrimary,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // Unpaid bill hero
          ..._bills.where((b) => b.status != 'PAID').take(1).map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 16), child: _heroBill(b))),
          // Bill history
          const KSectionTitle(title: 'Bill History'), const SizedBox(height: 10),
          if (_bills.isEmpty)
            KCard(child: const Center(child: Padding(padding: EdgeInsets.all(8), child: Text('No bills yet', style: TextStyle(color: kTextLight, fontSize: 12)))))
          else
            ..._bills.map((b) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _billCard(b))),
          const SizedBox(height: 16),
          // Last orders
          if (_orders.isNotEmpty) ...[
            const KSectionTitle(title: 'Order History'), const SizedBox(height: 10),
            ..._orders.take(5).map((o) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _orderCard(o))),
            const SizedBox(height: 16),
          ],
          // Transactions
          const KSectionTitle(title: 'Recent Transactions'), const SizedBox(height: 10),
          KCard(padding: const EdgeInsets.fromLTRB(12, 4, 12, 0), child: Column(
            children: _txns.take(10).toList().asMap().entries.map((entry) {
              final tx = entry.value;
              final isLast = entry.key == (_txns.take(10).length - 1);
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : kBorder))),
                child: Row(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(
                    color: tx.isCredit ? kGreenLt : tx.isExtraFee ? kOrangeLt : const Color(0xFFFCEBEB),
                    borderRadius: BorderRadius.circular(10)),
                    child: Icon(tx.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: tx.isCredit ? kGreen : tx.isExtraFee ? kOrange : kRed, size: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tx.description, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(tx.shortDate, style: const TextStyle(fontSize: 9, color: kTextLight)),
                  ])),
                  Text('${tx.isCredit ? '+' : '−'}₹${tx.amount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: tx.isExtraFee ? kOrange : tx.isCredit ? kGreen : kRed)),
                ]),
              );
            }).toList(),
          )),
          const SizedBox(height: 16),
        ]),
      )),
    ]),
  );

  Widget _heroBill(Bill bill) => Container(
    decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(18)),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('CURRENT MONTH DUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF90CAF9), letterSpacing: 0.5)),
      const SizedBox(height: 6),
      Text('₹${bill.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
      Text('${bill.monthName} ${bill.billYear}', style: const TextStyle(fontSize: 11, color: Color(0xFF90CAF9))),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
        child: const Text('Unpaid', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _miniStat('Subscription', '₹${bill.subscriptionAmount.toStringAsFixed(0)}')),
        const SizedBox(width: 8),
        Expanded(child: _miniStat('One-time', '₹${bill.oneTimeAmount.toStringAsFixed(0)}')),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _miniStat('Extra Del.', '₹${bill.extraDeliveryAmount.toStringAsFixed(0)}')),
        const SizedBox(width: 8),
        // Delivery charge highlighted orange
        Expanded(child: Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Del. Charges', style: TextStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text('₹${bill.deliveryCharges.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          ]))),
      ]),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: _paying ? null : () => _payBill(bill),
        child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: _paying ? kGreenLt : kCard, borderRadius: BorderRadius.circular(12)),
          child: Center(child: _paying
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2))
              : Text('Pay ₹${bill.totalAmount.toStringAsFixed(0)} Now', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kPrimary)))),
      ),
    ]),
  );

  Widget _miniStat(String l, String v) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(fontSize: 8, color: Color(0xFF90CAF9), fontWeight: FontWeight.w600)), const SizedBox(height: 3),
    Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
  ]));

  Widget _billCard(Bill bill) {
    final isPaid = bill.status == 'PAID';
    return KCard(borderColor: isPaid ? const Color(0xFFA5D6A7) : const Color(0xFFFFCC80), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${bill.monthName} ${bill.billYear}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark)),
        KStatusBadge(label: bill.status, color: isPaid ? kGreen : kOrange, bg: isPaid ? kGreenLt : kOrangeLt),
      ]),
      const SizedBox(height: 10),
      _brow('Subscription', '₹${bill.subscriptionAmount.toStringAsFixed(0)}', kTextDark),
      const SizedBox(height: 4),
      _brow('One-time orders', '₹${bill.oneTimeAmount.toStringAsFixed(0)}', kTextDark),
      if (bill.extraDeliveryAmount > 0) ...[const SizedBox(height: 4), _brow('Extra delivery', '₹${bill.extraDeliveryAmount.toStringAsFixed(0)}', kTextDark)],
      if (bill.deliveryCharges > 0) ...[
        const SizedBox(height: 4),
        _brow('Delivery charges', '₹${bill.deliveryCharges.toStringAsFixed(0)}', kOrange),
      ],
      const Divider(color: kBorder, height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextDark)),
        Text('₹${bill.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kPrimary)),
      ]),
    ]));
  }

  Widget _orderCard(RecentOrder order) => KCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Order #${order.id}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextDark)),
      KStatusBadge(
        label: order.status,
        color: order.status == 'DELIVERED' ? kGreen : order.status == 'CANCELLED' ? kRed : kOrange,
        bg: order.status == 'DELIVERED' ? kGreenLt : order.status == 'CANCELLED' ? kRedLt : kOrangeLt,
      ),
    ]),
    const SizedBox(height: 8),
    ...order.items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 3), child: Row(children: [
      Text(item.emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 8),
      Expanded(child: Text('${item.name} × ${item.qty}', style: const TextStyle(fontSize: 11, color: kTextMid))),
      Text('₹${(item.unitPrice * item.qty).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextDark)),
    ]))),
    const Divider(color: kBorder, height: 12),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Items subtotal: ₹${order.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: kTextMid)),
        if (order.deliveryCharge > 0)
          Row(children: [
            const Icon(Icons.local_shipping_rounded, size: 11, color: kOrange),
            const SizedBox(width: 3),
            Text('Delivery (${order.distanceKm.toStringAsFixed(1)}km): ₹${order.deliveryCharge.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 10, color: kOrange, fontWeight: FontWeight.w700)),
          ]),
      ]),
      Text('₹${(order.totalAmount + order.deliveryCharge).toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kPrimary)),
    ]),
    const SizedBox(height: 4),
    Text(order.createdAt.length >= 10 ? order.createdAt.substring(0, 10) : order.createdAt, style: const TextStyle(fontSize: 9, color: kTextLight)),
  ]));

  Row _brow(String l, String v, Color c) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(l, style: const TextStyle(fontSize: 11, color: kTextMid)),
    Text(v, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
  ]);
}
