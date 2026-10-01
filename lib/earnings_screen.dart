// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Earnings Screen
//  Route: /earnings
//  Firebase:
//    users/{uid}        → earnings (available balance)
//    submissions/{id}   → userId, status, releaseTitle, coverURL,
//                         earningsBalance, lastPayoutAt,
//                         splitLocked, royaltySplits (collaborators only)
//
//  Songs list: approved songs only. First view shows 4 (biggest earners
//  first, filled with approved songs if fewer than 4 have earned).
//  "See more" loads songs 5–10 (earning songs only). Past 10 it pages
//  by 10 and shows a search bar.
//
//  Fast path needs these Firestore indexes on `submissions`:
//    1. userId ↑, status ↑, earningsBalance ↓
//    2. userId ↑, releaseTitle ↑
//    3. userId ↑, lastPayoutAt ↓
//  If an index is missing the screen falls back to reading the user's own
//  releases once and sorting / paging / searching on the device.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
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

// Keep in sync with CURRENCY_RATES in the web earnings page.
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

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

double _num(dynamic v) => v == null ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
double _r2(double x) => (x * 100).round() / 100;
String _pctText(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
bool _isApproved(Map<String, dynamic> s) =>
    (s['status'] ?? '').toString().trim().toLowerCase() == 'approved';

// ─── DATA MODELS ───────────────────────────────────────────────────
class _Song {
  final String id;
  final String title;
  final String cover;
  final double earned;
  final double? share;      // owner share, only when a locked split exists
  final DateTime? paidAt;
  const _Song({
    required this.id,
    required this.title,
    required this.cover,
    required this.earned,
    required this.share,
    required this.paidAt,
  });
}

class _Page {
  final List<_Song> rows;
  final Object? cursor;     // DocumentSnapshot on the fast path, int offset in fallback mode
  final bool more;
  const _Page({required this.rows, required this.cursor, required this.more});
}

class _Compact {
  final List<_Song> rows;
  final List<_Song> earnerRows;
  final Object? cursor;
  final bool more;
  const _Compact({
    this.rows = const [],
    this.earnerRows = const [],
    this.cursor,
    this.more = false,
  });
}

class _LastPayout {
  final DateTime date;
  final String title;
  const _LastPayout(this.date, this.title);
}

enum _Mode { compact, paged, search }

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  static const double _minWithdrawal = 50.0;
  static const int _compactCount = 4;
  static const int _pageSize = 10;
  static const List<String> _approvedValues = ['Approved', 'approved'];

  final _db = FirebaseFirestore.instance;
  String? _uid;

  double _balance = 0;
  bool _loading = true;
  bool _showPopup = false;
  String _selectedCurrency = 'USD';

  // songs
  bool _songsLoading = true;
  String _songsError = '';
  bool _busy = false;
  _Mode _mode = _Mode.compact;
  _Compact _compact = const _Compact();
  List<_Page> _pages = [];
  int _pg = 0;
  List<_Song> _results = [];
  bool _searchEnabled = false;
  final _searchCtrl = TextEditingController();

  // stat cards
  int? _statEarning;
  int? _statTotal;
  bool _payoutLoaded = false;
  _LastPayout? _lastPayout;

  // fallback mode (used when an indexed query fails)
  bool _useMem = false;
  bool _searchMem = false;
  List<_Song>? _memRows;

  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── QUERIES ─────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _subs => _db.collection('submissions');

  Query<Map<String, dynamic>> _approvedQ() =>
      _subs.where('userId', isEqualTo: _uid).where('status', whereIn: _approvedValues);

  _Song _toSong(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final s = d.data();
    // Owner share is only shown when a locked split exists.
    // royaltySplits holds collaborators only, so owner = 100 - collaborators.
    final collabs = (s['splitLocked'] == true && s['royaltySplits'] is List)
        ? (s['royaltySplits'] as List)
        : const [];
    double cp = 0;
    for (final c in collabs) {
      if (c is Map) cp += _num(c['pct']);
    }
    final share = cp > 0 ? _r2((100 - cp).clamp(0, 100).toDouble()) : null;
    final ts = s['lastPayoutAt'];
    return _Song(
      id: d.id,
      title: (s['releaseTitle'] ?? 'Untitled').toString(),
      cover: (s['coverURL'] ?? s['officialCoverURL'] ?? '').toString(),
      earned: _num(s['earningsBalance']),
      share: share,
      paidAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  /// All approved songs of this user, biggest earners first (fallback mode only).
  Future<List<_Song>> _ensureMem() async {
    if (_memRows != null) return _memRows!;
    final sn = await _subs.where('userId', isEqualTo: _uid).get();
    final rows = <_Song>[];
    for (final d in sn.docs) {
      if (_isApproved(d.data())) rows.add(_toSong(d));
    }
    rows.sort((a, b) => b.earned.compareTo(a.earned));
    _memRows = rows;
    return rows;
  }

  /// One page of approved songs that have earned something, biggest first.
  Future<_Page> _earnersPage(Object? after, int n) async {
    if (_useMem) {
      final earners = (await _ensureMem()).where((r) => r.earned > 0).toList();
      final start = after is int ? after : 0;
      final shown = earners.skip(start).take(n).toList();
      return _Page(rows: shown, cursor: start + shown.length, more: earners.length > start + n);
    }
    var q = _approvedQ()
        .where('earningsBalance', isGreaterThan: 0)
        .orderBy('earningsBalance', descending: true);
    if (after is DocumentSnapshot) q = q.startAfterDocument(after);
    final docs = (await q.limit(n + 1).get()).docs;
    final shown = docs.take(n).toList();
    return _Page(
      rows: shown.map(_toSong).toList(),
      cursor: shown.isNotEmpty ? shown.last : null,
      more: docs.length > n,
    );
  }

  Future<_Compact> _fetchFirst() async {
    final r = await _earnersPage(null, _compactCount);
    final rows = [...r.rows];
    // Fewer than 4 earning songs: fill the first view with approved songs so it's never empty.
    if (!r.more && rows.length < _compactCount) {
      final have = rows.map((x) => x.id).toSet();
      final List<_Song> extra;
      if (_useMem) {
        extra = (await _ensureMem()).where((x) => !have.contains(x.id)).toList();
      } else {
        final sn = await _approvedQ().limit(_compactCount).get();
        extra = sn.docs.map(_toSong).where((x) => !have.contains(x.id)).toList();
      }
      for (final x in extra) {
        if (rows.length < _compactCount) rows.add(x);
      }
    }
    return _Compact(rows: rows, earnerRows: r.rows, cursor: r.cursor, more: r.more);
  }

  // ─── LOAD ────────────────────────────────────────────────────────
  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    _uid = user.uid;
    try {
      final snap = await _db.collection('users').doc(user.uid).get();
      final d = snap.exists ? snap.data()! : <String, dynamic>{};
      if (mounted) {
        setState(() {
          _balance = _num(d['earnings']);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
    _ctrl.forward();
    await _loadSongs();
    _loadStats();
  }

  Future<void> _loadSongs() async {
    if (mounted) setState(() { _songsLoading = true; _songsError = ''; });
    try {
      try {
        _compact = await _fetchFirst();
      } catch (e) {
        debugPrint('Indexed songs query failed, using fallback. Create the index from the link in this error: $e');
        _useMem = true;
        _compact = await _fetchFirst();
      }
    } catch (e) {
      debugPrint('Songs load failed: $e');
      _songsError = "Couldn't load your songs. Please try again.";
    }
    if (mounted) setState(() => _songsLoading = false);
  }

  Future<void> _loadStats() async {
    var done = false;
    if (!_useMem) {
      try {
        final total = await _approvedQ().count().get();
        final earning = await _approvedQ().where('earningsBalance', isGreaterThan: 0).count().get();
        final last = await _subs
            .where('userId', isEqualTo: _uid)
            .orderBy('lastPayoutAt', descending: true)
            .limit(1)
            .get();
        _statTotal = total.count ?? 0;
        _statEarning = earning.count ?? 0;
        _lastPayout = null;
        if (last.docs.isNotEmpty) {
          final data = last.docs.first.data();
          final ts = data['lastPayoutAt'];
          if (ts is Timestamp) {
            _lastPayout = _LastPayout(ts.toDate(), (data['releaseTitle'] ?? 'Untitled').toString());
          }
        }
        done = true;
      } catch (e) {
        debugPrint('Stat query failed, using fallback: $e');
      }
    }
    if (!done) {
      try {
        final rows = await _ensureMem();
        _statTotal = rows.length;
        _statEarning = rows.where((r) => r.earned > 0).length;
        final paid = rows.where((r) => r.paidAt != null).toList()
          ..sort((a, b) => b.paidAt!.compareTo(a.paidAt!));
        _lastPayout = paid.isNotEmpty ? _LastPayout(paid.first.paidAt!, paid.first.title) : null;
      } catch (e) {
        debugPrint('Stats failed: $e');
      }
    }
    if (mounted) setState(() => _payoutLoaded = true);
  }

  // ─── ACTIONS ─────────────────────────────────────────────────────
  Future<void> _seeMore() async {
    if (_busy || !_compact.more) return;
    setState(() => _busy = true);
    try {
      // songs 5–10 (only songs that have earned)
      final r = await _earnersPage(_compact.cursor, _pageSize - _compact.earnerRows.length);
      _pages = [
        _Page(
          rows: [..._compact.earnerRows, ...r.rows],
          cursor: r.cursor ?? _compact.cursor,
          more: r.more,
        )
      ];
      _pg = 0;
      _mode = _Mode.paged;
      _searchEnabled = r.more;
    } catch (e) {
      debugPrint('See more failed: $e');
      _songsError = "Couldn't load more songs. Please try again.";
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _goPage(int i) async {
    if (_busy || i < 0) return;
    if (i < _pages.length) {
      setState(() => _pg = i);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await _earnersPage(_pages[i - 1].cursor, _pageSize);
      if (r.rows.isNotEmpty) {
        _pages.add(_Page(rows: r.rows, cursor: r.cursor, more: r.more));
        _pg = i;
      } else {
        _pages[i - 1] = _Page(rows: _pages[i - 1].rows, cursor: _pages[i - 1].cursor, more: false);
      }
    } catch (e) {
      debugPrint('Page load failed: $e');
      _songsError = "Couldn't load that page. Please try again.";
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Search by title across the user's own approved songs (earned or not).
  Future<void> _runSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _mode = _Mode.paged);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      List<_Song>? list;
      if (!_useMem && !_searchMem) {
        try {
          final variants = <String>{
            q,
            q.toLowerCase(),
            q.toUpperCase(),
            q.replaceAllMapped(RegExp(r'\b\w'), (m) => m[0]!.toUpperCase()),
          };
          final snaps = await Future.wait(variants.map((v) => _subs
              .where('userId', isEqualTo: _uid)
              .where('releaseTitle', isGreaterThanOrEqualTo: v)
              .where('releaseTitle', isLessThanOrEqualTo: '$v\uf8ff')
              .limit(10)
              .get()));
          final found = <String, _Song>{};
          for (final sn in snaps) {
            for (final d in sn.docs) {
              if (_isApproved(d.data())) found[d.id] = _toSong(d);
            }
          }
          list = found.values.toList();
        } catch (e) {
          debugPrint('Indexed search failed, using fallback. Create the index from the link in this error: $e');
          _searchMem = true;
        }
      }
      if (list == null) {
        final ql = q.toLowerCase();
        list = (await _ensureMem()).where((r) => r.title.toLowerCase().contains(ql)).toList();
      }
      list.sort((a, b) => b.earned.compareTo(a.earned));
      _results = list;
      _mode = _Mode.search;
    } catch (e) {
      debugPrint('Search failed: $e');
      _songsError = 'Search failed. Please try again.';
    }
    if (mounted) setState(() => _busy = false);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _mode = _Mode.paged);
  }

  void _showLess() {
    _searchCtrl.clear();
    setState(() => _mode = _Mode.compact);
  }

  void _handleWithdraw() {
    if (_balance < _minWithdrawal) {
      setState(() => _showPopup = true);
    } else {
      Navigator.pushNamed(context, '/withdrawal');
    }
  }

  // ─── FORMATTING ──────────────────────────────────────────────────
  _CurrencyInfo get _cur => _currencyRates[_selectedCurrency] ?? _currencyRates['USD']!;
  String _fmt(double usd, {int? decimals}) {
    final v = usd * _cur.rate;
    final d = decimals ?? (_selectedCurrency == 'XOF' ? 0 : 2);
    final parts = v.toStringAsFixed(d).split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return '${_cur.symbol}$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
  }

  // ─── BUILD ───────────────────────────────────────────────────────
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
        SizedBox(height: top + 16),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), child: _heroCard()),
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: _statsRow()),
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _withdrawCard()),
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _songsCard()),
        SizedBox(height: bottom + 40),
      ]),
    );
  }

  // ── BALANCE CARD — currency select sits inside ──
  Widget _heroCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: _black2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _white10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _white10, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.account_balance_wallet_rounded, color: _white, size: 17),
            ),
            const Spacer(),
            _currencyPill(),
          ]),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_fmt(_balance), maxLines: 1, style: _head(30, FontWeight.w900, ls: -1)),
          ),
          const SizedBox(height: 6),
          Text('AVAILABLE BALANCE', style: _body(10, FontWeight.w700).copyWith(letterSpacing: 0.8)),
          if (_selectedCurrency != 'USD')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Approximate. Paid out in USD.', style: _body(11, FontWeight.w500)),
            ),
        ]),
      );

  Widget _currencyPill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: _white10, borderRadius: BorderRadius.circular(99), border: Border.all(color: _white20)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedCurrency,
            dropdownColor: _black3,
            isDense: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _grey, size: 16),
            style: _body(13, FontWeight.w700, c: _white),
            items: _currencyRates.keys
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) { if (v != null) setState(() => _selectedCurrency = v); },
          ),
        ),
      );

  // ── LAST PAYOUT / SONGS EARNING — white cards ──
  Widget _statsRow() {
    final lp = _lastPayout;
    final payoutValue = lp != null ? _date(lp.date) : '—';
    final payoutSub = lp != null ? lp.title : (_payoutLoaded ? 'No payouts yet' : '');
    final earningValue = _statEarning?.toString() ?? '—';
    final earningSub = _statTotal != null ? 'of $_statTotal approved' : '';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _plainWhiteCard(Icons.history_rounded, payoutValue, 'LAST PAYOUT', payoutSub)),
      const SizedBox(width: 12),
      Expanded(child: _plainWhiteCard(Icons.music_note_rounded, earningValue, 'SONGS EARNING', earningSub)),
    ]);
  }

  Widget _plainWhiteCard(IconData icon, String value, String label, String sub) => Container(
        width: double.infinity,
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
          if (sub.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: _body(11, FontWeight.w500, c: _ink2)),
            ),
        ]),
      );

  // ── WITHDRAW CARD ──
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
          'Minimum withdrawal is ${_fmt(_minWithdrawal)}.',
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

  // ── EARNINGS BY SONG ──
  Widget _songsCard() {
    final List<_Song> rows;
    switch (_mode) {
      case _Mode.compact:
        rows = _compact.rows;
        break;
      case _Mode.paged:
        rows = _pg < _pages.length ? _pages[_pg].rows : const [];
        break;
      case _Mode.search:
        rows = _results;
        break;
    }

    Widget body;
    if (_songsLoading) {
      body = Column(children: List.generate(_compactCount, (_) => _skeletonRow()));
    } else if (_songsError.isNotEmpty) {
      body = _emptyText(_songsError);
    } else if (rows.isEmpty) {
      body = _emptyText(_mode == _Mode.search ? 'No songs found.' : 'No approved songs yet.');
    } else {
      body = Column(children: rows.map(_songRow).toList());
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _black2, borderRadius: BorderRadius.circular(18), border: Border.all(color: _white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.album_rounded, color: _white, size: 15),
          const SizedBox(width: 8),
          Text('Earnings by song', style: _head(15, FontWeight.w800, ls: -0.3)),
        ]),
        if (_searchEnabled) ...[
          const SizedBox(height: 14),
          _searchField(),
        ],
        const SizedBox(height: 16),
        body,
        if (!_songsLoading && _songsError.isEmpty) _songsFooter(),
      ]),
    );
  }

  Widget _searchField() => TextField(
        controller: _searchCtrl,
        enabled: !_busy,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _runSearch(),
        onChanged: (v) {
          if (v.isEmpty && _mode == _Mode.search) setState(() => _mode = _Mode.paged);
        },
        style: _body(13, FontWeight.w600, c: _white),
        cursorColor: _white,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search a song',
          hintStyle: _body(13, FontWeight.w500),
          filled: true,
          fillColor: _black3,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: _white10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: _white20)),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: _white10)),
        ),
      );

  Widget _emptyText(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Text(t, textAlign: TextAlign.center, style: _body(13, FontWeight.w500))),
      );

  Widget _skeletonRow() => Container(
        height: 70,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(12)),
      );

  Widget _songRow(_Song s) {
    final meta = <String>[];
    if (s.share != null) meta.add('Your share ${_pctText(s.share!)}%');
    if (s.earned > 0 && s.paidAt != null) meta.add('Updated ${_date(s.paidAt!)}');
    final fallbackCover = Container(
      color: _black,
      child: const Icon(Icons.music_note_rounded, color: _grey, size: 16),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _black3, borderRadius: BorderRadius.circular(12), border: Border.all(color: _white10)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 44, height: 44,
            child: s.cover.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: s.cover,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => fallbackCover,
                    errorWidget: (_, __, ___) => fallbackCover,
                  )
                : fallbackCover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: _body(13.5, FontWeight.w700, c: _white)),
            if (meta.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(meta.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: _body(11, FontWeight.w500)),
              ),
          ]),
        ),
        const SizedBox(width: 10),
        Text(_fmt(s.earned),
            style: s.earned > 0 ? _head(15, FontWeight.w800) : _head(15, FontWeight.w600, c: _grey)),
      ]),
    );
  }

  Widget _pillButton(String label, VoidCallback? onTap, {bool small = false}) => GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: small ? 14 : 22, vertical: small ? 8 : 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99), border: Border.all(color: _white20)),
            child: Text(label, style: _body(small ? 12 : 13, FontWeight.w700, c: _white)),
          ),
        ),
      );

  Widget _linkButton(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(label, style: _body(12.5, FontWeight.w600)),
        ),
      );

  Widget _songsFooter() {
    switch (_mode) {
      case _Mode.compact:
        if (!_compact.more) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Center(child: _pillButton(_busy ? 'Loading…' : 'See more', _busy ? null : _seeMore)),
        );
      case _Mode.search:
        return Center(child: _linkButton('Clear search', _clearSearch));
      case _Mode.paged:
        if (_pg >= _pages.length) return const SizedBox.shrink();
        final p = _pages[_pg];
        final paged = _pages.length > 1 || p.more;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _linkButton('Show less', _showLess),
            if (paged)
              Row(children: [
                _pillButton('‹ Prev', (_pg == 0 || _busy) ? null : () => _goPage(_pg - 1), small: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Page ${_pg + 1}', style: _body(12, FontWeight.w600)),
                ),
                _pillButton('Next ›', (!p.more || _busy) ? null : () => _goPage(_pg + 1), small: true),
              ]),
          ]),
        );
    }
  }

  // ── POPUP ──
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
                  Text('Your balance must reach ${_fmt(_minWithdrawal)} to withdraw.',
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
