// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Analytics Screen (simplified, backend-only)
//  Route  : /analytics
//  Nav    : Bottom Nav (index 1) + Sidebar "Analytics"
//  Font   : Outfit (matches Home Screen)
//  Theme  : Pure black & white, very dark
//  Charts : CustomPainter (donut only)
//  Firebase: analytics/{uid}  +  submissions where userId==uid
// ═══════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── PALETTE (darker) ───────────────────────────────────────────────
const _black    = Color(0xFF000000);
const _black2   = Color(0xFF0A0A0A);
const _black3   = Color(0xFF101010);
const _black4   = Color(0xFF181818);
const _white    = Color(0xFFFFFFFF);
const _white70  = Color(0xB3FFFFFF);
const _white10  = Color(0x14FFFFFF);
const _white06  = Color(0x0FFFFFFF);
const _grey     = Color(0xFF7A7A7A);
const _greyDark = Color(0xFF3A3A3A);

const _green    = Color(0xFF22C55E);
const _greenDim = Color(0x1A22C55E);
const _warn     = Color(0xFFF59E0B);
const _warnDim  = Color(0x1AF59E0B);

const _spotify  = Color(0xFF1DB954);
const _apple    = Color(0xFFFC3C44);
const _youtube  = Color(0xFFFF0000);
const _boomplay = Color(0xFF00C853);

// ════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ════════════════════════════════════════════════════════════════════
class _AnalyticsData {
  final int totalStreams, totalReleases;
  final int spotifyStreams, appleStreams, youtubeStreams, boomplayStreams;
  final List<_Release> releases;
  const _AnalyticsData({
    this.totalStreams = 0,
    this.totalReleases = 0,
    this.spotifyStreams = 0,
    this.appleStreams = 0,
    this.youtubeStreams = 0,
    this.boomplayStreams = 0,
    this.releases = const [],
  });
}

class _Release {
  final String title, type, genre, date, status;
  const _Release({
    required this.title,
    this.type = 'Single',
    this.genre = '—',
    this.date = '—',
    this.status = 'Pending',
  });
}

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
  bool _loading = true;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _barAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
      final aSnap = await FirebaseFirestore.instance
          .collection('analytics')
          .doc(user.uid)
          .get();
      final aData = aSnap.exists ? aSnap.data()! : <String, dynamic>{};

      final sSnap = await FirebaseFirestore.instance
          .collection('submissions')
          .where('userId', isEqualTo: user.uid)
          .get();

      final releases = sSnap.docs.map((d) {
        final r = d.data();
        return _Release(
          title: r['releaseTitle'] ?? 'Untitled Release',
          type: r['releaseType'] ?? 'Single',
          genre: r['genre'] ?? '—',
          date: r['releaseDate'] ?? '—',
          status: r['status'] ?? 'Pending',
        );
      }).toList();

      if (mounted) {
        setState(() {
          _data = _AnalyticsData(
            totalStreams: _int(aData['totalStreams']),
            totalReleases: sSnap.size,
            spotifyStreams: _int(aData['spotifyStreams']),
            appleStreams: _int(aData['appleStreams']),
            youtubeStreams: _int(aData['youtubeStreams']),
            boomplayStreams: _int(aData['boomplayStreams']),
            releases: releases,
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      body: Stack(children: [
        if (_loading)
          const Center(
              child: CircularProgressIndicator(
                  color: _white, strokeWidth: 2))
        else
          SlideTransition(
            position: _slide,
            child: FadeTransition(opacity: _fade, child: _buildBody()),
          ),
      ]),
    );
  }

  Widget _buildBody() {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: top),
          _topBar(),
          _heroStrip(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: _statGrid(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _platformSplit(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _topStores(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _topReleases(),
          ),
          SizedBox(height: bottom + 100),
        ],
      ),
    );
  }

  // ══ TOP BAR ══
  Widget _topBar() {
    return Container(
      height: 58,
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
            height: 26,
            color: _white,
            colorBlendMode: BlendMode.srcIn,
            errorWidget: (_, __, ___) => Text('444Music',
                style: GoogleFonts.outfit(
                    color: _white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _white06,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _white10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _white, size: 15),
          ),
        ),
      ]),
    );
  }

  // ══ HERO ══
  Widget _heroStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _white10))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Artist Insights',
            style: GoogleFonts.outfit(
                color: _white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.05)),
        const SizedBox(height: 4),
        Text('Live performance data across your releases.',
            style: GoogleFonts.outfit(
                color: _grey, fontSize: 12.5, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ══ STAT GRID (real data only) ══
  Widget _statGrid() {
    return Row(children: [
      Expanded(
        child: _StatCard(
          icon: Icons.headphones_rounded,
          label: 'Total Streams',
          value: _fmt(_data.totalStreams),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _StatCard(
          icon: Icons.music_note_rounded,
          label: 'Total Releases',
          value: _data.totalReleases.toString(),
        ),
      ),
    ]);
  }

  // ══ PLATFORM SPLIT ══
  Widget _platformSplit() {
    final sp = _data.spotifyStreams.toDouble();
    final ap = _data.appleStreams.toDouble();
    final yt = _data.youtubeStreams.toDouble();
    final bp = _data.boomplayStreams.toDouble();
    final tot = (sp + ap + yt + bp);

    if (tot <= 0) {
      return _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CardTitle(icon: Icons.donut_large_rounded, label: 'Platform Split'),
          const SizedBox(height: 14),
          _emptyState(
              icon: Icons.donut_large_rounded,
              text: 'Platform data will appear once streams come in.'),
        ]),
      );
    }

    String pct(double v) => '${(v / tot * 100).round()}%';
    final segments = [
      _DonutSegment(label: 'Spotify', value: sp, color: _spotify, pct: pct(sp)),
      _DonutSegment(
          label: 'Apple Music', value: ap, color: _apple, pct: pct(ap)),
      _DonutSegment(
          label: 'YouTube', value: yt, color: _youtube, pct: pct(yt)),
      _DonutSegment(
          label: 'Others', value: bp, color: _white70, pct: pct(bp)),
    ];

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardTitle(icon: Icons.donut_large_rounded, label: 'Platform Split'),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: AnimatedBuilder(
                animation: _barAnim,
                builder: (_, __) => CustomPaint(
                  painter: _DonutPainter(
                    segments: segments,
                    progress: _barAnim.value,
                    centerLabel: _fmt(_data.totalStreams),
                    centerSub: 'Streams',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: segments
                    .where((s) => s.value > 0)
                    .map((s) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: s.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(s.label,
                                  style: GoogleFonts.outfit(
                                      color: _white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ),
                            Text(s.pct,
                                style: GoogleFonts.outfit(
                                    color: _white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ]),
    );
  }

  // ══ TOP STORES (real counts only, no fake bars) ══
  Widget _topStores() {
    final stores = [
      _StoreInfo(
          name: 'Spotify',
          icon: Icons.music_note_rounded,
          color: _spotify,
          count: _data.spotifyStreams),
      _StoreInfo(
          name: 'Apple Music',
          icon: Icons.apple_rounded,
          color: _apple,
          count: _data.appleStreams),
      _StoreInfo(
          name: 'YouTube',
          icon: Icons.play_circle_rounded,
          color: _youtube,
          count: _data.youtubeStreams),
    ];

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardTitle(icon: Icons.storefront_rounded, label: 'Top Stores'),
        const SizedBox(height: 14),
        ...stores.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(s.icon, color: s.color, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s.name,
                      style: GoogleFonts.outfit(
                          color: _white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                Text(_fmt(s.count),
                    style: GoogleFonts.outfit(
                        color: _white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
            )),
      ]),
    );
  }

  // ══ TOP RELEASES ══
  Widget _topReleases() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardTitle(icon: Icons.library_music_rounded, label: 'Releases'),
        const SizedBox(height: 12),
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
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: _black4,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        const Icon(Icons.album_rounded, color: _white, size: 16),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title,
                            style: GoogleFonts.outfit(
                                color: _white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('${r.type} · ${r.date}',
                            style: GoogleFonts.outfit(
                                color: _grey, fontSize: 10.5),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLive ? _greenDim : _warnDim,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(r.status,
                        style: GoogleFonts.outfit(
                            color: isLive ? _green : _warn,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            );
          }),
      ]),
    );
  }

  Widget _emptyState({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        Icon(icon, color: _greyDark, size: 34),
        const SizedBox(height: 10),
        Text(text,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                color: _greyDark, fontSize: 12.5, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  DATA CLASSES
// ════════════════════════════════════════════════════════════════════
class _StoreInfo {
  final String name;
  final IconData icon;
  final Color color;
  final int count;
  const _StoreInfo(
      {required this.name,
      required this.icon,
      required this.color,
      required this.count});
}

class _DonutSegment {
  final String label, pct;
  final double value;
  final Color color;
  const _DonutSegment(
      {required this.label,
      required this.value,
      required this.color,
      required this.pct});
}

// ════════════════════════════════════════════════════════════════════
//  DONUT PAINTER
// ════════════════════════════════════════════════════════════════════
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
    final r = math.min(cx, cy) - 6;
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

    if (progress > 0.5) {
      final opacity = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
      final valPainter = TextPainter(
        text: TextSpan(
          text: centerLabel,
          style: GoogleFonts.outfit(
              color: Color.fromRGBO(255, 255, 255, opacity),
              fontSize: 19,
              fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      valPainter.paint(canvas,
          Offset(cx - valPainter.width / 2, cy - valPainter.height - 2));

      final subPainter = TextPainter(
        text: TextSpan(
          text: centerSub,
          style: GoogleFonts.outfit(
              color: Color.fromRGBO(122, 122, 122, opacity),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      subPainter.paint(canvas, Offset(cx - subPainter.width / 2, cy + 4));
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.progress != progress;
}

// ════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ════════════════════════════════════════════════════════════════════
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _black3,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _white10),
        ),
        child: child,
      );
}

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
              style: GoogleFonts.outfit(
                  color: _grey,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
        ],
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatCard(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _black3,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _white10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _white10,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: _white70, size: 16),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: GoogleFonts.outfit(
                  color: _white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8)),
          const SizedBox(height: 3),
          Text(label,
              style: GoogleFonts.outfit(
                  color: _grey, fontSize: 10.5, fontWeight: FontWeight.w600)),
        ]),
      );
}