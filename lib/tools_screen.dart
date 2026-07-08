// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Tools Screen
//  Route: '/tools'
//  Font: Nunito (matches rest of app)
//  All external URLs preserved exactly from web version
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── PALETTE (matches HomeScreen) ───────────────────────────────────
const _black      = Color(0xFF000000);
const _black1     = Color(0xFF0A0A0A);
const _black2     = Color(0xFF111111);
const _black3     = Color(0xFF1A1A1A);
const _black4     = Color(0xFF222222);
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
const _greenDim   = Color(0x1A22C55E);
const _gold       = Color(0xFFF59E0B);
const _goldDim    = Color(0x14F59E0B);
const _red        = Color(0xFFEF4444);
const _redDim     = Color(0x1AEF4444);

// ─── URL LAUNCHER ───────────────────────────────────────────────────
Future<void> _launch(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─── TOOL DATA MODEL ────────────────────────────────────────────────
enum _ToolType { standard, featured, contributor, danger }
enum _ToolCategory { all, artwork, audio, growth, royalties, management }

class _ToolData {
  final String title;
  final String description;
  final List<String> chips;
  final String buttonLabel;
  final String url; // empty = internal route
  final String? internalRoute;
  final IconData icon;
  final String tag;
  final double rating;
  final _ToolType type;
  final _ToolCategory category;

  const _ToolData({
    required this.title,
    required this.description,
    required this.chips,
    required this.buttonLabel,
    required this.url,
    this.internalRoute,
    required this.icon,
    required this.tag,
    required this.rating,
    this.type = _ToolType.standard,
    required this.category,
  });
}

const _tools = [
  // ── ARTWORK ──────────────────────────────────────────────────────
  _ToolData(
    title: 'Cover Art Generator',
    description: 'Design professional album and single cover artwork that meets streaming platform specs — no design experience needed.',
    chips: ['3000×3000px output', 'Templates included', 'Export PNG/JPG'],
    buttonLabel: 'Open Tool',
    url: 'https://www.postermywall.com/index.php/sizes/cover-art/album-cover-maker',
    icon: Icons.image_rounded,
    tag: 'Free',
    rating: 4.9,
    category: _ToolCategory.artwork,
  ),
  _ToolData(
    title: '3000px Image Resizer',
    description: 'Instantly upscale or convert your cover art to the required 3000×3000 pixel resolution accepted by all major DSPs.',
    chips: ['Exact 3000×3000', 'Lossless output', 'Drag & drop'],
    buttonLabel: 'Convert Image',
    url: 'https://www.imageresizer.work/resize-image-to-3000x3000',
    icon: Icons.photo_size_select_large_rounded,
    tag: 'Free',
    rating: 4.4,
    category: _ToolCategory.artwork,
  ),

  // ── AUDIO ────────────────────────────────────────────────────────
  _ToolData(
    title: 'Audio Mastering',
    description: 'Enhance loudness, clarity, stereo balance and dynamic range so your track meets industry standards across all platforms.',
    chips: ['Loudness normalisation', 'AI mastering', 'WAV output'],
    buttonLabel: 'Open Tool',
    url: 'https://majordecibel.com/',
    icon: Icons.tune_rounded,
    tag: 'Free',
    rating: 4.8,
    category: _ToolCategory.audio,
  ),
  _ToolData(
    title: 'Audio Format Converter',
    description: 'Convert MP3, AAC, AIFF and other audio files into WAV or FLAC — the formats required for lossless distribution.',
    chips: ['MP3 → WAV/FLAC', 'Batch convert', '320kbps support'],
    buttonLabel: 'Convert Audio',
    url: 'https://www.freeconvert.com/mp3-converter',
    icon: Icons.sync_rounded,
    tag: 'Free',
    rating: 4.3,
    category: _ToolCategory.audio,
  ),

  // ── GROWTH ───────────────────────────────────────────────────────
  _ToolData(
    title: 'Royalty Calculator',
    description: 'Estimate your potential streaming royalties across Spotify, Apple Music, Tidal, YouTube Music and more — before you release. Plan smarter.',
    chips: ['Enter expected streams', 'Select platforms', 'View estimated earnings'],
    buttonLabel: 'Calculate Royalties',
    url: 'https://www.royalties-calculator.com/',
    icon: Icons.monetization_on_rounded,
    tag: 'Free',
    rating: 5.0,
    type: _ToolType.featured,
    category: _ToolCategory.growth,
  ),
  _ToolData(
    title: 'Release Planner',
    description: 'Build a full release campaign — timeline, marketing strategy, pre-save setup and rollout schedule — to maximise your first-week impact.',
    chips: ['Pre-save strategy', 'Rollout checklist', 'Playlist pitching'],
    buttonLabel: 'Plan Release',
    url: 'https://cyberprmusic.com/music-release-plan/',
    icon: Icons.calendar_today_rounded,
    tag: 'Guide',
    rating: 4.5,
    category: _ToolCategory.growth,
  ),
  _ToolData(
    title: 'Referral Program',
    description: 'Invite fellow artists to 444Music and earn rewards for every successful signup. No cap on earnings — the more you share, the more you make.',
    chips: ['Instant rewards', 'No earning cap', 'Track referrals'],
    buttonLabel: 'Join Program',
    url: 'https://wa.me/233530399523',
    icon: Icons.people_rounded,
    tag: 'Earn',
    rating: 5.0,
    category: _ToolCategory.growth,
  ),

  // ── ROYALTIES ────────────────────────────────────────────────────
  _ToolData(
    title: 'Royalty Split Dashboard',
    description: 'Access your personal contributor dashboard to view earnings, track your royalty split percentage, set payment preferences and request withdrawals.',
    chips: ['View your split %', 'Track earnings', 'Withdraw funds', 'Set payout method'],
    buttonLabel: 'Open Dashboard',
    url: 'https://444music-distribution.vercel.app/splits',
    internalRoute: null,
    icon: Icons.pie_chart_rounded,
    tag: 'Royalties',
    rating: 0,
    type: _ToolType.contributor,
    category: _ToolCategory.royalties,
  ),

  // ── MANAGEMENT ───────────────────────────────────────────────────
  _ToolData(
    title: 'Claim Artist Profile',
    description: 'Step-by-step walkthrough to verify and claim your official artist pages on Spotify for Artists, Apple Music for Artists and Amazon Music.',
    chips: ['Spotify for Artists', 'Apple Music', 'Amazon Music'],
    buttonLabel: 'Get Guide',
    url: 'https://wa.me/233530399523',
    icon: Icons.verified_user_rounded,
    tag: 'Guide',
    rating: 4.9,
    category: _ToolCategory.management,
  ),
  _ToolData(
    title: 'Song Takedown / Delete',
    description: 'Submit a formal takedown request to remove a release from all digital platforms. Allow 5–14 business days for full removal across all DSPs.',
    chips: ['5–14 business days', 'All platforms', 'Confirmation email'],
    buttonLabel: 'Submit Takedown',
    url: '',
    internalRoute: '/takedown',
    icon: Icons.delete_rounded,
    tag: '⚠ Destructive',
    rating: 0,
    type: _ToolType.danger,
    category: _ToolCategory.management,
  ),
];

// ════════════════════════════════════════════════════════════════════
//  TOOLS SCREEN
// ════════════════════════════════════════════════════════════════════
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen>
    with SingleTickerProviderStateMixin {
  _ToolCategory _activeFilter = _ToolCategory.all;

  late AnimationController _entranceCtrl;
  late Animation<double>   _entranceFade;
  late Animation<Offset>   _entranceSlide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ));
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _entranceFade  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(
        begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  List<_ToolData> get _filtered => _activeFilter == _ToolCategory.all
      ? _tools
      : _tools.where((t) => t.category == _activeFilter).toList();

  void _onTap(_ToolData tool) {
    if (tool.internalRoute != null) {
      Navigator.pushNamed(context, tool.internalRoute!);
    } else if (tool.url.isNotEmpty) {
      _launch(tool.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _black,
      body: SlideTransition(
        position: _entranceSlide,
        child: FadeTransition(
          opacity: _entranceFade,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── TOP BAR ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22, top + 16, 22, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: _white06,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _white10),
                          ),
                          child: const Icon(
                              Icons.arrow_back_rounded,
                              color: _white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Artist Toolkit',
                        style: GoogleFonts.nunito(
                          color: _white, fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      // Live badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _greenDim,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: _green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BlinkDot(color: _green),
                            const SizedBox(width: 5),
                            Text(
                              '10 Tools Live',
                              style: GoogleFonts.nunito(
                                color: _green, fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── HERO ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                  const EdgeInsets.fromLTRB(22, 28, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: _white10,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: _white20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded,
                                color: _white70, size: 12),
                            const SizedBox(width: 6),
                            Text(
                              'ARTIST TOOLKIT',
                              style: GoogleFonts.nunito(
                                color: _white70, fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Every Tool You\nNeed to Release Right',
                        style: GoogleFonts.nunito(
                          color: _white, fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Professional-grade resources built for independent artists who take their craft seriously.',
                        style: GoogleFonts.nunito(
                          color: _grey, fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Stats row
                      Row(
                        children: [
                          _HeroStat(value: '10', label: 'Tools'),
                          _vDivider(),
                          _HeroStat(value: 'Free', label: 'No Hidden Fees'),
                          _vDivider(),
                          _HeroStat(value: '24/7', label: 'Support'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── FILTER PILLS ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
                  child: SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding:
                      const EdgeInsets.symmetric(horizontal: 22),
                      physics: const BouncingScrollPhysics(),
                      children: _ToolCategory.values.map((cat) {
                        final active = _activeFilter == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _activeFilter = cat),
                            child: AnimatedContainer(
                              duration:
                              const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: active
                                    ? _white
                                    : _black2,
                                borderRadius:
                                BorderRadius.circular(99),
                                border: Border.all(
                                    color: active
                                        ? _white
                                        : _white10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _catIcon(cat),
                                    size: 12,
                                    color: active
                                        ? _black
                                        : _grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _catLabel(cat),
                                    style: GoogleFonts.nunito(
                                      color: active
                                          ? _black
                                          : _grey,
                                      fontSize: 12.5,
                                      fontWeight:
                                      FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                  child: SizedBox(height: 24)),

              // ── TOOL CARDS ──────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) {
                      final filtered = _filtered;

                      // Insert section headers
                      final items = _buildListItems(filtered);
                      if (i >= items.length) return null;
                      final item = items[i];

                      if (item is _SectionHeader) {
                        return _SectionLabel(
                            icon: item.icon, title: item.title);
                      }

                      final tool = item as _ToolData;

                      // Danger notice
                      if (tool.type == _ToolType.danger &&
                          (_activeFilter == _ToolCategory.all ||
                              _activeFilter ==
                                  _ToolCategory.management)) {
                        return Column(
                          children: [
                            _DangerNotice(),
                            const SizedBox(height: 12),
                            _ToolCard(
                                tool: tool,
                                onTap: () => _onTap(tool)),
                            const SizedBox(height: 14),
                          ],
                        );
                      }

                      return Padding(
                        padding:
                        const EdgeInsets.only(bottom: 14),
                        child: _ToolCard(
                            tool: tool,
                            onTap: () => _onTap(tool)),
                      );
                    },
                    childCount: _buildListItems(_filtered).length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                  child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  List<dynamic> _buildListItems(List<_ToolData> tools) {
    if (_activeFilter != _ToolCategory.all) return tools;

    final items = <dynamic>[];
    _ToolCategory? lastCat;
    for (final t in tools) {
      if (t.category != lastCat) {
        items.add(_SectionHeader(
            icon: _catIcon(t.category),
            title: _catSectionTitle(t.category)));
        lastCat = t.category;
      }
      items.add(t);
    }
    return items;
  }
}

class _SectionHeader {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});
}

// ─── HELPERS ─────────────────────────────────────────────────────────
IconData _catIcon(_ToolCategory cat) {
  switch (cat) {
    case _ToolCategory.all:        return Icons.grid_view_rounded;
    case _ToolCategory.artwork:    return Icons.palette_rounded;
    case _ToolCategory.audio:      return Icons.graphic_eq_rounded;
    case _ToolCategory.growth:     return Icons.trending_up_rounded;
    case _ToolCategory.royalties:  return Icons.monetization_on_rounded;
    case _ToolCategory.management: return Icons.settings_rounded;
  }
}

String _catLabel(_ToolCategory cat) {
  switch (cat) {
    case _ToolCategory.all:        return 'All Tools';
    case _ToolCategory.artwork:    return 'Artwork';
    case _ToolCategory.audio:      return 'Audio';
    case _ToolCategory.growth:     return 'Growth';
    case _ToolCategory.royalties:  return 'Royalties';
    case _ToolCategory.management: return 'Management';
  }
}

String _catSectionTitle(_ToolCategory cat) {
  switch (cat) {
    case _ToolCategory.artwork:    return 'Artwork & Visuals';
    case _ToolCategory.audio:      return 'Audio Tools';
    case _ToolCategory.growth:     return 'Growth & Revenue';
    case _ToolCategory.royalties:  return 'Royalty Splits';
    case _ToolCategory.management: return 'Account Management';
    default:                        return '';
  }
}

Widget _vDivider() => Container(
  width: 1, height: 28,
  margin: const EdgeInsets.symmetric(horizontal: 14),
  color: _white10,
);

// ════════════════════════════════════════════════════════════════════
//  SECTION LABEL
// ════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionLabel({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 8),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _white10,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _white10),
            ),
            child: Icon(icon, color: _white70, size: 14),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.nunito(
              color: _grey, fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: _white10)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  TOOL CARD
// ════════════════════════════════════════════════════════════════════
class _ToolCard extends StatefulWidget {
  final _ToolData tool;
  final VoidCallback onTap;
  const _ToolCard({required this.tool, required this.onTap});

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tool;
    final isFeatured    = t.type == _ToolType.featured;
    final isContributor = t.type == _ToolType.contributor;
    final isDanger      = t.type == _ToolType.danger;

    Color borderColor = _white10;
    Color bgColor     = _black2;
    if (isContributor) {
      borderColor = _gold.withValues(alpha: 0.25);
      bgColor     = _goldDim;
    } else if (isDanger) {
      borderColor = _red.withValues(alpha: 0.22);
      bgColor     = _redDim;
    } else if (isFeatured) {
      borderColor = _white20;
      bgColor     = _black3;
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, _pressed ? 1 : 0, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _pressed ? _white20 : borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isContributor
                        ? _gold.withValues(alpha: 0.12)
                        : isDanger
                        ? _red.withValues(alpha: 0.12)
                        : _white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isContributor
                          ? _gold.withValues(alpha: 0.22)
                          : isDanger
                          ? _red.withValues(alpha: 0.22)
                          : _white10,
                    ),
                  ),
                  child: Icon(
                    t.icon,
                    color: isContributor
                        ? _gold
                        : isDanger
                        ? _red
                        : _white70,
                    size: 20,
                  ),
                ),
                const Spacer(),
                // Tag badge
                _TagBadge(tag: t.tag, type: t.type),
              ],
            ),

            const SizedBox(height: 16),

            // ── TITLE ────────────────────────────────────────
            Row(
              children: [
                if (isFeatured)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _white10,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: _white20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              color: _white70, size: 9),
                          const SizedBox(width: 4),
                          Text(
                            'STAFF PICK',
                            style: GoogleFonts.nunito(
                              color: _white70, fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (isFeatured) const SizedBox(height: 8),

            Text(
              t.title,
              style: GoogleFonts.nunito(
                color: _white, fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),

            // ── DESCRIPTION ──────────────────────────────────
            Text(
              t.description,
              style: GoogleFonts.nunito(
                color: _grey, fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),

            // ── CHIPS ────────────────────────────────────────
            Wrap(
              spacing: 6, runSpacing: 6,
              children: t.chips.map((c) => _Chip(
                label: c,
                isGold: isContributor,
              )).toList(),
            ),

            const SizedBox(height: 18),

            // ── FOOTER ───────────────────────────────────────
            Row(
              children: [
                // Main button
                _ActionBtn(
                  label: t.buttonLabel,
                  icon: _btnIcon(t),
                  type: t.type,
                  onTap: widget.onTap,
                ),
                const Spacer(),
                // Rating or special badge
                if (isContributor)
                  _InviteOnlyBadge()
                else if (isDanger)
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded,
                          color: _red, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'Irreversible',
                        style: GoogleFonts.nunito(
                          color: _red, fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else if (t.rating > 0)
                    _RatingStars(rating: t.rating),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _btnIcon(_ToolData t) {
    if (t.type == _ToolType.contributor) return Icons.pie_chart_rounded;
    if (t.type == _ToolType.danger)      return Icons.delete_rounded;
    switch (t.category) {
      case _ToolCategory.artwork:    return Icons.brush_rounded;
      case _ToolCategory.audio:      return Icons.graphic_eq_rounded;
      case _ToolCategory.growth:     return Icons.trending_up_rounded;
      case _ToolCategory.management: return Icons.open_in_new_rounded;
      default:                        return Icons.open_in_new_rounded;
    }
  }
}

// ════════════════════════════════════════════════════════════════════
//  SMALL WIDGETS
// ════════════════════════════════════════════════════════════════════
class _TagBadge extends StatelessWidget {
  final String tag;
  final _ToolType type;
  const _TagBadge({required this.tag, required this.type});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (type) {
      case _ToolType.contributor:
        bg = _gold.withValues(alpha: 0.12);
        fg = _gold;
      case _ToolType.danger:
        bg = _red.withValues(alpha: 0.12);
        fg = _red;
      default:
        bg = _white10;
        fg = _white70;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        tag.toUpperCase(),
        style: GoogleFonts.nunito(
          color: fg, fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isGold;
  const _Chip({required this.label, this.isGold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _black3,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 9,
            color: isGold ? _gold : _white40,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.nunito(
              color: _grey, fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final _ToolType type;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (type) {
      case _ToolType.contributor:
        bg = _gold;
        fg = _black;
      case _ToolType.danger:
        bg = _red.withValues(alpha: 0.15);
        fg = _red;
      default:
        bg = _white;
        fg = _black;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 14),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.nunito(
                color: fg, fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  final double rating;
  const _RatingStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) => Icon(
          i < rating.floor()
              ? Icons.star_rounded
              : (i < rating ? Icons.star_half_rounded : Icons.star_outline_rounded),
          color: _gold, size: 12,
        )),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.nunito(
            color: _grey, fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InviteOnlyBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _goldDim,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BlinkDot(color: _gold),
          const SizedBox(width: 4),
          Text(
            'Invite Only',
            style: GoogleFonts.nunito(
              color: _gold, fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: _gold, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.nunito(
                  color: _grey, fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                ),
                children: const [
                  TextSpan(
                      text: 'The takedown tool permanently removes your release from all connected streaming platforms. '),
                  TextSpan(
                    text: 'This action cannot be undone.',
                    style: TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                      text: ' Ensure you have downloaded your analytics and confirmed any pending royalties before submitting.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.nunito(
            color: _white, fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            color: _grey, fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _BlinkDot extends StatefulWidget {
  final Color color;
  const _BlinkDot({required this.color});

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 1, end: 0.3).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 5, height: 5,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}