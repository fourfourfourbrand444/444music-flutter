// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — My Releases Dashboard (App)
//  Rebuilt to mirror the web version 1:1 — iOS look.
//  Same logic, same Firestore reads/writes. Only the styling changed.
// ═══════════════════════════════════════════════════════════════════
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pricing_screen.dart'; // for PaymentWaitingScreen (Pay Now)

// ─── PALETTE (same tokens as the web) ───────────────────────────────
const _bg        = Color(0xFF000000);
const _s1        = Color(0xFF1C1C1E);
const _s2        = Color(0xFF2C2C2E);
const _s3        = Color(0xFF3A3A3C);
const _sep       = Color(0x8C545458);
const _fill      = Color(0x3D787880);
const _fillSoft  = Color(0x29787880);
const _white     = Color(0xFFFFFFFF);
const _white90   = Color(0xE6FFFFFF);
const _white70   = Color(0xB3EBEBF5);
const _t2        = Color(0x99EBEBF5);
const _t3        = Color(0x52EBEBF5);
const _blue      = Color(0xFF0A84FF);
const _green     = Color(0xFF30D158);
const _amber     = Color(0xFFFF9F0A);
const _rose      = Color(0xFFFF453A);
const _cyan      = Color(0xFF64D2FF);
const _takenDown = Color(0xFFAEAEB2);

// ─── TYPOGRAPHY — SF on iOS, Inter elsewhere (web font stack) ───────
bool get _isApple =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

TextStyle _ts(double size, FontWeight w, Color c,
    {double em = -0.01, double? height, TextDecoration? deco, Color? decoColor}) {
  final base = TextStyle(
    fontSize: size,
    fontWeight: w,
    color: c,
    letterSpacing: size * em,
    height: height,
    decoration: deco ?? TextDecoration.none,
    decorationColor: decoColor,
  );
  return _isApple ? base : GoogleFonts.inter(textStyle: base);
}

TextStyle _mono(double size, Color c) => TextStyle(
      fontFamily: _isApple ? 'Menlo' : 'monospace',
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: c,
      letterSpacing: size * 0.04,
      decoration: TextDecoration.none,
    );

// ─── STATUS HELPERS ─────────────────────────────────────────────────
Color _statusColor(String s) {
  switch (s.toLowerCase()) {
    case 'approved':   return _green;
    case 'review':     return _cyan;
    case 'rejected':   return _rose;
    case 'taken down': return _takenDown;
    default:           return _amber;
  }
}

Color _statusBg(String s) => s.toLowerCase() == 'taken down'
    ? const Color(0x2E98989D)
    : _statusColor(s).withValues(alpha: 0.16);

// Display-only label mapping — same as web statusDisplayLabel().
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

// ─── FEATURING HELPERS ──────────────────────────────────────────────
List<String> _featuredFromArtists(dynamic artists) {
  final out = <String>[];
  if (artists is! List) return out;
  for (final a in artists) {
    if (a is Map && (a['type'] ?? '').toString() == 'featured') {
      final n = (a['name'] ?? '').toString().trim();
      if (n.isNotEmpty && !out.any((x) => x.toLowerCase() == n.toLowerCase())) {
        out.add(n);
      }
    }
  }
  return out;
}

List<Map<String, dynamic>> _trackList(Map<String, dynamic> data) {
  for (final key in ['audioFiles', 'featuredArtists']) {
    final list = data[key];
    if (list is! List || list.isEmpty) continue;
    final out = <Map<String, dynamic>>[];
    for (final t in list) {
      if (t is! Map) continue;
      out.add({
        'title': (t['title'] ?? t['track'] ?? '').toString().trim(),
        'featuring': _featuredFromArtists(t['artists']),
      });
    }
    if (out.isNotEmpty) return out;
  }
  return <Map<String, dynamic>>[];
}

bool _isMultiTrack(Map<String, dynamic> data) => _trackList(data).length > 1;

String _featuringDisplay(Map<String, dynamic> data) {
  final names = <String>[];
  void add(dynamic n) {
    final s = (n ?? '').toString().trim();
    if (s.isNotEmpty && !names.any((x) => x.toLowerCase() == s.toLowerCase())) {
      names.add(s);
    }
  }

  final direct = data['featuring'];
  if (direct is List) {
    for (final x in direct) add(x is Map ? x['name'] : x);
  } else {
    add(direct);
  }
  for (final t in _trackList(data)) {
    for (final n in (t['featuring'] as List<String>)) add(n);
  }
  return names.isEmpty ? 'None' : names.join(', ');
}

String _rowArtistLine(Map<String, dynamic> data) {
  final main = (data['artistName'] ?? 'Unknown Artist').toString();
  final feat = _featuringDisplay(data);
  return (_isMultiTrack(data) || feat == 'None') ? main : '$main ft. $feat';
}

// ─── DATE HELPERS ───────────────────────────────────────────────────
const _monthsShort = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const _monthsLong  = ['January','February','March','April','May','June','July','August','September','October','November','December'];

DateTime? _toDate(dynamic d) {
  if (d == null) return null;
  try {
    if (d is Timestamp) return d.toDate();
    if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
    return DateTime.parse(d.toString());
  } catch (_) {
    return null;
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

String _formatDate(dynamic d) {
  final dt = _toDate(d);
  if (dt == null) return d?.toString() ?? '';
  return '${_two(dt.day)} ${_monthsShort[dt.month - 1]} ${dt.year}';
}

String _formatDateLong(dynamic d) {
  final dt = _toDate(d);
  if (dt == null) return '—';
  return '${_two(dt.day)} ${_monthsLong[dt.month - 1]} ${dt.year}';
}

String _formatDateTime(dynamic d) {
  final dt = _toDate(d);
  if (dt == null) return '';
  return '${_two(dt.day)} ${_monthsShort[dt.month - 1]} ${dt.year}, ${_two(dt.hour)}:${_two(dt.minute)}';
}

// Days-left countdown — mirrors web releaseCountdownLabel().
String? _releaseCountdownLabel(dynamic releaseDateValue) {
  final releaseDate = _toDate(releaseDateValue);
  if (releaseDate == null) return null;
  final now = DateTime.now();
  final startOfToday   = DateTime(now.year, now.month, now.day);
  final startOfRelease = DateTime(releaseDate.year, releaseDate.month, releaseDate.day);
  final diffDays = startOfRelease.difference(startOfToday).inDays;
  if (diffDays > 1) return '$diffDays days left';
  if (diffDays == 1) return '1 day left';
  return null;
}

// ─── UPC / SMART LINK ───────────────────────────────────────────────
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

const _smartLinkBase = 'https://444musicdistro.com/';

Future<void> _launch(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ─── SHARED SMALL HELPERS ───────────────────────────────────────────
Widget _coverImage(String url,
    {double? width, double? height, double iconSize = 18, Color bg = _s1}) {
  Widget placeholder() => Container(
        width: width, height: height, color: bg, alignment: Alignment.center,
        child: Icon(Icons.music_note_rounded, color: _t3, size: iconSize),
      );
  if (url.isEmpty) return placeholder();
  if (url.startsWith('data:image')) {
    try {
      return Image.memory(base64Decode(url.split(',').last),
          width: width, height: height, fit: BoxFit.cover);
    } catch (_) {
      return placeholder();
    }
  }
  return CachedNetworkImage(
    imageUrl: url, width: width, height: height, fit: BoxFit.cover,
    placeholder: (_, __) => Container(width: width, height: height, color: bg),
    errorWidget: (_, __, ___) => placeholder(),
  );
}

void _showToast(BuildContext context, String msg, {bool error = false}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      left: 16, right: 16,
      bottom: MediaQuery.of(ctx).padding.bottom + 16,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xEB2C2C2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Icon(error ? Icons.error_outline_rounded : Icons.check_rounded,
                    color: error ? _rose : _green, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(msg, style: _ts(14, FontWeight.w500, _white))),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 2600), () {
    if (entry.mounted) entry.remove();
  });
}

// ════════════════════════════════════════════════════════════════════
//  RELEASES SCREEN
// ════════════════════════════════════════════════════════════════════
class ReleasesScreen extends StatefulWidget {
  const ReleasesScreen({super.key});
  @override
  State<ReleasesScreen> createState() => _ReleasesScreenState();
}

class _ReleasesScreenState extends State<ReleasesScreen> with TickerProviderStateMixin {
  static const int _pageSize = 10;

  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  User? get _user => _auth.currentUser;

  List<Map<String, dynamic>> _releases = [];
  List<Map<String, dynamic>> _filtered = [];
  bool   _loading     = true;
  String _filter      = 'all';
  String _searchQuery = '';
  bool   _sidebarOpen = false;
  int    _page        = 1;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  late AnimationController _entranceCtrl;
  late Animation<double>   _entranceFade;
  late AnimationController _sidebarCtrl;
  late Animation<double>   _sidebarFade;
  late Animation<Offset>   _sidebarSlide;

  final _filters      = ['all', 'pending', 'review', 'approved', 'rejected', 'taken down'];
  final _filterLabels = {
    'all':        'All',
    'pending':    'Draft',
    'review':     'In Review',
    'approved':   'Approved',
    'rejected':   'Rejection',
    'taken down': 'Taken Down',
  };

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _bg,
    ));
    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _entranceFade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _sidebarCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _sidebarFade  = CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOut);
    _sidebarSlide = Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _sidebarCtrl, curve: const Cubic(0.32, 0.72, 0, 1)));
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q != _searchQuery) {
        _searchQuery = q;
        _recomputeFiltered(resetPage: true);
      }
    });
    _loadReleases();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _sidebarCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
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
          final upc = (data['upc'] ?? '').toString().trim().isNotEmpty
              ? data['upc'].toString()
              : _generateUPC();
          final url = _buildSmartLinkURL(data['artistName'] ?? '', data['releaseTitle'] ?? '');
          await doc.reference.update({'upc': upc, 'smartLinkURL': url, 'smartLinkGeneratedAt': FieldValue.serverTimestamp()});
          data['upc'] = upc;
          data['smartLinkURL'] = url;
        }
        list.add(data);
      }

      // Newest first, same ordering the web dashboard uses.
      int ms(dynamic v) => v is Timestamp ? v.millisecondsSinceEpoch : (v is int ? v : 0);
      list.sort((a, b) => ms(b['createdAt']).compareTo(ms(a['createdAt'])));

      if (mounted) {
        _releases = list;
        _loading = false;
        _recomputeFiltered(resetPage: false);
        _entranceCtrl.forward();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter(String f) {
    _filter = f;
    _recomputeFiltered(resetPage: true);
  }

  void _recomputeFiltered({required bool resetPage}) {
    setState(() {
      Iterable<Map<String, dynamic>> base = _releases;
      if (_filter != 'all') {
        base = base.where((r) => (r['status'] ?? 'Pending').toString().trim().toLowerCase() == _filter);
      }
      if (_searchQuery.isNotEmpty) {
        base = base.where((r) {
          final title  = (r['releaseTitle'] ?? '').toString().toLowerCase();
          final artist = (r['artistName']  ?? '').toString().toLowerCase();
          return title.contains(_searchQuery) || artist.contains(_searchQuery);
        });
      }
      _filtered = base.toList();
      if (resetPage) _page = 1;
      final pages = _pageCount;
      if (_page > pages) _page = pages;
    });
  }

  int get _pageCount => max(1, (_filtered.length / _pageSize).ceil());

  void _goToPage(int p) {
    setState(() => _page = p);
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  String get _displayName {
    final u = _user;
    if (u == null) return 'Artist';
    final n = (u.displayName ?? '').trim();
    if (n.isNotEmpty) return n;
    final e = u.email ?? '';
    return e.contains('@') ? e.split('@').first : 'Artist';
  }

  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _loading ? const AlwaysStoppedAnimation(1) : _entranceFade,
            child: Column(
              children: [
                _buildTopBar(top),
                Expanded(child: _loading ? _buildSkeletons() : _buildBody(bottom)),
              ],
            ),
          ),

          if (_sidebarOpen)
            GestureDetector(
              onTap: _closeSidebar,
              child: FadeTransition(
                opacity: _sidebarFade,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(color: Colors.black.withValues(alpha: 0.5)),
                ),
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

  // ── TOP BAR ───────────────────────────────────────────────────────
  Widget _buildTopBar(double top) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, top + 10, 16, 10),
          color: _bg.withValues(alpha: 0.72),
          child: Row(
            children: [
              _CircleBtn(icon: Icons.menu_rounded, onTap: _openSidebar, color: _white),
              const SizedBox(width: 12),
              Text('My Releases', style: _ts(17, FontWeight.w700, _white, em: -0.02)),
              const Spacer(),
              _PillBtn(
                label: 'New Release',
                icon: Icons.add_circle_outline_rounded,
                onTap: () => Navigator.pushNamed(context, '/upload'),
              ),
              const SizedBox(width: 10),
              _CircleBtn(
                icon: Icons.help_outline_rounded,
                color: _t2,
                onTap: () => Navigator.pushNamed(context, '/support'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BODY ──────────────────────────────────────────────────────────
  Widget _buildBody(double bottom) {
    return SingleChildScrollView(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 18, 16, bottom + 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 20),
          _buildSectionHeader(),
          const SizedBox(height: 12),
          _buildFilterRow(),
          const SizedBox(height: 16),
          if (_releases.isEmpty) _buildEmptyState() else ...[
            _buildListHead(),
            _buildRows(),
            if (_filtered.length > _pageSize) _buildPager(),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _t2, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              cursorColor: _white,
              style: _ts(16, FontWeight.w400, _white),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search by title or artist...',
                hintStyle: _ts(16, FontWeight.w400, _t2),
              ),
            ),
          ),
          if (_searchCtrl.text.trim().isNotEmpty)
            GestureDetector(
              onTap: () { _searchCtrl.clear(); setState(() {}); },
              child: Container(
                width: 18, height: 18,
                decoration: const BoxDecoration(color: _t2, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.black, size: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: const BoxDecoration(color: _white, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('All Releases', style: _ts(17.6, FontWeight.w700, _white, em: -0.02)),
      ],
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final f      = _filters[i];
          final active = f == _filter;
          return GestureDetector(
            onTap: () => _applyFilter(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? _white : _fillSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _filterLabels[f]!,
                style: _ts(14, FontWeight.w500, active ? Colors.black : _white90),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListHead() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _sep, width: 0.5))),
      child: Row(
        children: [
          const SizedBox(width: 20 + 12 + 48 + 12),
          Text('RELEASE', style: _ts(12, FontWeight.w500, _t3, em: 0.04)),
        ],
      ),
    );
  }

  Widget _buildRows() {
    final start = (_page - 1) * _pageSize;
    final end   = min(start + _pageSize, _filtered.length);
    final slice = _filtered.sublist(start, end);
    return Column(
      children: List.generate(slice.length, (i) {
        return TweenAnimationBuilder<double>(
          key: ValueKey('${slice[i]['_id']}_$_page'),
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 400 + i * 45),
          curve: const Cubic(0.32, 0.72, 0, 1),
          builder: (_, v, child) => Transform.translate(
            offset: Offset(0, 8 * (1 - v)),
            child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
          ),
          child: _ReleaseRow(
            index: start + i,
            data: slice[i],
            db: _db,
            onRefresh: _loadReleases,
            onOpenRejection: (data) =>
                Navigator.pushNamed(context, '/rejection', arguments: data)
                    .then((_) => _loadReleases()),
          ),
        );
      }),
    );
  }

  Widget _buildPager() {
    final pages = _pageCount;
    Widget btn(String label, bool enabled, VoidCallback onTap) => GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1 : 0.3,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: _ts(15, FontWeight.w600, _white)),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          btn('Previous', _page > 1, () => _goToPage(_page - 1)),
          Text('Page $_page of $pages',
              style: _ts(13, FontWeight.w400, _t2).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          btn('Next', _page < pages, () => _goToPage(_page + 1)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: _s1, borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.music_note_rounded, color: _t2, size: 34),
            ),
            const SizedBox(height: 18),
            Text('No releases yet', style: _ts(19, FontWeight.w700, _white, em: -0.02)),
            const SizedBox(height: 7),
            Text(
              'Create your first release to start distributing your music worldwide.',
              style: _ts(15, FontWeight.w400, _t2, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/upload'),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_circle_outline_rounded, color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  Text('New Release', style: _ts(16, FontWeight.w600, Colors.black)),
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        children: List.generate(4, (_) => const _SkeletonRow()),
      ),
    );
  }

  // ── SIDEBAR ───────────────────────────────────────────────────────
  Widget _buildSidebar(double top, double bottom) {
    final w = (MediaQuery.of(context).size.width * 0.78).clamp(260.0, 320.0);
    return SizedBox(
      width: w, height: double.infinity,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xC71C1C1E),
              border: Border(right: BorderSide(color: _sep, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, top + 20, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text('444Music', style: _ts(17, FontWeight.w700, _white, em: -0.02)),
                      const Spacer(),
                      _CircleBtn(icon: Icons.close_rounded, onTap: _closeSidebar, color: _t2, size: 32, iconSize: 16),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SidebarSection(label: 'Main'),
                        _SidebarItem(icon: Icons.home_rounded, label: 'Home',
                            onTap: () { _closeSidebar(); Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false); }),
                        _SidebarItem(icon: Icons.library_music_rounded, label: 'My Releases',
                            onTap: _closeSidebar, active: true),
                        _SidebarItem(icon: Icons.add_circle_outline_rounded, label: 'New Release',
                            onTap: () { _closeSidebar(); Future.delayed(const Duration(milliseconds: 300), () => Navigator.pushNamed(context, '/upload')); }),
                        const _SidebarSection(label: 'Finance'),
                        _SidebarItem(icon: Icons.attach_money_rounded, label: 'Royalties',
                            onTap: () { _closeSidebar(); Future.delayed(const Duration(milliseconds: 300), () => Navigator.pushNamed(context, '/earnings')); }),
                        _SidebarItem(icon: Icons.ondemand_video_rounded, label: 'Watch Tutorials',
                            onTap: () { _closeSidebar(); _launch('https://www.youtube.com/@444musicdistribution'); }),
                        _SidebarItem(icon: Icons.call_split_rounded, label: 'Royalty Split',
                            onTap: () { _closeSidebar(); Future.delayed(const Duration(milliseconds: 300), () async {
                              final Uri url = Uri.parse('https://444music-distribution.vercel.app/splits');
                              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                throw Exception('Could not launch $url');
                              }
                            }); }),
                        const _SidebarSection(label: 'Tools'),
                        _SidebarItem(icon: Icons.trending_up_rounded, label: 'Promote/Playlist',
                            onTap: () { _closeSidebar(); _launch('https://444musicblog.vercel.app'); }),
                        _SidebarItem(icon: Icons.bar_chart_rounded, label: 'Analytics',
                            onTap: () { _closeSidebar(); Future.delayed(const Duration(milliseconds: 300), () => Navigator.pushNamed(context, '/analytics')); }),
                        _SidebarItem(icon: Icons.help_outline_rounded, label: 'Support',
                            onTap: () { _closeSidebar(); Future.delayed(const Duration(milliseconds: 300), () => Navigator.pushNamed(context, '/support')); }),
                        _SidebarItem(icon: Icons.speed_rounded, label: 'Dashboard',
                            onTap: () { _closeSidebar(); Future.delayed(const Duration(milliseconds: 300), () => Navigator.pushNamed(context, '/dashboard')); }),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 18),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Container(
                              width: 34, height: 34,
                              decoration: const BoxDecoration(color: _s3, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text(_displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'A',
                                  style: _ts(14, FontWeight.w600, _white)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_displayName,
                                      style: _ts(14, FontWeight.w600, _white),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text('Artist', style: _ts(12, FontWeight.w400, _t2)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                          _closeSidebar();
                          if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: _rose.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.logout_rounded, color: _rose, size: 17),
                            const SizedBox(width: 9),
                            Text('Logout', style: _ts(15, FontWeight.w600, _rose)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  RELEASE ROW — index | thumb | title / artist / meta | countdown + chevron
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

  void _openModal() async {
    final proceed = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => _AppleShowcaseScreen(data: widget.data),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (proceed == true && mounted) _showDetailModal();
  }

  void _showDetailModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _ReleaseDetailModal(
        data: widget.data,
        db: widget.db,
        onRefresh: widget.onRefresh,
        onOpenRejection: widget.onOpenRejection,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final releaseDate = widget.data['releaseDate'] != null ? _formatDate(widget.data['releaseDate']) : 'TBA';
    final countdown   = _releaseCountdownLabel(widget.data['releaseDate']);
    final releaseType = (widget.data['releaseType'] ?? 'Single').toString();
    final showMeta    = MediaQuery.of(context).size.width > 480;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); _openModal(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: _pressed ? const Color(0x14FFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${widget.index + 1}',
                    textAlign: TextAlign.center,
                    style: _ts(13, FontWeight.w600, _t3).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _s1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x1AFFFFFF), width: 0.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _coverImage(widget.data['coverURL']?.toString() ?? '', width: 48, height: 48),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (widget.data['releaseTitle'] ?? 'Untitled Release').toString(),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: _ts(16, FontWeight.w600, _white, em: -0.02),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _rowArtistLine(widget.data),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: _ts(14, FontWeight.w400, _t2),
                      ),
                      if (showMeta) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(releaseType.toUpperCase(),
                                style: _ts(11, FontWeight.w600, _t2, em: 0.04)),
                            const SizedBox(width: 7),
                            Container(width: 3, height: 3, decoration: const BoxDecoration(color: _t3, shape: BoxShape.circle)),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                '${_isPending ? "Scheduled: " : "Release: "}$releaseDate',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: _ts(12, FontWeight.w400, _t3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (countdown != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(999)),
                        child: Text(countdown, style: _ts(11, FontWeight.w600, Colors.black)),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: _t3, size: 18),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 92, right: -6, bottom: -12,
              child: Container(height: 0.5, color: _sep),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  APPLE-STYLE SHOWCASE — shown first when a row is tapped;
//  tapping anywhere continues to the detail sheet.
// ════════════════════════════════════════════════════════════════════
class _AppleShowcaseScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const _AppleShowcaseScreen({required this.data});

  @override
  State<_AppleShowcaseScreen> createState() => _AppleShowcaseScreenState();
}

class _AppleShowcaseScreenState extends State<_AppleShowcaseScreen>
    with SingleTickerProviderStateMixin {
  static const double _totalMs = 3600;
  static const Cubic _ease = Cubic(0.22, 1, 0.36, 1);

  late final AnimationController _ctrl;
  late final Animation<double> _statusAnim;
  late final Animation<double> _titleAnim;
  late final Animation<double> _subtitleAnim;
  late final Animation<double> _distribAnim;
  late final Animation<double> _artworkAnim;
  late final Animation<double> _hintAnim;

  String get _status     => (widget.data['status'] ?? 'Pending').toString().trim();
  bool   get _isApproved => _status.toLowerCase() == 'approved';

  Animation<double> _interval(double startMs, double endMs) {
    return CurvedAnimation(
      parent: _ctrl,
      curve: Interval(
        (startMs / _totalMs).clamp(0.0, 1.0),
        (endMs / _totalMs).clamp(0.0, 1.0),
        curve: _ease,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
    _statusAnim   = _interval(200, 900);
    _titleAnim    = _interval(550, 1450);
    _subtitleAnim = _interval(1000, 1900);
    _distribAnim  = _interval(1450, 2350);
    _artworkAnim  = _interval(1900, 3000);
    _hintAnim     = _interval(2900, 3600);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _fadeUp(Animation<double> anim, {required Widget child, double distance = 16}) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, distance * (1 - anim.value)), child: c),
      ),
      child: child,
    );
  }

  Widget _buildArtwork() {
    final url = widget.data['coverURL']?.toString() ?? '';
    return AnimatedBuilder(
      animation: _artworkAnim,
      builder: (_, c) => Opacity(
        opacity: _artworkAnim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 26 * (1 - _artworkAnim.value)),
          child: Transform.scale(scale: 0.96 + (0.04 * _artworkAnim.value), child: c),
        ),
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFE3E2DD),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 60, offset: const Offset(0, 30)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _coverImage(url, bg: const Color(0xFFE3E2DD)),
          ),
        ),
      ),
    );
  }

  void _proceed() => Navigator.of(context).pop(true);
  void _dismiss() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    final releaseType   = (widget.data['releaseType'] ?? 'Single').toString();
    final title         = (widget.data['releaseTitle'] ?? 'Untitled Release').toString();
    final displayStatus = _statusDisplayLabel(_status);
    final top   = MediaQuery.of(context).padding.top;
    final width = MediaQuery.of(context).size.width;
    final hPad  = width > 480 ? (((width - 430) / 2) + 30).clamp(24.0, 400.0) : 24.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _proceed,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.35, -1),
              end: Alignment(0.35, 1),
              colors: [Color(0xFFFAF9F6), Color(0xFFF1EFE9), Color(0xFFE7E4DB), Color(0xFFDEDBD0)],
              stops: [0.0, 0.42, 0.78, 1.0],
            ),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, top + 80, hPad, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isApproved)
                      _fadeUp(_statusAnim, child: Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(999)),
                        child: Text(displayStatus.toUpperCase(),
                            style: _ts(12, FontWeight.w600, Colors.white, em: 0.04)),
                      )),
                    _fadeUp(_titleAnim, child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RichText(
                        text: TextSpan(
                          style: _ts(24, FontWeight.w700, Colors.black, em: -0.03, height: 1.2),
                          children: [
                            TextSpan(text: title),
                            TextSpan(
                              text: ' - $releaseType',
                              style: _ts(24, FontWeight.w500, Colors.black.withValues(alpha: 0.5), em: -0.03, height: 1.2),
                            ),
                          ],
                        ),
                      ),
                    )),
                    _fadeUp(_subtitleAnim, child: Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Text('Distributed by',
                          style: _ts(16, FontWeight.w500, Colors.black.withValues(alpha: 0.46))),
                    )),
                    _fadeUp(_distribAnim, child: Padding(
                      padding: const EdgeInsets.only(bottom: 52),
                      child: Row(children: [
                        Image.network(
                          'https://www.444musicdistro.com/black.png',
                          height: 26,
                          errorBuilder: (_, __, ___) => const SizedBox(width: 26, height: 26),
                        ),
                        const SizedBox(width: 10),
                        Text('444Music', style: _ts(18, FontWeight.w600, Colors.black, em: -0.02)),
                      ]),
                    )),
                    _buildArtwork(),
                    _fadeUp(_hintAnim, child: Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: Text('TAP ANYWHERE TO VIEW DETAILS',
                              style: _ts(12, FontWeight.w500, Colors.black.withValues(alpha: 0.32), em: 0.06)),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
              Positioned(
                top: top + 20, right: 20,
                child: GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    width: 34, height: 34,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x243C3C43)),
                    child: Icon(Icons.close_rounded, color: Colors.black.withValues(alpha: 0.55), size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── SKELETON ─────────────────────────────────────────────────────────
class _SkeletonRow extends StatefulWidget {
  const _SkeletonRow();
  @override
  State<_SkeletonRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<_SkeletonRow> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _a = Tween<double>(begin: -2, end: 2).animate(_c);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  BoxDecoration _shimmer(double radius) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(_a.value - 1, 0),
          end: Alignment(_a.value + 1, 0),
          colors: const [_s1, Color(0x0FFFFFFF), _s1],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Row(children: [
          const SizedBox(width: 32),
          Container(width: 48, height: 48, decoration: _shimmer(12)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FractionallySizedBox(widthFactor: 0.6, child: Container(height: 12, decoration: _shimmer(8))),
            const SizedBox(height: 8),
            FractionallySizedBox(widthFactor: 0.4, child: Container(height: 12, decoration: _shimmer(8))),
          ])),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  RELEASE DETAIL SHEET
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
  String get _id          => widget.data['_id'] ?? '';
  String get _status      => (widget.data['status'] ?? 'Pending').toString().trim();
  bool   get _isApproved  => _status.toLowerCase() == 'approved';
  bool   get _isRejected  => _status.toLowerCase() == 'rejected';
  bool   get _isPending   => _status.toLowerCase() == 'pending';
  bool   get _isTakenDown => _status.toLowerCase() == 'taken down';

  late Map<String, dynamic> _data;

  bool get _isPaid       => _isPaidValue(_data['paid']);
  bool get _needsPayment => _isPending && !_isPaid;
  bool get _isMulti      => _isMultiTrack(_data);

  bool _smartLinkCopied = false;

  @override
  void initState() {
    super.initState();
    _data = Map.from(widget.data);
    if (_isApproved && (_data['upc'] == null || _data['smartLinkURL'] == null)) {
      _generateSmartLink();
    }
  }

  Future<void> _generateSmartLink() async {
    try {
      final snap     = await widget.db.collection('submissions').doc(_id).get();
      final existing = snap.data() ?? {};
      if (existing['upc'] != null && existing['smartLinkURL'] != null) {
        if (mounted) {
          setState(() {
            _data['upc']          = existing['upc'];
            _data['smartLinkURL'] = existing['smartLinkURL'];
          });
        }
        return;
      }
      final upc = (existing['upc'] ?? '').toString().trim().isNotEmpty
          ? existing['upc'].toString()
          : _generateUPC();
      final url = _buildSmartLinkURL(_data['artistName'] ?? '', _data['releaseTitle'] ?? '');
      await widget.db.collection('submissions').doc(_id).update({
        'upc': upc, 'smartLinkURL': url, 'smartLinkGeneratedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() { _data['upc'] = upc; _data['smartLinkURL'] = url; });
      widget.onRefresh();
    } catch (_) {}
  }

  String? get _smartLinkSlug {
    final s = (_data['smartLinkSlug'] ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  String get _smartLinkUrl => '$_smartLinkBase${_smartLinkSlug ?? ''}';

  void _copySmartLinkUrl() {
    Clipboard.setData(ClipboardData(text: _smartLinkUrl));
    HapticFeedback.lightImpact();
    setState(() => _smartLinkCopied = true);
    _showToast(context, 'SmartLink copied to clipboard!');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _smartLinkCopied = false);
    });
  }

  // iOS-style "Proceed to payment?" alert, then the existing pay flow.
  Future<void> _payNow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _id.isEmpty) return;
    final amount = _priceForReleaseType(_data['releaseType']);
    final title  = (_data['releaseTitle'] ?? 'this release').toString();

    final go = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _IosAlert(
        icon: Icons.credit_card_rounded,
        iconColor: _cyan,
        title: 'Proceed to payment?',
        message: 'You\'ll be taken to a secure payment page to release "$title" (GHC ${amount.toStringAsFixed(2)}) for review.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Continue',
      ),
    );
    if (go != true || !mounted) return;

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

  bool get _hasProducers  => _hasCreditsIn('producer');
  bool get _hasMusicians  => _hasCreditsIn('musician');
  bool get _hasWriters    => _hasCreditsIn('writer');
  bool get _hasPublishers => _hasCreditsIn('publishing');

  bool _hasCreditsIn(String key) {
    final c = _data['credits'];
    if (c == null || c is! Map) return false;
    final list = c[key];
    return list is List && list.any((x) => x is Map && (x['name'] ?? '').toString().trim().isNotEmpty);
  }

  List _creditList(String key) {
    final c = _data['credits'];
    if (c is Map && c[key] is List) return c[key] as List;
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final bottom   = MediaQuery.of(context).padding.bottom;
    final feat     = _featuringDisplay(_data);
    final upcText  = (_data['upc'] ?? '').toString().trim();
    final catText  = (_data['catalogNumber'] ?? '').toString().trim();
    final submitted = _formatDateTime(_data['createdAt']);
    final rejection = (_data['rejectionReason'] ?? '').toString().trim();
    final takedown  = (_data['takedownReason'] ?? '').toString().trim();
    final lyrics    = (_data['description'] ?? '').toString().trim();
    final referral  = (_data['refferal'] ?? '').toString().trim();

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: _s1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: Column(
          children: [
            _SheetHeader(title: 'Release Details', subtitle: (_data['releaseTitle'] ?? '').toString()),
            _buildTopAction(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCoverStrip(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // STATUS
                          const _SectionLabel(label: 'Status', icon: Icons.info_outline_rounded),
                          _buildStatusRow(submitted),
                          if (_isRejected && rejection.isNotEmpty)
                            _ReasonBox(label: 'Reason for rejection', text: rejection, color: _rose, bg: const Color(0x1FFF453A)),
                          if (_isTakenDown && takedown.isNotEmpty)
                            _ReasonBox(label: 'Reason for takedown', text: takedown, color: _takenDown, bg: const Color(0x2498989D)),
                          if (_isApproved && _smartLinkSlug != null) ...[
                            const SizedBox(height: 22),
                            _buildSmartLinkRow(),
                          ],
                          const SizedBox(height: 22),

                          // ARTIST & RELEASE
                          const _SectionLabel(label: 'Artist & Release', icon: Icons.person_outline_rounded),
                          _MetaGrid(fields: [
                            _MetaField(label: 'Main Artist', value: _data['artistName'], full: true),
                            if (!_isMulti)
                              _MetaField(label: 'Featuring', value: feat, full: true, dim: feat == 'None'),
                            _MetaField(label: 'Release Title', value: _data['releaseTitle'], full: true),
                            _MetaField(label: 'Type',     value: _data['releaseType']),
                            _MetaField(label: 'Genre',    value: _data['genre']),
                            _MetaField(label: 'Language', value: _data['language']),
                            _MetaField(label: 'Release Date', value: _data['releaseDate'] != null ? _formatDateLong(_data['releaseDate']) : null),
                            _MetaField(label: 'Explicit Content', value: _data['explicit']?.toString() ?? 'No'),
                          ]),

                          if (_isMulti) ...[
                            const SizedBox(height: 22),
                            const _SectionLabel(label: 'Tracklist', icon: Icons.format_list_bulleted_rounded),
                            _buildTracklistSection(),
                          ],
                          const SizedBox(height: 22),

                          // LABEL & RIGHTS
                          const _SectionLabel(label: 'Label & Rights', icon: Icons.shield_outlined),
                          _MetaGrid(fields: [
                            _MetaField(label: 'Label Name', value: (_data['label'] ?? '').toString().trim().isEmpty ? 'Independent' : _data['label']),
                            _MetaField(label: 'Copyright Holder', value: _data['copyright']),
                          ]),
                          const SizedBox(height: 22),

                          // IDENTIFIERS
                          const _SectionLabel(label: 'Identifiers', icon: Icons.grid_view_rounded),
                          _MetaGrid(fields: [
                            _MetaField(label: 'ISRC Code', value: _data['isrc'], mono: true),
                            _MetaField(
                              label: 'UPC / EAN Barcode',
                              value: upcText.isNotEmpty ? upcText : (_isApproved ? 'Generating…' : 'Assigned upon approval'),
                              mono: true, dim: upcText.isEmpty,
                            ),
                            _MetaField(
                              label: 'Catalog Number',
                              value: catText.isNotEmpty ? catText : (_isApproved ? 'Pending assignment' : 'Assigned upon approval'),
                              dim: catText.isEmpty,
                            ),
                          ]),
                          const SizedBox(height: 22),

                          // CONTACT & LOCATION
                          const _SectionLabel(label: 'Contact & Location', icon: Icons.location_on_outlined),
                          _MetaGrid(fields: [
                            _MetaField(label: 'Country', value: _data['country']),
                            _MetaField(label: 'Email', value: _data['email'], full: true),
                            if (referral.isNotEmpty)
                              _MetaField(label: 'Referral Code', value: referral),
                          ]),

                          if (_hasProducers || _hasMusicians) ...[
                            const SizedBox(height: 22),
                            const _SectionLabel(label: 'Production Credits', icon: Icons.star_outline_rounded),
                            if (_hasProducers) ...[
                              const _SubLabel(label: 'Producers & Engineers'),
                              _CreditsList(list: _creditList('producer')),
                            ],
                            if (_hasMusicians) ...[
                              _SubLabel(label: 'Musicians', spaced: _hasProducers),
                              _CreditsList(list: _creditList('musician')),
                            ],
                          ],

                          if (_hasWriters || _hasPublishers) ...[
                            const SizedBox(height: 22),
                            const _SectionLabel(label: 'Songwriting & Publishing'),
                            if (_hasWriters) ...[
                              const _SubLabel(label: 'Songwriters & Composers'),
                              _CreditsList(list: _creditList('writer')),
                            ],
                            if (_hasPublishers) ...[
                              _SubLabel(label: 'Publishing & PRO', spaced: _hasWriters),
                              _CreditsList(list: _creditList('publishing')),
                            ],
                          ],

                          if (lyrics.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            const _SectionLabel(label: 'Lyrics', icon: Icons.menu_book_outlined),
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxHeight: 240),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(14)),
                              child: SingleChildScrollView(
                                child: Text(lyrics, style: _ts(14, FontWeight.w400, _t2, height: 1.7)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TRACKLIST ─────────────────────────────────────────────────────
  Widget _buildTracklistSection() {
    final tracks = _trackList(_data);
    return Column(
      children: List.generate(tracks.length, (i) {
        final rawTitle = tracks[i]['title'] as String;
        final title    = rawTitle.isEmpty ? 'Track ${i + 1}' : rawTitle;
        final feats    = tracks[i]['featuring'] as List<String>;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(14)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 30, child: Text('${i + 1}', style: _ts(14, FontWeight.w600, _t3))),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _ts(15, FontWeight.w600, _white)),
                    const SizedBox(height: 3),
                    Text(
                      feats.isEmpty ? 'Featuring: None' : 'Featuring: ${feats.join(', ')}',
                      style: _ts(13, FontWeight.w400, feats.isEmpty ? _t3 : _white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── TOP ACTION BAR ────────────────────────────────────────────────
  Widget _actionBar({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        color: bg,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 9),
          Text(label, style: _ts(15, FontWeight.w600, color)),
        ]),
      ),
    );
  }

  Widget _buildTopAction() {
    if (_needsPayment) {
      final price = _priceForReleaseType(_data['releaseType']);
      return _actionBar(
        icon: Icons.credit_card_rounded,
        label: 'Pay GHC ${price.toStringAsFixed(2)} to Release',
        color: _cyan, bg: _cyan.withValues(alpha: 0.16), onTap: _payNow,
      );
    }
    if (_isApproved) {
      return _actionBar(
        icon: Icons.show_chart_rounded,
        label: 'Promote This Release',
        color: _amber, bg: _amber.withValues(alpha: 0.16),
        onTap: () => _launch('https://444musicblog.vercel.app'),
      );
    }
    if (_isTakenDown) {
      return _actionBar(
        icon: Icons.info_outline_rounded,
        label: 'This Release Was Taken Down',
        color: _takenDown, bg: const Color(0x2998989D),
      );
    }
    if (_isRejected) {
      return _actionBar(
        icon: Icons.info_outline_rounded,
        label: 'Check Reasons & Fix',
        color: _rose, bg: _rose.withValues(alpha: 0.16),
        onTap: () { Navigator.pop(context); widget.onOpenRejection(_data); },
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCoverStrip() {
    const h = 190.0;
    final url = _data['coverURL']?.toString() ?? '';
    return SizedBox(
      height: h, width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _coverImage(url, width: double.infinity, height: h, iconSize: 44, bg: _s2),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 70,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [_s1, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String submitted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Wrap(
        spacing: 8, runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Badge(
            label: _statusDisplayLabel(_status),
            color: _statusColor(_status),
            bg: _statusBg(_status),
            pulse: _isRejected,
          ),
          _Badge(
            label: _isPaid ? 'Paid' : 'Unpaid',
            color: _isPaid ? _green : _amber,
            bg: (_isPaid ? _green : _amber).withValues(alpha: 0.16),
          ),
          if (submitted.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('Submitted $submitted', style: _ts(12, FontWeight.w400, _t2)),
            ),
        ],
      ),
    );
  }

  Widget _buildSmartLinkRow() {
    final url = _smartLinkUrl;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _launch(url),
              behavior: HitTestBehavior.opaque,
              child: Text(url, style: _ts(14, FontWeight.w500, _blue)),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _copySmartLinkUrl,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 34, height: 34,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _smartLinkCopied ? _green : _white),
              child: Icon(
                _smartLinkCopied ? Icons.check_rounded : Icons.copy_rounded,
                color: _smartLinkCopied ? _white : Colors.black,
                size: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── META FIELD + GRID ───────────────────────────────────────────────
class _MetaField {
  final String label;
  final dynamic value;
  final bool full;
  final bool mono;
  final bool dim;
  const _MetaField({required this.label, this.value, this.full = false, this.mono = false, this.dim = false});
}

class _MetaGrid extends StatelessWidget {
  final List<_MetaField> fields;
  const _MetaGrid({required this.fields});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // Phones: single column, like the web at ≤768px. Wider: two columns.
      final narrow = MediaQuery.of(context).size.width < 768;
      final full   = c.maxWidth;
      final half   = (c.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8, runSpacing: 8,
        children: fields.map((f) => SizedBox(
          width: (narrow || f.full) ? full : half,
          child: _MetaFieldWidget(field: f),
        )).toList(),
      );
    });
  }
}

class _MetaFieldWidget extends StatelessWidget {
  final _MetaField field;
  const _MetaFieldWidget({required this.field});

  @override
  Widget build(BuildContext context) {
    final raw   = field.value?.toString().trim() ?? '';
    final empty = raw.isEmpty;
    final val   = empty ? '—' : raw;
    final dim   = empty || field.dim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(field.label, style: _ts(12, FontWeight.w500, _t2)),
        const SizedBox(height: 3),
        Text(
          val,
          style: field.mono
              ? _mono(15, dim ? _t3 : _white)
              : _ts(dim ? 14 : 15, dim ? FontWeight.w400 : FontWeight.w500, dim ? _t3 : _white, height: 1.4),
        ),
      ]),
    );
  }
}

// ── CREDITS ──────────────────────────────────────────────────────────
class _CreditsList extends StatelessWidget {
  final List list;
  const _CreditsList({required this.list});

  @override
  Widget build(BuildContext context) {
    final valid = list.where((x) => x is Map && (x['name'] ?? '').toString().trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('None added', style: _ts(14, FontWeight.w400, _t3)),
      );
    }
    return Column(
      children: valid.map((c) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: _white, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((c['name'] ?? '').toString(), style: _ts(15, FontWeight.w600, _white)),
            if ((c['role'] ?? '').toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(c['role'].toString(), style: _ts(13, FontWeight.w400, _t2)),
              ),
            if ((c['ipi'] ?? '').toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('IPI / CAE: ${c['ipi']}', style: _mono(12, _t3)),
              ),
          ])),
        ]),
      )).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ════════════════════════════════════════════════════════════════════
class _Badge extends StatefulWidget {
  final String label;
  final Color color, bg;
  final bool pulse;
  const _Badge({required this.label, required this.color, required this.bg, this.pulse = false});
  @override
  State<_Badge> createState() => _BadgeState();
}

class _BadgeState extends State<_Badge> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    }
  }
  @override
  void dispose() { _c?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dot = Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(color: widget.bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _c != null ? FadeTransition(opacity: Tween(begin: 1.0, end: 0.3).animate(_c!), child: dot) : dot,
        const SizedBox(width: 6),
        Text(widget.label, style: _ts(12, FontWeight.w600, widget.color, em: 0)),
      ]),
    );
  }
}

class _ReasonBox extends StatelessWidget {
  final String label, text;
  final Color color, bg;
  const _ReasonBox({required this.label, required this.text, required this.color, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: _ts(12, FontWeight.w600, color, em: 0.04)),
          const SizedBox(height: 5),
          Text(text, style: _ts(14, FontWeight.w400, _white90, height: 1.55)),
        ]),
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _SectionLabel({required this.label, this.icon});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: _t2, size: 13),
            const SizedBox(width: 7),
          ],
          Text(label.toUpperCase(), style: _ts(12, FontWeight.w500, _t2, em: 0.04)),
        ]),
      );
}

class _SubLabel extends StatelessWidget {
  final String label;
  final bool spaced;
  const _SubLabel({required this.label, this.spaced = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(4, spaced ? 14 : 4, 4, 8),
        child: Text(label, style: _ts(13, FontWeight.w500, _t2)),
      );
}

class _SheetHeader extends StatelessWidget {
  final String title, subtitle;
  const _SheetHeader({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xDB1C1C1E),
              border: Border(bottom: BorderSide(color: _sep, width: 0.5)),
            ),
            child: Column(children: [
              const SizedBox(height: 6),
              Container(
                width: 36, height: 5,
                decoration: BoxDecoration(color: const Color(0x4DEBEBF5), borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.music_note_rounded, color: _t2, size: 16),
                      const SizedBox(width: 8),
                      Text(title, style: _ts(16.8, FontWeight.w700, _white, em: -0.02)),
                    ]),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle,
                            style: _ts(13, FontWeight.w400, _t2),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ])),
                  const SizedBox(width: 12),
                  _CircleBtn(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                    color: _t2, size: 30, iconSize: 15,
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size, iconSize;
  const _CircleBtn({required this.icon, required this.onTap, required this.color, this.size = 36, this.iconSize = 17});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size, height: size,
          decoration: const BoxDecoration(color: _fill, shape: BoxShape.circle),
          child: Icon(icon, color: color, size: iconSize),
        ),
      );
}

class _PillBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PillBtn({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.black, size: 15),
            const SizedBox(width: 7),
            Text(label, style: _ts(14, FontWeight.w600, Colors.black)),
          ]),
        ),
      );
}

class _SidebarSection extends StatelessWidget {
  final String label;
  const _SidebarSection({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
        child: Text(label.toUpperCase(), style: _ts(12, FontWeight.w500, _t3, em: 0.04)),
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
        behavior: HitTestBehavior.opaque,
        onTapDown:   (_) => setState(() => _pressed = true),
        onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
        onTapCancel: ()  => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.active ? _fill : (_pressed ? _fillSoft : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(widget.icon, color: widget.active ? _white : _t2, size: 17),
            const SizedBox(width: 11),
            Text(widget.label,
                style: _ts(15, FontWeight.w500, widget.active ? _white : _t2)),
          ]),
        ),
      );
}

// iOS-style alert (used for "Proceed to payment?")
class _IosAlert extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, message, cancelLabel, confirmLabel;
  const _IosAlert({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    Widget action(String label, bool primary, bool result) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context, result),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              child: Text(label, style: _ts(17, primary ? FontWeight.w600 : FontWeight.w400, _blue, em: -0.02)),
            ),
          ),
        );
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                color: const Color(0xF02C2C2E),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                      child: Column(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.16), shape: BoxShape.circle),
                          child: Icon(icon, color: iconColor, size: 22),
                        ),
                        const SizedBox(height: 14),
                        Text(title, textAlign: TextAlign.center, style: _ts(17, FontWeight.w600, _white, em: -0.02)),
                        const SizedBox(height: 6),
                        Text(message, textAlign: TextAlign.center, style: _ts(13, FontWeight.w400, _white70, height: 1.45)),
                      ]),
                    ),
                    Container(height: 0.5, color: _sep),
                    Row(children: [
                      action(cancelLabel, false, false),
                      Container(width: 0.5, height: 48, color: _sep),
                      action(confirmLabel, true, true),
                    ]),
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
