import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../widgets/theme.dart';

class KycFormScreen extends StatefulWidget {
  const KycFormScreen({super.key});
  @override State<KycFormScreen> createState() => _KycFormState();
}

class _KycFormState extends State<KycFormScreen> {
  final _nameCtrl     = TextEditingController();
  final _altCtrl      = TextEditingController();
  final _waCtrl       = TextEditingController();
  final _addrCtrl     = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _cityCtrl     = TextEditingController();
  final _pinCtrl      = TextEditingController();
  final _notesCtrl    = TextEditingController();
  String _freq = 'MORNING';
  String _time = '6:00 AM – 7:00 AM';
  double _advance = 500;
  bool _loading = false;
  String? _error;
  int _step = 0;

  @override void dispose() {
    for (final c in [_nameCtrl,_altCtrl,_waCtrl,_addrCtrl,_landmarkCtrl,_cityCtrl,_pinCtrl,_notesCtrl]) c.dispose();
    super.dispose();
  }

// ✅ NEW: load existing KYC
  @override
  void initState() {
    super.initState();
    _loadKyc();
  }

  Future<void> _loadKyc() async {
    setState(() => _loading = true);

    try {
      final data = await ApiClient.get('/kyc/me');
final res = data['data'];
      if (res != null && res is Map<String, dynamic>) {
        setState(() {
          _nameCtrl.text     = res['fullName'] ?? '';
          _altCtrl.text      = res['alternateMobile'] ?? '';
          _waCtrl.text       = res['whatsappNumber'] ?? '';
          _addrCtrl.text     = res['address'] ?? '';
          _landmarkCtrl.text = res['landmark'] ?? '';
          _cityCtrl.text     = res['city'] ?? '';
          _pinCtrl.text      = res['pincode'] ?? '';
          _notesCtrl.text    = res['notes'] ?? '';

          _freq    = res['deliveryFrequency'] ?? 'MORNING';
          _time    = res['preferredTime'] ?? '6:00 AM – 7:00 AM';
          _advance = (res['advancePayment'] ?? 500).toDouble();
        });
      }
    } catch (e) {
      debugPrint("No existing KYC or error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _addrCtrl.text.trim().isEmpty || _cityCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please fill all required fields'); return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.post('/kyc/submit', {
        'fullName': _nameCtrl.text.trim(),
        'alternateMobile': _altCtrl.text.trim(),
        'whatsappNumber': _waCtrl.text.trim(),
        'address': _addrCtrl.text.trim(),
        'landmark': _landmarkCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'pincode': _pinCtrl.text.trim(),
        'deliveryFrequency': _freq,
        'preferredTime': _time,
        'advancePayment': _advance,
        'notes': _notesCtrl.text.trim(),
      });
      if (!mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎉', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 14),
          const Text('KYC Submitted!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextDark)),
          const SizedBox(height: 8),
          const Text('Our team will call you shortly to verify your address and complete setup. Advance payment of ₹500 will be refunded after your first month bill.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kTextMid, height: 1.6)),
          const SizedBox(height: 20),
          KPrimaryButton(label: 'Got it!', onTap: () {
            Navigator.pop(context);
            Navigator.pop(context);
          }),
        ]),
      ));
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(backgroundColor: kPrimary, foregroundColor: Colors.white, elevation: 0,
      title: const Text('KYC Registration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    ),
    body: Column(children: [
      // Step indicator
      Container(color: kPrimary, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Row(children: [
        _stepDot(0, 'Personal'), const Expanded(child: Divider(color: Colors.white38)),
        _stepDot(1, 'Address'), const Expanded(child: Divider(color: Colors.white38)),
        _stepDot(2, 'Delivery'),
      ])),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        if (_step == 0) ..._step0(),
        if (_step == 1) ..._step1(),
        if (_step == 2) ..._step2(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(10)),
            child: Text(_error!, style: const TextStyle(color: kRed, fontSize: 12))),
        ],
        const SizedBox(height: 20),
        Row(children: [
          if (_step > 0) ...[
            Expanded(child: OutlinedButton(
              onPressed: () => setState(() => _step--),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Back'),
            )),
            const SizedBox(width: 12),
          ],
          Expanded(child: ElevatedButton(
            onPressed: _loading ? null : () {
              if (_step < 2) setState(() => _step++); else _submit();
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_step == 2 ? 'Submit KYC' : 'Continue',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          )),
        ]),
        const SizedBox(height: 16),
      ]))),
    ]),
  );

  List<Widget> _step0() => [
    const _StepHeader(icon: '👤', title: 'Personal Information', subtitle: 'Your basic contact details'),
    const SizedBox(height: 20),
    KTextField(label: 'Full Name *', controller: _nameCtrl),
    const SizedBox(height: 14),
    KTextField(label: 'Alternate Mobile', controller: _altCtrl, keyboardType: TextInputType.phone),
    const SizedBox(height: 14),
    KTextField(label: 'WhatsApp Number', controller: _waCtrl, keyboardType: TextInputType.phone),
    const SizedBox(height: 14),
    KTextField(label: 'Notes (optional)', controller: _notesCtrl, maxLines: 2),
  ];

  List<Widget> _step1() => [
    const _StepHeader(icon: '🏠', title: 'Delivery Address', subtitle: 'Where should we deliver?'),
    const SizedBox(height: 20),
    KTextField(label: 'Full Address *', controller: _addrCtrl, maxLines: 3),
    const SizedBox(height: 14),
    KTextField(label: 'Landmark', controller: _landmarkCtrl),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: KTextField(label: 'City *', controller: _cityCtrl)),
      const SizedBox(width: 12),
      Expanded(child: KTextField(label: 'Pincode', controller: _pinCtrl, keyboardType: TextInputType.number)),
    ]),
  ];

  List<Widget> _step2() => [
    const _StepHeader(icon: '🥛', title: 'Delivery Preferences', subtitle: 'Set up your subscription details'),
    const SizedBox(height: 20),
    _label('Delivery Frequency *'),
    const SizedBox(height: 8),
    Row(children: [
      _freqBtn('MORNING', '🌅 Morning'),
      // const SizedBox(width: 8),
      // _freqBtn('EVENING', '🌙 Evening'),
      // const SizedBox(width: 8),
      // _freqBtn('BOTH', '⏰ Both'),
    ]),
    const SizedBox(height: 16),
    _label('Preferred Time Slot'),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: [
      '6:00 AM – 7:00 AM', '7:00 AM – 8:00 AM',
      // '5:00 PM – 6:00 PM', '6:00 PM – 7:00 PM',
    ].map((t) => GestureDetector(
      onTap: () => setState(() => _time = t),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _time == t ? kPrimary : kCard, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _time == t ? kPrimary : kBorder)),
        child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _time == t ? Colors.white : kTextMid))),
    )).toList()),
    const SizedBox(height: 16),
    _label('Advance Payment'),
    const SizedBox(height: 4),
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: kOrangeLt, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFCC80))), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Advance Amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOrange)),
        Text('₹${_advance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kOrange)),
      ]),
      const SizedBox(height: 8),
      const Text('This amount will be fully refunded after your first month\'s bill is settled.',
          style: TextStyle(fontSize: 11, color: kOrange, height: 1.4)),
      const SizedBox(height: 8),
      Row(children: [0.0, 500.0].map((v) => Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onTap: () => setState(() => _advance = v),
          child: Container(padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: _advance == v ? kOrange : kCard, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _advance == v ? kOrange : const Color(0xFFFFCC80))),
            child: Center(child: Text(v == 0 ? 'None' : '₹${v.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _advance == v ? Colors.white : kOrange)))),
        ),
      ))).toList()),
    ])),
  ];

  Widget _freqBtn(String val, String label) => Expanded(child: GestureDetector(
    onTap: () => setState(() => _freq = val),
    child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _freq == val ? kPrimary : kCard, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _freq == val ? kPrimary : kBorder)),
      child: Center(child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _freq == val ? Colors.white : kTextMid), textAlign: TextAlign.center)),
    ),
  ));

  Widget _stepDot(int step, String label) => Column(children: [
    Container(width: 28, height: 28, decoration: BoxDecoration(
      color: _step >= step ? Colors.white : Colors.white24, shape: BoxShape.circle),
      child: Center(child: _step > step
          ? const Icon(Icons.check_rounded, color: kPrimary, size: 16)
          : Text('${step+1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _step >= step ? kPrimary : Colors.white70)))),
    const SizedBox(height: 3),
    Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _step >= step ? Colors.white : Colors.white54)),
  ]);

  Widget _label(String t) => Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextDark));
}

class _StepHeader extends StatelessWidget {
  final String icon, title, subtitle;
  const _StepHeader({required this.icon, required this.title, required this.subtitle});
  @override Widget build(BuildContext context) => Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(color: kPrimaryLt, borderRadius: BorderRadius.circular(14)),
      child: Center(child: Text(icon, style: const TextStyle(fontSize: 24)))),
    const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextDark)),
      Text(subtitle, style: const TextStyle(fontSize: 11, color: kTextMid)),
    ]),
  ]);
}
