// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Pricing Screen
//  Matches home screen aesthetic: black/white, Nunito, same patterns
//  Upload button → navigates here from home bottom nav
// ═══════════════════════════════════════════════════════════════════
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'payment_success_screen.dart';

// ─── PALETTE (same as home) ──────────────────────────────────────────
const _black      = Color(0xFF000000);
const _black1     = Color(0xFF0A0A0A);
const _black2     = Color(0xFF111111);
const _black3     = Color(0xFF1A1A1A);
const _black4     = Color(0xFF222222);
const _white      = Color(0xFFFFFFFF);
const _white90    = Color(0xE6FFFFFF);
const _white70    = Color(0xB3FFFFFF);
const _white40    = Color(0x66FFFFFF);
const _white20    = Color(0x33FFFFFF);
const _white10    = Color(0x1AFFFFFF);
const _white06    = Color(0x0FFFFFFF);
const _grey       = Color(0xFF888888);
const _greyLight  = Color(0xFFAAAAAA);
const _greyDark   = Color(0xFF444444);
const _green      = Color(0xFF22C55E);
const _greenDim   = Color(0x1F22C55E);
const _greenBorder= Color(0x3322C55E);

// ─── BACKEND CONFIG ───────────────────────────────────────────────────
const _backendBase = 'https://444music-backend.bonto.run';
const _successMarker = 'www.444musicdistro.com/payment-success';

// ─── FONT HELPERS ────────────────────────────────────────────────────
TextStyle _outfit(double size, FontWeight weight, Color color,
    {double ls = 0, double h = 1.4}) =>
    GoogleFonts.outfit(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: ls,
      height: h,
    );

TextStyle _mono(double size, FontWeight weight, Color color,
    {double ls = 0}) =>
    GoogleFonts.dmMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: ls,
    );

// ─── PLAN DATA ────────────────────────────────────────────────────────
class _Plan {
  final String badge, badgeIcon, planName, desc, price, usdPrice, period, btnLabel, btnRoute;
  final double amountGHS;
  final bool isFeatured;
  final PlanStyle style;
  final List<_Feature> features;
  final List<_StoreChip> stores;
  final String? saveBadge;

  const _Plan({
    required this.badge,
    required this.badgeIcon,
    required this.planName,
    required this.desc,
    required this.price,
    required this.usdPrice,
    required this.period,
    required this.btnLabel,
    required this.btnRoute,
    required this.amountGHS,
    required this.features,
    required this.stores,
    this.isFeatured = false,
    this.style = PlanStyle.outline,
    this.saveBadge,
  });
}

enum PlanStyle { outline, solid, green }

class _Feature {
  final String text;
  final bool included;
  const _Feature(this.text, {this.included = true});
}

class _StoreChip {
  final IconData icon;
  final String label;
  const _StoreChip(this.icon, this.label);
}

final _plans = [
  _Plan(
    badge: 'Starter',
    badgeIcon: 'seedling',
    planName: 'Release as Draft',
    desc: 'Upload now, settle fees after your release starts earning.',
    price: '0',
    usdPrice: '0',
    period: 'No upfront payment',
    btnLabel: 'Get Started Free',
    btnRoute: '/agreement',
    amountGHS: 0,
    style: PlanStyle.outline,
    features: [
      const _Feature('Upload unlimited songs as draft'),
      const _Feature('100+ digital store distribution'),
      const _Feature('Free ISRC & UPC barcode'),
      const _Feature('Keep 100% of royalties'),
      const _Feature('Artist dashboard access'),
      const _Feature('Basic streaming analytics'),
      const _Feature('Cover art design', included: false),
      const _Feature('Priority delivery', included: false),
    ],
    stores: const [
      _StoreChip(Icons.music_note_rounded, 'Spotify'),
      _StoreChip(Icons.apple_rounded, 'Apple'),
      _StoreChip(Icons.play_circle_filled_rounded, 'YouTube'),
      _StoreChip(Icons.music_video_rounded, 'TikTok'),
    ],
  ),
  _Plan(
    badge: 'Most Popular',
    badgeIcon: 'fire',
    planName: 'Single',
    desc: 'Drop a track professionally with fast global delivery and store cover art.',
    price: '1',
    usdPrice: '3.41',
    period: 'One-time per release',
    btnLabel: 'Release Single',
    btnRoute: '',
    amountGHS: 1,
    isFeatured: true,
    style: PlanStyle.solid,
    features: [
      const _Feature('1 single release (1–2 tracks)'),
      const _Feature('Spotify, Apple Music, TikTok & 100+ stores'),
      const _Feature('Free ISRC & UPC barcode'),
      const _Feature('Keep 100% of royalties'),
      const _Feature('Fast 5–7 day delivery'),
      const _Feature('Cover art review & upload'),
      const _Feature('Streaming analytics dashboard'),
      const _Feature('Metadata & credits management'),
    ],
    stores: const [
      _StoreChip(Icons.music_note_rounded, 'Spotify'),
      _StoreChip(Icons.apple_rounded, 'Apple'),
      _StoreChip(Icons.play_circle_filled_rounded, 'YouTube'),
      _StoreChip(Icons.shopping_bag_rounded, 'Amazon'),
    ],
  ),
  _Plan(
    badge: 'Pro',
    badgeIcon: 'layers',
    planName: 'EP / Album',
    desc: 'Full project distribution with advanced reporting and priority support.',
    price: '59',
    usdPrice: '5.16',
    period: 'One-time per project',
    btnLabel: 'Release Project',
    btnRoute: '',
    amountGHS: 59,
    style: PlanStyle.outline,
    features: [
      const _Feature('Up to 20 tracks per project'),
      const _Feature('Global distribution to 100+ stores'),
      const _Feature('Free ISRC for each track + UPC'),
      const _Feature('Keep 100% of royalties'),
      const _Feature('Priority 3–5 day delivery'),
      const _Feature('Full royalty breakdown reports'),
      const _Feature('Artist dashboard with insights'),
      const _Feature('Priority email support'),
    ],
    stores: const [
      _StoreChip(Icons.music_note_rounded, 'Spotify'),
      _StoreChip(Icons.apple_rounded, 'Apple'),
      _StoreChip(Icons.play_circle_filled_rounded, 'YouTube'),
      _StoreChip(Icons.headphones_rounded, 'Tidal'),
    ],
  ),
];

// ─── FAQ DATA ─────────────────────────────────────────────────────────
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
    q: 'Can I pay in US Dollars instead of Cedis?',
    a: 'Yes. Prices are shown in both Ghanaian Cedis (GHC) and US Dollars so international artists know exactly what they will be charged. Payment can be made in either currency at checkout.',
  ),
];

class _FAQ {
  final String q, a;
  const _FAQ({required this.q, required this.a});
}

// ════════════════════════════════════════════════════════════════════
//  PRICING SCREEN
// ════════════════════════════════════════════════════════════════════
class PricingScreen extends StatefulWidget {
  final String? submissionId;

  const PricingScreen({super.key, this.submissionId});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  final Set<int> _openFaqs = {};

  bool _checkingResume = true;
  String? _resumeReference;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _entranceFade =
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
            CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();
    _checkForUnclaimedPayment();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkForUnclaimedPayment() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _checkingResume = false);
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('pendingPayments')
          .where('uid', isEqualTo: uid)
          .where('paid', isEqualTo: true)
          .where('claimed', isEqualTo: false)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty && mounted) {
        setState(() {
          _resumeReference = query.docs.first.id;
          _checkingResume = false;
        });
      } else if (mounted) {
        setState(() => _checkingResume = false);
      }
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

  Future<void> _handlePlanTap(_Plan plan) async {
    if (plan.amountGHS == 0) {
      Navigator.pushNamed(context, plan.btnRoute);
      return;
    }

    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final tempReference = '${uid.isEmpty ? 'guest' : uid}_${DateTime.now().millisecondsSinceEpoch}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentWaitingScreen(
          amountGHS: plan.amountGHS,
          submissionId: tempReference,
          uid: uid,
          email: email,
          successRouteName: '/upload',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final hasLockedPayment = !_checkingResume && _resumeReference != null;

    return WillPopScope(
      // Block the back button while a completed payment is waiting —
      // forces the user through "Continue" instead of getting stuck
      // back on a pricing page they can't fully use anyway.
      onWillPop: () async => !hasLockedPayment,
      child: Scaffold(
        backgroundColor: _black,
        body: Stack(
          children: [
            FadeTransition(
              opacity: _entranceFade,
              child: SlideTransition(
                position: _entranceSlide,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TopBarDelegate(
                        topPadding: top,
                        onBack: () => Navigator.pop(context),
                      ),
                    ),
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverToBoxAdapter(child: _buildTrustStrip()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                        child: Text(
                          'CHOOSE YOUR PLAN',
                          style: _outfit(11, FontWeight.w700, _grey, ls: 2),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (_, i) => _PlanCard(
                            plan: _plans[i],
                            index: i,
                            onTap: () => _handlePlanTap(_plans[i]),
                          ),
                          childCount: _plans.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: _buildCompareSection()),
                    SliverToBoxAdapter(child: _buildFaqSection()),
                    SliverToBoxAdapter(child: _buildBottomBanner()),
                    SliverToBoxAdapter(child: SizedBox(height: bottom + 30)),
                  ],
                ),
              ),
            ),
            // ── Blocking payment overlay ──
            // Appears automatically whenever a paid-but-unclaimed payment
            // exists. Blurs and blocks the entire pricing page — the only
            // way past it is tapping Continue, which routes straight into
            // the release flow. Nothing behind it is reachable.
            if (hasLockedPayment) _buildPaymentLockOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentLockOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // absorbs all taps, nothing behind is reachable
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: _black.withValues(alpha: 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _black1,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _greenBorder, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: _greenDim,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded,
                          color: _green, size: 32),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Payment Completed',
                      textAlign: TextAlign.center,
                      style: _outfit(18, FontWeight.w800, _white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "You've already paid for a release. Continue to finish submitting it before starting anything new.",
                      textAlign: TextAlign.center,
                      style: _outfit(13, FontWeight.w500, _white70, h: 1.5),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _resumeRelease,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'CONTINUE',
                              style: _outfit(13, FontWeight.w800, _black, ls: 1.2),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded,
                                color: _black, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _white06,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: _white70, size: 12),
                const SizedBox(width: 6),
                Text(
                  'DISTRIBUTION PLANS',
                  style: _outfit(10, FontWeight.w800, _white70, ls: 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Simple pricing.\nSerious distribution.',
            style: _outfit(34, FontWeight.w800, _white, h: 1.1),
          ),
          const SizedBox(height: 12),
          Text(
            'Upload once. Reach millions. Keep every cent you earn — no hidden cuts, no annual surprises.',
            style: _outfit(14, FontWeight.w500, _grey, h: 1.6),
          ),
          const SizedBox(height: 6),
          Text(
            'Prices shown in Ghana Cedis (GHC) with US Dollar equivalents for international artists.',
            style: _outfit(12, FontWeight.w500, _greyDark, h: 1.5),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildTrustStrip() {
    final items = [
      (Icons.check_circle_outline_rounded, '100% Royalties'),
      (Icons.store_rounded, '100+ Stores'),
      (Icons.qr_code_rounded, 'Free ISRC & UPC'),
      (Icons.cancel_outlined, 'Cancel Anytime'),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 28),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _black2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _white10),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        children: items.map((item) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.$1, color: _green, size: 14),
              const SizedBox(width: 6),
              Text(
                item.$2,
                style: _outfit(12, FontWeight.w600, _white70),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCompareSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 36, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan Comparison',
            style: _outfit(22, FontWeight.w800, _white),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: _black2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _white10),
            ),
            clipBehavior: Clip.hardEdge,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: _CompareTable(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 36, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frequently Asked Questions',
            style: _outfit(22, FontWeight.w800, _white),
          ),
          const SizedBox(height: 16),
          ..._faqs.asMap().entries.map((e) {
            final i = e.key;
            final faq = e.value;
            final open = _openFaqs.contains(i);
            return _FaqItem(
              faq: faq,
              isOpen: open,
              onTap: () => setState(() {
                if (open) {
                  _openFaqs.remove(i);
                } else {
                  _openFaqs.clear();
                  _openFaqs.add(i);
                }
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 36, 22, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to get your\nmusic heard?',
                  style: _outfit(20, FontWeight.w800, _black, h: 1.15),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join thousands of independent artists already distributing with 444Music.',
                  style: _outfit(12, FontWeight.w500, const Color(0xFF666666), h: 1.5),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/upload'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: _black,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.rocket_launch_rounded, color: _white, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          'Start Distributing',
                          style: _outfit(13, FontWeight.w800, _white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(color: _black, shape: BoxShape.circle),
            child: const Icon(Icons.headphones_rounded, color: _white, size: 26),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  STICKY TOP BAR DELEGATE
// ════════════════════════════════════════════════════════════════════
class _TopBarDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final VoidCallback onBack;

  const _TopBarDelegate({required this.topPadding, required this.onBack});

  @override
  double get minExtent => topPadding + 64;
  @override
  double get maxExtent => topPadding + 64;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: _black.withValues(alpha: 0.88),
          padding: EdgeInsets.only(top: topPadding),
          child: Container(
            height: 64,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _white10)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _white06,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _white10),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: _white, size: 16),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Pricing',
                  style: _outfit(18, FontWeight.w800, _white),
                ),
                const Spacer(),
                Text(
                  '444Music',
                  style: _outfit(13, FontWeight.w700, _grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TopBarDelegate oldDelegate) => false;
}

// ════════════════════════════════════════════════════════════════════
//  PLAN CARD
// ════════════════════════════════════════════════════════════════════
class _PlanCard extends StatefulWidget {
  final _Plan plan;
  final int index;
  final VoidCallback onTap;

  const _PlanCard({required this.plan, required this.index, required this.onTap});

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: 80 + widget.index * 100), () {
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
    final plan = widget.plan;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: plan.isFeatured ? _black2 : _black1,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: plan.isFeatured ? _white40 : _white10,
              width: plan.isFeatured ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (plan.isFeatured)
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, _white70, Colors.transparent],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Badge(plan: plan),
                        const Spacer(),
                        if (plan.isFeatured)
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                                color: _white, shape: BoxShape.circle),
                            child: const Icon(Icons.star_rounded,
                                color: _black, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      plan.planName,
                      style: _outfit(22, FontWeight.w800, _white, ls: 0.3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      plan.desc,
                      style: _outfit(13, FontWeight.w500, _grey, h: 1.55),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'GHC',
                              style: _outfit(15, FontWeight.w700, _white70),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              plan.price,
                              style: _mono(44, FontWeight.w500, _white),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '/ \$${plan.usdPrice}',
                            style: _outfit(13, FontWeight.w600, _grey),
                          ),
                        ),
                        if (plan.saveBadge != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _greenDim,
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: _greenBorder),
                              ),
                              child: Text(
                                plan.saveBadge!,
                                style: _outfit(11, FontWeight.w700, _green),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.period,
                      style: _outfit(12, FontWeight.w500, _greyDark),
                    ),
                    const SizedBox(height: 22),
                    Container(height: 1, color: _white10),
                    const SizedBox(height: 20),
                    Text(
                      "WHAT'S INCLUDED",
                      style: _outfit(10, FontWeight.w800, _greyDark, ls: 1.5),
                    ),
                    const SizedBox(height: 12),
                    ...plan.features.map((f) => _FeatureRow(feature: f)),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...plan.stores.map((s) => _StoreChipWidget(chip: s)),
                        _StoreChipWidget(
                          chip: const _StoreChip(Icons.add_rounded, '96 more'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _PlanButton(plan: plan, onTap: widget.onTap),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── BADGE ─────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final _Plan plan;
  const _Badge({required this.plan});

  @override
  Widget build(BuildContext context) {
    Color bg, textColor, borderColor;
    IconData icon;

    switch (plan.style) {
      case PlanStyle.solid:
        bg = _white20;
        textColor = _white;
        borderColor = _white40;
        icon = Icons.local_fire_department_rounded;
        break;
      case PlanStyle.green:
        bg = _greenDim;
        textColor = _green;
        borderColor = _greenBorder;
        icon = Icons.workspace_premium_rounded;
        break;
      case PlanStyle.outline:
      default:
        bg = _white06;
        textColor = _grey;
        borderColor = _white10;
        icon = plan.badge == 'Pro'
            ? Icons.layers_rounded
            : Icons.eco_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 10),
          const SizedBox(width: 5),
          Text(
            plan.badge.toUpperCase(),
            style: _outfit(9, FontWeight.w800, textColor, ls: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── FEATURE ROW ───────────────────────────────────────────────────────
class _FeatureRow extends StatelessWidget {
  final _Feature feature;
  const _FeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: feature.included ? _white10 : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              feature.included ? Icons.check_rounded : Icons.close_rounded,
              color: feature.included ? _white70 : _greyDark,
              size: 11,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              feature.text,
              style: _outfit(13, FontWeight.w600,
                  feature.included ? _white70 : _greyDark, h: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── STORE CHIP ────────────────────────────────────────────────────────
class _StoreChipWidget extends StatelessWidget {
  final _StoreChip chip;
  const _StoreChipWidget({required this.chip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _black3,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, color: _grey, size: 11),
          const SizedBox(width: 5),
          Text(
            chip.label,
            style: _outfit(11, FontWeight.w600, _grey),
          ),
        ],
      ),
    );
  }
}

// ── PLAN BUTTON ───────────────────────────────────────────────────────
class _PlanButtonState extends State<_PlanButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Color bg, textColor, borderColor;
    switch (widget.plan.style) {
      case PlanStyle.solid:
        bg = _white;
        textColor = _black;
        borderColor = _white;
        break;
      case PlanStyle.green:
        bg = Colors.transparent;
        textColor = _green;
        borderColor = _greenBorder;
        break;
      case PlanStyle.outline:
      default:
        bg = Colors.transparent;
        textColor = _white70;
        borderColor = _white20;
    }

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
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: _pressed ? bg.withValues(alpha: 0.85) : bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.plan.btnLabel.toUpperCase(),
              style: _outfit(13, FontWeight.w800, textColor, ls: 1.2),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: textColor, size: 16),
          ],
        ),
      ),
    );
  }
}

class _PlanButton extends StatefulWidget {
  final _Plan plan;
  final VoidCallback onTap;
  const _PlanButton({required this.plan, required this.onTap});

  @override
  State<_PlanButton> createState() => _PlanButtonState();
}

// ════════════════════════════════════════════════════════════════════
//  COMPARISON TABLE
// ════════════════════════════════════════════════════════════════════
class _CompareTable extends StatelessWidget {
  static const _headers = ['Feature', 'Starter', 'Single', 'EP / Album'];
  static const _rows = [
    ['Store Distribution', '100+', '100+', '100+'],
    ['Royalty Split', '100%', '100%', '100%'],
    ['Releases', '1', '1 Single', '1 Project'],
    ['Free ISRC & UPC', 'yes', 'yes', 'yes'],
    ['Analytics', 'Basic', 'Standard', 'Advanced'],
    ['Support', 'Community', 'Email', 'Priority'],
  ];

  const _CompareTable();

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(130),
        1: FixedColumnWidth(72),
        2: FixedColumnWidth(72),
        3: FixedColumnWidth(88),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(
            color: _black3,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          children: _headers.asMap().entries.map((e) {
            final isHighlighted = e.key == 2;
            return TableCell(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Text(
                  e.value.toUpperCase(),
                  style: _outfit(9, FontWeight.w800,
                      isHighlighted ? _white : _greyDark, ls: 1.5),
                  textAlign: e.key == 0 ? TextAlign.left : TextAlign.center,
                ),
              ),
            );
          }).toList(),
        ),
        ..._rows.map((row) {
          return TableRow(
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: _white.withValues(alpha: 0.03))),
            ),
            children: row.asMap().entries.map((e) {
              final isHighlighted = e.key == 2;
              final val = e.value;
              Widget child;
              if (val == 'yes') {
                child = const Center(
                  child: Icon(Icons.check_rounded, color: _green, size: 16),
                );
              } else if (val == 'no') {
                child = Center(
                  child: Icon(Icons.close_rounded, color: _greyDark, size: 16),
                );
              } else {
                child = Text(
                  val,
                  style: e.key == 0
                      ? _outfit(12, isHighlighted ? FontWeight.w700 : FontWeight.w500,
                      isHighlighted ? _white : _white70)
                      : _mono(11, FontWeight.w500,
                      isHighlighted ? _white : _white70),
                  textAlign: e.key == 0 ? TextAlign.left : TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                );
              }
              return TableCell(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: child,
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  FAQ ITEM
// ════════════════════════════════════════════════════════════════════
class _FaqItem extends StatelessWidget {
  final _FAQ faq;
  final bool isOpen;
  final VoidCallback onTap;

  const _FaqItem({required this.faq, required this.isOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: _white.withValues(alpha: 0.06))),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      faq.q,
                      style: _outfit(14, FontWeight.w700, _white, h: 1.4),
                    ),
                  ),
                  const SizedBox(width: 16),
                  AnimatedRotation(
                    turns: isOpen ? 0.125 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: Icon(
                      Icons.add_rounded,
                      color: isOpen ? _white : _greyDark,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                faq.a,
                style: _outfit(13, FontWeight.w500, _grey, h: 1.65),
              ),
            ),
            crossFadeState:
            isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 280),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PAYMENT SCREEN — External Browser (no WebView)
//  Opens Paystack checkout in the device's real browser instead of an
//  embedded WebView, and directly verifies payment status against
//  Paystack's own API rather than depending only on the webhook.
// ════════════════════════════════════════════════════════════════════
class PaymentWaitingScreen extends StatefulWidget {
  final double amountGHS;
  final String submissionId;
  final String uid;
  final String email;
  final String successRouteName;

  const PaymentWaitingScreen({
    super.key,
    required this.amountGHS,
    required this.submissionId,
    required this.uid,
    required this.email,
    required this.successRouteName,
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
  String? _statusMessage;
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

  Future<void> _verifyPayment({bool manual = false}) async {
    if (_checkingStatus || _paystackReference == null) return;

    setState(() {
      _checkingStatus = true;
      if (manual) _statusMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_backendBase/api/paystack/verify-payment/$_paystackReference'),
      );
      final data = jsonDecode(response.body);

      if (data['paid'] == true) {
        _pollTimer?.cancel();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PaymentSuccessScreen(
                paymentReference: widget.submissionId,
              ),
            ),
          );
        }
        return;
      }

      if (manual && mounted) {
        setState(() {
          _statusMessage =
              "Payment not confirmed yet. This can take a little while to settle — keep this screen open and it will move forward automatically once confirmed.";
        });
      }
    } catch (_) {
      if (manual && mounted) {
        setState(() {
          _statusMessage = 'Could not check payment status. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      appBar: AppBar(
        backgroundColor: _black,
        title: Text('Complete Payment', style: _outfit(16, FontWeight.w700, _white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: _outfit(13, FontWeight.w500, _white70),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _loading = true;
                    });
                    _startPayment();
                  },
                  child: const Text('Try Again'),
                ),
              ] else if (_loading) ...[
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'Preparing your payment…',
                  style: _outfit(13, FontWeight.w500, _white70),
                ),
              ] else ...[
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: _white06, shape: BoxShape.circle),
                  child: const Icon(Icons.open_in_new_rounded, color: _white, size: 28),
                ),
                const SizedBox(height: 20),
                Text(
                  'Complete your payment in the\nbrowser that just opened',
                  textAlign: TextAlign.center,
                  style: _outfit(15, FontWeight.w700, _white, h: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  "We'll bring you back here automatically once payment is confirmed. This can take a short moment to settle — no need to close this screen.",
                  textAlign: TextAlign.center,
                  style: _outfit(12, FontWeight.w500, _white70, h: 1.5),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: _checkingStatus ? null : () => _verifyPayment(manual: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: _white06,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: _white10),
                    ),
                    child: _checkingStatus
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              ),
                              const SizedBox(width: 10),
                              Text('Checking…', style: _outfit(13, FontWeight.w700, _white)),
                            ],
                          )
                        : Text(
                            "I've completed payment",
                            style: _outfit(13, FontWeight.w700, _white),
                          ),
                  ),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: _outfit(12, FontWeight.w500, _white70, h: 1.4),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}