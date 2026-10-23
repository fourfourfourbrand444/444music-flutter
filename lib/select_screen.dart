import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─── PALETTE (mirrors web CSS variables) ─────────────────────────────
const _bg     = Color(0xFF000000);
const _s1     = Color(0xFF1C1C1E);
const _s2     = Color(0xFF2C2C2E);
const _sep    = Color.fromRGBO(84, 84, 88, 0.55);
const _fill   = Color.fromRGBO(120, 120, 128, 0.24);
const _t1     = Color(0xFFFFFFFF);
const _t2     = Color.fromRGBO(235, 235, 245, 0.60);
const _t3     = Color.fromRGBO(235, 235, 245, 0.30);
const _yellow = Color(0xFFFDEB0D);
const _ease   = Cubic(0.32, 0.72, 0, 1);

TextStyle _ts(double size, FontWeight w, Color c, {double ls = -0.01, double? h}) =>
    TextStyle(
      fontSize: size,
      fontWeight: w,
      color: c,
      letterSpacing: size * ls,
      height: h,
      decoration: TextDecoration.none,
    );

// ─── MODEL ───────────────────────────────────────────────────────────
class _Store {
  final String name;
  final String? slug;
  final IconData icon;
  final String tag;
  final String label;
  const _Store(this.name, this.slug, this.icon, {this.tag = '', String? label})
      : label = label ?? name;
}

class _Section {
  final String title;
  final List<_Store> items;
  const _Section(this.title, this.items);
}

// ─── DATA (identical order and names to web) ─────────────────────────
const _sections = <_Section>[
  _Section('Streaming', [
    _Store('Spotify', 'spotify', Icons.music_note_rounded, tag: 'Top'),
    _Store('Apple Music', 'applemusic', Icons.apple_rounded, tag: 'Top'),
    _Store('YouTube Music', 'youtubemusic', Icons.smart_display_rounded, tag: 'Top'),
    _Store('Amazon Music', 'amazonmusic', Icons.shopping_bag_rounded),
    _Store('Tidal', 'tidal', Icons.water_rounded),
    _Store('Deezer', 'deezer', Icons.play_circle_rounded),
    _Store('Pandora', 'pandora', Icons.radio_rounded),
    _Store('SoundCloud', 'soundcloud', Icons.cloud_rounded),
    _Store('Napster', 'napster', Icons.music_note_rounded),
    _Store('Qobuz', null, Icons.album_rounded),
    _Store('iHeart Radio', 'iheartradio', Icons.cell_tower_rounded),
    _Store('Anghami', null, Icons.public_rounded),
  ]),
  _Section('Social & video', [
    _Store('TikTok', 'tiktok', Icons.music_video_rounded, tag: 'Viral'),
    _Store('Instagram', 'instagram', Icons.camera_alt_rounded),
    _Store('Facebook', 'facebook', Icons.facebook_rounded),
    _Store('YouTube', 'youtube', Icons.smart_display_rounded),
    _Store('Snapchat', 'snapchat', Icons.chat_bubble_rounded),
    _Store('Triller', null, Icons.videocam_rounded),
  ]),
  _Section('African platforms', [
    _Store('Boomplay', null, Icons.music_note_rounded, tag: 'Africa'),
    _Store('Audiomack', 'audiomack', Icons.headphones_rounded, tag: 'Africa'),
    _Store('Mdundo', null, Icons.album_rounded),
    _Store('Aftown', null, Icons.music_note_rounded),
    _Store('Spinlet', null, Icons.headphones_rounded),
    _Store('Iroking', null, Icons.play_arrow_rounded, label: 'iROKING'),
  ]),
  _Section('Radio, sync & more', [
    _Store('Shazam', 'shazam', Icons.search_rounded),
    _Store('Beatport', 'beatport', Icons.album_rounded),
    _Store('Bandcamp', 'bandcamp', Icons.graphic_eq_rounded),
    _Store('7digital', null, Icons.download_rounded),
    _Store('Resso', null, Icons.graphic_eq_rounded),
    _Store('NetEase Music', 'neteasecloudmusic', Icons.cloud_rounded, label: 'NetEase'),
    _Store('KKBox', 'kkbox', Icons.inventory_2_rounded),
    _Store('Joox', null, Icons.music_note_rounded),
    _Store('Claro Música', null, Icons.signal_cellular_alt_rounded),
    _Store('Fizy', null, Icons.play_arrow_rounded),
    _Store('Yandex Music', 'yandex', Icons.music_note_rounded),
    _Store('Gaana', null, Icons.music_note_rounded),
    _Store('JioSaavn', 'jiosaavn', Icons.play_arrow_rounded),
    _Store('Hungama', null, Icons.headphones_rounded),
    _Store('Nuuday', null, Icons.cell_tower_rounded),
    _Store('MediaNet', null, Icons.lan_rounded),
  ]),
  _Section('Global & regional', [
    _Store('AMI Entertainment', null, Icons.headphones_rounded),
    _Store('AWA', null, Icons.music_note_rounded),
    _Store('Gracenote', null, Icons.storage_rounded),
    _Store('InProdicon', null, Icons.interests_rounded),
    _Store('LINE', 'line', Icons.chat_bubble_rounded),
    _Store('MixCloud', 'mixcloud', Icons.cloud_rounded),
    _Store('Music Aroma', null, Icons.music_note_rounded),
    _Store('Muud', null, Icons.sentiment_satisfied_alt_rounded),
    _Store('Peloton', 'peloton', Icons.directions_bike_rounded),
    _Store('Saavn', 'jiosaavn', Icons.play_arrow_rounded),
    _Store('Sirius XM', 'siriusxm', Icons.satellite_alt_rounded),
    _Store('SoundMouse', null, Icons.mouse_rounded),
    _Store('Tencent', 'tencentqq', Icons.chat_rounded),
    _Store('iMusica', null, Icons.signal_cellular_alt_rounded),
    _Store('KION', null, Icons.movie_rounded),
    _Store('Zvuk', null, Icons.volume_up_rounded),
    _Store('VK Музыка', 'vk', Icons.people_rounded),
    _Store('ОК Музыка', 'odnoklassniki', Icons.people_alt_rounded),
  ]),
];

// ════════════════════════════════════════════════════════════════════
//  SCREEN — every store is pre-selected and locked (same as web).
//  Search only filters what is visible; Continue carries the full list.
// ════════════════════════════════════════════════════════════════════
class SelectScreen extends StatefulWidget {
  const SelectScreen({super.key});
  @override
  State<SelectScreen> createState() => _SelectScreenState();
}

class _SelectScreenState extends State<SelectScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  late final List<String> _allNames =
      _sections.expand((s) => s.items).map((i) => i.name).toList();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _bg,
    ));
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase().trim();
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    HapticFeedback.mediumImpact();
    Navigator.pushNamed(context, '/confirm', arguments: _allNames);
  }

  @override
  Widget build(BuildContext context) {
    final mq     = MediaQuery.of(context);
    final top    = mq.padding.top;
    final bottom = mq.padding.bottom;
    final width  = mq.size.width;
    final hPad   = width > 672 ? (width - 640) / 2 + 16 : 16.0;
    final narrow = width <= 420;

    // Filtered sections
    final visible = <_Section>[];
    var visibleCount = 0;
    for (final s in _sections) {
      final items = _query.isEmpty
          ? s.items
          : s.items.where((i) => i.name.toLowerCase().contains(_query)).toList();
      if (items.isNotEmpty) {
        visible.add(_Section(s.title, items));
        visibleCount += items.length;
      }
    }
    final showEmpty = visibleCount == 0 && _query.isNotEmpty;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── SCROLL CONTENT ────────────────────────────────────
          CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(hPad, top + 56, hPad, bottom + 130),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _hero(narrow),
                    _search(),
                    for (final s in visible) _sectionBlock(s),
                    if (_query.isEmpty) _moreBlock(),
                    if (showEmpty) _empty(),
                  ]),
                ),
              ),
            ],
          ),

          // ── TOP BAR ───────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _topBar(top, hPad),
          ),

          // ── DOCK ──────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _dock(bottom, hPad),
          ),
        ],
      ),
    );
  }

  // ── TOP BAR ─────────────────────────────────────────────────────
  Widget _topBar(double top, double hPad) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            color: const Color.fromRGBO(0, 0, 0, 0.72),
            padding: EdgeInsets.only(top: top, left: hPad, right: hPad),
            height: top + 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Pressable(
                  scale: 0.92,
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(
                        color: _fill, shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_left_rounded,
                        color: _t1, size: 26),
                  ),
                ),
                Text('Stores', style: _ts(17, FontWeight.w600, _t1)),
                const SizedBox(width: 36),
              ],
            ),
          ),
        ),
      );

  // ── HERO ────────────────────────────────────────────────────────
  Widget _hero(bool narrow) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your stores',
                style: _ts(narrow ? 30 : 34, FontWeight.w700, _t1,
                    ls: -0.04, h: 1.1)),
            const SizedBox(height: 6),
            Text('Your release goes to every platform below.',
                style: _ts(17, FontWeight.w400, _t2, h: 1.4)),
          ],
        ),
      );

  // ── SEARCH ──────────────────────────────────────────────────────
  Widget _search() => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: _fill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.search_rounded, color: _t2, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: _ts(17, FontWeight.w400, _t1),
                  cursorColor: _yellow,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: _ts(17, FontWeight.w400, _t2),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _searchCtrl.clear();
                    FocusScope.of(context).unfocus();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.cancel_rounded, color: _t2, size: 17),
                  ),
                ),
            ],
          ),
        ),
      );

  // ── SECTION ─────────────────────────────────────────────────────
  Widget _sectionBlock(_Section s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 30, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.title.toUpperCase(),
                    style: _ts(13, FontWeight.w500, _t2, ls: 0.04)),
                Text('${s.items.length}',
                    style: _ts(13, FontWeight.w400, _t3).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _s1,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < s.items.length; i++) ...[
                  if (i > 0) _divider(),
                  _StoreRow(item: s.items[i]),
                ],
              ],
            ),
          ),
        ],
      );

  Widget _divider() => Container(
        height: 0.5,
        margin: const EdgeInsets.only(left: 70),
        color: _sep,
      );

  // ── "AND MORE" ──────────────────────────────────────────────────
  Widget _moreBlock() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 30, 16, 8),
            child: Text('AND MORE',
                style: _ts(13, FontWeight.w500, _t2, ls: 0.04)),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _s1,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _s2,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.layers_rounded,
                      color: _yellow, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('+150 more stores',
                          style: _ts(17, FontWeight.w600, _t1)),
                      const SizedBox(height: 2),
                      Text(
                        'Your music also reaches every other store in our distribution network worldwide.',
                        style: _ts(14, FontWeight.w400, _t2, h: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  // ── EMPTY ───────────────────────────────────────────────────────
  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 20),
        child: Column(
          children: [
            Icon(Icons.search_rounded,
                color: _t2.withOpacity(0.4), size: 36),
            const SizedBox(height: 10),
            Text('No results', style: _ts(17, FontWeight.w400, _t2)),
          ],
        ),
      );

  // ── DOCK ────────────────────────────────────────────────────────
  Widget _dock(double bottom, double hPad) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12 + bottom),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(0, 0, 0, 0.72),
              border: Border(top: BorderSide(color: _sep, width: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    style: _ts(14, FontWeight.w400, _t2),
                    children: [
                      const TextSpan(text: 'All '),
                      TextSpan(
                        text: '${_allNames.length}',
                        style: _ts(14, FontWeight.w600, _t1).copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                      const TextSpan(text: ' platforms selected'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                _Pressable(
                  scale: 0.98,
                  onTap: _continue,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _yellow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Continue',
                        style: _ts(17, FontWeight.w600, Colors.black)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  STORE ROW — always "selected", not tappable (cursor: default on web)
// ════════════════════════════════════════════════════════════════════
class _StoreRow extends StatelessWidget {
  final _Store item;
  const _StoreRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _s2,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: _icon(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ts(17, FontWeight.w400, _t1)),
            ),
            if (item.tag.isNotEmpty) ...[
              const SizedBox(width: 14),
              Text(item.tag, style: _ts(13, FontWeight.w400, _t3)),
            ],
            const SizedBox(width: 14),
            Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(
                  color: _yellow, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: Colors.black, size: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _icon() {
    final fallback = Icon(item.icon, color: _t2, size: 18);
    if (item.slug == null) return fallback;
    return SizedBox(
      width: 20, height: 20,
      child: SvgPicture.network(
        'https://cdn.simpleicons.org/${item.slug}/ffffff',
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox.shrink(),
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PRESSABLE — iOS-style press scale (matches web :active transform)
// ════════════════════════════════════════════════════════════════════
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;
  const _Pressable({
    required this.child,
    required this.onTap,
    required this.scale,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 300),
        curve: _ease,
        child: widget.child,
      ),
    );
  }
}
