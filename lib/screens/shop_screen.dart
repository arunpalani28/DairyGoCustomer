import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/models.dart';
import '../widgets/theme.dart';

class ShopScreen extends StatefulWidget {
  final Function(int) onCartChange;
  final Function(int index)? onNavigate;
  const ShopScreen({super.key, required this.onCartChange,
  this.onNavigate});
  @override State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<Product> _products = [];
  final Map<int, int> _cart = {}; // productId → qty
  bool _loading = true, _showCart = false, _ordering = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await ApiClient.get('/customer/products');
      setState(() {
        _products = (res['data'] as List).map((e) => Product.fromJson(e)).toList();
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  int get _cartTotal => _cart.values.fold(0, (s, q) => s + q);
  double get _cartPrice {
    double total = 0;
    _cart.forEach((id, qty) {
      final p = _products.where((p) => p.id == id).firstOrNull;
      if (p != null) total += p.price * qty;
    });
    return total;
  }

  void _addToCart(int productId) {
    setState(() => _cart[productId] = (_cart[productId] ?? 0) + 1);
    widget.onCartChange(_cartTotal);
  }

  void _changeQty(int productId, int delta) {
    setState(() {
      final newQty = (_cart[productId] ?? 0) + delta;
      if (newQty <= 0) _cart.remove(productId); else _cart[productId] = newQty;
    });
    widget.onCartChange(_cartTotal);
  }

  Future<void> _placeOrder() async {
    if (_cart.isEmpty) return;
    setState(() => _ordering = true);
    try {
      final items = _cart.entries.map((e) => {'productId': e.key, 'qty': e.value}).toList();
      await ApiClient.post('/customer/orders', {'items': items});
      setState(() { _cart.clear(); _showCart = false; });
      widget.onCartChange(0);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed! 🎉 Delivery by tomorrow morning.'), backgroundColor: kGreen));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _ordering = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: Column(children: [
      // Header
      Container(color: kPrimary, child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(children: [
          Row(children: [
            const KAvatar(initials: 'RK'),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Store', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('One-time essentials', style: TextStyle(fontSize: 11, color: Color(0xFF90CAF9))),
            ])),
            GestureDetector(
              onTap: () => setState(() => _showCart = true),
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 18)),
            ),
          ]),
          const SizedBox(height: 12),
          // Tab bar
          Container(
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(4),
            child: Row(children: [
              _stab('Products', !_showCart, () => setState(() => _showCart = false)),
              _stab(_cartTotal > 0 ? 'Cart ($_cartTotal)' : 'Cart', _showCart,
                  () => setState(() => _showCart = true)),
            ]),
          ),
          const SizedBox(height: 12),
        ]),
      ))),
      // Content
      if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: kPrimary)))
      else if (!_showCart) _productGrid()
      else _cartView(),
    ]),
  );

  Widget _stab(String label, bool on, VoidCallback tap) => Expanded(
    child: GestureDetector(onTap: tap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: on ? kPrimary : Colors.transparent, borderRadius: BorderRadius.circular(9)),
        child: Center(child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: on ? Colors.white : kTextLight))))));

  Widget _productGrid() => Expanded(child: GridView.builder(
    padding: const EdgeInsets.all(14),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.8),
    itemCount: _products.length,
    itemBuilder: (ctx, i) {
      final p = _products[i];
      final inCart = _cart[p.id] ?? 0;
      return KCard(padding: const EdgeInsets.all(13), child: Column(children: [
        Text(p.emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 6),
        Text(p.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextDark), textAlign: TextAlign.center),
        Text(p.weightLabel, style: const TextStyle(fontSize: 9, color: kTextLight)),
        const SizedBox(height: 4),
        Text('₹${p.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kPrimary)),
        const Spacer(),
        inCart > 0
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _qbtn(Icons.remove_rounded, () => _changeQty(p.id, -1)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('$inCart', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark))),
                _qbtn(Icons.add_rounded, () => _changeQty(p.id, 1)),
              ])
            : GestureDetector(
                onTap: () => _addToCart(p.id),
                child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('Add to Cart',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))))),
      ]));
    },
  ));

  Widget _cartView() {
    if (_cart.isEmpty) {
      return Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🛒', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        const Text('Your cart is empty', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextMid)),
        const SizedBox(height: 6),
        const Text('Add items from the Products tab', style: TextStyle(fontSize: 12, color: kTextLight)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => setState(() => _showCart = false),
          style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
          child: const Text('Browse Products'),
        ),
      ])));
    }
    return Column(children: [
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _cart.length,
        itemBuilder: (ctx, i) {
          final entry = _cart.entries.toList()[i];
          final p = _products.where((pr) => pr.id == entry.key).firstOrNull;
          if (p == null) return const SizedBox();
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: KCard(child: Row(children: [
            Text(p.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextDark)),
              Text('₹${p.price.toStringAsFixed(0)} each', style: const TextStyle(fontSize: 10, color: kTextLight)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${(p.price * entry.value).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary)),
              const SizedBox(height: 6),
              Row(children: [
                _qbtn(Icons.remove_rounded, () => _changeQty(p.id, -1)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('${entry.value}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark))),
                _qbtn(Icons.add_rounded, () => _changeQty(p.id, 1)),
              ]),
            ]),
          ])));
        },
      )),
      // Cart footer
      Container(
        decoration: const BoxDecoration(color: kCard, border: Border(top: BorderSide(color: kBorder))),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _totRow('Subtotal', '₹${_cartPrice.toStringAsFixed(0)}', kTextDark),
          const SizedBox(height: 4),
          _totRow('Delivery', 'Free', kGreen),
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(color: kBorder, height: 1)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
            Text('₹${_cartPrice.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kPrimary)),
          ]),
          const SizedBox(height: 12),
          KPrimaryButton(label: 'Place Order  →', loading: _ordering, onTap: _placeOrder),
        ]),
      ),
    ]);
  }

  Widget _qbtn(IconData icon, VoidCallback onTap) => GestureDetector(onTap: onTap,
    child: Container(width: 26, height: 26,
      decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
      child: Icon(icon, size: 15, color: kPrimary)));

  Row _totRow(String l, String v, Color vc) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(l, style: const TextStyle(fontSize: 11, color: kTextMid)),
    Text(v, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: vc)),
  ]);
}
