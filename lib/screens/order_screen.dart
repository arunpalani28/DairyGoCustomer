import 'package:dairygo_customer/models/models.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../widgets/theme.dart';

class OrdersScreen extends StatefulWidget {
  final Function(int index)? onNavigate;
  const OrdersScreen({super.key, this.onNavigate});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Map? activeOrder;
  UserProfile? _profile;
  List history = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final activeRes = await ApiClient.get('/customer/orders/active');
      final historyRes = await ApiClient.get('/customer/orders/history');
      final _profileres = await ApiClient.get('/customer/profile');
      setState(() {
        _profile = UserProfile.fromJson(_profileres['data']);
        activeOrder = activeRes['data'];
        history = historyRes['data'] ?? [];
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }
Widget _emptyOrdersPlaceholder() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade100),
    ),
    child: Column(
      children: [
        Icon(Icons.shopping_bag_outlined, color: Colors.grey.shade300, size: 40),
        const SizedBox(height: 8),
        Text(
          "No recent orders found",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      body: Column(
        children: [
          _buildHeader(), // Your Original Design preserved
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (activeOrder == null && history.isEmpty)...[
                          _emptyOrdersPlaceholder()
                        ],
                        if (activeOrder != null) ...[
                          _sectionTitle("TRACK ORDER"),
                          _activeOrderCard(),
                        ],
                        if (history.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _sectionTitle("PAST ORDERS"),
                          ...history.map((o) => _historyCard(o)).toList()
                        ]
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[600], letterSpacing: 1)),
    );
  }

  /// 🔵 YOUR ORIGINAL HEADER (UNCHANGED)
  Widget _buildHeader() => Container(
        color: kPrimary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                child: Text(_profile?.initials ?? 'RK', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('My Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ])),
              GestureDetector(
                onTap: _load,
                child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18)),
              ),
            ]),
          ),
        ),
      );

  /// 🚚 SOLID ACTIVE CARD DESIGN
  Widget _activeOrderCard() {
    List items = activeOrder!['items'] ?? [];
    String status = activeOrder!['status'] ?? 'PLACED';

    return Container(
      decoration: BoxDecoration(
        color: kGreenLt, // Solid White
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimary.withOpacity(0.2), width: 1.5), // Stronger primary border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 12, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Current Delivery", 
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text("₹${activeOrder!['totalAmount']}", 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Minimalist Product Badges
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items.map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8), // Solid soft blue-grey
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text("${item['quantity']}x ${item['productName']}", 
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4A5568))),
              )).toList(),
            ),
            const SizedBox(height: 20),
            _buildCenterRoadmap(status),
          ],
        ),
      ),
    );
  }


 Widget _historyCard(Map o) {
  List items = o['items'] ?? [];
  bool isCanceled = o['status'] == 'CANCELLED';
  
  String orderDate = o['date'] ?? "";
  String deliveryDate = o['deliveryDate'] ?? "Pending";

  Color accentColor = isCanceled ? const Color(0xFFD32F2F) : kGreen;
  Color iconBg = isCanceled ? Colors.red.shade50 : const Color(0xFFF0F4F8);

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))
      ],
    ),
    child: Column(
      children: [
        // --- HEADER: CENTER ALIGNED ---
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // CRITICAL: Centers everything in the row
            children: [
              // Icon Container
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCanceled ? Icons.close_rounded : Icons.local_shipping_outlined,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              
              // Text Column: Centered relative to the icon
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Shrinks to fit text height
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderDate,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800, 
                        fontSize: 14,
                        height: 1.2, // Removes extra vertical space
                      ),
                    ),
                    Text(
                      isCanceled ? "Canceled" : "Delivered: $deliveryDate",
                      style: TextStyle(
                        fontSize: 11, 
                        color: isCanceled ? Colors.red.shade400 : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Price: Also centered relative to the row
              Text(
                "₹${o['totalAmount']}",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: isCanceled ? Colors.grey.shade400 : Colors.black,
                  decoration: isCanceled ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),

        // --- BULLETED ITEMS ---
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "${item['quantity']}x ",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor),
                  ),
                  Expanded(
                    child: Text(
                      "${item['productName']}",
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // --- FOOTER ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ID: #${o['orderId']}",
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {},
                child: Text(
                  isCanceled ? "Not Paid" : "Paid",
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  /// 🛤 CENTER ALIGNED ROADMAP WITH COLORFUL ICONS
  Widget _buildCenterRoadmap(String currentStatus) {
    final stages = [
      {'title': 'Confirmed', 'key': 'PLACED', 'icon': Icons.receipt_long, 'color': Colors.blue},
      {'title': 'On Way', 'key': 'ASSIGNED', 'icon': Icons.delivery_dining, 'color': Colors.orange},
      {'title': 'Delivered', 'key': 'DELIVERED', 'icon': Icons.check_circle, 'color': Colors.green},
    ];

    int currentIndex = stages.indexWhere((element) => element['key'] == currentStatus);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: stages.asMap().entries.map((entry) {
        int idx = entry.key;
        bool isDone = idx <= currentIndex;
        bool isLast = idx == stages.length - 1;
        Color stageColor = entry.value['color'] as Color;

        return Expanded(
          child: Row(
            children: [
              // Icon and Text Column
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? stageColor.withOpacity(0.15) : Colors.grey[100],
                        border: isDone ? Border.all(color: stageColor, width: 1.5) : null,
                      ),
                      child: Icon(
                        entry.value['icon'] as IconData,
                        size: 18,
                        color: isDone ? stageColor : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.value['title'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                        color: isDone ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Connector
              if (!isLast)
                Container(
                  width: 30,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 20),
                  color: isDone ? stageColor.withOpacity(0.5) : Colors.grey[200],
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

}