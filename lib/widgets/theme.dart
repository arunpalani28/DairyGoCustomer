import 'package:flutter/material.dart';

// ── Colors ───────────────────────────────────────────────────────────────────
const Color kPrimary   = Color(0xFF1565C0);
const Color kPrimaryLt = Color(0xFFE3F2FD);
const Color kPrimaryDk = Color(0xFF0D47A1);
const Color kGreen     = Color(0xFF2E7D32);
const Color kGreenLt   = Color(0xFFE8F5E9);
const Color kOrange    = Color(0xFFE65100);
const Color kOrangeLt  = Color(0xFFFFF3E0);
const Color kYellowLt  = Color(0xFFFFF8E1);
const Color kYellowBd  = Color(0xFFFFE082);
const Color kBg        = Color(0xFFEEF3FA);
const Color kCard      = Color(0xFFFFFFFF);
const Color kBorder    = Color(0xFFE3F2FD);
const Color kTextDark  = Color(0xFF1A237E);
const Color kTextMid   = Color(0xFF607D8B);
const Color kTextLight = Color(0xFF90A4AE);
const Color kRed       = Color(0xFFC62828);
const Color kRedLt     = Color(0xFFFCEBEB);

// ── Shared Widgets ────────────────────────────────────────────────────────────

class KAvatar extends StatelessWidget {
  final String initials;
  final double size;
  const KAvatar({super.key, required this.initials, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(size / 2)),
        child: Center(
          child: Text(initials,
              style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      );
}

class KCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final double borderWidth;
  const KCard({super.key, required this.child, this.padding, this.borderColor, this.borderWidth = 1});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor ?? kBorder, width: borderWidth),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        padding: padding ?? const EdgeInsets.all(14),
        child: child,
      );
}

class KPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final Color color;
  const KPrimaryButton({super.key, required this.label, this.onTap, this.loading = false, this.color = kPrimary});

  @override
  State<KPrimaryButton> createState() => _KPrimaryButtonState();
}

class _KPrimaryButtonState extends State<KPrimaryButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) { setState(() => _pressed = false); widget.onTap?.call(); },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: _pressed ? kPrimaryDk : widget.color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(widget.label,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      );
}

class KSectionTitle extends StatelessWidget {
  final String title;
  final String? link;
  final VoidCallback? onLink;
  const KSectionTitle({super.key, required this.title, this.link, this.onLink});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextDark, letterSpacing: 0.3)),
          if (link != null)
            GestureDetector(
              onTap: onLink,
              child: Text(link!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kPrimary)),
            ),
        ],
      );
}

class KStatusBadge extends StatelessWidget {
  final String label;
  final Color color, bg;
  const KStatusBadge({super.key, required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
      );
}

class KTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final Widget? suffix;
  final Widget? prefix;
  final Color focusColor;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int? maxLines;
  const KTextField({super.key, required this.label, required this.controller, this.obscure = false, this.suffix, this.prefix, this.focusColor = kPrimary, this.keyboardType, this.maxLength, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller, obscureText: obscure,
        keyboardType: keyboardType, maxLength: maxLength,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13, color: kTextDark, fontFamily: 'Poppins'),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12, color: kTextMid, fontFamily: 'Poppins'),
          filled: true, fillColor: kCard,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: focusColor, width: 1.5)),
          suffixIcon: suffix, prefixIcon: prefix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          counterText: '',
        ),
      );
}

// Updated KTextField with keyboard type and other options
class KTextField2 extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final Widget? suffix;
  final Widget? prefix;
  final Color focusColor;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int? maxLines;
  const KTextField2({super.key, required this.label, required this.controller, this.obscure = false, this.suffix, this.prefix, this.focusColor = kPrimary, this.keyboardType, this.maxLength, this.maxLines = 1});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, obscureText: obscure,
    keyboardType: keyboardType, maxLength: maxLength,
    maxLines: maxLines,
    style: const TextStyle(fontSize: 13, color: kTextDark, fontFamily: 'Poppins'),
    decoration: InputDecoration(
      labelText: label, labelStyle: const TextStyle(fontSize: 12, color: kTextMid, fontFamily: 'Poppins'),
      filled: true, fillColor: kCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: focusColor, width: 1.5)),
      suffixIcon: suffix, prefixIcon: prefix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      counterText: '',
    ),
  );
}
