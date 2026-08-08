// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Artist Insights (Analytics) Screen
//  Mirrors web: wey.html — all-time totals only, no date filters
//  except the 7D/30D/All chart tabs. Two-tone black/white cards.
//  Route: /analytics
//  Firebase: analytics/{uid} (totalStreams, spotifyStreams,
//            appleStreams, youtubeStreams) + submissions where userId==uid
//
//  v2 patch: overflow-safety only, mirroring the earnings_screen.dart
//  patch — hero/plain stat values wrapped in FittedBox, the chart
//  header row won't squeeze its tabs off-screen, source-row name/count/
//  pct all ellipsis-guarded.
//
//  v3 patch: RepaintBoundary isolation. Every BoxShadow-decorated card
//  AND the live-animating line chart are each wrapped in their own
//  RepaintBoundary, so a compositing glitch or stale-frame issue in
//  one (particularly the CustomPaint chart, which repaints on every
//  animation tick) can't bleed into the header text or neighboring
//  cards — this matches the "Artist Insights" / day-label overlap seen
//  on-device. Nothing else — chart painter, avatar upload, all-time
//  totals logic — changed.
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

// ─── PALETTE (mirrors :root in wey.html) ─────────────────────────────
const _bg         = Color(0xFF070707);
const _surface    = Color(0xFF111111);
const _surface2   = Color(0xFF161616);
const _surface3   = Color(0xFF1C1C1C);
const _border     = Color(0x14FFFFFF);
const _borderH    = Color(0x21FFFFFF);

const _wht        = Color(0xFFFFFFFF);
const _inkBorder  = Color(0x14000000);

const _text1      = Color(0xFFF2F2F2);
const _text2      = Color(0xFF9A9A9A);
const _text3      = Color(0xFF4D4D4D);
const _ink1       = Color(0xFF0D0D0D);
const _ink2       = Color(0xFF6E6E6E);

const _ease = Curves.easeOutCubic;
const _entranceDuration = Duration(milliseconds: 900);

TextStyle _head(double size, FontWeight w, {Color color = _wht, double? letterSpacing}) =>
    GoogleFonts.outfit(fontSize: size, fontWeight: w, color: color, letterSpacing: letterSpacing);
TextStyle _body(double size, FontWeight w, {Color color = _text2, double? height}) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: color, height: height);

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
  String? _photoURL;
  String? _uid;
  bool _uploadingAvatar = false;

  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _reveal;

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
      systemNavigationBarColor: _bg,
    ));
    _ctrl = AnimationController(vsync: this, duration: _entranceDuration);
    _fade = CurvedAnimation(parent: _ctrl, curve: _ease);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: _ease));
    _reveal = CurvedAnimation(parent: _ctrl, curve: const Interval(0.35, 1.0, curve: _ease));
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
      final userSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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
          if (userSnap.exists) {
            _photoURL = userSnap.data()?['photoURL'];
          } else {
            _photoURL = null;
          }
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
      if (mounted) {
        setState(() => _loading = false);
        _ctrl.forward();
      }
    }
  }

  ImageProvider _avatarImageProvider(String url) {
    if (url.startsWith('data:')) {
      final b64 = url.substring(url.indexOf(',') + 1);
      return MemoryImage(base64Decode(b64));
    }
    return CachedNetworkImageProvider(url);
  }

  String _fmt(num n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_uid == null || _uploadingAvatar) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image must be under 5MB')),
        );
      }
      return;
    }

    setState(() => _uploadingAvatar = true);
    try {
      final ext = picked.path.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final base64Str = 'data:$mime;base64,${base64Encode(bytes)}';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .set({'photoURL': base64Str}, SetOptions(merge: true));
      if (mounted) setState(() => _photoURL = base64Str);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update your photo. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _wht, strokeWidth: 2))
          // PATCH: RepaintBoundary around the whole animated subtree —
          // gives Skia a clean compositing boundary for the slide+fade
          // layer instead of it sharing a layer with the Scaffold.
          : RepaintBoundary(
              child: SlideTransition(
                position: _slide,
                child: FadeTransition(opacity: _fade, child: _buildBody()),
              ),
            ),
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
        Padding(padding: const EdgeInsets.fromLTRB(20, 26, 20, 0), child: _pageHeader()),
        // PATCH: each card below gets its own RepaintBoundary so a paint
        // glitch in one (especially the live-animating chart) can't
        // bleed into the header or a neighboring card.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: RepaintBoundary(child: _statRow()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: RepaintBoundary(child: _chartCard()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: RepaintBoundary(child: _sourceCard()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: RepaintBoundary(child: _topReleasesCard()),
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
        color: _bg,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _wht, size: 16),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _pickAndUploadAvatar,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _surface2,
                  shape: BoxShape.circle,
                  border: Border.all(color: _borderH),
                  image: _photoURL != null
                      ? DecorationImage(image: _avatarImageProvider(_photoURL!), fit: BoxFit.cover)
                      : null,
                ),
                child: _photoURL == null ? const Icon(Icons.person_rounded, color: _text2, size: 19) : null,
              ),
              if (_uploadingAvatar)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                    child: const Center(
                      child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(color: _wht, strokeWidth: 2),
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  bottom: -2, right: -2,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: _bg, width: 2),
                    ),
                    child: const Icon(Icons.edit_rounded, color: _wht, size: 9),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _pageHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6, height: 6,
          decoration: const BoxDecoration(color: _wht, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x17FFFFFF),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: const Color(0x2EFFFFFF)),
          ),
          child: Text('444MUSIC · ANALYTICS SUITE',
              style: _body(10, FontWeight.w700, color: _wht).copyWith(letterSpacing: 1.2)),
        ),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        const Icon(Icons.show_chart_rounded, color: _wht, size: 22),
        const SizedBox(width: 10),
        Text('Artist Insights', style: _head(26, FontWeight.w900)),
      ]),
      const SizedBox(height: 8),
      Text('All-time performance across every release and store.',
          style: _body(13, FontWeight.w400, height: 1.5)),
    ]);
  }

  // ── STATS ──
  Widget _statRow() {
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        flex: 13,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 16, 18),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x38FFFFFF)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 44, offset: const Offset(0, 16))],
          ),
          child: Stack(children: [
            Positioned(
              top: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(99)),
                child: Text('All-Time', style: _body(10, FontWeight.w700, color: _wht)),
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.headphones_rounded, color: _wht, size: 16),
              ),
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(_fmt(_totalStreams),
                    maxLines: 1, style: _head(24, FontWeight.w900, letterSpacing: -1)),
              ),
              const SizedBox(height: 5),
              Text('TOTAL STREAMS',
                  style: _body(9.5, FontWeight.w700, color: const Color(0x8CFFFFFF)).copyWith(letterSpacing: 0.7)),
            ]),
          ]),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(flex: 10, child: _plainStat(Icons.music_note_rounded, _releases.length.toString(), 'Total Releases')),
      const SizedBox(width: 12),
      Expanded(flex: 10, child: _plainStat(Icons.public_rounded, '50+', 'Stores Distributed')),
    ]);
  }

  Widget _plainStat(IconData icon, String value, String label) => Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 14, 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: const Color(0x17FFFFFF), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: _wht, size: 15),
          ),
          const SizedBox(height: 13),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: _head(18, FontWeight.w900, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: _body(9, FontWeight.w700, color: _text2).copyWith(letterSpacing: 0.6)),
        ]),
      );

  // ── CHART ──
  Widget _chartCard() {
    late List<double> values;
    late List<String> labels;
    switch (_period) {
      case _Period.d7:
        values = _scale(_w7, _totalStreams.toDouble());
        labels = _labels7;
        break;
      case _Period.d30:
        values = _scale(_w30, _totalStreams.toDouble());
        labels = _labels30;
        break;
      case _Period.all:
        values = _scale(_wAll, _totalStreams.toDouble());
        labels = _labelsAll;
        break;
    }

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
            child: Text('Streaming Growth',
                overflow: TextOverflow.ellipsis,
                style: _head(15, FontWeight.w800, letterSpacing: -0.3)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _tab('7D', _period == _Period.d7, () => setState(() => _period = _Period.d7)),
              _tab('30D', _period == _Period.d30, () => setState(() => _period = _Period.d30)),
              _tab('All', _period == _Period.all, () => setState(() => _period = _Period.all)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        // PATCH: RepaintBoundary around the chart specifically — this
        // subtree repaints on every animation tick via AnimatedBuilder,
        // so isolating it stops its per-frame repaint from invalidating
        // or bleeding into the static title/tabs row above it.
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _reveal,
            builder: (_, __) => _LineChart(values: values, labels: labels, progress: _reveal.value),
          ),
        ),
      ]),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: _ease,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: active ? _surface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
              style: _body(10.5, FontWeight.w700, color: active ? _wht : _text3).copyWith(letterSpacing: 0.6)),
        ),
      );

  // ── SOURCE OF STREAMS ──
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
          Flexible(
            child: Text('Source of Streams',
                overflow: TextOverflow.ellipsis,
                style: _head(15, FontWeight.w800, letterSpacing: -0.3)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x17FFFFFF),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0x29FFFFFF)),
            ),
            child: Text('ALL-TIME', style: _body(9.5, FontWeight.w700, color: _wht).copyWith(letterSpacing: 0.6)),
          ),
        ]),
        const SizedBox(height: 18),
        ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderH),
                    ),
                    child: Icon(r.icon, color: _wht, size: 15),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 92,
                    child: Text(r.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: _body(13, FontWeight.w700, color: _text1)),
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _reveal,
                      builder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          height: 5, color: _surface3,
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
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 56),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(_fmt(r.value), maxLines: 1, style: _head(12.5, FontWeight.w800, color: _text1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    child: Text('${pct(r.value)}%',
                        textAlign: TextAlign.right,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: _body(10.5, FontWeight.w700, color: _text3)),
                  ),
                ]),
              ),
            )),
      ]),
    );
  }

  // ── TOP RELEASES ──
  Widget _topReleasesCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
            child: Text('Top Releases',
                overflow: TextOverflow.ellipsis,
                style: _head(15, FontWeight.w800, letterSpacing: -0.3)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x17FFFFFF),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0x29FFFFFF)),
            ),
            child: Text('LIBRARY', style: _body(9.5, FontWeight.w700, color: _wht).copyWith(letterSpacing: 0.6)),
          ),
        ]),
        const SizedBox(height: 16),
        if (_releases.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(children: [
              const Icon(Icons.album_rounded, color: _wht, size: 34),
              const SizedBox(height: 12),
              Text('Your releases will appear here once submitted.',
                  textAlign: TextAlign.center, style: _body(12.5, FontWeight.w600, color: _text3)),
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
                  color: _surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(children: [
                  Text((i + 1).toString().padLeft(2, '0'),
                      style: _body(10.5, FontWeight.w700, color: _text3)),
                  const SizedBox(width: 12),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFCFCFCF), _wht]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: r.coverURL != null
                        ? CachedNetworkImage(imageUrl: r.coverURL!, fit: BoxFit.cover)
                        : const Icon(Icons.album_rounded, color: Colors.black, size: 17),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: _body(13.5, FontWeight.w700, color: _text1)),
                      const SizedBox(height: 3),
                      Text('${r.type} · ${r.genre}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: _body(11, FontWeight.w500, color: _text3)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: approved ? const Color(0x1FFFFFFF) : const Color(0x0DFFFFFF),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: approved ? const Color(0x33FFFFFF) : const Color(0x1FFFFFFF)),
                    ),
                    child: Text(approved ? 'Approved' : r.status,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: _body(10, FontWeight.w700, color: approved ? _text1 : _text2)),
                  ),
                ]),
              ),
            );
          }),
      ]),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: child,
      );
}

// ════════════════════════════════════════════════════════════════════
//  LINE CHART — white line on black card, matches Chart.js styling in
//  wey.html (soft white gradient fill, rounded points, faint grid)
// ════════════════════════════════════════════════════════════════════
class _LineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double progress;
  const _LineChart({required this.values, required this.labels, required this.progress});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 200,
        child: CustomPaint(
          painter: _LineChartPainter(values: values, labels: labels, progress: progress),
          size: const Size(double.infinity, 200),
        ),
      );
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double progress;
  const _LineChartPainter({required this.values, required this.labels, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const padLeft = 36.0, padBottom = 24.0, padTop = 8.0, padRight = 8.0;
    final w = size.width - padLeft - padRight;
    final h = size.height - padBottom - padTop;
    final maxVal = values.reduce(math.max).clamp(1.0, double.infinity);

    final gridPaint = Paint()..color = const Color(0x0AFFFFFF)..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = padTop + h - (i / 4) * h;
      canvas.drawLine(Offset(padLeft, y), Offset(size.width - padRight, y), gridPaint);
      final val = maxVal * i / 4;
      final label = val >= 1000 ? '${(val / 1000).toStringAsFixed(0)}k' : val.toInt().toString();
      final tp = TextPainter(
        text: TextSpan(text: label, style: _body(9, FontWeight.w600, color: _text3)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    final step = values.length > 1 ? w / (values.length - 1) : w;
    final pts = List.generate(values.length, (i) {
      final x = padLeft + i * step;
      final y = padTop + h - (values[i] / maxVal) * h;
      return Offset(x, y);
    });

    final visible = (progress * (values.length - 1)).clamp(0.0, values.length - 1.0);

    Path curvedPath(bool asFill) {
      final path = Path();
      if (asFill) {
        path.moveTo(pts[0].dx, padTop + h);
        path.lineTo(pts[0].dx, pts[0].dy);
      } else {
        path.moveTo(pts[0].dx, pts[0].dy);
      }
      for (int i = 1; i < values.length; i++) {
        final frac = (visible - (i - 1)).clamp(0.0, 1.0);
        if (frac <= 0) break;
        final target = Offset(
          pts[i - 1].dx + (pts[i].dx - pts[i - 1].dx) * frac,
          pts[i - 1].dy + (pts[i].dy - pts[i - 1].dy) * frac,
        );
        final cp1 = Offset(pts[i - 1].dx + (pts[i].dx - pts[i - 1].dx) * 0.4, pts[i - 1].dy);
        final cp2 = Offset(pts[i - 1].dx + (pts[i].dx - pts[i - 1].dx) * 0.6, target.dy);
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, target.dx, target.dy);
      }
      if (asFill) {
        final lastVisible = pts[visible.floor()];
        path.lineTo(lastVisible.dx, padTop + h);
        path.close();
      }
      return path;
    }

    if (visible > 0) {
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0x38FFFFFF), const Color(0x00FFFFFF)],
        ).createShader(Rect.fromLTWH(0, padTop, size.width, h));
      canvas.drawPath(curvedPath(true), fillPaint);

      final linePaint = Paint()
        ..color = _wht
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(curvedPath(false), linePaint);

      final dotPaint = Paint()..color = _wht;
      final dotBorder = Paint()..color = _surface..style = PaintingStyle.stroke..strokeWidth = 2;
      for (int i = 0; i < values.length; i++) {
        if (i > visible) break;
        canvas.drawCircle(pts[i], 4, dotPaint);
        canvas.drawCircle(pts[i], 4, dotBorder);
      }
    }

    for (int i = 0; i < labels.length; i++) {
      final x = padLeft + i * step;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: _body(9, FontWeight.w600, color: _text3)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - padBottom + 6));
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => old.progress != progress || old.values != values;
}