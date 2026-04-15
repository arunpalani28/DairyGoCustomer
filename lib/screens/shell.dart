import 'package:flutter/material.dart';
import '../widgets/theme.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'shop_screen.dart';
import 'bills_screen.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _tab = 0;
  int _cartCount = 0;

  void _updateCart(int count) {
    setState(() => _cartCount = count);
  }

  void _switchTab(int idx) {
    setState(() {
      _tab = idx; // rebuild triggers fresh screen instance
    });
  }
  Widget _buildPage() {
    // 🔥 KEY FIX: new Key forces full rebuild → initState runs → APIs reload
    switch (_tab) {
      case 0:
        return HomeScreen(
          key: UniqueKey(),
          onCartUpdate: _updateCart,
          onNavigate: _switchTab,
        );

      case 1:
        return CalendarScreen(
          key: UniqueKey(),
          onNavigate: _switchTab,
        );

      case 2:
        return ShopScreen(
          key: UniqueKey(),
          onCartChange: _updateCart,
          onNavigate: _switchTab,
        );

      case 3:
        return BillsScreen(
          key: UniqueKey(),
          onNavigate: _switchTab,
        );

      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: _buildPage(),

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: kCard,
          boxShadow: [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            )
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 66,
            child: Row(
              children: [
                _ni(0, Icons.home_rounded, 'Home'),
                _ni(1, Icons.calendar_month_rounded, 'Calendar'),
                _cartNi(),
                _ni(3, Icons.receipt_long_rounded, 'Bills'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ni(int idx, IconData icon, String label) {
    final on = _tab == idx;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _switchTab(idx),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: on ? kPrimary : kTextLight, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: on ? kPrimary : kTextLight,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: on ? 6 : 0,
              height: on ? 6 : 0,
              decoration: const BoxDecoration(
                color: kPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartNi() {
    final on = _tab == 2;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _switchTab(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.shopping_cart_rounded,
                  color: on ? kPrimary : kTextLight,
                  size: 24,
                ),
                if (_cartCount > 0)
                  Positioned(
                    top: -5,
                    right: -7,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$_cartCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Shop',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: on ? kPrimary : kTextLight,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: on ? 6 : 0,
              height: on ? 6 : 0,
              decoration: const BoxDecoration(
                color: kPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}