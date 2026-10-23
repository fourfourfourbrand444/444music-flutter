// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Pricing Screen
//  Rebuilt to mirror pricing.html: iOS-style grouped surfaces, large
//  title, white featured "Single" card, yellow compare panel and a
//  yellow closing banner. No promo.
//  Backend calls, routes and the payment flow are UNCHANGED.
// ═══════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'
    show
        CupertinoActionSheet,
        CupertinoActionSheetAction,
        CupertinoActivityIndicator,
        CupertinoTheme,
        CupertinoThemeData,
        showCupertinoModalPopup;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'payment_success_screen.dart';
import 'home_screen.dart';

// ─── PALETTE — same tokens as the :root vars in pricing.html ────────
const _bg = Color(0xFF000000);
const _s1 = Color(0xFF1C1C1E);
const _fill = Color(0x3D787880); // rgba(120,120,128,.24)
const _sep = Color(0x8C545458); // rgba(84,84,88,.55)
const _label = Color(0xFFFFFFFF);
const _label2 = Color(0x99EBEBF5); // rgba(235,235,245,.60)
const _label3 = Color(0x4DEBEBF5); // rgba(235,235,245,.30)
const _blue = Color(0xFF0A84FF);
const _yellow = Color(0xFFFDEB0D);
const _green = Color(0xFF30D158);

// White featured card
const _ink = Color(0xFF1D1D1F);
const _inkSub = Color(0xFF6E6E73);
const _inkSub2 = Color(0xFF8E8E93);
const _inkLine = Color(0x1A000000);

// iOS spring-like curve, same as --ease on the web
const _ease = Cubic(0.32, 0.72, 0, 1);

// ─── BACKEND CONFIG — UNCHANGED ───────────────────────────────────────
const _backendBase = 'https://four44music-broadcast-backend.onrender.com';

// ─── CURRENCY DISPLAY — cosmetic only, never affects the amount sent
// to Paystack. plan.amountGHS is always the source of truth for payment.
// Keep these rates in sync with CURRENCY_RATES in pricing.html. ──────
class _CurrencyInfo {
  final String symbol;
  final double rate; // GHC → this currency
  const _CurrencyInfo({required this.symbol, required this.rate});
}

const Map<String, _CurrencyInfo> _currencyRates = {
  'GHS': _CurrencyInfo(symbol: 'GHC', rate: 1),
  'NGN': _CurrencyInfo(symbol: '₦', rate: 131),
  'USD': _CurrencyInfo(symbol: '\$', rate: 0.0873),
  'EUR': _CurrencyInfo(symbol: '€', rate: 0.0803),
  'GBP': _CurrencyInfo(symbol: '£', rate: 0.0690),
  'ZAR': _CurrencyInfo(symbol: 'R', rate: 1.615),
  'KES': _CurrencyInfo(symbol: 'KSh', rate: 11.26),
  'CAD': _CurrencyInfo(symbol: 'CA\$', rate: 0.1187),
  'XOF': _CurrencyInfo(symbol: 'CFA', rate: 52.6),
  'OTHER': _CurrencyInfo(symbol: '\$', rate: 0.0873),
};

const List<Map<String, String>> _currencyOptions = [
  {'code': 'GHS', 'label': '🇬🇭 Ghana — GHS'},
  {'code': 'NGN', 'label': '🇳🇬 Nigeria — NGN'},
  {'code': 'USD', 'label': '🇺🇸 United States — USD'},
  {'code': 'EUR', 'label': '🇪🇺 Europe — EUR'},
  {'code': 'GBP', 'label': '🇬🇧 United Kingdom — GBP'},
  {'code': 'ZAR', 'label': '🇿🇦 South Africa — ZAR'},
  {'code': 'KES', 'label': '🇰🇪 Kenya — KES'},
  {'code': 'CAD', 'label': '🇨🇦 Canada — CAD'},
  {'code': 'XOF', 'label': '🌍 West Africa (CFA) — XOF'},
  {'code': 'OTHER', 'label': '🌐 Other — USD'},
];

String _currencyLabel(String code) => _currencyOptions
    .firstWhere((o) => o['code'] == code, orElse: () => _currencyOptions.first)['label']!;

String _fmt(double v, int decimals) {
  final s = v.toStringAsFixed(decimals);
  final parts = s.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return parts.length > 1 ? '$whole.${parts[1]}' : whole;
}

String _amountIn(double ghs, String code) {
  if (ghs == 0) return '0';
  final info = _currencyRates[code] ?? _currencyRates['USD']!;
  return _fmt(ghs * info.rate, code == 'XOF' ? 0 : 2);
}

String _subLabel(double ghs, String code) {
  if (code == 'GHS') {
    return ghs == 0 ? '/ \$0' : '/ \$${_fmt(ghs * _currencyRates['USD']!.rate, 2)}';
  }
  return ghs == 0 ? '/ GHC 0' : '/ GHC ${_fmt(ghs, 2)}';
}

// ─── TEXT STYLE — Inter is the closest match to SF on every device ───
TextStyle _ts(double size, FontWeight weight, Color color,
        {double ls = 0, double h = 1.3, bool tabular = false}) =>
    GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: ls,
      height: h,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );

Widget _pad(Widget child) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        ),
      ),
    );

// ─── PLAN DATA ────────────────────────────────────────────────────────
enum _BtnStyle { outline, solid }

class _Plan {
  final String key, name, desc, period, btnLabel, route;
  final double amountGHS;
  final bool featured;
  final String? badge;
  final _BtnStyle style;
  final List<String> features;

  const _Plan({
    required this.key,
    required this.name,
    required this.desc,
    required this.period,
    required this.btnLabel,
    required this.route,
    required this.amountGHS,
    required this.style,
    required this.features,
    this.featured = false,
    this.badge,
  });
}

const _plans = [
  _Plan(
    key: 'draft',
    name: 'Release as Draft',
    desc: 'Upload now and settle the fee once your release starts earning.',
    period: 'No upfront payment',
    btnLabel: 'Get started free',
    route: '/agreement',
    amountGHS: 0,
    style: _BtnStyle.outline,
    features: [
      'Unlimited draft uploads',
      '100+ digital stores',
      'Free ISRC & UPC',
      'Keep 100% of royalties',
      'Artist dashboard & basic analytics',
    ],
  ),
  _Plan(
    key: 'single',
    name: 'Single',
    desc: 'Drop a track with fast global delivery and cover art review.',
    period: 'One-time per release',
    btnLabel: 'Release single',
    route: '',
    amountGHS: 39.99,
    featured: true,
    badge: 'Most popular',
    style: _BtnStyle.solid,
    features: [
      '1 single release (1–2 tracks)',
      'Spotify, Apple Music, TikTok & 100+ stores',
      'Free ISRC & UPC',
      'Keep 100% of royalties',
      '5–7 day delivery',
      'Cover art review & analytics',
    ],
  ),
  _Plan(
    key: 'ep',
    name: 'EP / Album',
    desc: 'A full project with advanced reporting and priority support.',
    period: 'One-time per project',
    btnLabel: 'Release project',
    route: '',
    amountGHS: 69.99,
    style: _BtnStyle.outline,
    features: [
      'Up to 20 tracks',
      '100+ stores worldwide',
      'Free ISRC for every track + UPC',
      'Keep 100% of royalties',
      'Priority 3–5 day delivery',
      'Full royalty reports & priority support',
    ],
  ),
];

// ─── FAQ DATA ─────────────────────────────────────────────────────────
class _FAQ {
  final String q, a;
  const _FAQ({required this.q, required this.a});
}

const _faqs = [
  _FAQ(
    q: 'When do I pay for the Release as Draft plan?',
    a: 'You upload for free and only settle the distribution fee once your release starts earning. We deduct from your first royalty payout — no upfront cash needed.',
  ),
  _FAQ(
    q: 'How long does it take for my music to go live?',
    a: 'Standard delivery is 5–7 business days. Pro plans enjoy priority processing of 3–5 days. Stores like Spotify and Apple Music control final publishing timelines.',
  ),
  _FAQ(
    q: 'Do you take any percentage of my royalties?',
    a: 'Never. You keep 100% of all streaming royalties across every store. Our revenue comes from the one-time plan fees only.',
  ),
  _FAQ(
    q: 'Can I upgrade my plan later?',
    a: 'Yes. You can choose a different plan for each new release from your dashboard. Your existing releases remain active regardless of which plan you pick next.',
  ),
  _FAQ(
    q: 'What currency will I be charged in?',
    a: 'All payments are processed in Ghanaian Cedis (GHC) through Paystack. The currency menu at the top only shows an approximate equivalent in your local currency so you know roughly what to expect before checkout.',
  ),
];

// ════════════════════════════════════════════════════════════════════
//  PRICING SCREEN
// ════════════════════════════════════════════════════════════════════
class PricingScreen extends StatefulWidget {
  final String? submissionId;

  const PricingScreen({super.key, this.submissionId});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  int? _openFaq;

  bool _checkingResume = true;
  String? _resumeReference;

  // Display only, defaults to Ghana
  String _selectedCurrency = 'GHS';

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _bg,
    ));
    _checkForUnclaimedPayment();
  }

  Future<void> _checkForUnclaimedPayment() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _checkingResume = false);
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('pendingPayments')
          .where('uid', isEqualTo: uid)
          .where('paid', isEqualTo: true)
          .where('claimed', isEqualTo: false)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;
      setState(() {
        if (query.docs.isNotEmpty) _resumeReference = query.docs.first.id;
        _checkingResume = false;
      });
    } catch (err) {
      if (mounted) setState(() => _checkingResume = false);
    }
  }

  void _resumeRelease() {
    if (_resumeReference == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentSuccessScreen(
          paymentReference: _resumeReference!,
        ),
      ),
    );
  }

  // Payment logic UNCHANGED — always uses plan.amountGHS regardless of
  // what currency is currently being previewed on screen.
  Future<void> _handlePlanTap(_Plan plan) async {
    if (plan.amountGHS == 0) {
      Navigator.pushNamed(context, plan.route);
      return;
    }

    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final tempReference =
        '${uid.isEmpty ? 'guest' : uid}_${DateTime.now().millisecondsSinceEpoch}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentWaitingScreen(
          amountGHS: plan.amountGHS,
          submissionId: tempReference,
          uid: uid,
          email: email,
          successRouteName: '/upload',
          // Pricing-screen flow: no submission exists yet, so this stays
          // false and the mandatory "Continue" lock screen keeps working.
          isExistingSubmission: false,
        ),
      ),
    );
  }

  Future<void> _pickCurrency() async {
    final picked = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: const CupertinoThemeData(brightness: Brightness.dark),
        child: CupertinoActionSheet(
          title: const Text('View prices in'),
          message: const Text('Display only. Checkout is always in GHC.'),
          actions: _currencyOptions
              .map((o) => CupertinoActionSheetAction(
                    isDefaultAction: o['code'] == _selectedCurrency,
                    onPressed: () => Navigator.pop(ctx, o['code']),
                    child: Text(o['label']!),
                  ))
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _selectedCurrency = picked);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final locked = !_checkingResume && _resumeReference != null;

    final sections = <Widget>[
      _pad(_buildHeader()),
      const SizedBox(height: 40),
      for (var i = 0; i < _plans.length; i++)
        _pad(_Reveal(
          delayMs: i * 80,
          child: _PlanCard(
            plan: _plans[i],
            currencyCode: _selectedCurrency,
            onTap: () => _handlePlanTap(_plans[i]),
          ),
        )),
      _pad(const _Reveal(child: _ComparePanel())),
      _pad(_Reveal(child: _buildFaq())),
      _pad(_Reveal(child: _buildBanner())),
    ];

    return PopScope(
      // Block the back button while a completed payment is waiting.
      canPop: !locked,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TopBarDelegate(
                    topPadding: top,
                    onBack: () => Navigator.maybePop(context),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => sections[i],
                    childCount: sections.length,
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: bottom + 64)),
              ],
            ),
            // Covers the page until the unclaimed-payment check finishes,
            // so the lock never flashes in after the prices.
            if (_checkingResume)
              Positioned(
                left: 0,
                right: 0,
                top: top + 56,
                bottom: 0,
                child: Container(
                  color: _bg,
                  alignment: Alignment.center,
                  child: const CupertinoActivityIndicator(radius: 14, color: _label),
                ),
              ),
            if (locked) _buildLockOverlay(),
          ],
        ),
      ),
    );
  }

  // ── Header: large title, subtitle, currency pill ──
  Widget _buildHeader() {
    final code = _selectedCurrency;
    final note = code == 'GHS'
        ? "You'll be charged the exact GHC amount at checkout."
        : "Approximate ${code == 'OTHER' ? 'USD' : code} preview. You'll be charged the GHC amount shown next to it.";

    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Text(
            'Pricing',
            textAlign: TextAlign.center,
            style: _ts(44, FontWeight.w700, _label, ls: -1.9, h: 1.05),
          ),
          const SizedBox(height: 14),
          Text(
            'Upload once, reach 100+ stores and keep every cent you earn.',
            textAlign: TextAlign.center,
            style: _ts(17, FontWeight.w400, _label2, h: 1.4),
          ),
          const SizedBox(height: 28),
          _Pressable(
            onTap: _pickCurrency,
            child: Container(
              height: 38,
              padding: const EdgeInsets.only(left: 16, right: 12),
              decoration: BoxDecoration(
                color: _fill,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currencyLabel(code),
                    style: _ts(15, FontWeight.w500, _label),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.expand_more_rounded, color: _label2, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            note,
            textAlign: TextAlign.center,
            style: _ts(13, FontWeight.w400, _label3, h: 1.4),
          ),
        ],
      ),
    );
  }

  // ── FAQ: one grouped iOS list ──
  Widget _buildFaq() {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Text(
            'Questions',
            textAlign: TextAlign.center,
            style: _ts(28, FontWeight.w700, _label, ls: -0.9),
          ),
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: _s1,
              child: Column(
                children: [
                  for (var i = 0; i < _faqs.length; i++)
                    _FaqItem(
                      faq: _faqs[i],
                      first: i == 0,
                      isOpen: _openFaq == i,
                      onTap: () => setState(() => _openFaq = _openFaq == i ? null : i),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Closing banner: yellow ──
  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: _yellow,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Text(
              'Ready to get your music heard?',
              textAlign: TextAlign.center,
              style: _ts(30, FontWeight.w700, Colors.black, ls: -1.1, h: 1.12),
            ),
            const SizedBox(height: 10),
            Text(
              'Join thousands of independent artists distributing with 444Music.',
              textAlign: TextAlign.center,
              style: _ts(17, FontWeight.w400, const Color(0xA6000000), h: 1.4),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                _Pressable(
                  onTap: () => Navigator.pushNamed(context, '/agreement'),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Start distributing',
                      style: _ts(17, FontWeight.w600, Colors.white, ls: -0.2),
                    ),
                  ),
                ),
                _Pressable(
                  onTap: () => launchUrl(
                    Uri.parse('https://www.444musicdistro.com/support.html'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    alignment: Alignment.center,
                    child: Text(
                      'Talk to support',
                      style: _ts(17, FontWeight.w500, Colors.black, ls: -0.2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Already-paid lock: iOS alert ──
  Widget _buildLockOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // absorbs all taps, nothing behind is reachable
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: const Color(0x80000000),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: _ease,
                builder: (_, t, child) => Opacity(
                  opacity: t.clamp(0.0, 1.0).toDouble(),
                  child: Transform.scale(scale: 1.12 - 0.12 * t, child: child),
                ),
                child: _buildLockCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockCard() {
    return SizedBox(
      width: 280,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: const Color(0xF02C2C2E),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0x2930D158),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: _green, size: 24),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Payment completed',
                      textAlign: TextAlign.center,
                      style: _ts(17, FontWeight.w600, _label, ls: -0.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "You've already paid for a release. Continue to finish submitting it before starting anything new.",
                      textAlign: TextAlign.center,
                      style: _ts(13, FontWeight.w400, const Color(0xD9FFFFFF), h: 1.4),
                    ),
                  ],
                ),
              ),
              Container(height: 0.5, color: _sep),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _resumeRelease,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  child: Text(
                    'Continue',
                    style: _ts(17, FontWeight.w600, _blue),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SMALL SHARED WIDGETS
// ════════════════════════════════════════════════════════════════════

// Press feedback: scales down slightly, like iOS buttons.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;
  const _Pressable({required this.child, required this.onTap, this.scale = 0.97});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: _ease,
        child: widget.child,
      ),
    );
  }
}

// Fade + rise when a section first appears, like the web's scroll reveal.
class _Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _Reveal({required this.child, this.delayMs = 0});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    final curved = CurvedAnimation(parent: _ctrl, curve: _ease);
    _fade = curved;
    _slide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved);
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  STICKY TOP BAR
// ════════════════════════════════════════════════════════════════════
class _TopBarDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final VoidCallback onBack;

  const _TopBarDelegate({required this.topPadding, required this.onBack});

  @override
  double get minExtent => topPadding + 56;
  @override
  double get maxExtent => topPadding + 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.only(top: topPadding),
          decoration: const BoxDecoration(
            color: Color(0xB8000000),
            border: Border(bottom: BorderSide(color: Color(0x14FFFFFF), width: 0.5)),
          ),
          child: SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text('444Music', style: _ts(17, FontWeight.w600, _label)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _CircleBack(onTap: onBack),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TopBarDelegate oldDelegate) =>
      topPadding != oldDelegate.topPadding;
}

class _CircleBack extends StatelessWidget {
  final VoidCallback onTap;
  const _CircleBack({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      scale: 0.92,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(color: _fill, shape: BoxShape.circle),
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: _label, size: 16),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PLAN CARD — Single is the white featured card, like the web
// ════════════════════════════════════════════════════════════════════
class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final String currencyCode;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.currencyCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final f = plan.featured;
    final ink = f ? _ink : _label;
    final sub = f ? _inkSub : _label2;
    final sub2 = f ? _inkSub2 : _label3;
    final symbol = (_currencyRates[currencyCode] ?? _currencyRates['USD']!).symbol;

    // Button colours
    Color btnBg, btnText;
    if (plan.style == _BtnStyle.solid) {
      btnBg = f ? Colors.black : Colors.white;
      btnText = f ? Colors.white : Colors.black;
    } else {
      btnBg = _fill;
      btnText = _label;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
            decoration: BoxDecoration(
              color: f ? Colors.white : _s1,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name, style: _ts(22, FontWeight.w600, ink, ls: -0.4)),
                const SizedBox(height: 6),
                Text(plan.desc, style: _ts(15, FontWeight.w400, sub, h: 1.45)),
                const SizedBox(height: 18),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Text(symbol, style: _ts(20, FontWeight.w600, sub)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _amountIn(plan.amountGHS, currencyCode),
                          style: _ts(48, FontWeight.w700, ink, ls: -1.9, h: 1, tabular: true),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _subLabel(plan.amountGHS, currencyCode),
                        style: _ts(14, FontWeight.w400, sub2, tabular: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(plan.period, style: _ts(14, FontWeight.w400, sub)),
                const SizedBox(height: 22),
                _Pressable(
                  onTap: onTap,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: btnBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      plan.btnLabel,
                      style: _ts(17, FontWeight.w600, btnText, ls: -0.2),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 24),
                  padding: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: f ? _inkLine : _sep, width: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: plan.features
                        .map((t) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(Icons.check_rounded,
                                        size: 16, color: f ? _ink : _label2),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      t,
                                      style: _ts(15, FontWeight.w400, ink, h: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          if (plan.badge != null)
            Positioned(
              top: 22,
              right: 22,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  plan.badge!,
                  style: _ts(12, FontWeight.w600, Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  COMPARE PANEL — yellow, like .compare-panel on the web
// ════════════════════════════════════════════════════════════════════
class _ComparePanel extends StatelessWidget {
  const _ComparePanel();

  static const _head = ['Feature', 'Starter', 'Single', 'EP / Album'];
  static const _rows = [
    ['Store distribution', '100+', '100+', '100+'],
    ['Royalty split', '100%', '100%', '100%'],
    ['Releases', '1', '1 single', '1 project'],
    ['Free ISRC & UPC', 'yes', 'yes', 'yes'],
    ['Analytics', 'Basic', 'Standard', 'Advanced'],
    ['Support', 'Community', 'Email', 'Priority'],
  ];

  @override
  Widget build(BuildContext context) {
    const muted = Color(0x8C000000); // rgba(0,0,0,.55)
    const body = Color(0xB3000000); // rgba(0,0,0,.70)
    const headLine = Color(0x33000000); // rgba(0,0,0,.20)
    const rowLine = Color(0x24000000); // rgba(0,0,0,.14)

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 14),
      decoration: BoxDecoration(
        color: _yellow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Compare plans',
              style: _ts(28, FontWeight.w700, Colors.black, ls: -0.9),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth < 440 ? 440.0 : c.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: w,
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FlexColumnWidth(1.6),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: headLine, width: 0.5)),
                        ),
                        children: [
                          for (var i = 0; i < _head.length; i++)
                            Padding(
                              padding: EdgeInsets.fromLTRB(i == 0 ? 4 : 8, 12, 8, 12),
                              child: Text(
                                _head[i],
                                textAlign: i == 0 ? TextAlign.left : TextAlign.center,
                                style: _ts(13, FontWeight.w600,
                                    i == 2 ? Colors.black : muted),
                              ),
                            ),
                        ],
                      ),
                      for (var r = 0; r < _rows.length; r++)
                        TableRow(
                          decoration: BoxDecoration(
                            border: r == _rows.length - 1
                                ? null
                                : const Border(
                                    bottom: BorderSide(color: rowLine, width: 0.5)),
                          ),
                          children: [
                            for (var i = 0; i < _rows[r].length; i++)
                              Padding(
                                padding: EdgeInsets.fromLTRB(i == 0 ? 4 : 8, 14, 8, 14),
                                child: _rows[r][i] == 'yes'
                                    ? const Center(
                                        child: Icon(Icons.check_rounded,
                                            size: 17, color: Colors.black),
                                      )
                                    : Text(
                                        _rows[r][i],
                                        textAlign:
                                            i == 0 ? TextAlign.left : TextAlign.center,
                                        style: _ts(
                                          15,
                                          i == 0
                                              ? FontWeight.w500
                                              : (i == 2 ? FontWeight.w600 : FontWeight.w400),
                                          (i == 0 || i == 2) ? Colors.black : body,
                                        ),
                                      ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  FAQ ITEM — row inside one grouped list
// ════════════════════════════════════════════════════════════════════
class _FaqItem extends StatelessWidget {
  final _FAQ faq;
  final bool first;
  final bool isOpen;
  final VoidCallback onTap;

  const _FaqItem({
    required this.faq,
    required this.first,
    required this.isOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!first)
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Container(height: 0.5, color: _sep),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    faq.q,
                    style: _ts(17, FontWeight.w500, _label, ls: -0.2, h: 1.3),
                  ),
                ),
                const SizedBox(width: 16),
                AnimatedRotation(
                  turns: isOpen ? 0.125 : 0,
                  duration: const Duration(milliseconds: 350),
                  curve: _ease,
                  child: Icon(Icons.add_rounded,
                      size: 20, color: isOpen ? _label : _label3),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: _ease,
          alignment: Alignment.topCenter,
          child: isOpen
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      faq.a,
                      style: _ts(15, FontWeight.w400, _label2, h: 1.5),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PAYMENT SCREEN — External Browser (no WebView)
//  Opens Paystack checkout in the device's real browser and verifies
//  payment status against the backend.
//
//  isExistingSubmission:
//    false (default) = Pricing screen. No submission exists yet.
//      "I've completed payment" goes to HomeScreen; confirmed payment
//      routes to PaymentSuccessScreen so the user can finish the release.
//    true = Pay Now on an existing Pending draft (releases screen).
//      The backend flips the submission to Review directly, so this just
//      returns to where the user came from.
//
//  Logic is UNCHANGED. Only the look was updated.
// ════════════════════════════════════════════════════════════════════
class PaymentWaitingScreen extends StatefulWidget {
  final double amountGHS;
  final String submissionId;
  final String uid;
  final String email;
  final String successRouteName;
  final bool isExistingSubmission;

  const PaymentWaitingScreen({
    super.key,
    required this.amountGHS,
    required this.submissionId,
    required this.uid,
    required this.email,
    required this.successRouteName,
    this.isExistingSubmission = false,
  });

  @override
  State<PaymentWaitingScreen> createState() => _PaymentWaitingScreenState();
}

class _PaymentWaitingScreenState extends State<PaymentWaitingScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _launched = false;
  bool _checkingStatus = false;
  String? _error;
  String? _paystackReference;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPayment();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _launched) {
      _verifyPayment();
    }
  }

  Future<void> _startPayment() async {
    try {
      final response = await http.post(
        Uri.parse('$_backendBase/api/paystack/create-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          'amountGHS': widget.amountGHS,
          'submissionId': widget.submissionId,
          'uid': widget.uid,
          // Tells the backend which flow this is, so verify-payment and
          // the webhook know whether to auto-claim the pendingPayments
          // doc right away (Pay Now) or leave it for later (Pricing).
          'isExistingSubmission': widget.isExistingSubmission,
        }),
      );

      final data = jsonDecode(response.body);
      final paymentUrl = data['paymentUrl'];
      final reference = data['reference'];

      if (paymentUrl == null || reference == null) {
        setState(() {
          _error = 'Could not start payment. Please try again.';
          _loading = false;
        });
        return;
      }

      _paystackReference = reference;

      final launched = await launchUrl(
        Uri.parse(paymentUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        setState(() {
          _error = 'Could not open the payment page. Please try again.';
          _loading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _launched = true;
        _loading = false;
      });

      _pollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _verifyPayment(),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error. Please check your connection and try again.';
        _loading = false;
      });
    }
  }

  // Automatic confirmation only: triggered by the app resuming or the
  // background poll timer. NOT called by the "I've completed payment" button.
  Future<void> _verifyPayment() async {
    if (_checkingStatus || _paystackReference == null) return;

    setState(() => _checkingStatus = true);

    try {
      final response = await http.get(
        Uri.parse('$_backendBase/api/paystack/verify-payment/$_paystackReference'),
      );
      final data = jsonDecode(response.body);

      if (data['paid'] == true) {
        _pollTimer?.cancel();
        if (mounted) {
          if (widget.isExistingSubmission) {
            // Pay Now flow: the submission already exists and the backend
            // has already flipped it to Review + Paid, so just go back.
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => PaymentSuccessScreen(
                  paymentReference: widget.submissionId,
                ),
              ),
            );
          }
        }
        return;
      }
    } catch (_) {
      // Silent: runs in the background. The next poll tries again in 5 seconds.
    } finally {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  // "I've completed payment" button.
  // Pricing flow: always sends the user to HomeScreen. Background
  // confirmation still runs through the webhook, and the "Payment
  // completed" lock on Pricing catches them if they tap Upload early.
  // Pay Now flow: pops back to My Releases, since the webhook updates
  // the submission directly.
  void _goHome() {
    _pollTimer?.cancel();
    if (widget.isExistingSubmission) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Widget _pill(String label, VoidCallback onTap, {bool solid = false}) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: solid ? Colors.white : _fill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: _ts(16, FontWeight.w600, solid ? Colors.black : _label, ls: -0.2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text('Complete payment',
                      style: _ts(17, FontWeight.w600, _label)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: _CircleBack(onTap: () => Navigator.maybePop(context)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error != null) ...[
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: _ts(15, FontWeight.w400, _label2, h: 1.45),
                        ),
                        const SizedBox(height: 20),
                        _pill('Try again', () {
                          setState(() {
                            _error = null;
                            _loading = true;
                          });
                          _startPayment();
                        }, solid: true),
                      ] else if (_loading) ...[
                        const CupertinoActivityIndicator(radius: 14, color: _label),
                        const SizedBox(height: 16),
                        Text(
                          'Preparing your payment…',
                          style: _ts(15, FontWeight.w400, _label2),
                        ),
                      ] else ...[
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: _fill,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.open_in_new_rounded,
                              color: _label, size: 28),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Complete your payment in the browser that just opened',
                          textAlign: TextAlign.center,
                          style: _ts(20, FontWeight.w600, _label, ls: -0.4, h: 1.25),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "We'll bring you back here automatically once payment is confirmed. This can take a short moment to settle. No need to close this screen.",
                          textAlign: TextAlign.center,
                          style: _ts(15, FontWeight.w400, _label2, h: 1.45),
                        ),
                        const SizedBox(height: 28),
                        _pill("I've completed payment", _goHome),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
