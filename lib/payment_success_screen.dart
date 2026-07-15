// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Payment Success Screen
//  Theme: Black & White (matches app style)
//  Deep link: 444music://payment-success → lands here
// ═══════════════════════════════════════════════════════════════════

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ─── PALETTE ────────────────────────────────────────────────────────
const _black      = Color(0xFF000000);
const _black2     = Color(0xFF111111);
const _black3     = Color(0xFF1A1A1A);
const _white      = Color(0xFFFFFFFF);
const _white90    = Color(0xE6FFFFFF);
const _white70    = Color(0xB3FFFFFF);
const _white40    = Color(0x66FFFFFF);
const _white20    = Color(0x33FFFFFF);
const _white10    = Color(0x1AFFFFFF);
const _white06    = Color(0x0FFFFFFF);
const _grey       = Color(0xFF888888);
const _greyDark   = Color(0xFF444444);
const _green      = Color(0xFF22C55E);
const _greenDim   = Color(0x1F22C55E);
const _greenBorder= Color(0x3322C55E);

class PaymentSuccessScreen extends StatefulWidget {
  // NEW — the pendingPayments doc ID (a.k.a. submissionId) for the
  // payment that just succeeded. Passed in directly when we navigate
  // here ourselves (from PaymentWaitingScreen). If this screen is
  // instead reached via a named route (e.g. the app's deep-link
  // handlers in main.dart), we fall back to reading it from the
  // route arguments in didChangeDependencies below — so either path
  // in still works, as long as whoever navigates here actually
  // supplies a reference.
  final String? paymentReference;

  const PaymentSuccessScreen({super.key, this.paymentReference});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with TickerProviderStateMixin {

  // ── Animations
  late AnimationController _checkCtrl;
  late AnimationController _contentCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _particleCtrl;

  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;
  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;
  late Animation<double> _contentFade;
  late Animation<Offset>  _contentSlide;
  late Animation<double> _pulse;
  late Animation<double> _particleFade;

  final String _time = _formatTime();

  // NEW — resolved reference: constructor param wins, falls back to
  // route arguments if this screen was pushed by name instead.
  String? _reference;
  bool _referenceResolved = false;

  static String _formatTime() {
    final d = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day}, $h:$m $ap';
  }

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));

    // Check circle animation
    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut));
    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _checkCtrl,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));

    // Ring ripple
    _ringScale = Tween<double>(begin: 0.8, end: 1.6).animate(
        CurvedAnimation(parent: _checkCtrl, curve: Curves.easeOut));
    _ringOpacity = Tween<double>(begin: 0.4, end: 0.0).animate(
        CurvedAnimation(parent: _checkCtrl, curve: Curves.easeOut));

    // Content slide up
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _contentFade = CurvedAnimation(
        parent: _contentCtrl, curve: Curves.easeOut);
    _contentSlide = Tween<Offset>(
        begin: const Offset(0, 0.08), end: Offset.zero).animate(
        CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));

    // Pulse ring
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Particle fade
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _particleFade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _particleCtrl,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));

    // Sequence
    _checkCtrl.forward().then((_) {
      _contentCtrl.forward();
      _particleCtrl.forward();
    });
  }

  // NEW — resolve the reference once we have a BuildContext. Constructor
  // param takes priority (that's how PaymentWaitingScreen gets here); if
  // that's null, this screen was probably reached by a named-route push
  // (e.g. a deep link), so fall back to route arguments if any exist.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_referenceResolved) {
      _reference = widget.paymentReference;
      if (_reference == null) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is String && args.isNotEmpty) {
          _reference = args;
        }
      }
      _referenceResolved = true;
    }
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    _contentCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final size   = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _black,
      body: Stack(
        children: [

          // ── BG IMAGE
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: 'https://images.pexels.com/photos/9008843/pexels-photo-9008843.jpeg?auto=compress&cs=tinysrgb&w=800&dpr=2',
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: _black),
              errorWidget: (_, __, ___) => Container(color: _black),
            ),
          ),

          // ── BG DARK OVERLAY
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCC000000),
                    Color(0xF5000000),
                    Color(0xFF000000),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // ── PARTICLES (floating dots)
          ..._buildParticles(size),

          // ── MAIN CONTENT
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                SizedBox(height: top + 20),

                // ── TOP BAR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      // Logo text
                      Text(
                        '444Music',
                        style: GoogleFonts.nunito(
                          color: _white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      // Secured badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _white06,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: _white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_rounded,
                                color: _grey, size: 10),
                            const SizedBox(width: 5),
                            Text(
                              'Secured by Paystack',
                              style: GoogleFonts.nunito(
                                color: _grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 52),

                // ── CHECK CIRCLE ANIMATION
                AnimatedBuilder(
                  animation: _checkCtrl,
                  builder: (_, __) {
                    return SizedBox(
                      width: 140,
                      height: 140,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer ripple ring
                          Transform.scale(
                            scale: _ringScale.value,
                            child: Opacity(
                              opacity: _ringOpacity.value,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: _white, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                          // Pulse ring
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (_, __) => Transform.scale(
                              scale: _pulse.value,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _white.withValues(alpha: 0.05),
                                  border: Border.all(
                                    color: _white.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Main check circle
                          Transform.scale(
                            scale: _checkScale.value,
                            child: Opacity(
                              opacity: _checkOpacity.value,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _white.withValues(alpha: 0.25),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: _black,
                                  size: 34,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // ── TITLE & SUBTITLE
                FadeTransition(
                  opacity: _contentFade,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Column(
                      children: [
                        Text(
                          'Payment Confirmed',
                          style: GoogleFonts.nunito(
                            color: _white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 44),
                          child: Text(
                            'Your payment went through.\nYou\'re ready to distribute your music.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              color: _grey,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // ── RECEIPT CARD
                FadeTransition(
                  opacity: _contentFade,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _black2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _white10),
                        ),
                        child: Column(
                          children: [
                            // Top glow line
                            Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    _white40,
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _ReceiptRow(
                                    label: 'Status',
                                    value: 'Approved',
                                    valueWidget: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: _green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Approved',
                                          style: GoogleFonts.nunito(
                                            color: _green,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _divider(),
                                  _ReceiptRow(
                                      label: 'Processed', value: _time),
                                  _divider(),
                                  _ReceiptRow(
                                      label: 'Provider',
                                      value: 'Paystack'),
                                  _divider(),
                                  _ReceiptRow(
                                      label: 'Next Step',
                                      value: 'Submit your music'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── BUTTONS
                FadeTransition(
                  opacity: _contentFade,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Column(
                        children: [
                          // Primary — Submit Music
                          _PrimaryButton(
                            label: 'Submit Your Music',
                            icon: Icons.cloud_upload_rounded,
                            // NEW — carry the payment reference forward into
                            // the upload flow so it can eventually reach
                            // ReleaseInfoScreen and get marked as claimed.
                            onTap: () =>
                                Navigator.pushReplacementNamed(
                                    context, '/upload-files',
                                    arguments: _reference),
                          ),
                          const SizedBox(height: 12),
                          // Secondary — Go Home
                          _SecondaryButton(
                            label: 'Back to Home',
                            icon: Icons.home_rounded,
                            onTap: () =>
                                Navigator.pushReplacementNamed(
                                    context, '/home'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── FOOTER
                FadeTransition(
                  opacity: _contentFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shield_rounded,
                            color: _greyDark, size: 12),
                        const SizedBox(width: 6),
                        Text(
                          'Payment secured by Paystack · 444Music',
                          style: GoogleFonts.nunito(
                            color: _greyDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: bottom + 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    height: 1,
    color: _white10,
    margin: const EdgeInsets.symmetric(vertical: 12),
  );

  List<Widget> _buildParticles(Size size) {
    final positions = [
      const Offset(0.15, 0.12),
      const Offset(0.82, 0.08),
      const Offset(0.65, 0.22),
      const Offset(0.08, 0.35),
      const Offset(0.92, 0.28),
      const Offset(0.45, 0.06),
    ];

    return positions.map((p) {
      return AnimatedBuilder(
        animation: _particleFade,
        builder: (_, __) => Positioned(
          left: p.dx * size.width,
          top: p.dy * size.height,
          child: Opacity(
            opacity: _particleFade.value * 0.6,
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: _white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ── RECEIPT ROW ───────────────────────────────────────────────────────
class _ReceiptRow extends StatelessWidget {
  final String label, value;
  final Widget? valueWidget;
  const _ReceiptRow(
      {required this.label, required this.value, this.valueWidget});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            color: _grey,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        valueWidget ??
            Text(
              value,
              style: GoogleFonts.nunito(
                color: _white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
      ],
    );
  }
}

// ── PRIMARY BUTTON ────────────────────────────────────────────────────
class _PrimaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _pressed
              ? const Color(0xFFE0E0E0)
              : _white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _pressed
              ? []
              : [
            BoxShadow(
              color: _white.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: _black, size: 18),
            const SizedBox(width: 10),
            Text(
              widget.label.toUpperCase(),
              style: GoogleFonts.nunito(
                color: _black,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SECONDARY BUTTON ──────────────────────────────────────────────────
class _SecondaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SecondaryButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _pressed ? _white10 : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _white20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: _white70, size: 18),
            const SizedBox(width: 10),
            Text(
              widget.label.toUpperCase(),
              style: GoogleFonts.nunito(
                color: _white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}