// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Earnings Screen (merged: old stable structure + new
//  monochrome theme + currency dropdown). No heavy BoxShadow blurs,
//  no per-card RepaintBoundary stacking — kept close to the old file's
//  proven-stable rendering pattern.
//  Route: /earnings
//  Firebase: users/{uid} → earnings, clearedEarnings, pendingEarnings,
//            spotifyEarnings, appleEarnings, youtubeEarnings, amazonEarnings
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── PALETTE ───────────────────────────────────────────────────────
const _black      = Color(0xFF000000);
const _black2     = Color(0xFF111111);
const _black3     = Color(0xFF1A1A1A);
const _white      = Color(0xFFFFFFFF);
const _white10    = Color(0x1AFFFFFF);
const _white20    = Color(0x33FFFFFF);
const _grey       = Color(0xFF8A8A8A);
const _ink1       = Color(0xFF0D0D0D);
const _ink2       = Color(0xFF6E6E6E);
const _inkBorder  = Color(0x14000000);

TextStyle _head(double s, FontWeight w, {Color c = _white, double? ls}) =>
    GoogleFonts.nunito(fontSize: s, fontWeight: w, color: c, letterSpacing: ls);
TextStyle _body(double s, FontWeight w, {Color c = _grey, double? h}) =>
    GoogleFonts.nunito(fontSize: s, fontWeight: w, color: c, height: h);

class _CurrencyInfo {
  final String symbol;
  final double rate;
  const _CurrencyInfo({required this.symbol, required this.rate});
}

const Map<String, _CurrencyInfo> _currencyRates = {
  'USD': _CurrencyInfo(symbol: '\$',   rate: 1),
  'GHS': _CurrencyInfo(symbol: 'GHC',  rate: 11.454),
  'NGN': _CurrencyInfo(symbol: '₦',    rate: 1500.5),
  'EUR': _CurrencyInfo(symbol: '€',    rate: 0.9198),
  'GBP': _CurrencyInfo(symbol: '£',    rate: 0.7903),
  'ZAR': _CurrencyInfo(symbol: 'R',    rate: 18.50),
  'KES': _CurrencyInfo(symbol: 'KSh',  rate: 128.98),
  'CAD': _CurrencyInfo(symbol: 'CA\$', rate: 1.360),
  'XOF': _CurrencyInfo(symbol: 'CFA',  rate: 602.5),
};

const List<Map<String, String>> _currencyOptions = [
  {'code': 'USD', 'label': '🇺🇸 USD'},
  {'code': 'GHS', 'label': '🇬🇭 GHS'},
  {'code': 'NGN', 'label': '🇳🇬 NGN'},
  {'code': 'EUR', 'label': '🇪🇺 EUR'},
  {'code': 'GBP', 'label': '🇬🇧 GBP'},
  {'code': 'ZAR', 'label': '🇿🇦 ZAR'},
  {'code': 'KES', 'label': '🇰🇪 KES'},
  {'code': 'CAD', 'label': '🇨🇦 CAD'},
  {'code': 'XOF', 'label': '🌍 XOF'},
];

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  static const double _minWithdrawal = 50.0;

  double _balance = 0, _cleared = 0, _pending = 0;
  double _spotify = 0, _apple = 0, _youtube = 0, _amazon = 0;
  bool _loading = true;
  bool _showPopup = false;
  String? _photoURL;
  String _selectedCurrency = 'USD';

  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));
    // NOTE: simple fade only — no slide/scale entrance stacked on top,
    // matching the old file's lighter entrance animation.
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final d = snap.exists ? snap.data()! : <String, dynamic>{};
      double num_(dynamic v) => v == null ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
      if (mounted) {
        setState(() {
          _photoURL = d['photoURL'];
          _balance  = num_(d['earnings']);
          _cleared  = num_(d['clearedEarnings']);
          _pending  = num_(d['pendingEarnings']);
          _spotify  = num_(d['spotifyEarnings']);
          _apple    = num_(d['appleEarnings']);
          _youtube  = num_(d['youtubeEarnings']);
          _amazon   = num_(d['amazonEarnings']);
          _loading  = false;
        });
        _ctrl.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _ctrl.forward();
    }
  }

  void _handleWithdraw() {
    if (_balance < _minWithdrawal) {
      setState(() => _showPopup = true);
    } else {
      Navigator.pushNamed(context, '/withdrawal');
    }
  }

  _CurrencyInfo get _cur => _currencyRates[_selectedCurrency] ?? _currencyRates['USD']!;
  String _fmt(double usd, {int? decimals}) {
    final v = usd * _cur.rate;
    final d = decimals ?? (_selectedCurrency == 'XOF' ? 0 : 2);
    return '${_cur.symbol}${v.toStringAsFixed(d)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      body: Stack(children: [
        if (_loading)
          const Center(child: CircularProgressIndicator(color: _white, strokeWidth: 2))
        else
          FadeTransition(opacity: _fade, child: _buildBody()),
        if (_showPopup) _popup(),
      ]),
    );
  }

  Widget _buildBody() {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: top),
        _topBar(),
        Padding(padding: const EdgeInsets.fromLTRB(20, 26, 20, 0), child: _header()),
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: _currencySelector()),
        Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), child: _heroCard()),
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: _clearedPendingRow()),
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _withdrawCard()),
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _platformCard()),
        SizedBox(height: bottom + 40),
      ]),
    );
  }

  Widget _topBar() => Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _white10))),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _black2, shape: BoxShape.circle, border: Border.all(color: _white20),
              image: _photoURL != null
                  ? DecorationImage(image: CachedNetworkImageProvider(_photoURL!), fit: BoxFit.cover)
                  : null,
            ),
            child: _photoURL == null ? const Icon(Icons.person_rounded, color: _grey, size: 18) : null,
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _black2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _white10)),
              child: const Icon(Icons.menu_rounded, color: _white, size: 18),
            ),
          ),
        ]),
      );

  Widget _header() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Earnings', style: _head(26, FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Your balance across every platform.', style: _body(13, FontWeight.w500)),
      ]);

  Widget _currencySelector() => Row(children: [
        Text('VIEW IN', style: _body(10, FontWeight.w700).copyWith(letterSpacing: 0.6)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: _black2, borderRadius: BorderRadius.circular(99), border: Border.all(color: _white20)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCurrency,
              dropdownColor: _black2,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _grey, size: 16),
              style: _body(13, FontWeight.w700, c: _white),
              items: _currencyOptions
                  .map((o) => DropdownMenuItem(value: o['code'], child: Text(o['label']!)))
                  .toList(),
              onChanged: (v) { if (v != null) setState(() => _selectedCurrency = v); },
            ),
          ),
        ),
      ]);

  // ── HERO BALANCE CARD — flat, no blur shadow ──
  Widget _heroCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: _black2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _white10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _white10, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.account_balance_wallet_rounded, color: _white, size: 17),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              maxLines: 1,
              text: TextSpan(children: [
                TextSpan(text: _fmt(_balance), style: _head(30, FontWeight.w900, ls: -1)),
                TextSpan(text: ' $_selectedCurrency', style: _body(13, FontWeight.w600)),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text('AVAILABLE BALANCE', style: _body(10, FontWeight.w700).copyWith(letterSpacing: 0.8)),
        ]),
      );

  // ── CLEARED / PENDING — white cards, flat ──
  Widget _clearedPendingRow() => Row(children: [
        Expanded(child: _plainWhiteCard(Icons.check_rounded, _fmt(_cleared), 'CLEARED')),
        const SizedBox(width: 12),
        Expanded(child: _plainWhiteCard(Icons.hourglass_bottom_rounded, _fmt(_pending), 'PENDING')),
      ]);

  Widget _plainWhiteCard(IconData icon, String value, String label) => Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 14, 16),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _inkBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: const Color(0x0D000000), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: _ink1, size: 14),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: _head(18, FontWeight.w900, c: _ink1, ls: -0.5)),
          ),
          const SizedBox(height: 4),
          Text(label, style: _body(9, FontWeight.w700, c: _ink2).copyWith(letterSpacing: 0.6)),
        ]),
      );

  // ── WITHDRAW CARD — white, flat, no blur shadow on the button ──
  Widget _withdrawCard() {
    final pct = (_balance / _minWithdrawal).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.arrow_upward_rounded, color: _ink1, size: 15),
          const SizedBox(width: 8),
          Text('Ready to withdraw', style: _head(14, FontWeight.w800, c: _ink1)),
        ]),
        const SizedBox(height: 8),
        Text(
          'Minimum withdrawal is ${_fmt(_minWithdrawal)}. Balances update once platform reports come in, usually 45–60 days after month end.',
          style: _body(12.5, FontWeight.w500, c: _ink2, h: 1.5),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 6, color: const Color(0x14000000),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft, widthFactor: pct,
              child: Container(color: _ink1),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Progress to payout', style: _body(11.5, FontWeight.w600, c: _ink2)),
          Text('${_fmt(_balance, decimals: 0)} / ${_fmt(_minWithdrawal, decimals: 0)}',
              style: _body(11.5, FontWeight.w800, c: _ink1)),
        ]),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: _handleWithdraw,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(color: _ink1, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.arrow_upward_rounded, color: _white, size: 16),
              const SizedBox(width: 9),
              Text('Withdraw Earnings', style: _body(14, FontWeight.w700, c: _white)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── PLATFORM BREAKDOWN — black card, flat ──
  Widget _platformCard() {
    final total = (_spotify + _apple + _youtube + _amazon).clamp(1.0, double.infinity);
    int pct(double v) => (v / total * 100).round();
    final rows = [
      (icon: Icons.music_note_rounded, name: 'Spotify', v: _spotify),
      (icon: Icons.apple_rounded, name: 'Apple Music', v: _apple),
      (icon: Icons.play_circle_fill_rounded, name: 'YouTube', v: _youtube),
      (icon: Icons.shopping_bag_rounded, name: 'Amazon Music', v: _amazon),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _black2, borderRadius: BorderRadius.circular(18), border: Border.all(color: _white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.pie_chart_rounded, color: _white, size: 15),
          const SizedBox(width: 8),
          Text('Earnings by Platform', style: _head(15, FontWeight.w800, ls: -0.3)),
        ]),
        const SizedBox(height: 18),
        ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _black3, borderRadius: BorderRadius.circular(12), border: Border.all(color: _white10)),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: _black, borderRadius: BorderRadius.circular(9)),
                    child: Icon(r.icon, color: _grey, size: 15),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(width: 100, child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: _body(13, FontWeight.w700, c: _white))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        height: 5, color: _black,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: r.v / total,
                          child: Container(color: _white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 36, child: Text('${pct(r.v)}%', textAlign: TextAlign.right,
                      style: _head(12.5, FontWeight.w800))),
                ]),
              ),
            )),
      ]),
    );
  }

  Widget _popup() => GestureDetector(
        onTap: () => setState(() => _showPopup = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.8),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 26),
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(20)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(color: const Color(0x0F000000), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.warning_amber_rounded, color: _ink1, size: 22),
                  ),
                  const SizedBox(height: 16),
                  Text('Minimum Not Reached', style: _head(18, FontWeight.w800, c: _ink1)),
                  const SizedBox(height: 8),
                  Text('Your balance is below the minimum withdrawal threshold.',
                      textAlign: TextAlign.center, style: _body(13, FontWeight.w500, c: _ink2, h: 1.5)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => setState(() => _showPopup = false),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: _ink1, borderRadius: BorderRadius.circular(11)),
                      child: Text('Got it', textAlign: TextAlign.center,
                          style: _body(14, FontWeight.w700, c: _white)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}