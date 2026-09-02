// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Analytics Screen ("Artist Insights")
//  Route  : /analytics
//  Font   : Outfit (matches Home Screen)
//  Theme  : Pure black & white, very dark
//  Firebase: analytics/{uid}  +  submissions where userId==uid  +  users/{uid}
//
//  v2 — rebuilt to exact parity with web's Artist Insights page.
//  Removed everything web does NOT have: the donut "Platform Split"
//  card, the "Top Stores" card, and the spotify/apple/boomplay stream
//  fields that backed them (web never reads those — Spotify and Apple
//  are always shown as "Pending" since there's no real data source for
//  either yet). Added everything web HAS that this screen was missing:
//   • Profile photo in the header — tap to change, uploads as a base64
//     data URI straight to users/{uid}.photoURL, same as web (no
//     Cloudinary here — this one field genuinely doesn't use it).
//   • Third stat card: "Stores Distributed" (static "50+").
//   • "Streaming Growth" line chart with 7D / 30D / All tabs. Since
//     the backend only stores a cumulative total (no per-day time
//     series yet), the curve is an illustrative distribution of that
//     REAL total across the range — same weighted-scale approach and
//     same weight arrays as web's buildTrendFromTotal(). The total
//     itself is always real; only its shape across the x-axis is
//     illustrative, exactly as commented in web's source.
//   • "Source of Streams" list — Spotify/Apple always "Pending",
//     YouTube shows the real count. Replaces the donut entirely.
//   • "Top Releases" rebuilt to use REAL YouTube view data per web's
//     getReleaseTrackBreakdown(): multi-track releases read
//     youtubeTrackMatches[i], legacy singles read youtubeViews. A
//     track/release with no confirmed views is "Pending", never 0,
//     and sorts to the bottom. Multi-track releases show a per-track
//     breakdown, matching web's .track-breakdown rows.
//
//  NOTE ON THE "Approved" STATUS CHECK: web's Top Releases badge
//  checks status.toLowerCase() === 'approved' specifically — not
//  'live', which is what Verification/Rejection elsewhere in this app
//  use. That looks like an inconsistency in the web app itself, but
//  since the ask here was byte-for-byte parity with THIS page, that
//  literal check is reproduced as-is rather than "corrected" to 'live'.
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

// ─── PALETTE (darker) ───────────────────────────────────────────────
const _black    = Color(0xFF000000);
const _black2   = Color(0xFF0A0A0A);
const _black3   = Color(0xFF101010);
const _black4   = Color(0xFF181818);
const _white    = Color(0xFFFFFFFF);
const _white70  = Color(0xB3FFFFFF);
const _white20  = Color(0x33FFFFFF);
const _white10  = Color(0x14FFFFFF);
const _white06  = Color(0x0FFFFFFF);
const _grey     = Color(0xFF7A7A7A);
const _greyDark = Color(0xFF3A3A3A);
const _green    = Color(0xFF22C55E);

// ════════════════════════════════════════════════════════════════════
//  DATA MODELS — mirror web's getReleaseTrackBreakdown() shape
// ════════════════════════════════════════════════════════════════════
class _Track {
  final String title;
  final int? views; // null = pending, never 0
  const _Track({required this.title, this.views});
}

class _ReleaseEntry {
  final String title, type, genre, coverUrl, status;
  final List<_Track> breakdown;
  final int total;
  final bool hasRealData;
  const _ReleaseEntry({
    required this.title,
    required this.type,
    required this.genre,
    required this.coverUrl,
    required this.status,
    required this.breakdown,
    required this.total,
    required this.hasRealData,
  });
}

// Same weighted-scale trend used by web's buildTrendFromTotal(). Builds
// a cumulative curve across the range that lands exactly on `total` at
// the last point — the total is real, its shape across the x-axis is
// illustrative (no daily history exists yet to plot for real).
List<double> _scaleWeights(List<double> weights, double total) {
  final sum = weights.fold(0.0, (a, b) => a + b);
  double running = 0;
  return weights.map((w) {
    running += (w / sum) * total;
    return running.roundToDouble();
  }).toList();
}

const _kWeights7D  = [0.05, 0.08, 0.11, 0.14, 0.18, 0.20, 0.24];
const _kLabels7D   = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _kWeights30D = [0.15, 0.22, 0.28, 0.35];
const _kLabels30D  = ['W1', 'W2', 'W3', 'W4'];
const _kWeightsAll = [0.06, 0.09, 0.11, 0.13, 0.16, 0.19, 0.26];
const _kLabelsAll  = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];

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
  bool _loading = true;

  int _totalStreams  = 0;
  int _totalReleases = 0;
  int _youtubeStreams = 0;
  List<_ReleaseEntry> _releases = const [];

  String? _avatarUrl; // may be a data: URI or a plain http URL
  bool _avatarUploading = false;

  String _chartRange = '7D';
  final Map<String, List<double>> _chartData = {};

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _revealAnim;

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
    _revealAnim = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic));
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
      final userSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userSnap.exists ? (userSnap.data() ?? {}) : <String, dynamic>{};

      final aSnap = await FirebaseFirestore.instance.collection('analytics').doc(user.uid).get();
      final aData = aSnap.exists ? aSnap.data()! : <String, dynamic>{};

      final sSnap = await FirebaseFirestore.instance
          .collection('submissions')
          .where('userId', isEqualTo: user.uid)
          .get();

      final releases = sSnap.docs.map((d) => _buildReleaseEntry(d.data())).toList();
      releases.sort((a, b) {
        if (a.hasRealData && !b.hasRealData) return -1;
        if (!a.hasRealData && b.hasRealData) return 1;
        return b.total.compareTo(a.total);
      });

      final total = _int(aData['totalStreams']);

      if (mounted) {
        setState(() {
          _avatarUrl      = (userData['photoURL'] as String?)?.isNotEmpty == true ? userData['photoURL'] : null;
          _totalStreams   = total;
          _totalReleases  = sSnap.size;
          _youtubeStreams = _int(aData['youtubeStreams']);
          _releases       = releases;
          _chartData['7D']  = _scaleWeights(_kWeights7D, total.toDouble());
          _chartData['30D'] = _scaleWeights(_kWeights30D, total.toDouble());
          _chartData['All'] = _scaleWeights(_kWeightsAll, total.toDouble());
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

  // Mirrors web's getReleaseTrackBreakdown() + getReleaseTotalViews() +
  // hasAnyRealViews() exactly.
  _ReleaseEntry _buildReleaseEntry(Map<String, dynamic> r) {
    final audioFiles = r['audioFiles'];
    final hasTrackList = audioFiles is List && audioFiles.isNotEmpty;

    List<_Track> breakdown;
    if (hasTrackList) {
      final matches = r['youtubeTrackMatches'];
      breakdown = List.generate(audioFiles.length, (i) {
        final track = audioFiles[i];
        final title = (track is Map && (track['title'] ?? '').toString().isNotEmpty)
            ? track['title'].toString()
            : 'Track ${i + 1}';
        final match = matches is Map ? matches[i.toString()] : null;
        final hasViews = match is Map && match['status'] == 'matched' && match['views'] is num;
        return _Track(title: title, views: hasViews ? (match['views'] as num).toInt() : null);
      });
    } else {
      final hasViews = r['youtubeViews'] is num;
      final title = (r['releaseTitle'] ?? r['songTitle'] ?? r['title'] ?? 'Untitled').toString();
      breakdown = [
        _Track(title: title, views: hasViews ? (r['youtubeViews'] as num).toInt() : null),
      ];
    }

    final total = breakdown.fold<int>(0, (sum, t) => sum + (t.views ?? 0));
    final hasRealData = breakdown.any((t) => t.views != null);

    return _ReleaseEntry(
      title: (r['releaseTitle'] ?? 'Untitled Release').toString(),
      type: (r['releaseType'] ?? 'Single').toString(),
      genre: (r['genre'] ?? '—').toString(),
      coverUrl: (r['coverURL'] ?? '').toString(),
      status: (r['status'] ?? 'Pending').toString(),
      breakdown: breakdown,
      total: total,
      hasRealData: hasRealData,
    );
  }

  int _int(dynamic v) =>
      v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  // ── AVATAR UPLOAD — stored as a base64 data URI directly on
  // users/{uid}.photoURL, matching web's FileReader → setDoc flow
  // exactly (this is the one place in the app that doesn't use
  // Cloudinary, because web doesn't either).
  Future<void> _pickAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image must be under 5MB')),
        );
      }
      return;
    }

    setState(() => _avatarUploading = true);
    try {
      final ext = picked.path.toLowerCase();
      final mime = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'photoURL': dataUrl},
        SetOptions(merge: true),
      );
      if (mounted) setState(() { _avatarUrl = dataUrl; _avatarUploading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _avatarUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update your photo. Please try again.")),
        );
      }
    }
  }

  Widget _buildAvatarContent() {
    if (_avatarUrl == null || _avatarUrl!.isEmpty) {
      return const Icon(Icons.person_rounded, color: _grey, size: 22);
    }
    if (_avatarUrl!.startsWith('data:image')) {
      try {
        final Uint8List bytes = base64Decode(_avatarUrl!.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover, width: 56, height: 56);
      } catch (_) {
        return const Icon(Icons.person_rounded, color: _grey, size: 22);
      }
    }
    return Image.network(
      _avatarUrl!,
      fit: BoxFit.cover, width: 56, height: 56,
      errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: _grey, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      body: Stack(children: [
        if (_loading)
          const Center(child: CircularProgressIndicator(color: _white, strokeWidth: 2))
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
          _backBar(),
          _pageHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: _statSection(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _growthChartCard(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _sourceOfStreamsCard(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _topReleasesCard(),
          ),
          SizedBox(height: bottom + 100),
        ],
      ),
    );
  }

  // ── Minimal back affordance — web is a standalone page with no back
  // button; this app pushes the screen, so it needs one. Nothing else
  // from the old top bar (the "444Music" logo tap-to-go-back) survives,
  // since that had no counterpart on web either.
  Widget _backBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _white06,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _white10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _white, size: 15),
          ),
        ),
      ),
    );
  }

  // ══ PAGE HEADER — title, subtitle, avatar ══
  Widget _pageHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Artist Insights',
                  style: GoogleFonts.outfit(color: _white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.05)),
              const SizedBox(height: 4),
              Text('Streams shown here are synced directly YouTube',
                  style: GoogleFonts.outfit(color: _grey, fontSize: 12.5, fontWeight: FontWeight.w500)),
            ]),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _black3,
                  border: Border.all(color: _white20),
                ),
                child: ClipOval(child: Center(child: _buildAvatarContent())),
              ),
              Positioned(
                bottom: -2, right: -2,
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: _black, shape: BoxShape.circle, border: Border.all(color: _black, width: 2),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                    child: _avatarUploading
                        ? const Padding(
                            padding: EdgeInsets.all(3),
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: _white),
                          )
                        : const Icon(Icons.edit_rounded, color: _white, size: 10),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ══ STAT SECTION — hero card full-width, then two plain cards in a
  // row below, matching web's ≤900px responsive layout exactly. ══
  Widget _statSection() {
    return Column(children: [
      _StatCard(
        icon: Icons.headphones_rounded,
        label: 'Total Streams',
        value: _fmt(_totalStreams),
        hero: true,
        badge: 'All-Time',
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _StatCard(icon: Icons.music_note_rounded, label: 'Total Releases', value: _totalReleases.toString())),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(icon: Icons.public_rounded, label: 'Stores Distributed', value: '50+')),
      ]),
    ]);
  }

  // ══ STREAMING GROWTH CHART ══
  Widget _growthChartCard() {
    final labels = _chartRange == '7D' ? _kLabels7D : (_chartRange == '30D' ? _kLabels30D : _kLabelsAll);
    final values = _chartData[_chartRange] ?? const [];

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Streaming Growth',
                style: GoogleFonts.outfit(color: _white, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: _black4, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                _chartTab('7D'),
                _chartTab('30D'),
                _chartTab('All'),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 200,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _revealAnim,
            builder: (_, __) => CustomPaint(
              painter: _LineChartPainter(values: values, labels: labels, progress: _revealAnim.value),
              size: Size.infinite,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chartTab(String key) {
    final active = _chartRange == key;
    return GestureDetector(
      onTap: () => setState(() => _chartRange = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _black3 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(key,
            style: GoogleFonts.outfit(
                color: active ? _white : _greyDark,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ),
    );
  }

  // ══ SOURCE OF STREAMS — Spotify/Apple always Pending, YouTube real ══
  Widget _sourceOfStreamsCard() {
    final ytActive = _totalStreams > 0;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CardTitle(icon: Icons.donut_large_rounded, label: 'Source of Streams'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _white06, borderRadius: BorderRadius.circular(99), border: Border.all(color: _white10)),
              child: Text('All-Time', style: GoogleFonts.outfit(color: _white, fontSize: 9.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _sourceRow('Spotify', Icons.music_note_rounded, 0, pending: true),
        const SizedBox(height: 10),
        _sourceRow('Apple Music', Icons.apple_rounded, 0, pending: true),
        const SizedBox(height: 10),
        _sourceRow('YouTube', Icons.smart_display_rounded, ytActive ? 1.0 : 0.0, pending: false, count: _youtubeStreams),
      ]),
    );
  }

  Widget _sourceRow(String name, IconData icon, double fillFraction, {required bool pending, int count = 0}) {
    return Opacity(
      opacity: pending ? 0.55 : 1.0,
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: _black, borderRadius: BorderRadius.circular(8), border: Border.all(color: _white20)),
          child: Icon(icon, color: _white, size: 16),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(name, style: GoogleFonts.outfit(color: _white, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: fillFraction,
              minHeight: 5,
              backgroundColor: _black4,
              valueColor: const AlwaysStoppedAnimation(_white),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
          child: Text(
            pending ? 'Pending' : _fmt(count),
            textAlign: TextAlign.right,
            style: pending
                ? GoogleFonts.outfit(color: _greyDark, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)
                : GoogleFonts.outfit(color: _white, fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }

  // ══ TOP RELEASES — real per-release / per-track view totals ══
  Widget _topReleasesCard() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CardTitle(icon: Icons.library_music_rounded, label: 'Top Releases'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _white06, borderRadius: BorderRadius.circular(99), border: Border.all(color: _white10)),
              child: Text('By Streams', style: GoogleFonts.outfit(color: _white, fontSize: 9.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_releases.isEmpty)
          _emptyState(icon: Icons.album_rounded, text: 'Your releases will appear here once submitted.')
        else
          ...List.generate(_releases.length, (i) => _releaseTile(i, _releases[i])),
      ]),
    );
  }

  Widget _releaseTile(int index, _ReleaseEntry r) {
    // Literal parity with web: this page's badge checks for 'approved'
    // specifically (not 'live', used elsewhere in the app).
    final isApproved = r.status.toLowerCase() == 'approved';
    final isMultiTrack = r.breakdown.length > 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: _black4, borderRadius: BorderRadius.circular(12), border: Border.all(color: _white06)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(
              width: 20,
              child: Text('${index + 1}'.padLeft(2, '0'),
                  style: GoogleFonts.outfit(color: _greyDark, fontSize: 10.5, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: r.coverUrl.isNotEmpty
                  ? Image.network(r.coverUrl, width: 36, height: 36, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _discPlaceholder())
                  : _discPlaceholder(),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.title,
                    style: GoogleFonts.outfit(color: _white, fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${r.type} · ${r.genre}',
                    style: GoogleFonts.outfit(color: _grey, fontSize: 10.5), overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: 8),
            Text(
              r.hasRealData ? _fmt(r.total) : 'Pending',
              style: GoogleFonts.outfit(
                  color: r.hasRealData ? _white : _greyDark, fontSize: r.hasRealData ? 13 : 10.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isApproved ? _white10 : _white06,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: isApproved ? _white20 : _white10),
              ),
              child: Text(isApproved ? 'Approved' : r.status,
                  style: GoogleFonts.outfit(color: isApproved ? _white : _grey, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
          if (isMultiTrack) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: _white10, margin: const EdgeInsets.only(left: 34)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Column(
                children: r.breakdown.map((t) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(
                          child: Text(t.title,
                              style: GoogleFonts.outfit(color: _grey, fontSize: 11.5), overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                          t.views == null ? 'Pending' : _fmt(t.views!),
                          style: t.views == null
                              ? GoogleFonts.outfit(color: _greyDark, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.4)
                              : GoogleFonts.outfit(color: _grey, fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ]),
                    )).toList(),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _discPlaceholder() => Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: _white10, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.album_rounded, color: _white, size: 16),
      );

  Widget _emptyState({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        Icon(icon, color: _greyDark, size: 34),
        const SizedBox(height: 10),
        Text(text,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: _greyDark, fontSize: 12.5, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  LINE CHART PAINTER — cumulative area/line chart with a gradient
//  fill, matching the visual language of web's Chart.js line (white
//  line + fading white area, no blue anywhere).
// ════════════════════════════════════════════════════════════════════
class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double progress;
  const _LineChartPainter({required this.values, required this.labels, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const bottomPad = 20.0;
    final chartHeight = size.height - bottomPad;
    final maxVal = values.reduce(math.max);
    final range = maxVal <= 0 ? 1.0 : maxVal;
    final stepX = values.length > 1 ? size.width / (values.length - 1) : 0.0;

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = values.length > 1 ? stepX * i : size.width / 2;
      final yFrac = (values[i] / range).clamp(0.0, 1.0);
      final y = chartHeight - (yFrac * chartHeight * progress);
      points.add(Offset(x, y));
    }

    // gradient fill under the line
    final fillPath = Path()..moveTo(points.first.dx, chartHeight);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, chartHeight);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));
    canvas.drawPath(fillPath, fillPaint);

    // line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // points
    final pointPaint = Paint()..color = Colors.white;
    final ringPaint = Paint()
      ..color = const Color(0xFF101010)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final p in points) {
      canvas.drawCircle(p, 4, pointPaint);
      canvas.drawCircle(p, 4, ringPaint);
    }

    // x-axis labels
    for (int i = 0; i < labels.length && i < points.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: GoogleFonts.outfit(color: _greyDark, fontSize: 9.5, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (points[i].dx - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, size.height - bottomPad + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values != values || old.progress != progress || old.labels != labels;
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
          Text(label,
              style: GoogleFonts.outfit(color: _white, fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
        ],
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool hero;
  final String? badge;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.hero = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 16, 18),
      decoration: BoxDecoration(
        color: hero ? Colors.black : _black3,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hero ? _white20 : _white10),
        boxShadow: hero
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 10))]
            : null,
      ),
      child: Stack(children: [
        if (badge != null)
          Positioned(
            top: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: _white10, borderRadius: BorderRadius.circular(99)),
              child: Text(badge!, style: GoogleFonts.outfit(color: _white, fontSize: 9.5, fontWeight: FontWeight.w700)),
            ),
          ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: _white10, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: _white, size: 16),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: GoogleFonts.outfit(
                  color: _white, fontSize: hero ? 30 : 22, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text(label.toUpperCase(),
              style: GoogleFonts.outfit(
                  color: hero ? _white70.withValues(alpha: 0.6) : _grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6)),
        ]),
      ]),
    );
  }
}