// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Analytics Screen (full rebuild using the exact same
//  proven-stable pattern as the working earnings_screen.dart: flat
//  Container cards, no BoxShadow, no CustomPaint/canvas repainting,
//  no AnimatedBuilder-driven redraws, simple one-shot fade entrance.
//  The line chart is replaced with a simple bar chart built from
//  plain Containers — same technique as Earnings' platform bars —
//  so there is no repaint-per-frame surface left anywhere on screen.
//  Route: /analytics
//  Firebase: analytics/{uid} + submissions where userId==uid
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── PALETTE (same as earnings_screen.dart) ──────────────────────
const _black    = Color(0xFF000000);
const _black2   = Color(0xFF111111);
const _black3   = Color(0xFF1A1A1A);
const _white    = Color(0xFFFFFFFF);
const _white10  = Color(0x1AFFFFFF);
const _white20  = Color(0x33FFFFFF);
const _grey     = Color(0xFF8A8A8A);
const _greyDark = Color(0xFF444444);
const _ink1     = Color(0xFF0D0D0D);
const _ink2     = Color(0xFF6E6E6E);
const _inkBorder= Color(0x14000000);

TextStyle _head(double s, FontWeight w, {Color c = _white, double? ls}) =>
    GoogleFonts.nunito(fontSize: s, fontWeight: w, color: c, letterSpacing: ls);
TextStyle _body(double s, FontWeight w, {Color c = _grey, double? h}) =>
    GoogleFonts.nunito(fontSize: s, fontWeight: w, color: c, height: h);

enum _Period { d7, d30, all }

class _Release {
  final String title, type, genre, status;
  final String? coverURL;
  const _Release({required this.title, this.type = 'Single', this.genre = '—', this.status = 'Pending', this.coverURL});
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  int _totalStreams = 0, _spotify = 0, _apple = 0, _youtube = 0;
  List<_Release> _releases = [];
  bool _loading = true;
  _Period _period = _Period.d7;

  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  static const _w7   = [0.05, 0.08, 0.11, 0.14, 0.18, 0.20, 0.24];
  static const _w30  = [0.15, 0.22, 0.28, 0.35];
  static const _wAll = [0.06, 0.09, 0.11, 0.13, 0.16, 0.19, 0.26];
  static const _labels7   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  static const _labels30  = ['W1','W2','W3','W4'];
  static const _labelsAll = ['Jan','Feb','Mar','Apr','May','Jun','Jul'];

  List<double> _scale(List<double> weights, double total) {
    final sum = weights.fold(0.0, (a, b) => a + b);
    double running = 0;
    return weights.map((w) => running += (w / sum) * total).toList();
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));
    // Same lightweight one-shot fade as earnings_screen.dart — no
    // repeating/continuous animation driving any repaint.
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
      final aSnap = await FirebaseFirestore.instance.collection('analytics').doc(user.uid).get();
      final sSnap = await FirebaseFirestore.instance
          .collection('submissions').where('userId', isEqualTo: user.uid).get();

      final aData = aSnap.exists ? aSnap.data()! : <String, dynamic>{};
      int int_(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);

      final releases = sSnap.docs.map((d) {
        final r = d.data();
        return _Release(
          title: r['releaseTitle'] ?? 'Untitled Release',
          type: r['releaseType'] ?? 'Single',
          genre: r['genre'] ?? '—',
          status: r['status'] ?? 'Pending',
          coverURL: r['coverURL'],
        );
      }).toList();

      if (mounted) {
        setState(() {
          _totalStreams = int_(aData['totalStreams']);
          _spotify = int_(aData['spotifyStreams']);
          _apple = int_(aData['appleStreams']);
          _youtube = int_(aData['youtubeStreams']);
          _releases = releases;
          _loading = false;
        });
        _ctrl.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _ctrl.forward();
    }
  }

  String _fmt(num n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _white, strokeWidth: 2))
          : FadeTransition(opacity: _fade, child: _buildBody()),
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
        Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 0), child: _header()),
        Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), child: _statRow()),
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _chartCard()),
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _sourceCard()),
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _topReleasesCard()),
        SizedBox(height: bottom + 40),
      ]),
    );
  }

  Widget _topBar() => Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _white10))),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: _black2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _white10)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _white, size: 16),
            ),
          ),
        ]),
      );

  Widget _header() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Artist Insights', style: _head(24, FontWeight.w900)),
        const SizedBox(height: 6),
        Text('All-time performance across every release and store.', style: _body(13, FontWeight.w500)),
      ]);

  // ── STATS — same flat pattern as Earnings' hero/plain cards ──
  Widget _statRow() => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          flex: 13,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 16, 18),
            decoration: BoxDecoration(
              color: _black2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _white20),
            ),
            child: Stack(children: [
              Positioned(
                top: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: _white10, borderRadius: BorderRadius.circular(99)),
                  child: Text('All-Time', style: _body(10, FontWeight.w700, c: _white)),
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: _white10, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.headphones_rounded, color: _white, size: 16),
                ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                  child: Text(_fmt(_totalStreams), maxLines: 1, style: _head(24, FontWeight.w900, ls: -1)),
                ),
                const SizedBox(height: 5),
                Text('TOTAL STREAMS', style: _body(9.5, FontWeight.w700).copyWith(letterSpacing: 0.7)),
              ]),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(flex: 10, child: _plainStat(Icons.music_note_rounded, _releases.length.toString(), 'Total Releases')),
        const SizedBox(width: 12),
        Expanded(flex: 10, child: _plainStat(Icons.public_rounded, '50+', 'Stores Distributed')),
      ]);

  Widget _plainStat(IconData icon, String value, String label) => Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 14, 16),
        decoration: BoxDecoration(
          color: _white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _inkBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: const Color(0x0D000000), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: _ink1, size: 15),
          ),
          const SizedBox(height: 13),
          FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: _head(18, FontWeight.w900, c: _ink1, ls: -0.5)),
          ),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: _body(9, FontWeight.w700, c: _ink2).copyWith(letterSpacing: 0.6)),
        ]),
      );

  // ── CHART — plain bar chart, built the same way as Earnings'
  // progress bars (Container + FractionallySizedBox). No CustomPaint,
  // no canvas, no per-frame repaint of any kind. ──
  Widget _chartCard() {
    late List<double> values;
    late List<String> labels;
    switch (_period) {
      case _Period.d7: values = _scale(_w7, _totalStreams.toDouble()); labels = _labels7; break;
      case _Period.d30: values = _scale(_w30, _totalStreams.toDouble()); labels = _labels30; break;
      case _Period.all: values = _scale(_wAll, _totalStreams.toDouble()); labels = _labelsAll; break;
    }
    final maxVal = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Streaming Growth', style: _head(15, FontWeight.w800, ls: -0.3)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _tab('7D', _period == _Period.d7, () => setState(() => _period = _Period.d7)),
              _tab('30D', _period == _Period.d30, () => setState(() => _period = _Period.d30)),
              _tab('All', _period == _Period.all, () => setState(() => _period = _Period.all)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(values.length, (i) {
              final frac = (values[i] / maxVal).clamp(0.02, 1.0);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: frac,
                            widthFactor: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(labels[i], style: _body(9, FontWeight.w600, c: _greyDark)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: active ? _black2 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label, style: _body(10.5, FontWeight.w700, c: active ? _white : _greyDark).copyWith(letterSpacing: 0.6)),
        ),
      );

  // ── SOURCE OF STREAMS — identical pattern to Earnings' platform card ──
  Widget _sourceCard() {
    final total = (_spotify + _apple + _youtube).clamp(1, 1 << 30);
    int pct(int v) => (v / total * 100).round();
    final rows = [
      (icon: Icons.music_note_rounded, name: 'Spotify', value: _spotify),
      (icon: Icons.apple_rounded, name: 'Apple Music', value: _apple),
      (icon: Icons.play_circle_fill_rounded, name: 'YouTube', value: _youtube),
    ];
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Source of Streams', style: _head(15, FontWeight.w800, ls: -0.3)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _white10, borderRadius: BorderRadius.circular(99)),
            child: Text('ALL-TIME', style: _body(9.5, FontWeight.w700, c: _white).copyWith(letterSpacing: 0.6)),
          ),
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
                    child: Icon(r.icon, color: _white, size: 15),
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
                          alignment: Alignment.centerLeft, widthFactor: r.value / total,
                          child: Container(color: _white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 40, child: Text('${pct(r.value)}%', textAlign: TextAlign.right,
                      style: _head(13, FontWeight.w800))),
                ]),
              ),
            )),
      ]),
    );
  }

  // ── TOP RELEASES ──
  Widget _topReleasesCard() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Top Releases', style: _head(15, FontWeight.w800, ls: -0.3)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _white10, borderRadius: BorderRadius.circular(99)),
              child: Text('LIBRARY', style: _body(9.5, FontWeight.w700, c: _white).copyWith(letterSpacing: 0.6)),
            ),
          ]),
          const SizedBox(height: 16),
          if (_releases.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(children: [
                const Icon(Icons.album_rounded, color: _white, size: 34),
                const SizedBox(height: 12),
                Text('Your releases will appear here once submitted.',
                    textAlign: TextAlign.center, style: _body(12.5, FontWeight.w600, c: _greyDark)),
              ]),
            )
          else
            ...List.generate(_releases.length, (i) {
              final r = _releases[i];
              final approved = r.status.toLowerCase() == 'approved';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                      color: _black3, borderRadius: BorderRadius.circular(12), border: Border.all(color: _white10)),
                  child: Row(children: [
                    Text((i + 1).toString().padLeft(2, '0'), style: _body(10.5, FontWeight.w700, c: _greyDark)),
                    const SizedBox(width: 12),
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(8)),
                      clipBehavior: Clip.antiAlias,
                      child: r.coverURL != null
                          ? CachedNetworkImage(imageUrl: r.coverURL!, fit: BoxFit.cover)
                          : const Icon(Icons.album_rounded, color: Colors.black, size: 17),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: _body(13.5, FontWeight.w700, c: _white)),
                        const SizedBox(height: 3),
                        Text('${r.type} · ${r.genre}', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: _body(11, FontWeight.w500, c: _greyDark)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                          color: approved ? _white10 : _black,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: _white10)),
                      child: Text(approved ? 'Approved' : r.status,
                          style: _body(10, FontWeight.w700, c: approved ? _white : _grey)),
                    ),
                  ]),
                ),
              );
            }),
        ]),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: _black2, borderRadius: BorderRadius.circular(18), border: Border.all(color: _white10)),
        child: child,
      );
}