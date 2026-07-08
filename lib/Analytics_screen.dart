// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Analytics Screen
//  Route  : /analytics
//  Nav    : Bottom Nav (index 1) + Sidebar "Analytics"
//  Font   : Nunito (Spotify-style rounded sans — matches app)
//  Theme  : Pure black & white
//  Charts : CustomPainter (no extra packages needed)
//  Firebase: analytics/{uid}  +  submissions where userId==uid
// ═══════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── PALETTE ────────────────────────────────────────────────────────
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
const _greyMid    = Color(0xFF666666);
const _greyDark   = Color(0xFF333333);

// accent colours (subdued — B&W palette)
const _green      = Color(0xFF22C55E);
const _greenDim   = Color(0x1A22C55E);
const _cyan       = Color(0xFF06B6D4);
const _cyanDim    = Color(0x1A06B6D4);
const _warn       = Color(0xFFF59E0B);
const _warnDim    = Color(0x1AF59E0B);
const _red        = Color(0xFFEF4444);
const _redDim     = Color(0x1AEF4444);

// platform brand colours (kept for identity only)
const _spotify    = Color(0xFF1DB954);
const _apple      = Color(0xFFFC3C44);
const _youtube    = Color(0xFFFF0000);
const _boomplay   = Color(0xFF00C853);

// ════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ════════════════════════════════════════════════════════════════════
class _AnalyticsData {
  final int    totalStreams;
  final int    totalReleases;
  final int    spotifyStreams;
  final int    appleStreams;
  final int    youtubeStreams;
  final int    boomplayStreams;
  final List<_Release> releases;

  const _AnalyticsData({
    this.totalStreams    = 0,
    this.totalReleases  = 0,
    this.spotifyStreams  = 0,
    this.appleStreams    = 0,
    this.youtubeStreams  = 0,
    this.boomplayStreams = 0,
    this.releases       = const [],
  });
}

class _Release {
  final String title, type, genre, date, status;
  const _Release({
    required this.title,
    this.type   = 'Single',
    this.genre  = '—',
    this.date   = '—',
    this.status = 'Pending',
  });
}

// chart period
enum _Period { d7, d30, all }

// ════════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════════
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {

  _AnalyticsData _data = const _AnalyticsData();
  bool           _loading = true;
  _Period        _period  = _Period.d7;

  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;
  late Animation<double>   _barAnim;   // drives bar/donut reveals

  // chart data sets
  static const _chartData = {
    _Period.d7:  [200.0, 500, 900, 1200, 1800, 2300, 3000],
    _Period.d30: [4200.0, 8900, 14200, 22000, 18000, 25000, 30000,
      28000, 32000, 40000, 38000, 44000, 50000, 55000,
      52000, 60000, 58000, 65000, 70000, 68000, 75000,
      72000, 80000, 78000, 85000, 90000, 88000, 92000,
      95000, 100000],
    _Period.all: [200.0, 500, 900, 1200, 1800, 2300, 3000,
      3500, 4200, 5000, 5800, 6500, 8000, 9500],
  };

  static const _periodLabels = {
    _Period.d7:  ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'],
    _Period.d30: ['W1','W2','W3','W4','W5','W6','W7',
      'W8','W9','W10','W11','W12','W13','W14',
      'W15','W16','W17','W18','W19','W20','W21',
      'W22','W23','W24','W25','W26','W27','W28',
      'W29','W30'],
    _Period.all: ['Jan','Feb','Mar','Apr','May','Jun','Jul',
      'Aug','Sep','Oct','Nov','Dec','Y2','Y3'],
  };

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _barAnim = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic));
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      // Analytics doc
      final aSnap = await FirebaseFirestore.instance
          .collection('analytics').doc(user.uid).get();
      final aData = aSnap.exists ? aSnap.data()! : <String, dynamic>{};

      // Submissions
      final sSnap = await FirebaseFirestore.instance
          .collection('submissions')
          .where('userId', isEqualTo: user.uid)
          .get();

      final releases = sSnap.docs.map((d) {
        final r = d.data();
        return _Release(
          title:  r['releaseTitle'] ?? 'Untitled Release',
          type:   r['releaseType']  ?? 'Single',
          genre:  r['genre']        ?? '—',
          date:   r['releaseDate']  ?? '—',
          status: r['status']       ?? 'Pending',
        );
      }).toList();

      if (mounted) {
        setState(() {
          _data = _AnalyticsData(
            totalStreams:    _int(aData['totalStreams']),
            totalReleases:   sSnap.size,
            spotifyStreams:  _int(aData['spotifyStreams']),
            appleStreams:    _int(aData['appleStreams']),
            youtubeStreams:  _int(aData['youtubeStreams']),
            boomplayStreams: _int(aData['boomplayStreams']),
            releases:        releases,
          );
          _loading = false;
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

  int _int(dynamic v) =>
      v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  // ── helpers ──
  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  // ── build ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      body: Stack(children: [
        if (_loading)
          const Center(child: CircularProgressIndicator(
              color: _white, strokeWidth: 2))
        else
          SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: _buildBody(),
            ),
          ),
      ]),
    );
  }

  Widget _buildBody() {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: top),
          _topBar(),
          _heroStrip(),

          // ── STAT CARDS
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _statGrid(),
          ),

          // ── STREAMING GROWTH CHART
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _streamChart(),
          ),

          // ── PLATFORM SPLIT (donut) + LEGEND
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _platformSplit(),
          ),

          // ── TOP COUNTRIES
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _topCountries(),
          ),

          // ── TOP STORES
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _topStores(),
          ),

          // ── PERFORMANCE METRICS
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _performanceMetrics(),
          ),

          // ── TOP RELEASES
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _topReleases(),
          ),

          // ── RECENT ACTIVITY
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _recentActivity(),
          ),

          SizedBox(height: bottom + 110),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ══════════════════════════════════════════════════════════════════
  Widget _topBar() {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: _black,
        border: Border(bottom: BorderSide(color: _white10)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: CachedNetworkImage(
            imageUrl: 'https://444music-distribution.vercel.app/black.png',
            height: 28, color: _white, colorBlendMode: BlendMode.srcIn,
            errorWidget: (_, __, ___) => Text('444Music',
                style: GoogleFonts.nunito(
                    color: _white, fontSize: 20, fontWeight: FontWeight.w800)),
          ),
        ),
        const Spacer(),
        // live badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _greenDim,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: _green.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _PulseDot(color: _green),
            const SizedBox(width: 5),
            Text('Live', style: GoogleFonts.nunito(
                color: _green, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _white06,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _white10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _white, size: 16),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  HERO STRIP
  // ══════════════════════════════════════════════════════════════════
  Widget _heroStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _white10))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // eyebrow pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _white10,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: _white20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _PulseDot(color: _white70),
            const SizedBox(width: 6),
            Text('444MUSIC · ANALYTICS SUITE',
                style: GoogleFonts.nunito(
                    color: _white70, fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ]),
        ),
        const SizedBox(height: 14),
        Text('Artist Insights',
            style: GoogleFonts.nunito(
                color: _white, fontSize: 30,
                fontWeight: FontWeight.w800, height: 1.05)),
        const SizedBox(height: 6),
        Text('Real-time performance data across all your releases and stores.',
            style: GoogleFonts.nunito(
                color: _grey, fontSize: 13,
                fontWeight: FontWeight.w500, height: 1.5)),
        const SizedBox(height: 4),
        Row(children: [
          _PulseDot(color: _green),
          const SizedBox(width: 6),
          Text('Live data · Auto-updating',
              style: GoogleFonts.nunito(
                  color: _green, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  STAT GRID  (4 cards)
  // ══════════════════════════════════════════════════════════════════
  Widget _statGrid() {
    final cards = [
      _StatInfo(icon: Icons.headphones_rounded,
          label: 'Total Streams',    value: _fmt(_data.totalStreams),
          badge: 'Live',  badgeColor: _green,  badgeDim: _greenDim),
      _StatInfo(icon: Icons.music_note_rounded,
          label: 'Total Releases',   value: _data.totalReleases.toString(),
          badge: 'Active',badgeColor: _white70, badgeDim: _white10),
      _StatInfo(icon: Icons.public_rounded,
          label: 'Stores Distributed',value: '50+',
          badge: 'Global',badgeColor: _cyan,   badgeDim: _cyanDim),
      _StatInfo(icon: Icons.flag_rounded,
          label: 'Top Markets',      value: '4',
          badge: 'Active',badgeColor: _warn,   badgeDim: _warnDim),
    ];
    return Column(children: [
      Row(children: [
        Expanded(child: _StatCard(info: cards[0])),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(info: cards[1])),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _StatCard(info: cards[2])),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(info: cards[3])),
      ]),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════
  //  STREAMING GROWTH CHART
  // ══════════════════════════════════════════════════════════════════
  Widget _streamChart() {
    final values = _chartData[_period]!.map((e) => e.toDouble()).toList();
    final labels = _periodLabels[_period]!;
    // show only first 7/8 labels for readability on mobile
    final showLabels = labels.length > 8
        ? List.generate(labels.length, (i) =>
    i % (labels.length ~/ 7) == 0 ? labels[i] : '')
        : labels;

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _CardTitle(icon: Icons.bar_chart_rounded, label: 'Streaming Growth'),
          const Spacer(),
          // period tabs
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _black3,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _PeriodTab(label: '7D',  active: _period == _Period.d7,
                  onTap: () => setState(() => _period = _Period.d7)),
              _PeriodTab(label: '30D', active: _period == _Period.d30,
                  onTap: () => setState(() => _period = _Period.d30)),
              _PeriodTab(label: 'All', active: _period == _Period.all,
                  onTap: () => setState(() => _period = _Period.all)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _barAnim,
          builder: (_, __) => _LineChart(
            values: values,
            labels: showLabels,
            progress: _barAnim.value,
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  PLATFORM SPLIT (donut + legend)
  // ══════════════════════════════════════════════════════════════════
  Widget _platformSplit() {
    final sp  = _data.spotifyStreams.toDouble();
    final ap  = _data.appleStreams.toDouble();
    final yt  = _data.youtubeStreams.toDouble();
    final bp  = _data.boomplayStreams.toDouble();
    final tot = (sp + ap + yt + bp).clamp(1.0, double.infinity);

    String pct(double v) => '${(v / tot * 100).round()}%';

    final segments = [
      _DonutSegment(label: 'Spotify',     value: sp,  color: _spotify,  pct: pct(sp)),
      _DonutSegment(label: 'Apple Music', value: ap,  color: _apple,    pct: pct(ap)),
      _DonutSegment(label: 'YouTube',     value: yt,  color: _youtube,  pct: pct(yt)),
      _DonutSegment(label: 'Others',      value: bp,  color: _white40,  pct: pct(bp)),
    ];

    // if all zero, show placeholder segments
    final displaySegs = tot == 1.0
        ? [
      _DonutSegment(label: 'Spotify',     value: 40, color: _spotify, pct: '—'),
      _DonutSegment(label: 'Apple Music', value: 25, color: _apple,   pct: '—'),
      _DonutSegment(label: 'YouTube',     value: 20, color: _youtube, pct: '—'),
      _DonutSegment(label: 'Others',      value: 15, color: _white40, pct: '—'),
    ]
        : segments;

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _CardTitle(icon: Icons.donut_large_rounded, label: 'Platform Split'),
          const Spacer(),
          _Tag(label: 'Stores'),
        ]),
        const SizedBox(height: 22),
        // donut + legend side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // donut
            SizedBox(
              width: 150, height: 150,
              child: AnimatedBuilder(
                animation: _barAnim,
                builder: (_, __) => CustomPaint(
                  painter: _DonutPainter(
                    segments: displaySegs,
                    progress: _barAnim.value,
                    centerLabel: '50+',
                    centerSub: 'Stores',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 22),
            // legend
            Expanded(
              child: Column(
                children: displaySegs.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Container(
                      width: 9, height: 9,
                      decoration: BoxDecoration(
                          color: s.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.label,
                          style: GoogleFonts.nunito(
                              color: _white70, fontSize: 12.5,
                              fontWeight: FontWeight.w500)),
                    ),
                    Text(s.pct,
                        style: GoogleFonts.nunito(
                            color: _white, fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ]),
                )).toList(),
              ),
            ),
          ],
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  TOP COUNTRIES
  // ══════════════════════════════════════════════════════════════════
  Widget _topCountries() {
    const countries = [
      ('🇺🇸', 'United States', 0.85),
      ('🇳🇬', 'Nigeria',       0.74),
      ('🇬🇧', 'United Kingdom',0.62),
      ('🇬🇭', 'Ghana',         0.58),
    ];
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _CardTitle(icon: Icons.public_rounded, label: 'Top Countries'),
          const Spacer(),
          _Tag(label: 'Audience', color: _green, dimColor: _greenDim),
        ]),
        const SizedBox(height: 16),
        ...countries.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: _black3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _white10),
            ),
            child: Row(children: [
              Text(c.$1, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(c.$2,
                    style: GoogleFonts.nunito(
                        color: _white, fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: AnimatedBuilder(
                  animation: _barAnim,
                  builder: (_, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      height: 4, color: _black4,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: c.$3 * _barAnim.value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_white40, _white]),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(c.$3 * 100).round()}%',
                  style: GoogleFonts.nunito(
                      color: _white70, fontSize: 11.5,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        )),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  TOP STORES
  // ══════════════════════════════════════════════════════════════════
  Widget _topStores() {
    final stores = [
      _StoreInfo(name: 'Spotify',     icon: Icons.music_note_rounded,
          color: _spotify,  count: _fmt(_data.spotifyStreams),  pct: 0.70),
      _StoreInfo(name: 'Apple Music', icon: Icons.apple_rounded,
          color: _apple,    count: _fmt(_data.appleStreams),    pct: 0.45),
      _StoreInfo(name: 'YouTube',     icon: Icons.play_circle_rounded,
          color: _youtube,  count: _fmt(_data.youtubeStreams),  pct: 0.30),
      _StoreInfo(name: 'Boomplay',    icon: Icons.headphones_rounded,
          color: _boomplay, count: _fmt(_data.boomplayStreams), pct: 0.20),
    ];
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _CardTitle(icon: Icons.storefront_rounded, label: 'Top Streaming Stores'),
          const Spacer(),
          _Tag(label: 'Platforms'),
        ]),
        const SizedBox(height: 16),
        ...stores.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(s.icon, color: s.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(s.name,
                        style: GoogleFonts.nunito(
                            color: _white, fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(s.count,
                        style: GoogleFonts.nunito(
                            color: _white, fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 6),
                  AnimatedBuilder(
                    animation: _barAnim,
                    builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        height: 3, color: _black3,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: s.pct * _barAnim.value,
                          child: Container(color: s.color),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        )),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  PERFORMANCE METRICS
  // ══════════════════════════════════════════════════════════════════
  Widget _performanceMetrics() {
    final releases = _data.totalReleases > 0 ? _data.totalReleases : 1;
    final avgDaily = (_data.totalStreams / (releases * 7)).round();

    final metrics = [
      _MetricInfo(label: 'Avg. Daily Streams',   value: avgDaily > 0 ? _fmt(avgDaily) : '—', sub: 'Per release',              pct: 0.60),
      _MetricInfo(label: 'Completion Rate',       value: '—',                                 sub: 'Listeners finishing track', pct: 0.75),
      _MetricInfo(label: 'Save Rate',             value: '—',                                 sub: 'Added to playlists',        pct: 0.40),
    ];

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _CardTitle(icon: Icons.speed_rounded, label: 'Performance Metrics'),
          const Spacer(),
          _Tag(label: 'Overview'),
        ]),
        const SizedBox(height: 16),
        ...metrics.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _black3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _white10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(m.label,
                    style: GoogleFonts.nunito(
                        color: _grey, fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
                const Spacer(),
                Text(m.value,
                    style: GoogleFonts.nunito(
                        color: _white, fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
              ]),
              const SizedBox(height: 4),
              Text(m.sub,
                  style: GoogleFonts.nunito(
                      color: _greyDark, fontSize: 11)),
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: _barAnim,
                builder: (_, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    height: 3, color: _black4,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: m.pct * _barAnim.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_white20, _white]),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        )),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  TOP RELEASES
  // ══════════════════════════════════════════════════════════════════
  Widget _topReleases() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _CardTitle(icon: Icons.library_music_rounded, label: 'Top Releases'),
          const Spacer(),
          _Tag(label: 'Library', color: _green, dimColor: _greenDim),
        ]),
        const SizedBox(height: 14),
        if (_data.releases.isEmpty)
          _emptyState(
            icon: Icons.album_rounded,
            text: 'Your releases will appear here once submitted.',
          )
        else
          ...List.generate(_data.releases.length, (i) {
            final r = _data.releases[i];
            final isLive = r.status.toLowerCase() == 'live';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _black3,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _white10),
                ),
                child: Row(children: [
                  // index
                  Text('${(i + 1).toString().padLeft(2, '0')}',
                      style: GoogleFonts.nunito(
                          color: _greyDark, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  // disc icon
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _white10,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.album_rounded,
                        color: _white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  // info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title,
                            style: GoogleFonts.nunito(
                                color: _white, fontSize: 13.5,
                                fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text('${r.type} · ${r.genre} · ${r.date}',
                            style: GoogleFonts.nunito(
                                color: _grey, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLive ? _greenDim : _warnDim,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: isLive
                              ? _green.withValues(alpha: 0.3)
                              : _warn.withValues(alpha: 0.3)),
                    ),
                    child: Text(r.status,
                        style: GoogleFonts.nunito(
                            color: isLive ? _green : _warn,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            );
          }),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  RECENT ACTIVITY
  // ══════════════════════════════════════════════════════════════════
  Widget _recentActivity() {
    const activities = [
      _Activity(
        dotColor: _green, iconColor: _green, iconBg: _greenDim,
        icon: Icons.check_circle_rounded,
        text: 'Spotify',
        sub: 'Your release is now live on the platform.',
        time: 'Just now',
      ),
      _Activity(
        dotColor: _white70, iconColor: _white70, iconBg: _white10,
        icon: Icons.trending_up_rounded,
        text: 'Analytics update',
        sub: 'Stream data refreshed across all stores.',
        time: '1h ago',
      ),
      _Activity(
        dotColor: _warn, iconColor: _warn, iconBg: _warnDim,
        icon: Icons.schedule_rounded,
        text: 'Apple Music',
        sub: 'Submission under review. Expected 2–5 days.',
        time: '3h ago',
      ),
      _Activity(
        dotColor: _cyan, iconColor: _cyan, iconBg: _cyanDim,
        icon: Icons.cloud_upload_rounded,
        text: 'New release',
        sub: 'Successfully distributed to 50+ stores.',
        time: 'Yesterday',
      ),
    ];

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _CardTitle(icon: Icons.bolt_rounded, label: 'Recent Activity'),
          const Spacer(),
          _Tag(label: 'Feed'),
        ]),
        const SizedBox(height: 12),
        ...activities.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: _black3,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                    color: a.dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                    color: a.iconBg,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(a.icon, color: a.iconColor, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.nunito(
                        color: _grey, fontSize: 12.5, height: 1.4),
                    children: [
                      TextSpan(text: a.text,
                          style: GoogleFonts.nunito(
                              color: _white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5)),
                      TextSpan(text: ' — ${a.sub}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(a.time,
                  style: GoogleFonts.nunito(
                      color: _greyDark, fontSize: 10.5)),
            ]),
          ),
        )),
      ]),
    );
  }

  // ─── empty state ──────────────────────────────────────────────────
  Widget _emptyState({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(children: [
        Icon(icon, color: _greyDark, size: 40),
        const SizedBox(height: 12),
        Text(text,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
                color: _greyDark, fontSize: 13,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  DATA CLASSES
// ════════════════════════════════════════════════════════════════════
class _StatInfo {
  final IconData icon;
  final String label, value, badge;
  final Color badgeColor, badgeDim;
  const _StatInfo({required this.icon, required this.label,
    required this.value, required this.badge,
    required this.badgeColor, required this.badgeDim});
}

class _StoreInfo {
  final String name, count;
  final IconData icon;
  final Color color;
  final double pct;
  const _StoreInfo({required this.name, required this.icon,
    required this.color, required this.count, required this.pct});
}

class _MetricInfo {
  final String label, value, sub;
  final double pct;
  const _MetricInfo({required this.label, required this.value,
    required this.sub, required this.pct});
}

class _DonutSegment {
  final String label, pct;
  final double value;
  final Color color;
  const _DonutSegment({required this.label, required this.value,
    required this.color, required this.pct});
}

class _Activity {
  final Color dotColor, iconColor, iconBg;
  final IconData icon;
  final String text, sub, time;
  const _Activity({required this.dotColor, required this.iconColor,
    required this.iconBg, required this.icon,
    required this.text, required this.sub, required this.time});
}

// ════════════════════════════════════════════════════════════════════
//  CUSTOM PAINTERS
// ════════════════════════════════════════════════════════════════════

// ── Donut chart ──────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double progress;
  final String centerLabel, centerSub;

  const _DonutPainter({
    required this.segments,
    required this.progress,
    required this.centerLabel,
    required this.centerSub,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 6;
    final inner = r * 0.62;

    final total = segments.fold(0.0, (s, e) => s + e.value);
    if (total <= 0) return;

    double start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;

    for (final seg in segments) {
      final frac = seg.value / total;
      final segSweep = frac * sweep;

      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = r - inner
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: (r + inner) / 2),
        start,
        segSweep - 0.03,
        false,
        paint,
      );
      start += frac * 2 * math.pi;
    }

    // gap track
    final trackPaint = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (r - inner) + 4;
    canvas.drawCircle(
        Offset(cx, cy), (r + inner) / 2,
        trackPaint..blendMode = BlendMode.dstOver);

    // center text
    if (progress > 0.5) {
      final opacity = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);

      final valPainter = TextPainter(
        text: TextSpan(
          text: centerLabel,
          style: GoogleFonts.nunito(
            color: Color.fromRGBO(255, 255, 255, opacity),
            fontSize: 22, fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      valPainter.paint(canvas,
          Offset(cx - valPainter.width / 2, cy - valPainter.height - 2));

      final subPainter = TextPainter(
        text: TextSpan(
          text: centerSub,
          style: GoogleFonts.nunito(
            color: Color.fromRGBO(136, 136, 136, opacity),
            fontSize: 10, fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      subPainter.paint(canvas,
          Offset(cx - subPainter.width / 2, cy + 4));
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress;
}

// ── Line / bar chart ────────────────────────────────────────────────
class _LineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double progress;
  const _LineChart({
    required this.values,
    required this.labels,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter: _LineChartPainter(
            values: values, labels: labels, progress: progress),
        size: const Size(double.infinity, 180),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double progress;

  const _LineChartPainter({
    required this.values,
    required this.labels,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const paddingLeft   = 36.0;
    const paddingBottom = 24.0;
    const paddingTop    = 8.0;
    const paddingRight  = 8.0;

    final w = size.width - paddingLeft - paddingRight;
    final h = size.height - paddingBottom - paddingTop;

    final maxVal = values.reduce(math.max).clamp(1.0, double.infinity);

    // grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = paddingTop + h - (i / 4) * h;
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        gridPaint,
      );
      // y-axis label
      final val = (maxVal * i / 4);
      final label = val >= 1000
          ? '${(val / 1000).toStringAsFixed(0)}k'
          : val.toInt().toString();
      final tp = TextPainter(
        text: TextSpan(text: label,
            style: GoogleFonts.nunito(
                color: const Color(0xFF444444),
                fontSize: 9, fontWeight: FontWeight.w500)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(0, y - tp.height / 2));
    }

    // compute points
    final step = values.length > 1 ? w / (values.length - 1) : w;
    final pts = List.generate(values.length, (i) {
      final x = paddingLeft + i * step;
      final y = paddingTop + h - (values[i] / maxVal) * h;
      return Offset(x, y);
    });

    // clamp progress to visible points
    final visibleCount = (progress * (values.length - 1)).clamp(0.0, values.length - 1.0);

    // fill gradient path
    if (visibleCount > 0) {
      final fillPath = Path();
      fillPath.moveTo(pts[0].dx, paddingTop + h);
      fillPath.lineTo(pts[0].dx, pts[0].dy);

      for (int i = 1; i < values.length; i++) {
        final frac = (visibleCount - (i - 1)).clamp(0.0, 1.0);
        if (frac <= 0) break;
        final target = Offset(
          pts[i - 1].dx + (pts[i].dx - pts[i - 1].dx) * frac,
          pts[i - 1].dy + (pts[i].dy - pts[i - 1].dy) * frac,
        );
        final cp1 = Offset(
            pts[i - 1].dx + (pts[i].dx - pts[i - 1].dx) * 0.4,
            pts[i - 1].dy);
        final cp2 = Offset(
            pts[i - 1].dx + (pts[i].dx - pts[i - 1].dx) * 0.6,
            target.dy);
        fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, target.dx, target.dy);
      }

      final lastVisible = pts[visibleCount.floor()];
      fillPath.lineTo(lastVisible.dx, paddingTop + h);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _white.withValues(alpha: 0.15),
            _white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, paddingTop, size.width, h));
      canvas.drawPath(fillPath, fillPaint);
    }

    // line
    if (visibleCount > 0) {
      final linePaint = Paint()
        ..color = _white
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final linePath = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < values.length; i++) {
        final frac = (visibleCount - (i - 1)).clamp(0.0, 1.0);
        if (frac <= 0) break;
        final target = Offset(
          pts[i - 1].dx + (pts[i].dx - pts[i - 1].dx) * frac,
          pts[i - 1].dy + (pts[i].dy - pts[i - 1].dy) * frac,
        );
        final cp1 = Offset(
            pts[i - 1].dx + (pts[i].dx - pts[i - 1].dx) * 0.4,
            pts[i - 1].dy);
        final cp2 = Offset(
            pts[i - 1].dx + (pts[i].dx - pts[i - 1].dx) * 0.6,
            target.dy);
        linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, target.dx, target.dy);
      }
      canvas.drawPath(linePath, linePaint);

      // dots
      final dotPaint = Paint()..color = _white;
      final dotBorder = Paint()
        ..color = _black2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (int i = 0; i < values.length; i++) {
        if (i > visibleCount) break;
        canvas.drawCircle(pts[i], 4, dotPaint);
        canvas.drawCircle(pts[i], 4, dotBorder);
      }
    }

    // x labels
    for (int i = 0; i < labels.length; i++) {
      if (labels[i].isEmpty) continue;
      final x = paddingLeft + i * step;
      final tp = TextPainter(
        text: TextSpan(text: labels[i],
            style: GoogleFonts.nunito(
                color: const Color(0xFF444444),
                fontSize: 9, fontWeight: FontWeight.w500)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(x - tp.width / 2, size.height - paddingBottom + 6));
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.progress != progress || old.values != values;
}

// ════════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ════════════════════════════════════════════════════════════════════

// ── Pulsing dot ──
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _a = Tween(begin: 1.0, end: 0.2).animate(_c);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: Container(width: 6, height: 6,
        decoration: BoxDecoration(
            color: widget.color, shape: BoxShape.circle)),
  );
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
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: _white70, size: 14),
      const SizedBox(width: 7),
      Text(label.toUpperCase(),
          style: GoogleFonts.nunito(
              color: _grey, fontSize: 10.5,
              fontWeight: FontWeight.w800, letterSpacing: 1)),
    ],
  );
}

// ── Tag pill ──
class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final Color dimColor;
  const _Tag({
    required this.label,
    this.color    = _white70,
    this.dimColor = _white10,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: dimColor,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(label,
        style: GoogleFonts.nunito(
            color: color, fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 0.5)),
  );
}

// ── Period tab ──
class _PeriodTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PeriodTab({
    required this.label,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: active ? _black2 : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: active
            ? Border.all(color: _white10)
            : Border.all(color: Colors.transparent),
      ),
      child: Text(label,
          style: GoogleFonts.nunito(
              color: active ? _white : _greyDark,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    ),
  );
}

// ── Stat card ──
class _StatCard extends StatelessWidget {
  final _StatInfo info;
  const _StatCard({required this.info});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _black2,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _white10),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _white10,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(info.icon, color: _white70, size: 17),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: info.badgeDim,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(info.badge,
              style: GoogleFonts.nunito(
                  color: info.badgeColor,
                  fontSize: 9.5, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 14),
      Text(info.value,
          style: GoogleFonts.nunito(
              color: _white, fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1, height: 1)),
      const SizedBox(height: 5),
      Text(info.label,
          style: GoogleFonts.nunito(
              color: _grey, fontSize: 11,
              fontWeight: FontWeight.w600)),
    ]),
  );
}