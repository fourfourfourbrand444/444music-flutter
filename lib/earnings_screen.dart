// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Earnings Screen
//  Route: /earnings
//  Works from: Bottom Nav (index 3) + Sidebar nav item
//  Firebase: reads users/{uid}.earnings from Firestore
// ═══════════════════════════════════════════════════════════════════

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── PALETTE (matches home_screen.dart exactly) ──────────────────────
const _black      = Color(0xFF000000);
const _black1     = Color(0xFF0A0A0A);
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

// ─── ACCENT COLOURS ──────────────────────────────────────────────────
const _green      = Color(0xFF22C55E);
const _greenDim   = Color(0x1A22C55E);
const _cyan       = Color(0xFF06B6D4);
const _cyanDim    = Color(0x1A06B6D4);
const _warn       = Color(0xFFF59E0B);
const _warnDim    = Color(0x1AF59E0B);
const _redDim     = Color(0x1AEF4444);
const _red        = Color(0xFFEF4444);

// ─── PLATFORM DATA ───────────────────────────────────────────────────
class _Platform {
  final String name;
  final IconData icon;
  final Color color;
  final Color dimColor;
  const _Platform({required this.name, required this.icon,
    required this.color, required this.dimColor});
}

const _platforms = [
  _Platform(name: 'Spotify',       icon: Icons.music_note_rounded,        color: Color(0xFF1DB954), dimColor: Color(0x1A1DB954)),
  _Platform(name: 'Apple Music',   icon: Icons.apple_rounded,             color: Color(0xFFFC3C44), dimColor: Color(0x1AFC3C44)),
  _Platform(name: 'YouTube Music', icon: Icons.play_circle_filled_rounded,color: Color(0xFFFF0000), dimColor: Color(0x1AFF0000)),
  _Platform(name: 'Amazon Music',  icon: Icons.shopping_bag_rounded,      color: Color(0xFFFF9900), dimColor: Color(0x1AFF9900)),
  _Platform(name: 'Tidal',         icon: Icons.waves_rounded,             color: Color(0xFF06B6D4), dimColor: Color(0x1A06B6D4)),
];

// ─── GROWTH TIPS DATA ────────────────────────────────────────────────
class _Tip {
  final IconData icon;
  final Color color, dimColor;
  final String title, body;
  const _Tip({required this.icon, required this.color, required this.dimColor,
    required this.title, required this.body});
}

const _tips = [
  _Tip(icon: Icons.share_rounded,         color: _green, dimColor: _greenDim,
      title: 'Promote your releases',    body: 'Share on social media to drive streams and grow your audience.'),
  _Tip(icon: Icons.queue_music_rounded,   color: Color(0xFFa78bfa), dimColor: Color(0x1Aa78bfa),
      title: 'Pitch to playlists',       body: 'Submit for editorial playlists at least 7 days before release.'),
  _Tip(icon: Icons.calendar_today_rounded,color: _cyan, dimColor: _cyanDim,
      title: 'Release consistently',     body: 'Regular releases keep the algorithm working in your favour.'),
  _Tip(icon: Icons.trending_up_rounded,   color: _warn, dimColor: _warnDim,
      title: 'Monitor your analytics',   body: 'Check reports weekly to track which tracks perform best.'),
];

// ════════════════════════════════════════════════════════════════════
//  EARNINGS SCREEN
// ════════════════════════════════════════════════════════════════════
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {

  double _balance   = 0.0;
  bool   _loading   = true;
  bool   _showPopup = false;

  late AnimationController _entranceCtrl;
  late Animation<double>   _entranceFade;
  late Animation<Offset>   _entranceSlide;

  // Threshold fill animation
  late Animation<double> _threshAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _entranceFade  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    _threshAnim = const AlwaysStoppedAnimation(0.0);

    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      final amount = snap.exists
          ? (double.tryParse(snap.data()?['earnings']?.toString() ?? '0') ?? 0.0)
          : 0.0;
      if (mounted) {
        setState(() { _balance = amount; _loading = false; });
        _entranceCtrl.forward();
        // Animate threshold bar
        final pct = (amount / 20.0).clamp(0.0, 1.0);
        _threshAnim = Tween<double>(begin: 0, end: pct).animate(
          CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic)),
        );
      }
    } catch (_) {
      if (mounted) setState(() { _balance = 0.0; _loading = false; });
      _entranceCtrl.forward();
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _handleWithdraw() {
    if (_balance < 20.0) {
      setState(() => _showPopup = true);
    } else {
      Navigator.pushNamed(context, '/withdrawal');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      extendBody: true,
      body: Stack(
        children: [
          // ── MAIN CONTENT
          if (_loading)
            const Center(child: CircularProgressIndicator(color: _white, strokeWidth: 2))
          else
            SlideTransition(
              position: _entranceSlide,
              child: FadeTransition(
                opacity: _entranceFade,
                child: _buildBody(),
              ),
            ),

          // ── POPUP OVERLAY
          if (_showPopup) _buildPopup(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  BODY
  // ─────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: top),

          // ── TOP BAR
          _buildTopBar(),

          // ── HERO STRIP
          _buildHeroStrip(),

          // ── BALANCE CARD
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _buildBalanceCard(),
          ),

          // ── EARNINGS CHART
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildChartCard(),
          ),

          // ── RECENT ACTIVITY
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildActivityCard(),
          ),

          // ── PLATFORM BREAKDOWN
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildPlatformCard(),
          ),

          // ── PAYOUT METHODS
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildPayoutCard(),
          ),

          // ── GROWTH TIPS
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildTipsCard(),
          ),

          SizedBox(height: bottom + 110),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  TOP BAR
  // ─────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _black.withValues(alpha: 0.9),
        border: const Border(bottom: BorderSide(color: _white10)),
      ),
      child: Row(
        children: [
          // Logo — same as sidebar/home
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: CachedNetworkImage(
              imageUrl: 'https://444music-distribution.vercel.app/black.png',
              height: 28,
              color: _white,
              colorBlendMode: BlendMode.srcIn,
              errorWidget: (_, __, ___) => Text(
                '444Music',
                style: GoogleFonts.nunito(
                  color: _white, fontSize: 20, fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const Spacer(),
          // Live badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _greenDim,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(),
                const SizedBox(width: 5),
                Text('Live', style: GoogleFonts.nunito(
                  color: _green, fontSize: 11.5, fontWeight: FontWeight.w700,
                )),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _white06,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _white10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  HERO STRIP
  // ─────────────────────────────────────────────────────────────────
  Widget _buildHeroStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _white10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _white10,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _white20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_rounded, color: _white70, size: 12),
                const SizedBox(width: 6),
                Text('EARNINGS DASHBOARD',
                  style: GoogleFonts.nunito(
                    color: _white70, fontSize: 10, fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Your Revenue Center',
            style: GoogleFonts.nunito(
              color: _white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text('Real-time earnings from all streaming platforms.\nWithdraw once you hit \$20.',
            style: GoogleFonts.nunito(
              color: _grey, fontSize: 13, fontWeight: FontWeight.w500, height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Quick stat pills
          Row(
            children: [
              _HeroPill(icon: Icons.cell_tower_rounded,  iconColor: _green, dimColor: _greenDim, label: 'Platforms', value: '150+'),
              const SizedBox(width: 10),
              _HeroPill(icon: Icons.percent_rounded,     iconColor: _white70, dimColor: _white10, label: 'Your Cut',  value: '100%'),
              const SizedBox(width: 10),
              _HeroPill(icon: Icons.schedule_rounded,    iconColor: _cyan,  dimColor: _cyanDim,  label: 'Payout',    value: '3–7d'),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  BALANCE CARD
  // ─────────────────────────────────────────────────────────────────
  Widget _buildBalanceCard() {
    final pct = (_balance / 20.0).clamp(0.0, 1.0);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: Icons.account_balance_wallet_rounded, label: 'Account Balance'),
          const SizedBox(height: 16),

          // Main balance block
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _black2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _white10),
            ),
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: _white10,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: _white20),
                  ),
                  child: const Icon(Icons.monetization_on_rounded, color: _white, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Available Balance',
                        style: GoogleFonts.nunito(color: _grey, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('\$', style: GoogleFonts.nunito(
                            color: _grey, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 2),
                        Text(_balance.toStringAsFixed(2),
                            style: GoogleFonts.nunito(
                                color: _white, fontSize: 36, fontWeight: FontWeight.w800, height: 1)),
                        const SizedBox(width: 6),
                        Text('USD', style: GoogleFonts.nunito(
                            color: _grey, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Cleared / Pending / Withdrawn row
          Row(
            children: [
              Expanded(child: _BalBadge(icon: Icons.check_circle_rounded,        iconColor: _green, dimColor: _greenDim, label: 'Cleared',   value: '\$0.00')),
              const SizedBox(width: 8),
              Expanded(child: _BalBadge(icon: Icons.hourglass_bottom_rounded,    iconColor: _cyan,  dimColor: _cyanDim,  label: 'Pending',   value: '\$0.00')),
              const SizedBox(width: 8),
              Expanded(child: _BalBadge(icon: Icons.north_rounded,               iconColor: _warn,  dimColor: _warnDim,  label: 'Withdrawn', value: '\$0.00')),
            ],
          ),

          const SizedBox(height: 14),

          // Threshold progress bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _black2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Payout threshold progress',
                        style: GoogleFonts.nunito(color: _grey, fontSize: 11.5, fontWeight: FontWeight.w500)),
                    Text('\$${_balance.toStringAsFixed(2)} / \$20.00',
                        style: GoogleFonts.nunito(color: _white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: _threshAnim,
                  builder: (_, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      height: 5,
                      color: _black3,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _threshAnim.value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_white40, _white]),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _handleWithdraw,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.north_rounded, color: _black, size: 16),
                        const SizedBox(width: 7),
                        Text('Withdraw Earnings',
                            style: GoogleFonts.nunito(
                                color: _black, fontSize: 13, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _OutlineBtn(icon: Icons.history_rounded, label: 'History',
                  onTap: () => Navigator.pushNamed(context, '/transactions')),
            ],
          ),

          const SizedBox(height: 14),

          // Info note
          _InfoNote(
            text: 'Balances update after platform reports are received — typically 45–60 days after month end. '
                'Withdrawals require a minimum balance of ',
            bold: '\$20.00',
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  CHART CARD
  // ─────────────────────────────────────────────────────────────────
  Widget _buildChartCard() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: Icons.bar_chart_rounded, label: 'Earnings Over Time'),
          const SizedBox(height: 16),
          // Bars
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(days.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: _black2,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _white10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(days[i],
                            style: GoogleFonts.nunito(
                                color: _greyDark, fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
          // Legend
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(99))),
              const SizedBox(width: 6),
              Text('Daily Revenue', style: GoogleFonts.nunito(color: _grey, fontSize: 11.5)),
              const SizedBox(width: 16),
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: _black2, borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: _white10))),
              const SizedBox(width: 6),
              Text('No Data', style: GoogleFonts.nunito(color: _grey, fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  RECENT ACTIVITY
  // ─────────────────────────────────────────────────────────────────
  Widget _buildActivityCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: Icons.format_list_bulleted_rounded, label: 'Recent Activity'),
          const SizedBox(height: 8),
          _ActivityRow(icon: Icons.music_note_rounded,   iconBg: _greenDim,  iconColor: _green,  title: 'Streams',             sub: 'All platforms · This month',  trailing: _ActivityTrailing.dash),
          _ActivityRow(icon: Icons.download_rounded,     iconBg: _cyanDim,   iconColor: _cyan,   title: 'Downloads',           sub: 'All platforms · This month',  trailing: _ActivityTrailing.dash),
          _ActivityRow(icon: Icons.attach_money_rounded, iconBg: _white10,   iconColor: _white70,title: 'Revenue Pending',     sub: 'Awaiting platform report',    trailing: _ActivityTrailing.pending),
          _ActivityRow(icon: Icons.favorite_rounded,     iconBg: _warnDim,   iconColor: _warn,   title: 'Saves / Likes',      sub: 'Spotify, Apple Music',        trailing: _ActivityTrailing.dash),
          _ActivityRow(icon: Icons.play_circle_filled_rounded, iconBg: _redDim, iconColor: _red, title: 'YouTube Content ID', sub: 'Monetisation active',         trailing: _ActivityTrailing.active),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  PLATFORM BREAKDOWN
  // ─────────────────────────────────────────────────────────────────
  Widget _buildPlatformCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: Icons.pie_chart_rounded, label: 'Platform Breakdown'),
          const SizedBox(height: 16),
          ..._platforms.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: p.dimColor,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(p.icon, color: p.color, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: GoogleFonts.nunito(
                          color: _white, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Container(height: 4, color: _black2,
                          child: const FractionallySizedBox(
                              alignment: Alignment.centerLeft, widthFactor: 0,
                              child: SizedBox()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text('0%', style: GoogleFonts.nunito(color: _grey, fontSize: 12)),
              ],
            ),
          )),
          const SizedBox(height: 2),
          _InfoNote(text: 'Platform data updates after DSP reports are received.'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  PAYOUT METHODS
  // ─────────────────────────────────────────────────────────────────
  Widget _buildPayoutCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: Icons.swap_horiz_rounded, label: 'Payout Methods'),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: const [
              _PayMethod(icon: Icons.paypal_rounded,              iconColor: Color(0xFF1DB954), dimColor: Color(0x1A1DB954), name: 'PayPal',        eta: '3–5 days'),
              _PayMethod(icon: Icons.account_balance_rounded,     iconColor: _cyan,             dimColor: _cyanDim,          name: 'Bank Transfer',  eta: '5–7 days'),
              _PayMethod(icon: Icons.phone_android_rounded,       iconColor: _warn,             dimColor: _warnDim,          name: 'Mobile Money',   eta: '1–3 days'),
              _PayMethod(icon: Icons.currency_bitcoin_rounded,    iconColor: Color(0xFFa78bfa), dimColor: Color(0x1Aa78bfa), name: 'Crypto',         eta: 'Coming soon'),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  GROWTH TIPS
  // ─────────────────────────────────────────────────────────────────
  Widget _buildTipsCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: Icons.lightbulb_rounded, label: 'Growth Tips'),
          const SizedBox(height: 12),
          ..._tips.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _black2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _white10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: t.dimColor, borderRadius: BorderRadius.circular(9)),
                    child: Icon(t.icon, color: t.color, size: 15),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, style: GoogleFonts.nunito(
                            color: _white, fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(t.body, style: GoogleFonts.nunito(
                            color: _grey, fontSize: 12, fontWeight: FontWeight.w500, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  POPUP — minimum not reached
  // ─────────────────────────────────────────────────────────────────
  Widget _buildPopup() {
    return GestureDetector(
      onTap: () => setState(() => _showPopup = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // prevent dismiss on card tap
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                decoration: BoxDecoration(
                  color: _black2,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _white10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Warning icon
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: _warnDim,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _warn.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: _warn, size: 26),
                    ),
                    const SizedBox(height: 18),
                    Text('Minimum Not Reached',
                        style: GoogleFonts.nunito(
                            color: _white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text('Your balance is below the minimum withdrawal threshold.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(color: _grey, fontSize: 13, height: 1.5)),
                    const SizedBox(height: 16),
                    // Threshold indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: _black3,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _white10),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          const Icon(Icons.monetization_on_rounded, color: _warn, size: 18),
                          Text('Balance must reach',
                              style: GoogleFonts.nunito(color: _grey, fontSize: 13)),
                          Text('\$20.00',
                              style: GoogleFonts.nunito(
                                  color: _warn, fontSize: 16, fontWeight: FontWeight.w800)),
                          Text('to withdraw',
                              style: GoogleFonts.nunito(color: _grey, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Keep promoting your music to build streams. Your balance updates automatically as earnings are reported.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(color: _greyDark, fontSize: 12, height: 1.55),
                    ),
                    const SizedBox(height: 20),
                    // Got it button
                    GestureDetector(
                      onTap: () => setState(() => _showPopup = false),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Got it',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                                color: _black, fontSize: 15, fontWeight: FontWeight.w800)),
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
}

// ════════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ════════════════════════════════════════════════════════════════════

// ── Pulsing green dot ──
class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _anim = Tween(begin: 1.0, end: 0.25).animate(_ctrl);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(width: 6, height: 6,
        decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
  );
}

// ── Hero pill ──
class _HeroPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor, dimColor;
  final String label, value;
  const _HeroPill({required this.icon, required this.iconColor,
    required this.dimColor, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: _black2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: dimColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 14),
            ),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.nunito(
                color: _white, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: GoogleFonts.nunito(
                color: _grey, fontSize: 10.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Card container ──
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _black2,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _white10),
    ),
    child: child,
  );
}

// ── Card title ──
class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CardTitle({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: _white70, size: 15),
      const SizedBox(width: 8),
      Text(label.toUpperCase(),
          style: GoogleFonts.nunito(
              color: _grey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
    ],
  );
}

// ── Balance badge ──
class _BalBadge extends StatelessWidget {
  final IconData icon;
  final Color iconColor, dimColor;
  final String label, value;
  const _BalBadge({required this.icon, required this.iconColor,
    required this.dimColor, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
    decoration: BoxDecoration(
      color: _black3,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: _white10),
    ),
    child: Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: dimColor, borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, color: iconColor, size: 13),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.nunito(color: _grey, fontSize: 10)),
              Text(value, style: GoogleFonts.nunito(
                  color: _white, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Outline button ──
class _OutlineBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _black3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _white70, size: 15),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.nunito(
              color: _white70, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

// ── Info note ──
class _InfoNote extends StatelessWidget {
  final String text;
  final String? bold;
  const _InfoNote({required this.text, this.bold});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _black3,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: _white10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: _white40, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.nunito(color: _grey, fontSize: 11.5, height: 1.6),
              children: [
                TextSpan(text: text),
                if (bold != null)
                  TextSpan(text: bold,
                      style: GoogleFonts.nunito(color: _white, fontWeight: FontWeight.w700, fontSize: 11.5)),
                if (bold != null)
                  const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Activity trailing type ──
enum _ActivityTrailing { dash, pending, active }

// ── Activity row ──
class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String title, sub;
  final _ActivityTrailing trailing;
  const _ActivityRow({required this.icon, required this.iconBg, required this.iconColor,
    required this.title, required this.sub, required this.trailing});
  @override
  Widget build(BuildContext context) {
    Widget trailingWidget;
    switch (trailing) {
      case _ActivityTrailing.dash:
        trailingWidget = Text('—', style: GoogleFonts.nunito(color: _greyDark, fontSize: 14, fontWeight: FontWeight.w700));
        break;
      case _ActivityTrailing.pending:
        trailingWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: _warnDim, borderRadius: BorderRadius.circular(99)),
          child: Text('Pending', style: GoogleFonts.nunito(color: _warn, fontSize: 10.5, fontWeight: FontWeight.w700)),
        );
        break;
      case _ActivityTrailing.active:
        trailingWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: _greenDim, borderRadius: BorderRadius.circular(99)),
          child: Text('Active', style: GoogleFonts.nunito(color: _green, fontSize: 10.5, fontWeight: FontWeight.w700)),
        );
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.nunito(
                    color: _white, fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text(sub, style: GoogleFonts.nunito(
                    color: _grey, fontSize: 11.5)),
              ],
            ),
          ),
          trailingWidget,
        ],
      ),
    );
  }
}

// ── Payout method ──
class _PayMethod extends StatelessWidget {
  final IconData icon;
  final Color iconColor, dimColor;
  final String name, eta;
  const _PayMethod({required this.icon, required this.iconColor,
    required this.dimColor, required this.name, required this.eta});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: _black3,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _white10),
    ),
    child: Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: dimColor, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 15),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(name, style: GoogleFonts.nunito(
                  color: _white, fontSize: 12.5, fontWeight: FontWeight.w700)),
              Text(eta, style: GoogleFonts.nunito(
                  color: _grey, fontSize: 10.5)),
            ],
          ),
        ),
      ],
    ),
  );
}