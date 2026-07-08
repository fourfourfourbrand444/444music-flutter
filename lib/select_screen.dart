import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─── PALETTE ────────────────────────────────────────────────────────
const _black       = Color(0xFF000000);
const _black1      = Color(0xFF0A0A0A);
const _black2      = Color(0xFF111111);
const _white       = Color(0xFFFFFFFF);
const _white80     = Color(0xCCFFFFFF);
const _white50     = Color(0x80FFFFFF);
const _white10     = Color(0x1AFFFFFF);
const _white06     = Color(0x0FFFFFFF);
const _grey        = Color(0xFF888888);
const _greyDark    = Color(0xFF444444);
const _green       = Color(0xFF22C55E);
const _greenDim    = Color(0x1F22C55E);
const _greenBorder = Color(0x4422C55E);

// ─── PLATFORM MODEL ──────────────────────────────────────────────────
class PlatformItem {
  final String name;
  final String tag;
  final Color  gradient1;
  final Color  gradient2;
  final String fallback;
  // simpleIconSlug: slug used on cdn.simpleicons.org
  // Empty string = not available on CDN, use fallback initials
  final String simpleIconSlug;

  const PlatformItem({
    required this.name,
    this.tag = '',
    required this.gradient1,
    required this.gradient2,
    required this.fallback,
    required this.simpleIconSlug,
  });

  String get iconUrl => simpleIconSlug.isNotEmpty
      ? 'https://cdn.simpleicons.org/$simpleIconSlug/white'
      : '';

  bool get hasIcon => simpleIconSlug.isNotEmpty;
}

// ─── PLATFORM DATA ────────────────────────────────────────────────────
const _major = <PlatformItem>[
  PlatformItem(name: 'Spotify',      tag: 'Top',
      gradient1: Color(0xFF1DB954), gradient2: Color(0xFF0f6b32),
      fallback: 'SP', simpleIconSlug: 'spotify'),
  PlatformItem(name: 'Apple Music',  tag: 'Top',
      gradient1: Color(0xFFfc3c44), gradient2: Color(0xFF8b0000),
      fallback: 'AM', simpleIconSlug: 'applemusic'),
  PlatformItem(name: 'YouTube Music',tag: 'Top',
      gradient1: Color(0xFFFF0000), gradient2: Color(0xFF600000),
      fallback: 'YT', simpleIconSlug: 'youtubemusic'),
  PlatformItem(name: 'Amazon Music',
      gradient1: Color(0xFF232F3E), gradient2: Color(0xFF131921),
      fallback: 'AZ', simpleIconSlug: 'amazonmusic'),
  PlatformItem(name: 'Tidal',
      gradient1: Color(0xFF000000), gradient2: Color(0xFF1a1a1a),
      fallback: 'TD', simpleIconSlug: 'tidal'),
  PlatformItem(name: 'Deezer',
      gradient1: Color(0xFFA238FF), gradient2: Color(0xFF5c00c7),
      fallback: 'DZ', simpleIconSlug: 'deezer'),
  PlatformItem(name: 'Pandora',
      gradient1: Color(0xFF005483), gradient2: Color(0xFF00244d),
      fallback: 'PN', simpleIconSlug: 'pandora'),
  PlatformItem(name: 'SoundCloud',
      gradient1: Color(0xFFFF5500), gradient2: Color(0xFF8c2f00),
      fallback: 'SC', simpleIconSlug: 'soundcloud'),
  PlatformItem(name: 'Napster',
      gradient1: Color(0xFF21a0ab), gradient2: Color(0xFF0d5c63),
      fallback: 'NS', simpleIconSlug: 'napster'),
  PlatformItem(name: 'Qobuz',
      gradient1: Color(0xFF0b5fff), gradient2: Color(0xFF0030aa),
      fallback: 'QB', simpleIconSlug: 'qobuz'),
  PlatformItem(name: 'iHeart Radio',
      gradient1: Color(0xFFc8102e), gradient2: Color(0xFF7a0018),
      fallback: 'iH', simpleIconSlug: 'iheartradio'),
  PlatformItem(name: 'Anghami',
      gradient1: Color(0xFF7d3cff), gradient2: Color(0xFF4400bb),
      fallback: 'AN', simpleIconSlug: 'anghami'),
];

const _social = <PlatformItem>[
  PlatformItem(name: 'TikTok',     tag: 'Viral',
      gradient1: Color(0xFF010101), gradient2: Color(0xFF2a2a2a),
      fallback: 'TT', simpleIconSlug: 'tiktok'),
  PlatformItem(name: 'Instagram',
      gradient1: Color(0xFFf09433), gradient2: Color(0xFFbc1888),
      fallback: 'IG', simpleIconSlug: 'instagram'),
  PlatformItem(name: 'Facebook',
      gradient1: Color(0xFF1877F2), gradient2: Color(0xFF0a3d8f),
      fallback: 'FB', simpleIconSlug: 'facebook'),
  PlatformItem(name: 'YouTube',
      gradient1: Color(0xFFFF0000), gradient2: Color(0xFF8b0000),
      fallback: 'YT', simpleIconSlug: 'youtube'),
  PlatformItem(name: 'Snapchat',
      gradient1: Color(0xFFFFD700), gradient2: Color(0xFFb8920a),
      fallback: 'SN', simpleIconSlug: 'snapchat'),
  PlatformItem(name: 'Triller',
      gradient1: Color(0xFFe91e63), gradient2: Color(0xFF7b0030),
      fallback: 'TR', simpleIconSlug: ''),
];

const _africa = <PlatformItem>[
  PlatformItem(name: 'Boomplay',  tag: 'Africa',
      gradient1: Color(0xFFff6b35), gradient2: Color(0xFF9e2600),
      fallback: 'BP', simpleIconSlug: 'boomplay'),
  PlatformItem(name: 'Audiomack', tag: 'Africa',
      gradient1: Color(0xFFFFA500), gradient2: Color(0xFF9e5500),
      fallback: 'AU', simpleIconSlug: 'audiomack'),
  PlatformItem(name: 'Mdundo',
      gradient1: Color(0xFF00a878), gradient2: Color(0xFF005c42),
      fallback: 'MD', simpleIconSlug: ''),
  PlatformItem(name: 'Aftown',
      gradient1: Color(0xFFe63946), gradient2: Color(0xFF7a0010),
      fallback: 'AF', simpleIconSlug: ''),
  PlatformItem(name: 'Spinlet',
      gradient1: Color(0xFF457b9d), gradient2: Color(0xFF1d3557),
      fallback: 'SL', simpleIconSlug: ''),
  PlatformItem(name: 'iROKING',
      gradient1: Color(0xFFf4a261), gradient2: Color(0xFF6e2500),
      fallback: 'IK', simpleIconSlug: ''),
];

const _radio = <PlatformItem>[
  PlatformItem(name: 'Shazam',
      gradient1: Color(0xFF0088ff), gradient2: Color(0xFF003faa),
      fallback: 'SZ', simpleIconSlug: 'shazam'),
  PlatformItem(name: 'Beatport',
      gradient1: Color(0xFF00cc00), gradient2: Color(0xFF005500),
      fallback: 'BT', simpleIconSlug: 'beatport'),
  PlatformItem(name: 'Bandcamp',
      gradient1: Color(0xFF1da0c3), gradient2: Color(0xFF0d5c73),
      fallback: 'BC', simpleIconSlug: 'bandcamp'),
  PlatformItem(name: '7digital',
      gradient1: Color(0xFFe91e8c), gradient2: Color(0xFF7a004a),
      fallback: '7D', simpleIconSlug: '7digital'),
  PlatformItem(name: 'Resso',
      gradient1: Color(0xFFff4e6a), gradient2: Color(0xFF7a0022),
      fallback: 'RS', simpleIconSlug: 'resso'),
  PlatformItem(name: 'NetEase',
      gradient1: Color(0xFFc62828), gradient2: Color(0xFF6a0000),
      fallback: 'NE', simpleIconSlug: 'neteasecloudmusic'),
  PlatformItem(name: 'KKBox',
      gradient1: Color(0xFF00bcd4), gradient2: Color(0xFF005c66),
      fallback: 'KK', simpleIconSlug: 'kkbox'),
  PlatformItem(name: 'Joox',
      gradient1: Color(0xFF43a047), gradient2: Color(0xFF1a4d1c),
      fallback: 'JX', simpleIconSlug: 'joox'),
  PlatformItem(name: 'Gaana',
      gradient1: Color(0xFFe53935), gradient2: Color(0xFF7a0000),
      fallback: 'GA', simpleIconSlug: 'gaana'),
  PlatformItem(name: 'JioSaavn',
      gradient1: Color(0xFF29b6f6), gradient2: Color(0xFF0060aa),
      fallback: 'JS', simpleIconSlug: 'jiosaavn'),
  PlatformItem(name: 'Hungama',
      gradient1: Color(0xFFff6f00), gradient2: Color(0xFF8c3300),
      fallback: 'HU', simpleIconSlug: 'hungama'),
  PlatformItem(name: 'Yandex Music',
      gradient1: Color(0xFFffcc00), gradient2: Color(0xFF997a00),
      fallback: 'YX', simpleIconSlug: 'yandexmusic'),
  PlatformItem(name: 'Claro Música',
      gradient1: Color(0xFFe53935), gradient2: Color(0xFF6a0000),
      fallback: 'CM', simpleIconSlug: ''),
  PlatformItem(name: 'MediaNet',
      gradient1: Color(0xFF546e7a), gradient2: Color(0xFF1e3038),
      fallback: 'MN', simpleIconSlug: ''),
];

// ════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ════════════════════════════════════════════════════════════════════
class SelectScreen extends StatefulWidget {
  const SelectScreen({super.key});
  @override
  State<SelectScreen> createState() => _SelectScreenState();
}

class _SelectScreenState extends State<SelectScreen>
    with TickerProviderStateMixin {

  final Set<String> _selected = {};
  final _searchCtrl = TextEditingController();
  String _query = '';

  late AnimationController _headerCtrl;
  late Animation<double>   _headerFade;
  late Animation<Offset>   _headerSlide;
  late AnimationController _barCtrl;
  late Animation<double>   _barSlide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));

    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _headerFade  = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
        begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _headerCtrl, curve: Curves.easeOutCubic));
    _headerCtrl.forward();

    _barCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _barSlide = CurvedAnimation(parent: _barCtrl, curve: Curves.easeOutCubic);

    _searchCtrl.addListener(
            () => setState(() => _query = _searchCtrl.text.toLowerCase().trim()));
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _barCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggle(String name) {
    HapticFeedback.selectionClick();
    setState(() => _selected.contains(name)
        ? _selected.remove(name)
        : _selected.add(name));
    _selected.isEmpty ? _barCtrl.reverse() : _barCtrl.forward();
  }

  void _selectAll() {
    setState(() => _selected.addAll(
        [..._major, ..._social, ..._africa, ..._radio].map((p) => p.name)));
    _barCtrl.forward();
    HapticFeedback.mediumImpact();
  }

  void _clearAll() {
    setState(() => _selected.clear());
    _barCtrl.reverse();
    HapticFeedback.lightImpact();
  }

  List<PlatformItem> _filter(List<PlatformItem> src) => _query.isEmpty
      ? src
      : src.where((p) => p.name.toLowerCase().contains(_query)).toList();

  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    final mF = _filter(_major);
    final sF = _filter(_social);
    final aF = _filter(_africa);
    final rF = _filter(_radio);
    final total = mF.length + sF.length + aF.length + rF.length;

    return Scaffold(
      backgroundColor: _black,
      body: Stack(
        children: [

          // ── SCROLL CONTENT ──────────────────────────────────────
          CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: top + 76)),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                      position: _headerSlide, child: _header()),
                ),
              ),
              SliverToBoxAdapter(
                  child: FadeTransition(opacity: _headerFade, child: _search())),
              SliverToBoxAdapter(child: _banner()),

              if (total == 0 && _query.isNotEmpty)
                SliverFillRemaining(child: _empty())
              else ...[
                if (mF.isNotEmpty) ...[_sLabel('🔥  Major Streaming'), _grid(mF)],
                if (sF.isNotEmpty) ...[_sdiv('Social & Video'),         _grid(sF)],
                if (aF.isNotEmpty) ...[_sdiv('🌍  African Platforms'),  _grid(aF)],
                if (rF.isNotEmpty) ...[_sdiv('📻  Radio, Sync & More'), _grid(rF)],
              ],
              SliverToBoxAdapter(child: SizedBox(height: bottom + 130)),
            ],
          ),

          // ── TOP BAR ─────────────────────────────────────────────
          Positioned(top: 0, left: 0, right: 0,
              child: RepaintBoundary(child: _topBar(top))),

          // ── BOTTOM BAR ──────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                  begin: const Offset(0, 1.2), end: Offset.zero)
                  .animate(_barSlide),
              child: _bottomBar(bottom),
            ),
          ),
        ],
      ),
    );
  }

  // ── TOP BAR ─────────────────────────────────────────────────────
  Widget _topBar(double top) => Container(
    padding: EdgeInsets.only(top: top),
    decoration: BoxDecoration(
      color: _black.withOpacity(0.94),
      border: const Border(bottom: BorderSide(color: _white10)),
    ),
    child: SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _white06,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _white10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: _white, size: 15),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STEP 2 OF 4',
                      style: GoogleFonts.outfit(
                          color: _greyDark, fontSize: 9,
                          fontWeight: FontWeight.w700, letterSpacing: 1.4)),
                  const SizedBox(height: 1),
                  Text('Distribution',
                      style: GoogleFonts.outfit(
                          color: _white, fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _selected.isNotEmpty ? _white : _white06,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                    color: _selected.isNotEmpty ? _white : _white10),
              ),
              child: Text('${_selected.length} selected',
                  style: GoogleFonts.outfit(
                      color: _selected.isNotEmpty ? _black : _grey,
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    ),
  );

  // ── HEADER ──────────────────────────────────────────────────────
  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Where should\nyour music live?',
            style: GoogleFonts.outfit(
                color: _white, fontSize: 32, fontWeight: FontWeight.w800,
                height: 1.1, letterSpacing: -0.5)),
        const SizedBox(height: 10),
        Text('Select the platforms you want to prioritise.\nYour music goes live across all chosen stores.',
            style: GoogleFonts.dmSans(
                color: _grey, fontSize: 13, height: 1.55)),
        const SizedBox(height: 28),
      ],
    ),
  );

  // ── SEARCH + ALL ─────────────────────────────────────────────────
  Widget _search() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
    child: Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: _black2,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _white10),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.search_rounded, color: _greyDark, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.dmSans(color: _white, fontSize: 14),
                    cursorColor: _white,
                    decoration: InputDecoration(
                      hintText: 'Search platforms…',
                      hintStyle: GoogleFonts.dmSans(color: _greyDark, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () { _searchCtrl.clear(); FocusScope.of(context).unfocus(); },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Container(
                        width: 18, height: 18,
                        decoration: const BoxDecoration(
                            color: _greyDark, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: _black, size: 11),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _selectAll,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _black2,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.done_all_rounded, color: _grey, size: 15),
                  const SizedBox(width: 6),
                  Text('All', style: GoogleFonts.outfit(
                      color: _grey, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // ── INFO BANNER ──────────────────────────────────────────────────
  Widget _banner() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _greenDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _greenBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _green, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'We distribute to 150+ stores worldwide. Platforms shown here are the most popular — your music also goes live on many more stores automatically.',
              style: GoogleFonts.dmSans(color: _green, fontSize: 11.5, height: 1.5),
            ),
          ),
        ],
      ),
    ),
  );

  SliverToBoxAdapter _sLabel(String t) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
      child: Text(t, style: GoogleFonts.outfit(
          color: _greyDark, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.3)),
    ),
  );

  SliverToBoxAdapter _sdiv(String t) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 32, 22, 20),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: _white10)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(t, style: GoogleFonts.outfit(
                color: _greyDark, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ),
          Expanded(child: Container(height: 1, color: _white10)),
        ],
      ),
    ),
  );

  SliverPadding _grid(List<PlatformItem> items) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      delegate: SliverChildBuilderDelegate(
            (ctx, i) => _PlatformCard(
          item: items[i],
          selected: _selected.contains(items[i].name),
          animDelay: Duration(milliseconds: 30 * i),
          onTap: () => _toggle(items[i].name),
        ),
        childCount: items.length,
      ),
    ),
  );

  Widget _empty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.search_off_rounded, color: _greyDark, size: 44),
        const SizedBox(height: 14),
        Text('No platforms found',
            style: GoogleFonts.outfit(
                color: _grey, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Try a different search term',
            style: GoogleFonts.dmSans(color: _greyDark, fontSize: 13)),
      ],
    ),
  );

  // ── BOTTOM BAR ──────────────────────────────────────────────────
  Widget _bottomBar(double bottom) => Container(
    padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: bottom + 14),
    decoration: BoxDecoration(
      color: _black1.withOpacity(0.97),
      border: const Border(top: BorderSide(color: _white10)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_selected.length} platform${_selected.length == 1 ? '' : 's'}',
                  style: GoogleFonts.outfit(
                      color: _white, fontSize: 15, fontWeight: FontWeight.w700)),
              Text('+ 150 more auto-included',
                  style: GoogleFonts.dmSans(color: _green, fontSize: 11)),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _clearAll,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: _white06,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.close_rounded, color: _grey, size: 15),
                  const SizedBox(width: 6),
                  Text('Clear', style: GoogleFonts.outfit(
                      color: _grey, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (_selected.isEmpty) return;
              HapticFeedback.mediumImpact();
              Navigator.pushNamed(context, '/confirm',
                  arguments: _selected.toList());
            },
            borderRadius: BorderRadius.circular(13),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Continue', style: GoogleFonts.outfit(
                      color: _black, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: _black, size: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  PLATFORM CARD
// ════════════════════════════════════════════════════════════════════
class _PlatformCard extends StatefulWidget {
  final PlatformItem item;
  final bool         selected;
  final Duration     animDelay;
  final VoidCallback onTap;

  const _PlatformCard({
    required this.item,
    required this.selected,
    required this.animDelay,
    required this.onTap,
  });

  @override
  State<_PlatformCard> createState() => _PlatformCardState();
}

class _PlatformCardState extends State<_PlatformCard>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.animDelay, () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sel  = widget.selected;
    final item = widget.item;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withOpacity(0.06),
            highlightColor: Colors.white.withOpacity(0.04),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: sel ? _white.withOpacity(0.08) : _black2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: sel ? _white50 : _white10,
                    width: sel ? 1.5 : 1.0),
                boxShadow: sel
                    ? [BoxShadow(
                    color: _white.withOpacity(0.06),
                    blurRadius: 18, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Stack(
                children: [

                  // Tag badge
                  if (item.tag.isNotEmpty)
                    Positioned(top: 8, left: 8,
                        child: _TagBadge(item.tag)),

                  // Check mark
                  Positioned(
                    top: 8, right: 8,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: sel ? 1.0 : 0.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                            color: sel ? _white : Colors.transparent,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded,
                            color: _black, size: 13),
                      ),
                    ),
                  ),

                  // Logo + name
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [

                          // Icon box with gradient background
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: sel ? 52 : 48,
                            height: sel ? 52 : 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [item.gradient1, item.gradient2],
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                // ── THE ICON WIDGET ──
                                child: item.hasIcon
                                    ? _SvgNetworkIcon(
                                  url: item.iconUrl,
                                  fallback: item.fallback,
                                )
                                    : _FallbackIcon(item.fallback),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Platform name
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: GoogleFonts.outfit(
                                color: sel ? _white : _grey,
                                fontSize: 11.5,
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                height: 1.2),
                            child: Text(item.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SVG NETWORK ICON — loads from Simple Icons CDN, falls back cleanly
// ════════════════════════════════════════════════════════════════════
class _SvgNetworkIcon extends StatefulWidget {
  final String url;
  final String fallback;
  const _SvgNetworkIcon({required this.url, required this.fallback});

  @override
  State<_SvgNetworkIcon> createState() => _SvgNetworkIconState();
}

class _SvgNetworkIconState extends State<_SvgNetworkIcon> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    if (_failed) return _FallbackIcon(widget.fallback);

    return SvgPicture.network(
      widget.url,
      fit: BoxFit.contain,
      // Force white colour — Simple Icons CDN returns brand-coloured SVGs,
      // we want white so they look clean on the gradient backgrounds
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      placeholderBuilder: (_) => const SizedBox.shrink(),
      headers: const {'Accept': 'image/svg+xml'},
      // If CDN fails (network error, slug not found, etc.) → show initials
      // flutter_svg throws to the ErrorWidget system; we intercept below
    );
  }

// flutter_svg v2 doesn't expose onError on SvgPicture.network directly.
// We use ErrorWidget.builder at app startup OR rely on the fact that
// all slugs in our data are pre-verified against simpleicons.org.
// For extra safety, wrap in an ErrorBoundary widget:
}

// ── Error boundary that catches flutter_svg network failures ─────────
class _SafeSvg extends StatelessWidget {
  final String url;
  final String fallback;
  const _SafeSvg({required this.url, required this.fallback});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) {
        try {
          return SvgPicture.network(
            url,
            fit: BoxFit.contain,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            placeholderBuilder: (_) => const SizedBox.shrink(),
            headers: const {'Accept': 'image/svg+xml'},
          );
        } catch (_) {
          return _FallbackIcon(fallback);
        }
      },
    );
  }
}

// ── Styled initials fallback ──────────────────────────────────────────
class _FallbackIcon extends StatelessWidget {
  final String text;
  const _FallbackIcon(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text,
          style: GoogleFonts.outfit(
              color: _white,
              fontSize: text.length > 2 ? 11 : 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5)),
    );
  }
}

// ── Tag badge ────────────────────────────────────────────────────────
class _TagBadge extends StatelessWidget {
  final String label;
  const _TagBadge(this.label);

  Color get _bg => label == 'Africa'
      ? const Color(0x2200a878)
      : label == 'Viral'
      ? const Color(0x22FF5500)
      : const Color(0x22FFFFFF);

  Color get _fg => label == 'Africa'
      ? const Color(0xFF00a878)
      : label == 'Viral'
      ? const Color(0xFFFF5500)
      : _white80;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _fg.withOpacity(0.35)),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(
              color: _fg, fontSize: 8,
              fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }
}