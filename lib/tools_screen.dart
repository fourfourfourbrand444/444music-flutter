// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Tools Screen
//  Route: '/tools'
//  Same look as the web Tools page: system font, same colours and icons.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── PALETTE (same as web) ──────────────────────────────────────────
const _bg    = Color(0xFF000000);
const _card  = Color(0xFF1C1C1E);
const _fill  = Color(0x3D767680);
const _text  = Color(0xFFF2F2F7);
const _text2 = Color(0xFF98989D);
const _sep   = Color(0xFF38383A);
const _blue  = Color(0xFF0A84FF);
const _red   = Color(0xFFFF453A);
const _redBg = Color(0x29FF453A);

const _catColors = {
  'artwork':    Color(0xFFFF375F),
  'audio':      Color(0xFFFF9F0A),
  'growth':     Color(0xFF30D158),
  'royalties':  Color(0xFF0A84FF),
  'management': Color(0xFF636366),
};

// System font: SF Pro on iPhone, Roboto on Android (same as the web page).
TextStyle _ts(Color color, double size, FontWeight weight,
    {double? ls, double? h}) {
  return TextStyle(
    color: color,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: ls,
    height: h,
  );
}

// ─── LAUNCHER ───────────────────────────────────────────────────────
Future<void> _launch(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─── DATA ───────────────────────────────────────────────────────────
class _Section {
  final String id;
  final String name;
  const _Section(this.id, this.name);
}

class _Tool {
  final String cat;
  final IconData icon;
  final String title;
  final String desc;
  final List<String> tags;
  final String url;
  final String button;
  final String? note;
  final String? warn;
  final bool danger;
  final bool claim; // opens the store list instead of a link

  const _Tool({
    required this.cat,
    required this.icon,
    required this.title,
    required this.desc,
    required this.tags,
    required this.button,
    this.url = '',
    this.note,
    this.warn,
    this.danger = false,
    this.claim = false,
  });
}

/// Stores that let artists claim a profile. Order = order shown in the list.
class _Store {
  final String name;
  final String note;
  final IconData? icon;
  final String letter;
  final Color color;
  final String url;
  const _Store(this.name, this.note, this.icon, this.letter, this.color,
      this.url);
}

const _claimStores = [
  _Store('Spotify', 'Spotify for Artists', FontAwesomeIcons.spotify, 'S',
      Color(0xFF1DB954), 'https://artists.spotify.com/c/claim'),
  _Store('Apple Music', 'Apple Music for Artists', FontAwesomeIcons.apple, 'A',
      Color(0xFFFA243C), 'https://artists.apple.com'),
  _Store('Boomplay', 'Boomplay for Artists', null, 'B', Color(0xFFE8281E),
      'https://www.boomplay.com/ForArtist'),
  _Store('YouTube Music', 'Official Artist Channel', FontAwesomeIcons.youtube,
      'Y', Color(0xFFFF0000),
      'https://support.google.com/youtube/answer/7336634'),
  _Store('Amazon Music', 'Amazon Music for Artists', FontAwesomeIcons.amazon,
      'A', Color(0xFF00A8E1), 'https://artists.amazonmusic.com'),
  _Store('Audiomack', 'Audiomack for Creators', null, 'A', Color(0xFFFF7A00),
      'https://audiomack.com/creators'),
  _Store('Deezer', 'Deezer for Creators', FontAwesomeIcons.deezer, 'D',
      Color(0xFFA238FF), 'https://creators.deezer.com'),
  _Store('TIDAL', 'TIDAL for Artists', null, 'T', Color(0xFF111111),
      'https://artists.tidal.com'),
  _Store('SoundCloud', 'SoundCloud for Artists', FontAwesomeIcons.soundcloud,
      'S', Color(0xFFFF5500), 'https://artists.soundcloud.com'),
  _Store('Pandora', 'Pandora AMP', null, 'P', Color(0xFF224099),
      'https://amp.pandora.com'),
];

const _sections = [
  _Section('artwork', 'Artwork'),
  _Section('audio', 'Audio'),
  _Section('growth', 'Growth'),
  _Section('royalties', 'Royalties'),
  _Section('management', 'Account'),
];

const _tools = [
  _Tool(
    cat: 'artwork',
    icon: FontAwesomeIcons.image,
    title: 'Cover Art Generator',
    desc:
        'Design album and single cover art that meets streaming platform requirements. No design experience needed.',
    tags: ['3000×3000 output', 'Templates', 'PNG and JPG'],
    url:
        'https://www.postermywall.com/index.php/sizes/cover-art/album-cover-maker',
    button: 'Open',
  ),
  _Tool(
    cat: 'artwork',
    icon: FontAwesomeIcons.expand,
    title: '3000px Image Resizer',
    desc:
        'Convert your cover art to the 3000×3000 pixel size that streaming stores require.',
    tags: ['Exact size', 'Drag and drop'],
    url: 'https://www.imageresizer.work/resize-image-to-3000x3000',
    button: 'Convert',
  ),
  _Tool(
    cat: 'audio',
    icon: FontAwesomeIcons.sliders,
    title: 'Audio Mastering',
    desc:
        'Improve loudness, clarity and balance so your track sounds right on every platform.',
    tags: ['Loudness', 'AI mastering', 'WAV output'],
    url: 'https://majordecibel.com/',
    button: 'Open',
  ),
  _Tool(
    cat: 'audio',
    icon: FontAwesomeIcons.arrowsRotate,
    title: 'Audio Format Converter',
    desc:
        'Turn MP3, AAC and AIFF files into WAV or FLAC, the formats needed for distribution.',
    tags: ['MP3 to WAV', 'Batch convert'],
    url: 'https://www.freeconvert.com/mp3-converter',
    button: 'Convert',
  ),
  _Tool(
    cat: 'growth',
    icon: FontAwesomeIcons.calculator,
    title: 'Royalty Calculator',
    desc:
        'Estimate what your streams could earn on Spotify, Apple Music, Tidal and YouTube Music before you release.',
    tags: ['Enter streams', 'Pick platforms', 'See estimate'],
    url: 'https://www.royalties-calculator.com/',
    button: 'Calculate',
  ),
  _Tool(
    cat: 'growth',
    icon: FontAwesomeIcons.calendarDays,
    title: 'Release Planner',
    desc:
        'Plan your release with a timeline, pre-save setup and rollout schedule to get a strong first week.',
    tags: ['Pre-save', 'Checklist', 'Playlist pitching'],
    url: 'https://cyberprmusic.com/music-release-plan/',
    button: 'Plan',
  ),
  _Tool(
    cat: 'growth',
    icon: FontAwesomeIcons.userPlus,
    title: 'Referral Program',
    desc:
        'Invite other artists to 444Music and earn a reward for every successful signup. There is no cap.',
    tags: ['Instant rewards', 'No cap'],
    url: 'https://wa.me/233530399523',
    button: 'Join',
  ),
  _Tool(
    cat: 'royalties',
    icon: FontAwesomeIcons.chartPie,
    title: 'Royalty Split Dashboard',
    desc:
        'See your earnings and split percentage, set your payout method and request withdrawals.',
    tags: ['Your split', 'Earnings', 'Withdrawals'],
    url: 'https://444music-distribution.vercel.app/splits',
    button: 'Open',
    note: 'Invite only',
  ),
  _Tool(
    cat: 'management',
    icon: FontAwesomeIcons.barcode,
    title: 'ISRC Code',
    desc:
        'Get an ISRC code for your recording. Sign in or create an account to continue.',
    tags: ['Recording ID', 'Required by stores'],
    url: 'https://distrofinder.org/signin',
    button: 'Get code',
  ),
  _Tool(
    cat: 'management',
    icon: FontAwesomeIcons.userCheck,
    title: 'Claim Artist Profile',
    desc:
        'Choose a store and open its artist portal to claim your page, get verified and see your stats.',
    tags: [
      'Spotify',
      'Apple Music',
      'Boomplay',
      'YouTube Music',
      'Amazon Music',
      'Audiomack',
      'Deezer',
      'TIDAL',
    ],
    button: 'Choose store',
    claim: true,
  ),
  _Tool(
    cat: 'management',
    icon: FontAwesomeIcons.trashCan,
    title: 'Song Takedown',
    desc:
        'Request removal of a release from all platforms. Full removal takes 5 to 14 business days.',
    tags: ['All platforms', 'Confirmation email'],
    url: 'https://www.444musicdistro.com/takedown',
    button: 'Request',
    danger: true,
    warn:
        'This permanently removes your release and cannot be undone. Download your analytics and confirm pending royalties first.',
  ),
];

// ════════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════════
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _cat = 'all';
  String _query = '';
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ));
    _scroll.addListener(() {
      final s = _scroll.offset > 4;
      if (s != _scrolled) setState(() => _scrolled = s);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _matches(_Tool t) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '${t.title} ${t.desc} ${t.tags.join(' ')}'.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    final visible = <_Section, List<_Tool>>{};
    for (final s in _sections) {
      if (_cat != 'all' && _cat != s.id) continue;
      final items = _tools.where((t) => t.cat == s.id && _matches(t)).toList();
      if (items.isNotEmpty) visible[s] = items;
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── HEADER ───────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, top + 6, 16, 10),
            decoration: BoxDecoration(
              color: _bg,
              border: Border(
                bottom: BorderSide(
                  color: _scrolled ? _sep : Colors.transparent,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.maybePop(context),
                  child: const SizedBox(
                    height: 36,
                    width: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: _text, size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text('Tools',
                    style: _ts(_text, 34, FontWeight.w700, ls: -0.68, h: 1.1)),
                const SizedBox(height: 12),
                _SearchField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _Pill(
                        label: 'All',
                        active: _cat == 'all',
                        onTap: () => _setCat('all'),
                      ),
                      for (final s in _sections)
                        _Pill(
                          label: s.name,
                          active: _cat == s.id,
                          onTap: () => _setCat(s.id),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── LIST ─────────────────────────────────────────────
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      _query.trim().isEmpty
                          ? 'Nothing here yet'
                          : 'No results for “${_query.trim()}”',
                      style: _ts(_text2, 15, FontWeight.w400),
                    ),
                  )
                : ListView(
                    controller: _scroll,
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 40),
                    children: [
                      for (final e in visible.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
                          child: Text(e.key.name,
                              style: _ts(_text2, 13, FontWeight.w400)),
                        ),
                        for (final t in e.value)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ToolCard(tool: t),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _setCat(String id) {
    if (_cat == id) return;
    HapticFeedback.selectionClick();
    setState(() => _cat = id);
  }
}

// ════════════════════════════════════════════════════════════════════
//  SEARCH FIELD
// ════════════════════════════════════════════════════════════════════
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.search_rounded, color: _text2, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: _text,
              textInputAction: TextInputAction.search,
              style: _ts(_text, 17, FontWeight.w400),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search',
                hintStyle: _ts(_text2, 17, FontWeight.w400),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) => v.text.isEmpty
                ? const SizedBox(width: 10)
                : GestureDetector(
                    onTap: onClear,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child:
                          Icon(Icons.cancel_rounded, color: _text2, size: 17),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PILL
// ════════════════════════════════════════════════════════════════════
class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Pill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : _card,
            borderRadius: BorderRadius.circular(99),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: _ts(active ? Colors.black : _text, 14, FontWeight.w500),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  TOOL CARD
// ════════════════════════════════════════════════════════════════════
class _ToolCard extends StatelessWidget {
  final _Tool tool;
  const _ToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    final t = tool;
    final tileColor = t.danger ? _red : (_catColors[t.cat] ?? _blue);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: FaIcon(t.icon, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        style: _ts(_text, 17, FontWeight.w600,
                            ls: -0.17, h: 1.25)),
                    if (t.note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(t.note!,
                            style: _ts(_text2, 12, FontWeight.w400)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(t.desc, style: _ts(_text2, 14, FontWeight.w400, h: 1.5)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in t.tags)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _fill,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(g, style: _ts(_text2, 12, FontWeight.w400)),
                ),
            ],
          ),
          if (t.warn != null) ...[
            const SizedBox(height: 12),
            Text(t.warn!, style: _ts(_text2, 12, FontWeight.w400, h: 1.45)),
          ],
          const SizedBox(height: 16),
          _PillButton(
            label: t.button,
            danger: t.danger,
            onTap: t.claim
                ? () => _showClaimSheet(context)
                : () => _launch(t.url),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  CLAIM STORE SHEET
// ════════════════════════════════════════════════════════════════════
void _showClaimSheet(BuildContext context) {
  HapticFeedback.selectionClick();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: _card,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _ClaimSheet(),
  );
}

class _ClaimSheet extends StatelessWidget {
  const _ClaimSheet();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.86),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0x4DEBEBF5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Claim Artist Profile',
                          style: _ts(_text, 20, FontWeight.w700, ls: -0.4)),
                      const SizedBox(height: 3),
                      Text(
                        'Pick a store to open its artist portal and claim your page.',
                        style: _ts(_text2, 13, FontWeight.w400, h: 1.4),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(left: 8, top: 2),
                    decoration: const BoxDecoration(
                      color: _fill,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close_rounded, color: _text2, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0.5, thickness: 0.5, color: _sep),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              itemCount: _claimStores.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 0.5, thickness: 0.5, color: _sep),
              itemBuilder: (_, i) => _StoreRow(store: _claimStores[i]),
            ),
          ),
          const Divider(height: 0.5, thickness: 0.5, color: _sep),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, 14 + mq.padding.bottom),
            child: Text(
              'Your music must already be live on a store before you can claim your profile there. Keep your artist name the same on every release.',
              style: _ts(_text2, 12, FontWeight.w400, h: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  final _Store store;
  const _StoreRow({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.color,
              borderRadius: BorderRadius.circular(11),
            ),
            child: s.icon != null
                ? FaIcon(s.icon, color: Colors.white, size: 20)
                : Text(s.letter, style: _ts(Colors.white, 20, FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: _ts(_text, 16, FontWeight.w600, ls: -0.16)),
                const SizedBox(height: 1),
                Text(s.note, style: _ts(_text2, 12, FontWeight.w400, h: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _PillButton(
            label: 'Claim',
            danger: false,
            onTap: () => _launch(s.url),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PILL BUTTON (blue, same as web)
// ════════════════════════════════════════════════════════════════════
class _PillButton extends StatefulWidget {
  final String label;
  final bool danger;
  final VoidCallback onTap;
  const _PillButton({
    required this.label,
    required this.danger,
    required this.onTap,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _down ? 0.7 : 1,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.danger ? _redBg : _blue,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            widget.label,
            style: _ts(widget.danger ? _red : Colors.white, 15,
                FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
