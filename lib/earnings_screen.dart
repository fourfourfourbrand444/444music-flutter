// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Earnings Screen  (mirrors web: ear.html)
//  Route: /earnings
//  Theme: Two-tone monochrome — genuinely black cards + genuinely
//         white cards on a true-black page. Fonts: Outfit (headings)
//         + Plus Jakarta Sans (body), matching the web build exactly.
//  Firebase: users/{uid} → earnings, clearedEarnings, pendingEarnings,
//            spotifyEarnings, appleEarnings, youtubeEarnings, amazonEarnings
//
//  Currency preview dropdown (display-only, mirrors the pattern used
//  on pricing_screen.dart): balances are stored and computed in USD
//  everywhere in Firestore/logic. The dropdown only changes what's
//  RENDERED on screen — withdrawal eligibility, the $50 minimum check,
//  and all backend calls still use the raw USD figures. Rates below
//  are USD-based and derived from the same GHC snapshot used on
//  pricing.html/pricing_screen.dart, so the two screens stay coherent.
//  Keep in sync with that file if you refresh rates.
//
//  v2 patch: overflow-safety only — currency row now wraps instead of
//  a fixed Row, the progress-to-payout line and both stat-card values
//  are guarded (FittedBox / Flexible+ellipsis) so a long converted
//  amount (NGN, XOF, etc.) can never push past the screen edge.
//
//  v3 patch: RepaintBoundary isolation. Every BoxShadow-decorated card
//  is wrapped in its own RepaintBoundary so a compositing glitch in
//  one card's paint layer can't bleed into a neighboring widget — this
//  is the fix for cards rendering faint/missing/ghosted on some
//  Android GPUs. Nothing else — animations, layout, avatar button,
//  data logic — changed.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── PALETTE (mirrors :root in ear.html) ─────────────────────────────
const _page       = Color(0xFF000000);
const _blk        = Color(0xFF0A0A0A);
const _blk2       = Color(0xFF111111);
const _blkBorder  = Color(0x17FFFFFF);
const _blkBorderH = Color(0x2EFFFFFF);

const _wht        = Color(0xFFFFFFFF);
const _inkBorder  = Color(0x14000000);
const _inkBorderH = Color(0x29000000);

const _text1      = Color(0xFFF5F5F5);
const _text2      = Color(0xFF969696);
const _ink1       = Color(0xFF0D0D0D);
const _ink2       = Color(0xFF6E6E6E);

const _ease = Curves.easeOutCubic;
const _entranceDuration = Duration(milliseconds: 900);

TextStyle _head(double size, FontWeight w, {Color color = _wht, double? letterSpacing}) =>
    GoogleFonts.outfit(fontSize: size, fontWeight: w, color: color, letterSpacing: letterSpacing);
TextStyle _body(double size, FontWeight w, {Color color = _text2, double? height}) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: color, height: height);

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
  {'code': 'USD', 'label': '🇺🇸 United States — USD'},
  {'code': 'GHS', 'label': '🇬🇭 Ghana — GHS'},
  {'code': 'NGN', 'label': '🇳🇬 Nigeria — NGN'},
  {'code': 'EUR', 'label': '🇪🇺 Europe — EUR'},
  {'code': 'GBP', 'label': '🇬🇧 United Kingdom — GBP'},
  {'code': 'ZAR', 'label': '🇿🇦 South Africa — ZAR'},
  {'code': 'KES', 'label': '🇰🇪 Kenya — KES'},
  {'code': 'CAD', 'label': '🇨🇦 Canada — CAD'},
  {'code': 'XOF', 'label': '🌍 West Africa (CFA) — XOF'},
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
  String? _uid;

  String _selectedCurrency = 'USD';

  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _reveal;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _page,
    ));
    _ctrl = AnimationController(vsync: this, duration: _entranceDuration);
    _fade = CurvedAnimation(parent: _ctrl, curve: _ease);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: _ease));
    _reveal = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.35, 1.0, curve: _ease));
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
    _uid = user.uid;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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
      if (mounted) {
        setState(() => _loading = false);
        _ctrl.forward();
      }
    }
  }

  void _handleWithdraw() {
    if (_balance < _minWithdrawal) {
      setState(() => _showPopup = true);
    } else {
      Navigator.pushNamed(context, '/withdrawal');
    }
  }

  _CurrencyInfo get _currencyInfo =>
      _currencyRates[_selectedCurrency] ?? _currencyRates['USD']!;

  double _toSelectedCurrency(double usdValue) => usdValue * _currencyInfo.rate;

  String _formatSelected(double usdValue, {int? decimals}) {
    final converted = _toSelectedCurrency(usdValue);
    final d = decimals ?? (_selectedCurrency == 'XOF' ? 0 : 2);
    return '${_currencyInfo.symbol}${converted.toStringAsFixed(d)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: Stack(children: [
        if (_loading)
          const Center(child: CircularProgressIndicator(color: _wht, strokeWidth: 2))
        else
          // PATCH: RepaintBoundary around the whole animated subtree —
          // gives Skia a clean compositing boundary for the slide+fade
          // layer instead of it sharing a layer with the Scaffold/Stack.
          RepaintBoundary(
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(opacity: _fade, child: _buildBody()),
            ),
          ),
        if (_showPopup) _popup(),
      ]),
    );
  }

  Widget _buildBody() {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
   return SingleChildScrollView(
     physics: const BouncingScrollPhysics(),
     cacheExtent: 0,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: top),
        _topBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
          child: _pageHeader(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: _currencySelector(),
        ),
        // PATCH: each card below gets its own RepaintBoundary so a paint
        // glitch in one (e.g. the shadow-heavy hero stat card) can't
        // bleed into the card above/below it.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: RepaintBoundary(child: _statRow()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: RepaintBoundary(child: _withdrawCard()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: RepaintBoundary(child: _platformCard()),
        ),
        SizedBox(height: bottom + 40),
      ]),
    );
  }

  Widget _topBar() {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: _page,
        border: Border(bottom: BorderSide(color: _blkBorder)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _blk2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _blkBorder),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _wht, size: 16),
          ),
        ),
        const Spacer(),
        _AvatarButton(photoURL: _photoURL, uid: _uid, onUpdated: (u) {
          if (mounted) setState(() => _photoURL = u);
        }),
      ]),
    );
  }

  Widget _pageHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _eyebrow(Icons.attach_money_rounded, '444MUSIC · EARNINGS'),
      const SizedBox(height: 14),
      Text('Earnings', style: _head(28, FontWeight.w900)),
      const SizedBox(height: 6),
      Text('Your balance across every platform, all in one place.',
          style: _body(13, FontWeight.w400, height: 1.5)),
    ]);
  }

  Widget _eyebrow(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0x29FFFFFF)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: _wht),
          const SizedBox(width: 6),
          Text(label,
              style: _body(10, FontWeight.w700, color: _wht)
                  .copyWith(letterSpacing: 1.2)),
        ]),
      );

  Widget _currencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Text(
              'VIEW EARNINGS IN',
              style: _body(10, FontWeight.w700, color: _text2)
                  .copyWith(letterSpacing: 0.5),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 40),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: _blk2,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _blkBorderH),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCurrency,
                    dropdownColor: _blk2,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _text2, size: 16),
                    style: _body(13, FontWeight.w700, color: _wht),
                    selectedItemBuilder: (context) => _currencyOptions
                        .map((opt) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(opt['label']!,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    items: _currencyOptions
                        .map((opt) => DropdownMenuItem(
                              value: opt['code'],
                              child: Text(opt['label']!,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedCurrency = v);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _selectedCurrency == 'USD'
              ? 'Your real balance, shown in USD.'
              : 'Approximate $_selectedCurrency preview — your real balance is always tracked in USD.',
          style: _body(11, FontWeight.w500, color: const Color(0xFF5C5C5C), height: 1.4),
        ),
      ],
    );
  }

  Widget _statRow() {
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        flex: 13,
        child: _HeroStatCard(
          icon: Icons.account_balance_wallet_rounded,
          value: _formatSelected(_balance),
          suffix: _selectedCurrency,
          label: 'Available Balance',
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 10,
        child: _PlainStatCard(
          icon: Icons.check_rounded,
          value: _formatSelected(_cleared),
          label: 'Cleared',
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 10,
        child: _PlainStatCard(
          icon: Icons.hourglass_bottom_rounded,
          value: _formatSelected(_pending),
          label: 'Pending',
        ),
      ),
    ]);
  }

  Widget _withdrawCard() {
    final pct = (_balance / _minWithdrawal).clamp(0.0, 1.0);
    return _WhiteCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.arrow_upward_rounded, color: _ink1, size: 15),
          const SizedBox(width: 8),
          Text('Ready to withdraw',
              style: _head(13, FontWeight.w800, color: _ink1)),
        ]),
        const SizedBox(height: 8),
        Text(
          'Minimum withdrawal is ${_formatSelected(_minWithdrawal)}. Balances update once platform '
          'reports come in, usually 45–60 days after month end.',
          style: _body(12.5, FontWeight.w500, color: _ink2, height: 1.55),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _reveal,
          builder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 6,
              color: const Color(0x14000000),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct * _reveal.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_ink1, Color(0xFF3A3A3A)]),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Flexible(
            child: Text('Progress to payout',
                overflow: TextOverflow.ellipsis,
                style: _body(11.5, FontWeight.w600, color: _ink2)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${_formatSelected(_balance, decimals: 0)} / ${_formatSelected(_minWithdrawal, decimals: 0)}',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: _body(11.5, FontWeight.w800, color: _ink1),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: _handleWithdraw,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: _ink1,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 22, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.arrow_upward_rounded, color: _wht, size: 16),
              const SizedBox(width: 9),
              Text('Withdraw Earnings',
                  style: _body(14, FontWeight.w700, color: _wht)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _platformCard() {
    final total = (_spotify + _apple + _youtube + _amazon).clamp(1.0, double.infinity);
    int pct(double v) => (v / total * 100).round();

    final rows = [
      (icon: Icons.music_note_rounded, name: 'Spotify', value: _spotify),
      (icon: Icons.apple_rounded, name: 'Apple Music', value: _apple),
      (icon: Icons.play_circle_fill_rounded, name: 'YouTube', value: _youtube),
      (icon: Icons.shopping_bag_rounded, name: 'Amazon Music', value: _amazon),
    ];

    return _BlackCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle(Icons.pie_chart_rounded, 'Earnings by Platform'),
        const SizedBox(height: 18),
        ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _blk2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _blkBorder),
                ),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _page,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _blkBorderH),
                    ),
                    child: Icon(r.icon, color: _text2, size: 15),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 100,
                    child: Text(r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _body(13, FontWeight.w700, color: _text1)),
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _reveal,
                      builder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          height: 5, color: _page,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (r.value / total) * _reveal.value,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFCFCFCF), _wht]),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    child: Text('${pct(r.value)}%',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _head(13, FontWeight.w800, color: _text1)),
                  ),
                ]),
              ),
            )),
      ]),
    );
  }

  Widget _cardTitle(IconData icon, String label) => Row(children: [
        Icon(icon, color: _wht, size: 15),
        const SizedBox(width: 8),
        Text(label, style: _head(15, FontWeight.w800, letterSpacing: -0.3)),
      ]);

  Widget _popup() {
    return GestureDetector(
      onTap: () => setState(() => _showPopup = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.82),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: AnimatedScale(
              scale: 1, duration: const Duration(milliseconds: 260), curve: _ease,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 26),
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                decoration: BoxDecoration(
                  color: _wht,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 60)],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0x0F000000),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: _ink1, size: 22),
                  ),
                  const SizedBox(height: 16),
                  Text('Minimum Not Reached', style: _head(18, FontWeight.w800, color: _ink1)),
                  const SizedBox(height: 8),
                  Text('Your balance is below the minimum withdrawal threshold.',
                      textAlign: TextAlign.center,
                      style: _body(13, FontWeight.w500, color: _ink2, height: 1.5)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x0A000000),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      children: [
                        const Icon(Icons.attach_money_rounded, color: _ink1, size: 15),
                        Text('Your balance must reach', style: _body(12.5, FontWeight.w500, color: _ink2)),
                        Text(_formatSelected(_minWithdrawal),
                            style: _head(15, FontWeight.w800, color: _ink1)),
                        Text('to withdraw', style: _body(12.5, FontWeight.w500, color: _ink2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => setState(() => _showPopup = false),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: _ink1, borderRadius: BorderRadius.circular(11)),
                      child: Text('Got it',
                          textAlign: TextAlign.center,
                          style: _body(14, FontWeight.w700, color: _wht)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarButton extends StatefulWidget {
  final String? photoURL;
  final String? uid;
  final ValueChanged<String> onUpdated;
  const _AvatarButton({required this.photoURL, required this.uid, required this.onUpdated});
  @override
  State<_AvatarButton> createState() => _AvatarButtonState();
}

class _AvatarButtonState extends State<_AvatarButton> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: _blk2,
        shape: BoxShape.circle,
        border: Border.all(color: _blkBorderH),
        image: widget.photoURL != null
            ? DecorationImage(image: CachedNetworkImageProvider(widget.photoURL!), fit: BoxFit.cover)
            : null,
      ),
      child: widget.photoURL == null
          ? const Icon(Icons.person_rounded, color: _text2, size: 18)
          : null,
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  final IconData icon;
  final String value, suffix, label;
  final String? badge;
  const _HeroStatCard({required this.icon, required this.value, this.suffix = '', required this.label, this.badge});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 20, 16, 18),
        decoration: BoxDecoration(
          color: _blk,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _blkBorderH),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 40, offset: const Offset(0, 16))],
        ),
        child: Stack(children: [
          if (badge != null)
            Positioned(
              top: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(99)),
                child: Text(badge!, style: _body(10, FontWeight.w700, color: _wht)),
              ),
            ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: _wht, size: 16),
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                maxLines: 1,
                text: TextSpan(children: [
                  TextSpan(text: value, style: _head(24, FontWeight.w900, letterSpacing: -1)),
                  if (suffix.isNotEmpty)
                    TextSpan(text: ' $suffix', style: _body(11, FontWeight.w600, color: _text2)),
                ]),
              ),
            ),
            const SizedBox(height: 5),
            Text(label.toUpperCase(),
                style: _body(9.5, FontWeight.w700, color: const Color(0x8CFFFFFF)).copyWith(letterSpacing: 0.7)),
          ]),
        ]),
      );
}

class _PlainStatCard extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _PlainStatCard({required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 14, 16),
        decoration: BoxDecoration(
          color: _wht,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _inkBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: const Color(0x0F000000), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: _ink1, size: 15),
          ),
          const SizedBox(height: 13),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                style: _head(18, FontWeight.w900, color: _ink1, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 4),
          Text(label.toUpperCase(),
              style: _body(9, FontWeight.w700, color: _ink2).copyWith(letterSpacing: 0.6)),
        ]),
      );
}

class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _wht,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _inkBorder),
        ),
        child: child,
      );
}

class _BlackCard extends StatelessWidget {
  final Widget child;
  const _BlackCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _blk,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _blkBorder),
        ),
        child: child,
      );
}