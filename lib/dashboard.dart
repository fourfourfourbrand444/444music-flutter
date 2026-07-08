// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — My Releases Dashboard  (rebuilt)
//  Theme: Black & White Luxury  |  Font: Nunito
//  Fixes: no ? btn, cover art displays, reject/approve buttons visible
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
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

// ─── PALETTE ────────────────────────────────────────────────────────
const _black      = Color(0xFF000000);
const _black1     = Color(0xFF080808);
const _black2     = Color(0xFF0D0D0D);
const _black3     = Color(0xFF111111);
const _black4     = Color(0xFF161616);
const _black5     = Color(0xFF1A1A1A);
const _white      = Color(0xFFFFFFFF);
const _white90    = Color(0xE6FFFFFF);
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

// ─── STATUS HELPERS ─────────────────────────────────────────────────
Color _statusColor(String s) {
  switch (s.toLowerCase()) {
    case 'approved': return _green;
    case 'review':   return _cyan;
    case 'rejected': return _rose;
    default:         return _amber;
  }
}

int _statusProgress(String s) {
  switch (s.toLowerCase()) {
    case 'pending':  return 25;
    case 'review':   return 60;
    case 'approved': return 100;
    case 'rejected': return 10;
    default:         return 10;
  }
}

String _statusLabel(String s) {
  switch (s.toLowerCase()) {
    case 'pending':  return 'Awaiting payment';
    case 'review':   return 'Under review';
    case 'approved': return 'Live on stores';
    case 'rejected': return 'Action needed';
    default:         return 'Processing';
  }
}

// ─── UPC GENERATOR ──────────────────────────────────────────────────
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
  // Keep hyphens, replace spaces with hyphens, lowercase
  String toSlug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s\-]'), '') // keep letters, digits, spaces, hyphens
      .trim()
      .replaceAll(RegExp(r'\s+'), '-')            // spaces → hyphens
      .replaceAll(RegExp(r'-+'), '-');            // collapse multiple hyphens

  final aSlug = toSlug(artistName);
  final tRaw  = toSlug(releaseTitle);
  final tSlug = tRaw.length > 30 ? tRaw.substring(0, 30) : tRaw;
  return 'https://ffm.to/$aSlug-$tSlug';
}

Future<void> _launch(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ─── STORE CONFIG ───────────────────────────────────────────────────
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
  bool   _sidebarOpen = false;

  late AnimationController _entranceCtrl;
  late Animation<double>   _entranceFade;
  late AnimationController _sidebarCtrl;
  late Animation<double>   _sidebarFade;
  late Animation<Offset>   _sidebarSlide;

  final _filters      = ['all', 'pending', 'approved', 'review', 'rejected'];
  final _filterLabels = {
    'all':      'All',
    'pending':  'Pending',
    'approved': 'Approved',
    'review':   'In Review',
    'rejected': 'Rejected',
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
    _loadReleases();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _sidebarCtrl.dispose();
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
        if (data['paymentVerified'] == null) {
          await doc.reference.update({'paymentVerified': false});
          data['paymentVerified'] = false;
        }
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

      if (mounted) {
        setState(() { _releases = list; _filtered = list; _loading = false; });
        _applyFilter(_filter);
        _entranceCtrl.forward();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter(String f) {
    setState(() {
      _filter   = f;
      _filtered = f == 'all'
          ? List.from(_releases)
          : _releases.where((r) => (r['status'] ?? 'Pending').toString().toLowerCase() == f).toList();
    });
  }

  int get _totalReleases => _releases.length;
  int get _pendingCount  => _releases.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'pending').length;
  int get _approvedCount => _releases.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'approved').length;
  int get _paidCount     => _releases.where((r) => r['paymentVerified'] == true).length;

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

  // ── TOP BAR — no ? button, New Release fits properly ────────────
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
          const SizedBox(height: 22),
          _buildStatsRow(),
          const SizedBox(height: 22),
          _buildFilterRow(),
          const SizedBox(height: 20),
          _buildSectionHeader(),
          const SizedBox(height: 12),
          _releases.isEmpty ? _buildEmptyState() : _buildCards(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _StatCard(value: '$_totalReleases', label: 'Total',    sub: 'All time',       color: _white70)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: '$_pendingCount',  label: 'Pending',  sub: 'In queue',       color: _amber)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: '$_approvedCount', label: 'Approve', sub: 'Live', color: _green)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: '$_paidCount',     label: 'Paid',     sub: 'Confirmed',      color: _cyan)),
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

  Widget _buildCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(_filtered.length, (i) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + i * 80),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => Transform.translate(
              offset: Offset(0, 20 * (1 - v)),
              child: Opacity(opacity: v, child: child),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ReleaseCard(
                data: _filtered[i],
                db: _db,
                onRefresh: _loadReleases,
                onNavigate: (route) => Navigator.pushNamed(context, route),
              ),
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
        children: List.generate(3, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _SkeletonCard(),
        )),
      ),
    );
  }

  // ── SIDEBAR ─────────────────────────────────────────────────────
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
                  _SidebarItem(icon: Icons.credit_card_rounded,   label: 'Pay Now',            onTap: () { _closeSidebar(); _launch('https://444music-distribution.vercel.app/pay.html'); }),
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
//  RELEASE CARD
// ════════════════════════════════════════════════════════════════════
class _ReleaseCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final FirebaseFirestore db;
  final VoidCallback onRefresh;
  final void Function(String) onNavigate;
  const _ReleaseCard({required this.data, required this.db, required this.onRefresh, required this.onNavigate});
  @override
  State<_ReleaseCard> createState() => _ReleaseCardState();
}

class _ReleaseCardState extends State<_ReleaseCard> with SingleTickerProviderStateMixin {
  late AnimationController _progressCtrl;
  late Animation<double>   _progressAnim;
  bool _pressed = false;

  String get _id         => widget.data['_id'] ?? '';
  String get _status     => (widget.data['status'] ?? 'Pending').toString().trim();
  bool   get _isApproved => _status.toLowerCase() == 'approved';
  bool   get _isRejected => _status.toLowerCase() == 'rejected';
  bool   get _isPaid     => widget.data['paymentVerified'] == true;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    final pct = _statusProgress(_status) / 100.0;
    _progressAnim = Tween<double>(begin: 0, end: pct)
        .animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _progressCtrl.forward();
    });
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  void _openModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReleaseDetailModal(
        data: widget.data,
        db: widget.db,
        onRefresh: widget.onRefresh,
        onNavigate: widget.onNavigate,
      ),
    );
  }

  // ── FIXED: proper base64 encoding ───────────────────────────────
  Future<void> _editCoverArt() async {
    final picker = ImagePicker();
    final file   = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (file == null) return;
    final bytes      = await file.readAsBytes();
    final base64Str  = base64Encode(bytes);
    final dataUrl    = 'data:image/jpeg;base64,$base64Str';
    await widget.db.collection('submissions').doc(_id).update({'coverURL': dataUrl});
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(_status);
    final releaseDate = widget.data['releaseDate'] != null ? _formatDate(widget.data['releaseDate']) : 'TBA';

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); _openModal(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        transform: Matrix4.identity()..scale(_pressed ? 0.984 : 1.0),
        decoration: BoxDecoration(
          color: _black2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _isRejected ? _rose.withValues(alpha: 0.4) : _white10),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover art
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              child: _buildCoverArt(),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + artist
                  Row(
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.data['releaseTitle'] ?? 'Untitled Release',
                            style: GoogleFonts.nunito(color: _white, fontSize: 15, fontWeight: FontWeight.w800),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.data['artistName'] ?? 'Unknown Artist',
                            style: GoogleFonts.nunito(color: _grey, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      )),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _white, shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: _white.withValues(alpha: 0.12), blurRadius: 10)],
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded, color: _black, size: 14),
                      ),
                    ],
                  ),

                  if ((widget.data['featuring'] ?? '').toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(7), border: Border.all(color: _white10)),
                      child: Text('ft. ${widget.data['featuring']}',
                          style: GoogleFonts.nunito(color: _grey, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],

                  const SizedBox(height: 10),

                  Row(children: [
                    const Icon(Icons.calendar_today_rounded, color: _greyDark, size: 12),
                    const SizedBox(width: 5),
                    Text('Release: ', style: GoogleFonts.nunito(color: _grey, fontSize: 11)),
                    Text(releaseDate, style: GoogleFonts.nunito(color: _white70, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),

                  const SizedBox(height: 12),

                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_statusLabel(_status), style: GoogleFonts.nunito(color: _grey, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text('${_statusProgress(_status)}%', style: GoogleFonts.nunito(color: _grey, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 3,
                          child: AnimatedBuilder(
                            animation: _progressAnim,
                            builder: (_, __) => LinearProgressIndicator(
                              value: _progressAnim.value,
                              backgroundColor: _black4,
                              valueColor: AlwaysStoppedAnimation<Color>(_isRejected ? _rose : statusColor),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(children: [
                    _StatusBadge(status: _status, small: true),
                    const SizedBox(width: 6),
                    _PaidBadge(paid: _isPaid),
                    if (_isApproved) ...[const SizedBox(width: 6), const _LiveDot()],
                  ]),

                  // ── REJECTED BUTTON — fully visible ─────────────
                  if (_isRejected) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => widget.onNavigate('/rejection'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: _rose.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _rose, width: 1.5),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.info_rounded, color: _rose, size: 16),
                          const SizedBox(width: 8),
                          Text('Check Reasons',
                              style: GoogleFonts.nunito(color: _rose, fontSize: 13, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                  ],

                  // ── APPROVED PROMOTE BUTTON — fully visible ──────
                  if (_isApproved) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _launch('https://444musicblog.vercel.app'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: _amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _amber, width: 1.5),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.trending_up_rounded, color: _amber, size: 16),
                          const SizedBox(width: 8),
                          Text('Promote',
                              style: GoogleFonts.nunito(color: _amber, fontSize: 13, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Action row
                  Row(children: [
                    Expanded(child: _ActionBtn(icon: Icons.image_rounded, label: 'Edit Cover', onTap: _editCoverArt)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _isApproved
                          ? _ActionBtn(icon: Icons.link_rounded, label: 'Smart Link', onTap: _openModal, highlight: true)
                          : _ActionBtn(icon: Icons.add_rounded,  label: 'New Release', onTap: () => widget.onNavigate('/upload')),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── FIXED: handles base64 and network URLs ───────────────────────
  Widget _buildCoverArt() {
    final url = widget.data['coverURL']?.toString() ?? '';
    const h   = 200.0;

    if (url.isEmpty) return _coverPlaceholder(h);

    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, height: h, width: double.infinity, fit: BoxFit.cover);
      } catch (_) {
        return _coverPlaceholder(h);
      }
    }

    return CachedNetworkImage(
      imageUrl: url,
      height: h, width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(height: h, color: _black3),
      errorWidget: (_, __, ___) => _coverPlaceholder(h),
    );
  }

  Widget _coverPlaceholder(double h) => GestureDetector(
    onTap: _editCoverArt,
    child: Container(
      height: h, width: double.infinity, color: _black3,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.add_photo_alternate_outlined, color: _greyDark, size: 34),
        const SizedBox(height: 8),
        Text('Tap to add cover art', style: GoogleFonts.nunito(color: _greyDark, fontSize: 12)),
      ]),
    ),
  );
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

// ════════════════════════════════════════════════════════════════════
//  RELEASE DETAIL MODAL
// ════════════════════════════════════════════════════════════════════
class _ReleaseDetailModal extends StatefulWidget {
  final Map<String, dynamic> data;
  final FirebaseFirestore db;
  final VoidCallback onRefresh;
  final void Function(String) onNavigate;
  const _ReleaseDetailModal({required this.data, required this.db, required this.onRefresh, required this.onNavigate});
  @override
  State<_ReleaseDetailModal> createState() => _ReleaseDetailModalState();
}

class _ReleaseDetailModalState extends State<_ReleaseDetailModal> {
  bool    _generatingLink = false;
  String? _copiedMsg;

  String get _id         => widget.data['_id'] ?? '';
  String get _status     => (widget.data['status'] ?? 'Pending').toString().trim();
  bool   get _isApproved => _status.toLowerCase() == 'approved';

  late Map<String, dynamic> _data;

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
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        _StatusBadge(status: _status, small: true),
        _PaidBadge(paid: _data['paymentVerified'] == true),
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
//  SHARED WIDGETS
// ════════════════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final String value, label, sub;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.sub, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(color: _black2, borderRadius: BorderRadius.circular(14), border: Border.all(color: _white10)),
    child: Column(children: [
      Text(value, style: GoogleFonts.nunito(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.nunito(color: _white, fontSize: 11, fontWeight: FontWeight.w700)),
      const SizedBox(height: 1),
      Text(sub, style: GoogleFonts.nunito(color: _greyDark, fontSize: 9, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
    ]),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool small;
  const _StatusBadge({required this.status, this.small = false});
  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 9 : 12, vertical: small ? 4 : 6),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(7), border: Border.all(color: c.withValues(alpha: 0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(
          status.isEmpty ? 'Pending' : (status[0].toUpperCase() + status.substring(1)),
          style: GoogleFonts.nunito(color: c, fontSize: small ? 11 : 12, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ]),
    );
  }
}

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

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  const _ActionBtn({required this.icon, required this.label, required this.onTap, this.highlight = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? _white.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: highlight ? _white40 : _white20),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: highlight ? _white : _white70, size: 13),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.nunito(color: highlight ? _white : _white70, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
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

class _SkeletonCard extends StatefulWidget {
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}
class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
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
        decoration: BoxDecoration(color: _black2, borderRadius: BorderRadius.circular(20), border: Border.all(color: _white10)),
        child: Column(children: [
          Container(height: 180,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              gradient: LinearGradient(
                begin: Alignment(_a.value - 1, 0), end: Alignment(_a.value + 1, 0),
                colors: [_black3, _black4, _black3],
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _shimmerLine(0.7), const SizedBox(height: 8),
              _shimmerLine(0.45), const SizedBox(height: 12),
              _shimmerLine(0.3),
            ]),
          ),
        ]),
      ),
    );
  }
  Widget _shimmerLine(double w) => FractionallySizedBox(
    widthFactor: w,
    child: Container(height: 12, decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(6))),
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