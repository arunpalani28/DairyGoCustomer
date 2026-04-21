import 'package:dairygo_customer/screens/order_screen.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/models.dart';
import '../widgets/theme.dart';

class ShopScreen extends StatefulWidget {
  final Function(int) onCartChange;
  final Function(int index)? onNavigate;

  const ShopScreen({
    super.key,
    required this.onCartChange,
    this.onNavigate,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<Product> _products = [];

  static final Map<int, int> _cart = {};
  static final Map<int, Product> _productMap = {};

  bool _loading = true, _showCart = false, _ordering = false;

  @override
  void initState() {
    super.initState();
    checkActiveOrder();
    _load();
  }
bool _hasActiveOrder = false;

Future<void> checkActiveOrder() async {
  final res = await ApiClient.get('/customer/orders/active');
  setState(() {
    _hasActiveOrder = res['data'] != null;
  });
}
  Future<void> _load() async {
    try {
      final res = await ApiClient.get('/customer/products');

      final list =
          (res['data'] as List).map((e) => Product.fromJson(e)).toList();

      _productMap.clear();
      for (var p in list) {
        _productMap[p.id] = p;
      }

      setState(() {
        _products = list;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Product? _findProduct(int id) => _productMap[id];

  int get _cartTotal => _cart.values.fold(0, (s, q) => s + q);

  double get _cartPrice {
    double total = 0;
    _cart.forEach((id, qty) {
      final p = _findProduct(id);
      if (p != null) total += p.price * qty;
    });
    return total;
  }

  /// ✅ NEW: Charges
  double get _gst => _cartPrice * 0.05;
  double get _packing => _cart.isNotEmpty ? 10 : 0;
  double get _delivery =>  0;
  double get _grandTotal => _cartPrice + _gst + _packing + _delivery;

  void _addToCart(int productId) {
    setState(() {
      _cart[productId] = (_cart[productId] ?? 0) + 1;
    });

    // ✅ FIX: prevent tab switch issue
    if (!_showCart) {
      widget.onCartChange(_cartTotal);
    }
  }

  void _changeQty(int productId, int delta) {
    setState(() {
      final newQty = (_cart[productId] ?? 0) + delta;
      if (newQty <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = newQty;
      }
    });

    // ✅ FIX: prevent tab switch
    if (!_showCart) {
      widget.onCartChange(_cartTotal);
    }
  }

  /// ✅ NEW: Confirm popup
Future<void> _placeOrder() async {
  if (_cart.isEmpty) return;

  final confirm = await _showConfirmDialog();
  if (confirm != true) return;

  setState(() => _ordering = true);

  try {
    final items = _cart.entries
        .map((e) => {'productId': e.key, 'qty': e.value})
        .toList();

    await ApiClient.post('/customer/orders', {'items': items});

    setState(() {
      _cart.clear();
      _showCart = false;
    });

    widget.onCartChange(0);

    /// ✅ SHOW SUCCESS
    await _showSuccessDialog();

    /// 🔥 CRITICAL FIX
    // if (!mounted) return;

    /// use root navigator
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => const OrdersScreen(),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  } finally {
    if (mounted) setState(() => _ordering = false);
  }
}

Widget _stab(String label, bool on, VoidCallback tap) {
  return Expanded(
    child: GestureDetector(
      onTap: tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: on ? kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: on ? Colors.white : kTextLight,
            ),
          ),
        ),
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          /// HEADER (UNCHANGED)
          Container(
            color: kPrimary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const KAvatar(initials: 'RK'),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Store',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                              Text('One-time essentials',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF90CAF9))),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _showCart = true),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.shopping_cart_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _stab('Products', !_showCart,
                              () => setState(() => _showCart = false)),
                          _stab(
                            _cartTotal > 0
                                ? 'Cart ($_cartTotal)'
                                : 'Cart',
                            _showCart,
                            () => setState(() => _showCart = true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),

          /// BODY
          if (_loading)
            const Expanded(
                child:
                    Center(child: CircularProgressIndicator(color: kPrimary)))
          else if (!_showCart)
            _productGrid()
          else
            _cartView(),
        ],
      ),
    );
  }
Widget _productGrid() {
  return Expanded(
    child: GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: _products.length,
      itemBuilder: (ctx, i) {
        final p = _products[i];
        final inCart = _cart[p.id] ?? 0;

        return KCard(
          padding: const EdgeInsets.all(13),
          child: Column(
            children: [
              Text(p.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 6),

              Text(
                p.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),

              Text(
                p.weightLabel,
                style: const TextStyle(fontSize: 9, color: kTextLight),
              ),

              const SizedBox(height: 4),

              Text(
                '₹${p.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kPrimary,
                ),
              ),

              const Spacer(),

              /// ✅ ADD / QTY (unchanged design)
              inCart > 0
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _qbtn(Icons.remove_rounded,
                            () => _changeQty(p.id, -1)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('$inCart'),
                        ),
                        _qbtn(Icons.add_rounded,
                            () => _changeQty(p.id, 1)),
                      ],
                    )
                  : GestureDetector(
                      onTap: () => _addToCart(p.id),
                      child: Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'Add to Cart',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    ),
  );
}
Widget _modernQtyBtn(IconData icon, VoidCallback onTap) {
  return InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Container(
      width: 32,
      height: 34,
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: kPrimary),
    ),
  );
}
  /// 🛒 CART VIEW (UNCHANGED UI + added bill)
Widget _cartView() {
  if (_cart.isEmpty) {
    return Expanded(
      child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text("🛒", style: TextStyle(fontSize: 60)),
          SizedBox(height: 12),
          Text("Your cart is empty",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text("Add items from Products",
              style: TextStyle(fontSize: 12, color: kTextLight)),
        ],
      ),
    ));
  }

  return Expanded(
      child: Column(
    children: [
      /// 🎁 FREE DELIVERY BANNER
      if (_delivery == 0)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: const [
              Icon(Icons.local_offer, color: kGreen, size: 16),
              SizedBox(width: 6),
              Text("Free Delivery Coupon Applied",
                  style: TextStyle(
                      color: kGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),

      /// 🧾 CART LIST
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: _cart.length,
          itemBuilder: (ctx, i) {
            final entry = _cart.entries.toList()[i];
            final p = _findProduct(entry.key);
            if (p == null) return const SizedBox();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  )
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  /// Emoji
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(p.emoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),

                  const SizedBox(width: 12),

                  /// NAME + PRICE (FIXED HEIGHT BEHAVIOR)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 2, // ✅ FIX
                          overflow: TextOverflow.ellipsis, // ✅ FIX
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kTextDark),
                        ),
                        const SizedBox(height: 4),
                        Text("₹${p.price.toStringAsFixed(0)} each",
                            style: const TextStyle(
                                fontSize: 11, color: kTextLight)),
                      ],
                    ),
                  ),

                  /// QTY CONTROL (FIXED WIDTH)
                  Container(
                    width: 110, // ✅ keeps alignment stable
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6FA),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _modernQtyBtn(Icons.remove,
                            () => _changeQty(p.id, -1)),
                        Text(
                          "${entry.value}",
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                        _modernQtyBtn(Icons.add,
                            () => _changeQty(p.id, 1)),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  /// PRICE
                  SizedBox(
                    width: 60, // ✅ fixed width aligns all rows
                    child: Text(
                      "₹${(p.price * entry.value).toStringAsFixed(0)}",
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kPrimary),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),

      /// 💳 BILL SECTION
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kBorder)),
          boxShadow: [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, -4),
            )
          ],
        ),
        child: Column(
          children: [
            _billRow("Subtotal", _cartPrice),
            _billRow("GST (5%)", _gst),
            _billRow("Packing", _packing),
            _billRow("Delivery", _delivery),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total",
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text("₹${_grandTotal.toStringAsFixed(0)}",
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kPrimary)),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                  onPressed: _hasActiveOrder ? null : _placeOrder, 
                  style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
    _hasActiveOrder ? "Order in Progress" : "Place Order",
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            )
          ],
        ),
      ),
    ],
  ));
}

Widget _billRow(String label, double value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: kTextLight)),
        Text("₹${value.toStringAsFixed(0)}",
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
Widget _qtyBtn(IconData icon, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(4),
      child: Icon(icon, size: 16, color: kPrimary),
    ),
  );
}


  Widget _qbtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Icon(icon, size: 15, color: kPrimary),
      ),
    );
  }


Future<void> _showSuccessDialog() async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 60, color: Colors.green),
              const SizedBox(height: 10),
              const Text("Order Placed 🎉"),
              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // ✅ SAFE POP
                },
                child: const Text("ok"),
              )
            ],
          ),
        ),
      );
    },
  );
}

Future<bool?> _showConfirmDialog() {
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag, size: 40, color: kPrimary),
            const SizedBox(height: 10),
            const Text(
              "Confirm Order",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text("Pay ₹${_grandTotal.toStringAsFixed(0)}"),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Confirm"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    ),
  );
}
}