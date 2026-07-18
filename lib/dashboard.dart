//  444MUSIC — My Releases Dashboard  (rebuilt to mirror web layout)
//  Theme: Black & White Luxury  |  Font: Nunito
//
//  LAYOUT CHANGE ONLY — mirrors the web dashboard (pricing/my-releases.html):
//    - search bar (title/artist)
//    - filter chips: All / Draft / In Review / Approved / Rejection
//    - list rows (index, thumb, title/artist/meta, days-left countdown,
//      chevron) instead of the old grid of big cards
//    - status/paid badges and the Pay Now / Promote / Check Reasons & Fix
//      actions now live inside the opened detail modal's top action bar,
//      exactly like the web version, instead of inline on each card.
//
//  BEHAVIOR — UNCHANGED from the previous Flutter screen:
//    - Pay Now still calls PaymentWaitingScreen with the real submission
//      id and isExistingSubmission: true
//    - paid/status still read from the real Firestore fields ('paid' as
//      text "Paid"/"Unpaid", 'status' as text) — no paymentVerified bool
//    - rejection flow still hands the full submission map to
//      onOpenRejection exactly as before
//    - cover art edit still base64-encodes and writes coverURL directly
//    - Smart Link / UPC generation logic is untouched
//
//  SIDEBAR — the only change here: "Pay Now" nav item is replaced with
//  "Watch Tutorials", linking to the YouTube channel.
// ═══════════════════════════════════════════════════════════════════
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'pricing_screen.dart'; // for PaymentWaitingScreen (Pay Now)

// ─── PALETTE ────────────────────────────────────────────────────────
const _black      = Color(0xFF000000);
const _black1     = Color(0xFF080808);
const _black2     = Color(0xFF0D0D0D);
const _black3     = Color(0xFF111111);
const _black4     = Color(0xFF161616);
const _white      = Color(0xFFFFFFFF);
const _white70    = Color(0xB3FFFFFF);
const _white40    = Color(0x66FFFFFF);
const _white20    = Color(0x33FFFFFF);
const _white10    = Color(0x1AFFFFFF);
const _white06    = Color(0x0FFFFFFF);
const _grey       = Color(0xFF888888);
const _greyDark   = Color(0xFF444444);
const _green      = Color(0xFF22C55E);
const _amber      = Color(0xFFF59E0B);
const _rose       = Color(0xFFEF4444);
const _cyan       = Color(0xFF06B6D4);

// ─── STATUS HELPERS (unchanged logic) ───────────────────────────────
Color _statusColor(String s) {
  switch (s.toLowerCase()) {
    case 'approved': return _green;
    case 'review':   return _cyan;
    case 'rejected': return _rose;
    default:         return _amber;
  }
}

// Display-only label mapping — matches the web dashboard's
// statusDisplayLabel(): Firestore keeps writing/reading "Pending" and
// "Rejected" exactly as before; only what's SHOWN on screen changes.
String _statusDisplayLabel(String rawStatus) {
  final s = rawStatus.trim();
  if (s.toLowerCase() == 'pending')  return 'Draft';
  if (s.toLowerCase() == 'rejected') return 'Rejection';
  return s.isEmpty ? 'Draft' : (s[0].toUpperCase() + s.substring(1));
}

bool _isPaidValue(dynamic paidField) =>
    (paidField ?? '').toString().toLowerCase() == 'paid';

double _priceForReleaseType(dynamic releaseType) {
  final t = (releaseType ?? '').toString().toLowerCase();
  if (t == 'single') return 39.99;
  return 69.99; // EP or Album (or unset — default to the higher tier)
}

// Days-left countdown — mirrors the web dashboard's
// releaseCountdownLabel() exactly: positive days only, nothing shown
// on/after release day.
String? _releaseCountdownLabel(dynamic releaseDateValue) {
  if (releaseDateValue == null) return null;
  DateTime releaseDate;
  try {
    if (releaseDateValue is Timestamp) {
      releaseDate = releaseDateValue.toDate();
    } else {
      releaseDate = DateTime.parse(releaseDateValue.toString());
    }
  } catch (_) {
    return null;
  }
  final now = DateTime.now();
  final startOfToday   = DateTime(now.year, now.month, now.day);
  final startOfRelease = DateTime(releaseDate.year, releaseDate.month, releaseDate.day);
  final diffDays = startOfRelease.difference(startOfToday).inDays;
  if (diffDays > 1) return '$diffDays days left';
  if (diffDays == 1) return '1 day left';
  return null; // releasing today or already out
}

// ─── UPC GENERATOR (unchanged) ───────────────────────────────────────
String _generateUPC() {
  final rng  = Random();
  String code = '731';
  for (int i = 0; i < 8; i++) code += rng.nextInt(10).toString();
  int odd = 0, even = 0;
  for (int i = 0; i < 11; i++) {
    final d = int.parse(code[i]);
    if (i % 2 == 0) odd += d; else even += d;
  }
  final check = (10 - ((odd * 3 + even) % 10)) % 10;
  return '$code$check';
}

String _formatUPC(String upc) {
  if (upc.length < 12) return upc;
  return '${upc.substring(0,3)} ${upc.substring(3,6)} ${upc.substring(6,9)} ${upc.substring(9)}';
}

String _buildSmartLinkURL(String artistName, String releaseTitle) {
  String toSlug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s\-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-');

  final aSlug = toSlug(artistName);
  final tRaw  = toSlug(releaseTitle);
  final tSlug = tRaw.length > 30 ? tRaw.substring(0, 30) : tRaw;
  return 'https://ffm.to/$aSlug-$tSlug';
}

Future<void> _launch(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _formatDate(dynamic d) {
  try {
    DateTime dt;
    if (d is Timestamp) dt = d.toDate();
    else dt = DateTime.parse(d.toString());
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day.toString().padLeft(2,'0')} ${months[dt.month-1]} ${dt.year}';
  } catch (_) { return d.toString(); }
}

// ─── STORE CONFIG (unchanged) ────────────────────────────────────────
class _StoreInfo {
  final String key, name, sub;
  final Color color;
  final IconData icon;
  const _StoreInfo(this.key, this.name, this.sub, this.color, this.icon);
}

const _stores = [
  _StoreInfo('spotifyLink',      'Spotify',       'Stream on Spotify',      Color(0xFF1DB954), Icons.music_note_rounded),
  _StoreInfo('appleMusicLink',   'Apple Music',   'Listen on Apple Music',  Color(0xFFFC3C44), Icons.apple_rounded),
  _StoreInfo('audiomackLink',    'Audiomack',     'Play on Audiomack',      Color(0xFFFFa200), Icons.headphones_rounded),
  _StoreInfo('boomplayLink',     'Boomplay',      'Listen on Boomplay',     Color(0xFFFF6600), Icons.play_circle_rounded),
  _StoreInfo('youtubeMusicLink', 'YouTube Music', 'Watch on YouTube Music', Color(0xFFFF0000), Icons.smart_display_rounded),
  _StoreInfo('tidalLink',        'Tidal',         'Stream on Tidal',        Color(0xFF00FEFD), Icons.water_rounded),
  _StoreInfo('deezerLink',       'Deezer',        'Play on Deezer',         Color(0xFFa238ff), Icons.equalizer_rounded),
  _StoreInfo('amazonMusicLink',  'Amazon Music',  'Listen on Amazon Music', Color(0xFF00A8E0), Icons.storefront_rounded),
];

// ════════════════════════════════════════════════════════════════════
//  RELEASES SCREEN
// ════════════════════════════════════════════════════════════════════
class ReleasesScreen extends StatefulWidget {
  const ReleasesScreen({super.key});
  @override
  State<ReleasesScreen> createState() => _ReleasesScreenState();
}

class _ReleasesScreenState extends State<ReleasesScreen> with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  User? get _user => _auth.currentUser;

  List<Map<String, dynamic>> _releases = [];
  List<Map<String, dynamic>> _filtered = [];
  bool   _loading     = true;
  String _filter      = 'all';
  String _searchQuery = '';
  bool   _sidebarOpen = false;

  final TextEditingController _searchCtrl = TextEditingController();

  late AnimationController _entranceCtrl;
  late Animation<double>   _entranceFade;
  late AnimationController _sidebarCtrl;
  late Animation<double>   _sidebarFade;
  late Animation<Offset>   _sidebarSlide;

  // Same underlying status keys as before — only the visible labels
  // changed, to match the web dashboard's chip wording.
  final _filters      = ['all', 'pending', 'review', 'approved', 'rejected'];
  final _filterLabels = {
    'all':      'All',
    'pending':  'Draft',
    'review':   'In Review',
    'approved': 'Approved',
    'rejected': 'Rejection',
  };

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));
    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entranceFade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _sidebarCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 340));
    _sidebarFade  = CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOut);
    _sidebarSlide = Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOutCubic));
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q != _searchQuery) {
        _searchQuery = q;
        _recomputeFiltered();
      }
    });
    _loadReleases();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _sidebarCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openSidebar()  { setState(() => _sidebarOpen = true);  _sidebarCtrl.forward(); }
  void _closeSidebar() {
    _sidebarCtrl.reverse().then((_) { if (mounted) setState(() => _sidebarOpen = false); });
  }

  Future<void> _loadReleases() async {
    if (_user == null) return;
    try {
      final snap = await _db
          .collection('submissions')
          .where('userId', isEqualTo: _user!.uid)
          .get();

      final list = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['_id'] = doc.id;
        final status = (data['status'] ?? 'Pending').toString().toLowerCase();
        if (status == 'approved' && (data['upc'] == null || data['smartLinkURL'] == null)) {
          final upc = _generateUPC();
          final url = _buildSmartLinkURL(data['artistName'] ?? '', data['releaseTitle'] ?? '');
          await doc.reference.update({'upc': upc, 'smartLinkURL': url, 'smartLinkGeneratedAt': FieldValue.serverTimestamp()});
          data['upc'] = upc;
          data['smartLinkURL'] = url;
        }
        list.add(data);
      }

      // Newest first, same ordering the web dashboard uses.
      list.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        final aMs = aTime is Timestamp ? aTime.millisecondsSinceEpoch : (aTime is int ? aTime : 0);
        final bMs = bTime is Timestamp ? bTime.millisecondsSinceEpoch : (bTime is int ? bTime : 0);
        return bMs.compareTo(aMs);
      });

      if (mounted) {
        _releases = list;
        _loading = false;
        _recomputeFiltered();
        _entranceCtrl.forward();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter(String f) {
    _filter = f;
    _recomputeFiltered();
  }

  void _recomputeFiltered() {
    setState(() {
      Iterable<Map<String, dynamic>> base = _releases;
      if (_filter != 'all') {
        base = base.where((r) => (r['status'] ?? 'Pending').toString().toLowerCase() == _filter);
      }
      if (_searchQuery.isNotEmpty) {
        base = base.where((r) {
          final title  = (r['releaseTitle'] ?? '').toString().toLowerCase();
          final artist = (r['artistName']  ?? '').toString().toLowerCase();
          return title.contains(_searchQuery) || artist.contains(_searchQuery);
        });
      }
      _filtered = base.toList();
    });
  }

  String get _firstName {
    final name = _user?.displayName ?? 'Artist';
    return name.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _black,
      extendBody: true,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _loading ? const AlwaysStoppedAnimation(1) : _entranceFade,
            child: Column(
              children: [
                SizedBox(height: top),
                _buildTopBar(),
                Expanded(child: _loading ? _buildSkeletons() : _buildBody(bottom)),
              ],
            ),
          ),

          if (_sidebarOpen)
            GestureDetector(
              onTap: _closeSidebar,
              child: FadeTransition(
                opacity: _sidebarFade,
                child: Container(color: Colors.black.withValues(alpha: 0.7)),
              ),
            ),

          if (_sidebarOpen)
            SlideTransition(
              position: _sidebarSlide,
              child: _buildSidebar(top, bottom),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: _black,
        border: Border(bottom: BorderSide(color: _white10)),
      ),
      child: Row(
        children: [
          _IconBtn(icon: Icons.menu_rounded, onTap: _openSidebar),
          const SizedBox(width: 12),
          Text(
            'My Releases',
            style: GoogleFonts.outfit(color: _white, fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          _TopBtn(
            label: 'New Release',
            icon: Icons.add_circle_outline_rounded,
            onTap: () => Navigator.pushNamed(context, '/upload'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(double bottom) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          _buildSearchBar(),
          const SizedBox(height: 16),
          _buildSectionHeader(),
          const SizedBox(height: 10),
          _buildFilterRow(),
          const SizedBox(height: 16),
          _releases.isEmpty ? _buildEmptyState() : _buildRows(),
        ],
      ),
    );
  }

  // ── SEARCH BAR — mirrors the web's search-bar-wrap ───────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: _black2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _white10),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: _greyDark, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.nunito(color: _white, fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search by title or artist...',
                  hintStyle: GoogleFonts.nunito(color: _greyDark, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            if (_searchCtrl.text.trim().isNotEmpty)
              GestureDetector(
                onTap: () { _searchCtrl.clear(); },
                child: Container(
                  width: 20, height: 20,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(color: _white10, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: _grey, size: 12),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Text('All Releases', style: GoogleFonts.nunito(color: _white, fontSize: 15, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('${_filtered.length} release${_filtered.length != 1 ? 's' : ''}',
              style: GoogleFonts.nunito(color: _grey, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f      = _filters[i];
          final active = f == _filter;
          return GestureDetector(
            onTap: () => _applyFilter(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: active ? _white : _black2,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: active ? _white : _white10),
              ),
              child: Text(
                _filterLabels[f]!,
                style: GoogleFonts.nunito(
                  color: active ? _black : _grey,
                  fontSize: 12, fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── LIST ROWS — mirrors the web's release-row layout exactly ────
  Widget _buildRows() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(_filtered.length, (i) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 300 + i * 45),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => Transform.translate(
              offset: Offset(0, 8 * (1 - v)),
              child: Opacity(opacity: v, child: child),
            ),
            child: _ReleaseRow(
              index: i,
              data: _filtered[i],
              db: _db,
              onRefresh: _loadReleases,
              onOpenRejection: (data) =>
                  Navigator.pushNamed(context, '/rejection', arguments: data)
                      .then((_) => _loadReleases()),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: _black2, borderRadius: BorderRadius.circular(20), border: Border.all(color: _white10)),
              child: const Icon(Icons.music_note_rounded, color: _grey, size: 34),
            ),
            const SizedBox(height: 18),
            Text('No releases yet', style: GoogleFonts.nunito(color: _white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Create your first release to start distributing\nyour music worldwide.',
              style: GoogleFonts.nunito(color: _grey, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/upload'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded, color: _black, size: 18),
                  const SizedBox(width: 8),
                  Text('New Release', style: GoogleFonts.nunito(color: _black, fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletons() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(4, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SkeletonRow(),
        )),
      ),
    );
  }

  // ── SIDEBAR — unchanged except Pay Now -> Watch Tutorials ────────
  Widget _buildSidebar(double top, double bottom) {
    final w = MediaQuery.of(context).size.width * 0.78;
    return Container(
      width: w, height: double.infinity,
      color: _black1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, top + 18, 20, 18),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _white10))),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.music_note_rounded, color: _black, size: 18),
                ),
                const SizedBox(width: 10),
                Text('444Music', style: GoogleFonts.nunito(color: _white, fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                GestureDetector(
                  onTap: _closeSidebar,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(border: Border.all(color: _white10), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded, color: _grey, size: 17),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _white06, borderRadius: BorderRadius.circular(14), border: Border.all(color: _white10)),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _white20, border: Border.all(color: _white20)),
                    child: Center(child: Text(
                      _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'A',
                      style: GoogleFonts.nunito(color: _white, fontSize: 16, fontWeight: FontWeight.w800),
                    )),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_user?.displayName ?? 'Artist',
                          style: GoogleFonts.nunito(color: _white, fontSize: 13, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis),
                      Text(_user?.email ?? '',
                          style: GoogleFonts.nunito(color: _grey, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ],
                  )),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SidebarSection(label: 'Main'),
                  _SidebarItem(icon: Icons.home_rounded,          label: 'Home',               onTap: () { _closeSidebar(); Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false); }),
                  _SidebarItem(icon: Icons.library_music_rounded, label: 'My Releases',        onTap: _closeSidebar, active: true),
                  _SidebarItem(icon: Icons.cloud_upload_rounded,  label: 'New Release',        onTap: () { _closeSidebar(); Future.delayed(const Duration(milliseconds: 300), () => Navigator.pushNamed(context, '/upload')); }),
                  _SidebarSection(label: 'Finance'),
                  _SidebarItem(icon: Icons.attach_money_rounded,  label: 'Royalties',          onTap: () { _closeSidebar(); Future.delayed(const Duration(milliseconds: 300), () => Navigator.pushNamed(context, '/earnings')); }),
                  // ── CHANGED: was "Pay Now" -> pay.html; now "Watch Tutorials" -> YouTube channel.
                  _SidebarItem(icon: Icons.ondemand_video_rounded, label: 'Watch Tutorials', onTap: () { _closeSidebar(); _launch('https://www.youtube.com/@444musicdistribution'); }),
                  _SidebarItem(icon: Icons.call_split_rounded,    label: 'Royalty Split',      onTap: () { _closeSidebar(); Future.delayed(const Duration(milliseconds: 300), () async {
                    final Uri url = Uri.parse('https://444music-distribution.vercel.app/splits');
                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                      throw Exception('Could not launch $url');
                    }
                  }); }),
                  _SidebarSection(label: 'Tools'),
                  _SidebarItem(icon: Icons.trending_up_rounded,   label: 'Promote / Playlist', onTap: () { _closeSidebar(); _launch('https://444musicblog.vercel.app'); }),
                  _SidebarItem(icon: Icons.bar_chart_rounded,     label: 'Analytics',          onTap: () { _closeSidebar(); Future.delayed(const Duration(milliseconds: 300), () => Navigator.pushNamed(context, '/analytics')); }),
                  _SidebarItem(icon: Icons.help_outline_rounded,  label: 'Support',            onTap: () { _closeSidebar(); Future.delayed(const Duration(milliseconds: 300), () => Navigator.pushNamed(context, '/support')); }),
                  _SidebarItem(icon: Icons.speed_rounded,         label: 'Dashboard',          onTap: () { _closeSidebar(); Future.delayed(const Duration(milliseconds: 300), () => Navigator.pushNamed(context, '/dashboard')); }),
                  const _SidebarDivider(),
                ],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, bottom + 14),
            child: GestureDetector(
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                _closeSidebar();
                if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade900.withValues(alpha: 0.22)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.logout_rounded, color: Color(0xFFFF6B6B), size: 17),
                  const SizedBox(width: 9),
                  Text('Logout', style: GoogleFonts.nunito(color: const Color(0xFFFF6B6B), fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  RELEASE ROW — replaces the old big card; mirrors the web's
//  release-row grid: index | thumb | title/artist/meta | countdown+chevron
// ════════════════════════════════════════════════════════════════════
class _ReleaseRow extends StatefulWidget {
  final int index;
  final Map<String, dynamic> data;
  final FirebaseFirestore db;
  final VoidCallback onRefresh;
  final void Function(Map<String, dynamic>) onOpenRejection;
  const _ReleaseRow({
    required this.index,
    required this.data,
    required this.db,
    required this.onRefresh,
    required this.onOpenRejection,
  });
  @override
  State<_ReleaseRow> createState() => _ReleaseRowState();
}

class _ReleaseRowState extends State<_ReleaseRow> {
  bool _pressed = false;

  String get _status    => (widget.data['status'] ?? 'Pending').toString().trim();
  bool   get _isPending => _status.toLowerCase() == 'pending';

  void _openModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReleaseDetailModal(
        data: widget.data,
        db: widget.db,
        onRefresh: widget.onRefresh,
        onOpenRejection: widget.onOpenRejection,
      ),
    );
  }

  Widget _buildThumb() {
    final url = widget.data['coverURL']?.toString() ?? '';
    const size = 62.0;
    Widget child;
    if (url.isEmpty) {
      child = const Icon(Icons.music_note_rounded, color: _greyDark, size: 20);
    } else if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        child = Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
      } catch (_) {
        child = const Icon(Icons.music_note_rounded, color: _greyDark, size: 20);
      }
    } else {
      child = CachedNetworkImage(
        imageUrl: url, width: size, height: size, fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: _black3),
        errorWidget: (_, __, ___) => const Icon(Icons.music_note_rounded, color: _greyDark, size: 20),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size, height: size, color: _black3,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final releaseDate = widget.data['releaseDate'] != null ? _formatDate(widget.data['releaseDate']) : 'TBA';
    final countdown    = _releaseCountdownLabel(widget.data['releaseDate']);
    final releaseType  = (widget.data['releaseType'] ?? 'Single').toString().toUpperCase();
    final featuring    = (widget.data['featuring'] ?? '').toString().trim();

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); _openModal(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: _pressed ? _black2 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: const Border(bottom: BorderSide(color: _white10)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '${widget.index + 1}',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: _greyDark, fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            _buildThumb(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.data['releaseTitle'] ?? 'Untitled Release',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(color: _white, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    featuring.isNotEmpty
                        ? '${widget.data['artistName'] ?? 'Unknown Artist'} ft. $featuring'
                        : (widget.data['artistName'] ?? 'Unknown Artist'),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(color: _grey, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(releaseType,
                          style: GoogleFonts.nunito(color: _grey, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                      const SizedBox(width: 7),
                      Container(width: 3, height: 3, decoration: BoxDecoration(color: _greyDark, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          '${_isPending ? "Scheduled: " : "Release: "}$releaseDate',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(color: _greyDark, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (countdown != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _amber.withValues(alpha: 0.3)),
                    ),
                    child: Text(countdown, style: GoogleFonts.nunito(color: _amber, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right_rounded, color: _greyDark, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatefulWidget {
  @override
  State<_SkeletonRow> createState() => _SkeletonRowState();
}
class _SkeletonRowState extends State<_SkeletonRow> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _a = Tween<double>(begin: -2, end: 2).animate(_c);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _white10))),
        child: Row(children: [
          Container(width: 62, height: 62, decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(begin: Alignment(_a.value - 1, 0), end: Alignment(_a.value + 1, 0), colors: [_black3, _black4, _black3]),
          )),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _shimmerLine(0.6), const SizedBox(height: 8), _shimmerLine(0.4),
          ])),
        ]),
      ),
    );
  }
  Widget _shimmerLine(double w) => FractionallySizedBox(
    widthFactor: w,
    child: Container(height: 12, decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(6))),
  );
}

// ════════════════════════════════════════════════════════════════════
//  RELEASE DETAIL MODAL — same metadata/credits/smart-link content as
//  before, PLUS a top action bar (Pay Now / Promote / Check Reasons &
//  Fix) mirroring the web dashboard's modal-top-action, since those
//  actions no longer live inline on the row.
// ════════════════════════════════════════════════════════════════════
class _ReleaseDetailModal extends StatefulWidget {
  final Map<String, dynamic> data;
  final FirebaseFirestore db;
  final VoidCallback onRefresh;
  final void Function(Map<String, dynamic>) onOpenRejection;
  const _ReleaseDetailModal({
    required this.data,
    required this.db,
    required this.onRefresh,
    required this.onOpenRejection,
  });
  @override
  State<_ReleaseDetailModal> createState() => _ReleaseDetailModalState();
}

class _ReleaseDetailModalState extends State<_ReleaseDetailModal> {
  bool    _generatingLink = false;
  String? _copiedMsg;
  bool    _coverUploading = false;

  String get _id          => widget.data['_id'] ?? '';
  String get _status      => (widget.data['status'] ?? 'Pending').toString().trim();
  bool   get _isApproved  => _status.toLowerCase() == 'approved';
  bool   get _isRejected  => _status.toLowerCase() == 'rejected';
  bool   get _isPending   => _status.toLowerCase() == 'pending';

  late Map<String, dynamic> _data;

  bool get _isPaid       => _isPaidValue(_data['paid']);
  bool get _needsPayment => _isPending && !_isPaid;

  @override
  void initState() {
    super.initState();
    _data = Map.from(widget.data);
    if (_isApproved && (_data['upc'] == null || _data['smartLinkURL'] == null)) {
      _generateSmartLink();
    }
  }

  Future<void> _generateSmartLink() async {
    if (!mounted) return;
    setState(() => _generatingLink = true);
    try {
      final snap     = await widget.db.collection('submissions').doc(_id).get();
      final existing = snap.data() ?? {};
      if (existing['upc'] != null && existing['smartLinkURL'] != null) {
        setState(() {
          _data['upc']          = existing['upc'];
          _data['smartLinkURL'] = existing['smartLinkURL'];
          _generatingLink       = false;
        });
        return;
      }
      final upc = _generateUPC();
      final url = _buildSmartLinkURL(_data['artistName'] ?? '', _data['releaseTitle'] ?? '');
      await widget.db.collection('submissions').doc(_id).update({
        'upc': upc, 'smartLinkURL': url, 'smartLinkGeneratedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() { _data['upc'] = upc; _data['smartLinkURL'] = url; _generatingLink = false; });
      widget.onRefresh();
    } catch (e) {
      if (mounted) setState(() => _generatingLink = false);
    }
  }

  void _copyLink() {
    final url = _data['smartLinkURL']?.toString() ?? '';
    if (url.isEmpty) return;
    Clipboard.setData(ClipboardData(text: url));
    setState(() => _copiedMsg = 'Copied!');
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _copiedMsg = null); });
  }

  void _share() {
    final url    = _data['smartLinkURL']?.toString() ?? '';
    final title  = _data['releaseTitle']?.toString() ?? '';
    final artist = _data['artistName']?.toString() ?? '';
    if (url.isEmpty) return;
    Share.share('Listen to "$title" by $artist on all streaming platforms\n$url');
  }

  // ── Pay Now — unchanged from the previous card's _payNow: real
  // submission id, isExistingSubmission: true, price auto-picked from
  // releaseType. ──
  Future<void> _payNow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _id.isEmpty) return;
    final amount = _priceForReleaseType(_data['releaseType']);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentWaitingScreen(
          amountGHS: amount,
          submissionId: _id,
          uid: user.uid,
          email: user.email ?? '',
          successRouteName: '/releases',
          isExistingSubmission: true,
        ),
      ),
    );
    widget.onRefresh();
  }

  // ── Cover art edit — unchanged base64 logic, now reachable via the
  // pencil control on the modal's cover strip. ──
  Future<void> _editCoverArt() async {
    final picker = ImagePicker();
    final file   = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (file == null) return;
    setState(() => _coverUploading = true);
    try {
      final bytes     = await file.readAsBytes();
      final base64Str = base64Encode(bytes);
      final dataUrl   = 'data:image/jpeg;base64,$base64Str';
      await widget.db.collection('submissions').doc(_id).update({'coverURL': dataUrl});
      if (mounted) setState(() { _data['coverURL'] = dataUrl; _coverUploading = false; });
      widget.onRefresh();
    } catch (e) {
      if (mounted) setState(() => _coverUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: _black2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          _ModalHeader(title: 'Release Details', subtitle: _data['releaseTitle'] ?? ''),
          Container(height: 1, decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, _white40, Colors.transparent]),
          )),
          _buildTopAction(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCoverStrip(),
                  const SizedBox(height: 20),

                  if (_isApproved) ...[
                    _MetaSectionLabel(label: 'Smart Link & UPC', icon: Icons.link_rounded),
                    const SizedBox(height: 10),
                    _generatingLink ? _buildGeneratingCard() : _buildSmartLinkCard(),
                    const SizedBox(height: 22),
                  ],

                  _MetaSectionLabel(label: 'Status', icon: Icons.info_outline_rounded),
                  const SizedBox(height: 10),
                  _buildStatusRow(),
                  if (_isRejected && (_data['rejectionReason'] ?? '').toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: _rose.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _rose.withValues(alpha: 0.25)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('REASON FOR REJECTION', style: GoogleFonts.nunito(color: _rose, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        const SizedBox(height: 5),
                        Text(_data['rejectionReason'] ?? '', style: GoogleFonts.nunito(color: _white70, fontSize: 13, height: 1.5)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 22),

                  _MetaSectionLabel(label: 'Artist & Release', icon: Icons.person_rounded),
                  const SizedBox(height: 10),
                  _buildMetaGrid([
                    _MetaField(label: 'Main Artist',   value: _data['artistName']),
                    if ((_data['featuring'] ?? '').toString().trim().isNotEmpty)
                      _MetaField(label: 'Featuring',   value: _data['featuring'], full: true),
                    _MetaField(label: 'Release Title', value: _data['releaseTitle'], full: true),
                    _MetaField(label: 'Type',          value: _data['releaseType']),
                    _MetaField(label: 'Genre',         value: _data['genre']),
                    _MetaField(label: 'Language',      value: _data['language']),
                    _MetaField(label: 'Release Date',  value: _data['releaseDate'] != null ? _formatDate(_data['releaseDate']) : null),
                    _MetaField(label: 'Explicit',      value: _data['explicit']?.toString() ?? 'No'),
                  ]),
                  const SizedBox(height: 22),

                  _MetaSectionLabel(label: 'Label & Rights', icon: Icons.verified_rounded),
                  const SizedBox(height: 10),
                  _buildMetaGrid([
                    _MetaField(label: 'Label Name',       value: _data['label'] ?? 'Independent'),
                    _MetaField(label: 'Copyright Holder', value: _data['copyright']),
                  ]),
                  const SizedBox(height: 22),

                  _MetaSectionLabel(label: 'Identifiers', icon: Icons.qr_code_rounded),
                  const SizedBox(height: 10),
                  _buildMetaGrid([
                    _MetaField(label: 'ISRC Code',     value: _data['isrc'],        mono: true),
                    _MetaField(label: 'UPC / Barcode', value: _data['upc'] != null ? _formatUPC(_data['upc']) : (_isApproved ? 'Generating…' : 'Auto-assign'), mono: true),
                    _MetaField(label: 'Catalog No.',   value: _data['catalogNumber']),
                  ]),
                  const SizedBox(height: 22),

                  _MetaSectionLabel(label: 'Contact & Location', icon: Icons.location_on_rounded),
                  const SizedBox(height: 10),
                  _buildMetaGrid([
                    _MetaField(label: 'Country', value: _data['country']),
                    _MetaField(label: 'Phone',   value: _data['phone']),
                    _MetaField(label: 'Email',   value: _data['email'], full: true),
                    if ((_data['refferal'] ?? '').toString().trim().isNotEmpty)
                      _MetaField(label: 'Referral Code', value: _data['refferal']),
                  ]),

                  if (_hasCredits) ...[
                    const SizedBox(height: 22),
                    _MetaSectionLabel(label: 'Production Credits', icon: Icons.star_rounded),
                    const SizedBox(height: 10),
                    _buildCreditsSection(),
                  ],

                  if ((_data['description'] ?? '').toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _MetaSectionLabel(label: 'Lyrics / Notes', icon: Icons.lyrics_rounded),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(12), border: Border.all(color: _white10)),
                      child: Text(_data['description'] ?? '',
                          style: GoogleFonts.nunito(color: _white70, fontSize: 12, height: 1.8)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TOP ACTION BAR — mirrors renderModalTopAction() on the web:
  // Pay Now for pending+unpaid, Promote for approved, Check Reasons &
  // Fix for rejected. Same underlying callbacks as before. ──
  Widget _buildTopAction() {
    if (_needsPayment) {
      final price = _priceForReleaseType(_data['releaseType']);
      return GestureDetector(
        onTap: _payNow,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: _cyan.withValues(alpha: 0.14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.credit_card_rounded, color: _cyan, size: 16),
            const SizedBox(width: 8),
            Text('Pay GHC ${price.toStringAsFixed(2)} to Release',
                style: GoogleFonts.nunito(color: _cyan, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
    }
    if (_isApproved) {
      return GestureDetector(
        onTap: () => _launch('https://444musicblog.vercel.app'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: _amber.withValues(alpha: 0.14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.trending_up_rounded, color: _amber, size: 16),
            const SizedBox(width: 8),
            Text('Promote This Release',
                style: GoogleFonts.nunito(color: _amber, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
    }
    if (_isRejected) {
      return GestureDetector(
        onTap: () { Navigator.pop(context); widget.onOpenRejection(_data); },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: _rose.withValues(alpha: 0.14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.info_rounded, color: _rose, size: 16),
            const SizedBox(width: 8),
            Text('Check Reasons & Fix',
                style: GoogleFonts.nunito(color: _rose, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  bool get _hasCredits {
    final c = _data['credits'];
    if (c == null || c is! Map) return false;
    for (final key in ['producer', 'musician', 'writer', 'publishing']) {
      final list = c[key];
      if (list is List && list.any((x) => x is Map && (x['name'] ?? '').toString().trim().isNotEmpty)) return true;
    }
    return false;
  }

  Widget _buildCoverStrip() {
    final url = _data['coverURL']?.toString() ?? '';
    const h   = 190.0;
    Widget img;
    if (url.isNotEmpty && url.startsWith('data:image')) {
      try {
        img = Image.memory(base64Decode(url.split(',').last), height: h, width: double.infinity, fit: BoxFit.cover);
      } catch (_) { img = Container(height: h, color: _black3, width: double.infinity, child: const Icon(Icons.music_note_rounded, color: _greyDark, size: 40)); }
    } else if (url.isNotEmpty) {
      img = CachedNetworkImage(imageUrl: url, height: h, width: double.infinity, fit: BoxFit.cover,
          placeholder: (_, __) => Container(height: h, color: _black3),
          errorWidget: (_, __, ___) => Container(height: h, color: _black3, width: double.infinity, child: const Icon(Icons.music_note_rounded, color: _greyDark, size: 40)));
    } else {
      img = Container(height: h, color: _black3, width: double.infinity, child: const Icon(Icons.music_note_rounded, color: _greyDark, size: 40));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          img,
          Positioned(bottom: 0, left: 0, right: 0,
            child: Container(height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [_black2, Colors.transparent]),
              ),
            ),
          ),
          // ── Cover edit control — mirrors the web's meta-cover-edit-btn ──
          Positioned(
            bottom: 12, right: 14,
            child: GestureDetector(
              onTap: _coverUploading ? null : _editCoverArt,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _white20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _coverUploading
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: _white))
                      : const Icon(Icons.edit_rounded, color: _white, size: 12),
                  const SizedBox(width: 6),
                  Text(_coverUploading ? 'Uploading…' : 'Change Cover',
                      style: GoogleFonts.nunito(color: _white, fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(14), border: Border.all(color: _white10)),
      child: Row(children: [
        const SizedBox(width: 28, height: 28,
            child: CircularProgressIndicator(strokeWidth: 2, color: _white, backgroundColor: _white10)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Generating Smart Link & UPC…', style: GoogleFonts.nunito(color: _white, fontSize: 13, fontWeight: FontWeight.w700)),
          Text('Setting up your release profile', style: GoogleFonts.nunito(color: _grey, fontSize: 11)),
        ])),
      ]),
    );
  }

  Widget _buildSmartLinkCard() {
    final url = _data['smartLinkURL']?.toString() ?? '';
    final upc = _data['upc']?.toString() ?? '';
    return Container(
      decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(16), border: Border.all(color: _white20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 2, decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            gradient: LinearGradient(colors: [_white40, _white, _white40]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              const Icon(Icons.link_rounded, color: _white70, size: 15),
              const SizedBox(width: 6),
              Text('Smart Link', style: GoogleFonts.nunito(color: _white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const Spacer(),
              const _LiveDot(),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: _black4, borderRadius: BorderRadius.circular(10), border: Border.all(color: _white10)),
              child: Row(children: [
                const Icon(Icons.language_rounded, color: _grey, size: 15),
                const SizedBox(width: 8),
                Expanded(child: Text(url,
                    style: const TextStyle(color: _white70, fontSize: 11, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _copyLink,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _copiedMsg != null ? _green : _white,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(_copiedMsg ?? 'Copy',
                        style: GoogleFonts.nunito(color: _copiedMsg != null ? _white : _black, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
            ),
          ),
          if (upc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: _cyan.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(9), border: Border.all(color: _cyan.withValues(alpha: 0.18))),
                child: Row(children: [
                  Icon(Icons.qr_code_rounded, color: _cyan.withValues(alpha: 0.7), size: 14),
                  const SizedBox(width: 6),
                  Text('UPC / Barcode', style: GoogleFonts.nunito(color: _cyan.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const Spacer(),
                  Text(_formatUPC(upc), style: GoogleFonts.nunito(color: _white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: _stores.map((s) {
                final hasLink = (_data[s.key] ?? '').toString().trim().isNotEmpty;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasLink ? _white.withValues(alpha: 0.08) : _black4,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: hasLink ? _white20 : _white06),
                  ),
                  child: Text(s.name, style: GoogleFonts.nunito(color: hasLink ? _white : _greyDark, fontSize: 10, fontWeight: FontWeight.w700)),
                );
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _white10))),
            child: Row(children: [
              Expanded(child: _SlBtn(label: 'Open Smart Link', icon: Icons.open_in_new_rounded, primary: true, onTap: () => _launch(url))),
              const SizedBox(width: 8),
              Expanded(child: _SlBtn(label: 'Share', icon: Icons.share_rounded, green: true, onTap: _share)),
            ]),
          ),
          if (_stores.any((s) => (_data[s.key] ?? '').toString().trim().isNotEmpty))
            _buildStoreLinks(),
        ],
      ),
    );
  }

  Widget _buildStoreLinks() {
    final active = _stores.where((s) => (_data[s.key] ?? '').toString().trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: _white10, height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Listen Now', style: GoogleFonts.nunito(color: _grey, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        ),
        ...active.map((s) => GestureDetector(
          onTap: () => _launch(_data[s.key] ?? ''),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(color: _black4, borderRadius: BorderRadius.circular(12), border: Border.all(color: _white06)),
              child: Row(children: [
                Container(width: 34, height: 34,
                    decoration: BoxDecoration(color: s.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Icon(s.icon, color: s.color, size: 17)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, style: GoogleFonts.nunito(color: _white, fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(s.sub,  style: GoogleFonts.nunito(color: _grey,  fontSize: 10)),
                ])),
                const Icon(Icons.chevron_right_rounded, color: _greyDark, size: 18),
              ]),
            ),
          ),
        )),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildStatusRow() {
    final submittedAt = _data['createdAt'] is Timestamp
        ? _formatDate((_data['createdAt'] as Timestamp).toDate())
        : '';
    final displayLabel = _statusDisplayLabel(_status);
    final c = _statusColor(_status);
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(7), border: Border.all(color: c.withValues(alpha: 0.5))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 5, height: 5, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 5),
            Text(displayLabel, style: GoogleFonts.nunito(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
        _PaidBadge(paid: _isPaid),
        if (submittedAt.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(7), border: Border.all(color: _white10)),
            child: Text('Submitted $submittedAt', style: GoogleFonts.nunito(color: _grey, fontSize: 11)),
          ),
      ],
    );
  }

  Widget _buildMetaGrid(List<_MetaField> fields) {
    return Wrap(spacing: 8, runSpacing: 8,
        children: fields.map((f) => _MetaFieldWidget(field: f)).toList());
  }

  Widget _buildCreditsSection() {
    final credits = _data['credits'];
    if (credits == null || credits is! Map) return const SizedBox();
    const sections = [
      ('producer',   'Producers & Engineers'),
      ('musician',   'Musicians'),
      ('writer',     'Songwriters'),
      ('publishing', 'Publishing & PRO'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((s) {
        final list  = credits[s.$1];
        if (list == null || list is! List) return const SizedBox();
        final valid = list.where((x) => x is Map && (x['name'] ?? '').toString().trim().isNotEmpty).toList();
        if (valid.isEmpty) return const SizedBox();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.$2, style: GoogleFonts.nunito(color: _grey, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          ...valid.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(10), border: Border.all(color: _white10)),
              child: Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c['name'] ?? '', style: GoogleFonts.nunito(color: _white, fontSize: 13, fontWeight: FontWeight.w700)),
                  if ((c['role'] ?? '').toString().trim().isNotEmpty)
                    Text(c['role'] ?? '', style: GoogleFonts.nunito(color: _grey, fontSize: 11)),
                  if ((c['ipi'] ?? '').toString().trim().isNotEmpty)
                    Text('IPI: ${c['ipi']}', style: GoogleFonts.nunito(color: _greyDark, fontSize: 10)),
                ])),
              ]),
            ),
          )),
          const SizedBox(height: 10),
        ]);
      }).toList(),
    );
  }
}

// ── META FIELD ───────────────────────────────────────────────────────
class _MetaField {
  final String label;
  final dynamic value;
  final bool full;
  final bool mono;
  const _MetaField({required this.label, this.value, this.full = false, this.mono = false});
}

class _MetaFieldWidget extends StatelessWidget {
  final _MetaField field;
  const _MetaFieldWidget({required this.field});

  @override
  Widget build(BuildContext context) {
    final val     = field.value?.toString().trim() ?? '';
    final screenW = MediaQuery.of(context).size.width;
    final w       = field.full ? screenW - 40 : (screenW - 48) / 2;
    return SizedBox(
      width: w,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(10), border: Border.all(color: _white10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(field.label.toUpperCase(),
              style: GoogleFonts.nunito(color: _greyDark, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(
            val.isEmpty ? '—' : val,
            style: field.mono
                ? TextStyle(fontFamily: 'monospace', color: val.isEmpty ? _greyDark : _white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.08)
                : GoogleFonts.nunito(color: val.isEmpty ? _greyDark : _white, fontSize: 13, fontWeight: FontWeight.w600,
                fontStyle: val.isEmpty ? FontStyle.italic : FontStyle.normal),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS (unchanged)
// ════════════════════════════════════════════════════════════════════
class _PaidBadge extends StatelessWidget {
  final bool paid;
  const _PaidBadge({required this.paid});
  @override
  Widget build(BuildContext context) {
    final c = paid ? _green : _amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(7), border: Border.all(color: c.withValues(alpha: 0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(paid ? 'Paid' : 'Unpaid', style: GoogleFonts.nunito(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}
class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    FadeTransition(opacity: _c, child: Container(width: 5, height: 5, decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(3)))),
    const SizedBox(width: 5),
    Text('Live', style: GoogleFonts.nunito(color: _green, fontSize: 11, fontWeight: FontWeight.w700)),
  ]);
}

class _SlBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final bool green;
  const _SlBtn({required this.label, required this.icon, required this.onTap, this.primary = false, this.green = false});
  @override
  Widget build(BuildContext context) {
    Color bg = _black4; Color fg = _white70; Color border = _white10;
    if (primary) { bg = _white;  fg = _black;  border = _white; }
    if (green)   { bg = _green.withValues(alpha: 0.1); fg = _green; border = _green.withValues(alpha: 0.4); }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9), border: Border.all(color: border)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: fg, size: 13),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.nunito(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _MetaSectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MetaSectionLabel({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: _white70, size: 13),
    const SizedBox(width: 7),
    Text(label.toUpperCase(), style: GoogleFonts.nunito(color: _white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
    const SizedBox(width: 10),
    Expanded(child: Container(height: 1, decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [_white20, Colors.transparent]),
    ))),
  ]);
}

class _ModalHeader extends StatelessWidget {
  final String title, subtitle;
  const _ModalHeader({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(children: [
    const SizedBox(height: 10),
    Container(width: 36, height: 4, decoration: BoxDecoration(color: _white20, borderRadius: BorderRadius.circular(2))),
    const SizedBox(height: 14),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.nunito(color: _white, fontSize: 16, fontWeight: FontWeight.w800)),
          if (subtitle.isNotEmpty)
            Text(subtitle, style: GoogleFonts.nunito(color: _grey, fontSize: 12), overflow: TextOverflow.ellipsis),
        ])),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: _black3, shape: BoxShape.circle, border: Border.all(color: _white10)),
            child: const Icon(Icons.close_rounded, color: _grey, size: 15),
          ),
        ),
      ]),
    ),
    const SizedBox(height: 14),
  ]);
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(color: _white06, borderRadius: BorderRadius.circular(11), border: Border.all(color: _white10)),
      child: Icon(icon, color: _white, size: 19),
    ),
  );
}

class _TopBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _TopBtn({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _black, size: 14),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.nunito(color: _black, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    ),
  );
}

class _SidebarSection extends StatelessWidget {
  final String label;
  const _SidebarSection({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 12, 22, 6),
    child: Text(label.toUpperCase(),
        style: GoogleFonts.nunito(color: _greyDark, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2)),
  );
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _SidebarItem({required this.icon, required this.label, required this.onTap, this.active = false});
  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}
class _SidebarItemState extends State<_SidebarItem> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => setState(() => _pressed = true),
    onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
    onTapCancel: ()  => setState(() => _pressed = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: widget.active ? _white10 : (_pressed ? _white06 : Colors.transparent),
        borderRadius: BorderRadius.circular(11),
        border: widget.active ? Border.all(color: _white10) : null,
      ),
      child: Row(children: [
        Icon(widget.icon, color: widget.active ? _white : _grey, size: 17),
        const SizedBox(width: 13),
        Text(widget.label, style: GoogleFonts.nunito(
            color: widget.active ? _white : _grey,
            fontSize: 14, fontWeight: widget.active ? FontWeight.w700 : FontWeight.w600)),
        const Spacer(),
        Icon(Icons.arrow_forward_ios_rounded, color: widget.active ? _white40 : Colors.transparent, size: 11),
      ]),
    ),
  );
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();
  @override
  Widget build(BuildContext context) =>
      Container(margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), height: 1, color: _white10);
}