import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../widgets/theme.dart';
import 'shell.dart';
import 'kyc_screen.dart';
class KTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool readOnly;
  final Function(String)? onChanged;
  final Widget? prefix;
  final int? maxLength;

  const KTextField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.readOnly = false,
    this.onChanged,
    this.prefix,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: readOnly,
        onChanged: onChanged,
        maxLength: maxLength,

        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: kTextDark,
        ),

        decoration: InputDecoration(
          labelText: label,

          /// 🔷 LABEL STYLE
          labelStyle: const TextStyle(
            fontSize: 12,
            color: kTextMid,
            fontWeight: FontWeight.w500,
          ),

          /// 🔷 PREFIX ICON
          prefixIcon: prefix,

          /// 🔷 BACKGROUND
          filled: true,
          fillColor: const Color(0xFFF9FBFF),

          /// 🔷 REMOVE COUNTER (0/6)
          counterText: '',

          /// 🔷 PADDING
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),

          /// 🔷 BORDERS
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kPrimary, width: 1.4),
          ),

          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kRed),
          ),

          /// 🔷 HINT (optional)
          hintStyle: const TextStyle(
            fontSize: 12,
            color: kTextLight,
          ),
        ),
      ),
    );
  }
}

// ── SPLASH ────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 9000));
    final token = await ApiClient.loadToken();

    if (!mounted) return;

    if (token != null) {
      final userData = await ApiClient.loadUserData();
      final kycStatus = userData?['kycStatus'] ?? 'PENDING';

      if (kycStatus == 'VERIFIED') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerShell()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => KycGateScreen(userData: userData)),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔥 LOGO HERE
            Image.asset(
              'app_logo.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 40),

            const CircularProgressIndicator(
              color: kPrimary,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ── LOGIN (Mobile + OTP, no password) ─────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginState();
}
class _LoginState extends State<LoginScreen> {
  final _mobileCtrl = TextEditingController();
  final _otpCtrl    = TextEditingController();
  bool _loading = false, _otpSent = false;
  String? _error;
  int _resendSecs = 0;
  Timer? _timer;
  String? _otpNumber;

  @override void dispose() { _mobileCtrl.dispose(); _otpCtrl.dispose(); _timer?.cancel(); super.dispose(); }

  Future<void> _sendOtp() async {
    final mobile = _mobileCtrl.text.trim();
    if (mobile.length < 10) { setState(() => _error = 'Enter a valid 10-digit mobile number'); return; }
    setState(() { _loading = true; _error = null; });
    try {
     final res= await ApiClient.post('/auth/send-otp', {'mobile': mobile});
      setState(() { _otpNumber=res["data"];_otpSent = true; _loading = false; _resendSecs = 30; });
      _startTimer();
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_resendSecs <= 0) { _timer?.cancel(); setState(() {}); return; }
      setState(() => _resendSecs--);
    });
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.length != 6) { setState(() => _error = 'Enter the 6-digit OTP'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.post('/auth/verify-otp', {
        'mobile': _mobileCtrl.text.trim(), 'otp': _otpCtrl.text.trim()
      });
      final data = res['data'] as Map<String, dynamic>;
      if (data['role'] != 'CUSTOMER') {
        setState(() { _error = 'This app is for customers only.'; _loading = false; }); return;
      }
      await ApiClient.saveToken(data['token']);
      await ApiClient.saveUserData(data);
      if (!mounted) return;
      final kycStatus = data['kycStatus'] ?? 'PENDING';
      if (kycStatus == 'VERIFIED') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CustomerShell()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => KycGateScreen(userData: data)));
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kGreenLt,
    body: SafeArea(child: Column(children: [
      Expanded(flex: 2, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Text('🥛', style: TextStyle(fontSize: 60)),
        SizedBox(height: 12),
            Image.asset(
              'app_logo.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
        // Text('Aavinam Madurai', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
       // Text('Customer App', style: TextStyle(fontSize: 13, color: Color(0xFF90CAF9))),
      ]))),
      Expanded(flex: 3, child: Container(
        decoration: const BoxDecoration(color: kBg, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_otpSent ? 'Enter OTP' : 'Sign In',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kTextDark)),
          SizedBox(height: 4),
          Text(_otpSent ? '' : 'Enter your mobile number',
              style: const TextStyle(fontSize: 13, color: kTextMid)),
          const SizedBox(height: 24),
          if (!_otpSent) ...[
            KTextField(
              label: 'Mobile Number',
              controller: _mobileCtrl,
              keyboardType: TextInputType.phone,
             prefix: Container(
  width: 60,
  alignment: Alignment.center,
  decoration: const BoxDecoration(
    border: Border(
      right: BorderSide(color: Colors.grey, width: 0.5),
    ),
  ),
  child: const Text(
    '+91',
    style: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 13,
      color: kTextDark,
    ),
  ),
)),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: kGreenLt, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: kGreen, size: 16),
                const SizedBox(width: 8),
                Text('OTP is ${_otpNumber}', style: const TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 14),
            KTextField(
              label: 'Enter 6-digit OTP',
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              GestureDetector(
                onTap: _resendSecs > 0 ? null : _sendOtp,
                child: Text(
                  _resendSecs > 0 ? 'Resend in ${_resendSecs}s' : 'Resend OTP',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: _resendSecs > 0 ? kTextLight : kPrimary),
                ),
              ),
            ]),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: kRed, size: 16), const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: kRed, fontSize: 12))),
              ])),
          ],
          const SizedBox(height: 24),
          KPrimaryButton(
            label: _otpSent ? 'Verify OTP' : 'Send OTP',
            loading: _loading,
            onTap: _otpSent ? _verifyOtp : _sendOtp,
          ),
          if (_otpSent) ...[
            const SizedBox(height: 12),
            Center(child: GestureDetector(
              onTap: () => setState(() { _otpSent = false; _otpCtrl.clear(); _error = null; }),
              child: const Text('Change mobile number',
                  style: TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600)),
            )),
          ],
          const SizedBox(height: 16),
          // Center(child: Text('Demo: use 9000000002 (Customer)', style: TextStyle(fontSize: 11, color: kTextLight))),
        ])),
      )),
    ])),
  );
}

// ── KYC GATE (shown after login if KYC not verified) ─────────────────────────
class KycGateScreen extends StatelessWidget {
  final Map<String, dynamic>? userData;
  const KycGateScreen({super.key, this.userData});

  @override Widget build(BuildContext context) {
    final status = userData?['kycStatus'] ?? 'PENDING';
    final name = userData?['name'] ?? '';
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 88, height: 88,
            decoration: BoxDecoration(color: kOrangeLt, borderRadius: BorderRadius.circular(44)),
            child: const Center(child: Text('🪪', style: TextStyle(fontSize: 44)))),
          const SizedBox(height: 24),
          Text(status == 'REJECTED' ? 'KYC Rejected' : 'KYC Pending',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                  color: status == 'REJECTED' ? kRed : kTextDark)),
          const SizedBox(height: 10),
          Text(
            status == 'REJECTED'
                ? 'Your KYC was rejected. Please re-submit with correct details. Our team will call you shortly.'
                : status == 'PENDING' && (name.isEmpty)
                    ? 'Welcome! Please complete your KYC to start receiving deliveries. Our team will verify and call you shortly.'
                    : 'Your KYC is under review. Our team will call you shortly to verify your address and schedule deliveries.',
            style: const TextStyle(fontSize: 13, color: kTextMid, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (status != 'VERIFIED')
            KPrimaryButton(
              label: '📋  Submit / Update KYC',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const KycFormScreen())),
            ),
          const SizedBox(height: 16),
          if (status == 'PENDING' && name.isNotEmpty)
            Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: kPrimaryLt, borderRadius: BorderRadius.circular(12)),
              child: Row(children: const [
                Icon(Icons.info_rounded, color: kPrimary, size: 18), SizedBox(width: 8),
                Expanded(child: Text('Our team will call you within 24 hours to verify your KYC and set up your subscription.',
                    style: TextStyle(fontSize: 12, color: kPrimary, height: 1.5))),
              ])),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () async { await ApiClient.clearToken(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())); },
            child: const Text('Sign Out', style: TextStyle(color: kTextLight, fontSize: 12)),
          ),
        ]),
      ))),
    );
  }
}
