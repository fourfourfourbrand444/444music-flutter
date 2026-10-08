// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Tools Screen
//  Route: '/tools'
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── PALETTE ────────────────────────────────────────────────────────
const _bg    = Color(0xFF000000);
const _card  = Color(0xFF1C1C1E);
const _fill  = Color(0x3D767680);
const _text  = Color(0xFFF2F2F7);
const _text2 = Color(0xFF98989D);
const _red   = Color(0xFFFF453A);
const _redBg = Color(0x29FF453A);

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

  const _Tool({
    required this.cat,
    required this.icon,
    required this.title,
    required this.desc,
    required this.tags,
    required this.url,
    required this.button,
    this.note,
    this.warn,
    this.danger = false,
  });
}

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
    icon: Icons.image_rounded,
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
    icon: Icons.open_in_full_rounded,
    title: '3000px Image Resizer',
    desc:
        'Convert your cover art to the 3000×3000 pixel size that streaming stores require.',
    tags: ['Exact size', 'Drag and drop'],
    url: 'https://www.imageresizer.work/resize-image-to-3000x3000',
    button: 'Convert',
  ),
  _Tool(
    cat: 'audio',
    icon: Icons.tune_rounded,
    title: 'Audio Mastering',
    desc:
        'Improve loudness, clarity and balance so your track sounds right on every platform.',
    tags: ['Loudness', 'AI mastering', 'WAV output'],
    url: 'https://majordecibel.com/',
    button: 'Open',
  ),
  _Tool(
    cat: 'audio',
    icon: Icons.sync_rounded,
    title: 'Audio Format Converter',
    desc:
        'Turn MP3, AAC and AIFF files into WAV or FLAC, the formats needed for distribution.',
    tags: ['MP3 to WAV', 'Batch convert'],
    url: 'https://www.freeconvert.com/mp3-converter',
    button: 'Convert',
  ),
  _Tool(
    cat: 'growth',
    icon: Icons.calculate_rounded,
    title: 'Royalty Calculator',
    desc:
        'Estimate what your streams could earn on Spotify, Apple Music, Tidal and YouTube Music before you release.',
    tags: ['Enter streams', 'Pick platforms', 'See estimate'],
    url: 'https://www.royalties-calculator.com/',
    button: 'Calculate',
  ),
  _Tool(
    cat: 'growth',
    icon: Icons.calendar_month_rounded,
    title: 'Release Planner',
    desc:
        'Plan your release with a timeline, pre-save setup and rollout schedule to get a strong first week.',
    tags: ['Pre-save', 'Checklist', 'Playlist pitching'],
    url: 'https://cyberprmusic.com/music-release-plan/',
    button: 'Plan',
  ),
  _Tool(
    cat: 'growth',
    icon: Icons.person_add_alt_1_rounded,
    title: 'Referral Program',
    desc:
        'Invite other artists to 444Music and earn a reward for every successful signup. There is no cap.',
    tags: ['Instant rewards', 'No cap'],
    url: 'https://wa.me/233530399523',
    button: 'Join',
  ),
  _Tool(
    cat: 'royalties',
    icon: Icons.pie_chart_rounded,
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
    icon: Icons.numbers_rounded,
    title: 'ISRC Code',
    desc:
        'Get an ISRC code for your recording. Sign in or create an account to continue.',
    tags: ['Recording ID', 'Required by stores'],
    url: 'https://distrofinder.org/signin',
    button: 'Get code',
  ),
  _Tool(
    cat: 'management',
    icon: Icons.how_to_reg_rounded,
    title: 'Claim Artist Profile',
    desc:
        'A step-by-step guide to claim your artist page on Spotify, Apple Music and Amazon Music.',
    tags: ['Spotify for Artists', 'Apple Music', 'Amazon Music'],
    url: 'https://wa.me/233530399523',
    button: 'Get guide',
  ),
  _Tool(
    cat: 'management',
    icon: Icons.delete_outline_rounded,
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
                  color: _scrolled ? const Color(0xFF38383A) : Colors.transparent,
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
                Text(
                  'Tools',
                  style: GoogleFonts.nunito(
                    color: _text,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
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
                      style: GoogleFonts.nunito(
                        color: _text2,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
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
                          child: Text(
                            e.key.name,
                            style: GoogleFonts.nunito(
                              color: _text2,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
              style: GoogleFonts.nunito(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search',
                hintStyle: GoogleFonts.nunito(
                  color: _text2,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
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
                      child: Icon(Icons.cancel_rounded,
                          color: _text2, size: 17),
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
            style: GoogleFonts.nunito(
              color: active ? Colors.black : _text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
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
                decoration: BoxDecoration(
                  color: t.danger ? _redBg : _fill,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  t.icon,
                  color: t.danger ? _red : _text,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: GoogleFonts.nunito(
                        color: _text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),
                    if (t.note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          t.note!,
                          style: GoogleFonts.nunito(
                            color: _text2,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t.desc,
            style: GoogleFonts.nunito(
              color: _text2,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
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
                  child: Text(
                    g,
                    style: GoogleFonts.nunito(
                      color: _text2,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          if (t.warn != null) ...[
            const SizedBox(height: 12),
            Text(
              t.warn!,
              style: GoogleFonts.nunito(
                color: _text2,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _PillButton(
            label: t.button,
            danger: t.danger,
            onTap: () => _launch(t.url),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PILL BUTTON
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
        opacity: _down ? 0.65 : 1,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.danger ? _redBg : Colors.white,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.nunito(
              color: widget.danger ? _red : Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
