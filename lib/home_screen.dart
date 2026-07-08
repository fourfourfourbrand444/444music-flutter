// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Premium Home Screen v3
//  Font: Outfit (bold, clean, heavy — matches select screen)
//  Banner buttons → https://444musicblog.vercel.app/visit.html
// ═══════════════════════════════════════════════════════════════════
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── PALETTE ────────────────────────────────────────────────────────
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
const _greyLight  = Color(0xFFAAAAAA);
const _greyDark   = Color(0xFF444444);

// ─── URL LAUNCHER ───────────────────────────────────────────────────
Future<void> _launchVisitUrl() async {
  final uri = Uri.parse('https://444musicblog.vercel.app/visit.html');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─── FEATURED BANNER DATA ───────────────────────────────────────────
const _banners = [
  _Banner(
    image: 'https://images.pexels.com/photos/9008843/pexels-photo-9008843.jpeg?auto=compress&cs=tinysrgb&w=800&dpr=2',
    tag:   'NEW RELEASE',
    title: 'Distribute\nYour Music',
    sub:   'Go live on 30+ platforms in days',
    accent: Color(0xFF2A2A2A),
  ),
  _Banner(
    image: 'https://images.pexels.com/photos/17413080/pexels-photo-17413080.jpeg?auto=compress&cs=tinysrgb&w=800&dpr=2',
    tag:   'TRENDING',
    title: 'Keep 100%\nRoyalties',
    sub:   'No middlemen. Paid monthly.',
    accent: Color(0xFF1E1E1E),
  ),
  _Banner(
    image: 'https://images.pexels.com/photos/5135100/pexels-photo-5135100.jpeg?auto=compress&cs=tinysrgb&w=800&dpr=2',
    tag:   'ANALYTICS',
    title: 'Track Your\nGrowth',
    sub:   'Real-time streams & revenue data',
    accent: Color(0xFF202020),
  ),
  _Banner(
    image: 'https://images.pexels.com/photos/12448173/pexels-photo-12448173.jpeg?auto=compress&cs=tinysrgb&w=800&dpr=2',
    tag:   'MADE IN GHANA',
    title: 'Built for\nArtists',
    sub:   'Independent. Powerful. Yours.',
    accent: Color(0xFF1C1C1C),
  ),
];

class _Banner {
  final String image, tag, title, sub;
  final Color accent;
  const _Banner({required this.image, required this.tag, required this.title,
    required this.sub, required this.accent});
}

// ─── PLAYLIST DATA ──────────────────────────────────────────────────
const _playlists = [
  _Playlist(
    cover: 'https://images.pexels.com/photos/1105666/pexels-photo-1105666.jpeg?auto=compress&cs=tinysrgb&w=400',
    title: 'Afrobeats Heat',
    sub:   'By 444Music · 24 Artists',
    plays: '1.2M plays',
  ),
  _Playlist(
    cover: 'https://images.pexels.com/photos/3756766/pexels-photo-3756766.jpeg?auto=compress&cs=tinysrgb&w=400',
    title: 'Ghana Vibes',
    sub:   'By 444Music · 18 Artists',
    plays: '890K plays',
  ),
  _Playlist(
    cover: 'https://images.pexels.com/photos/1370545/pexels-photo-1370545.jpeg?auto=compress&cs=tinysrgb&w=400',
    title: 'New Releases',
    sub:   'By 444Music · Weekly',
    plays: '2.1M plays',
  ),
  _Playlist(
    cover: 'https://images.pexels.com/photos/167636/pexels-photo-167636.jpeg?auto=compress&cs=tinysrgb&w=400',
    title: 'Artist Picks',
    sub:   'By 444Music · Curated',
    plays: '650K plays',
  ),
  _Playlist(
    cover: 'https://images.pexels.com/photos/1021876/pexels-photo-1021876.jpeg?auto=compress&cs=tinysrgb&w=400',
    title: 'Late Night',
    sub:   'By 444Music · Mood',
    plays: '430K plays',
  ),
];

class _Playlist {
  final String cover, title, sub, plays;
  const _Playlist({required this.cover, required this.title,
    required this.sub, required this.plays});
}

// ─── PLATFORM COVERS ────────────────────────────────────────────────
const _platformCovers = [
  _PlatformCover(
    image: 'https://images.pexels.com/photos/1540406/pexels-photo-1540406.jpeg?auto=compress&cs=tinysrgb&w=400',
    platform: 'Spotify',
    icon: Icons.music_note_rounded,
    color: Color(0xFF1DB954),
  ),
  _PlatformCover(
    image: 'https://images.pexels.com/photos/2682543/pexels-photo-2682543.jpeg?auto=compress&cs=tinysrgb&w=400',
    platform: 'Apple Music',
    icon: Icons.apple_rounded,
    color: Color(0xFFFC3C44),
  ),
  _PlatformCover(
    image: 'https://images.pexels.com/photos/3944091/pexels-photo-3944091.jpeg?auto=compress&cs=tinysrgb&w=400',
    platform: 'YouTube Music',
    icon: Icons.play_circle_filled_rounded,
    color: Color(0xFFFF0000),
  ),
  _PlatformCover(
    image: 'https://images.pexels.com/photos/1389429/pexels-photo-1389429.jpeg?auto=compress&cs=tinysrgb&w=400',
    platform: 'Boomplay',
    icon: Icons.headphones_rounded,
    color: Color(0xFF00C853),
  ),
];

class _PlatformCover {
  final String image, platform;
  final IconData icon;
  final Color color;
  const _PlatformCover({required this.image, required this.platform,
    required this.icon, required this.color});
}

// ════════════════════════════════════════════════════════════════════
//  HOME SCREEN
// ════════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _navIndex = 0;
  final _bannerCtrl = PageController(viewportFraction: 0.88);
  int _bannerIndex = 0;

  bool _sidebarOpen = false;
  late AnimationController _sidebarCtrl;
  late Animation<double>   _sidebarFade;
  late Animation<Offset>   _sidebarSlide;

  late AnimationController _entranceCtrl;
  late Animation<double>   _entranceFade;
  late Animation<Offset>   _entranceSlide;

  int _filterIndex = 0;
  final _filters = ['All', 'New Release', 'Trending', 'Top Charts'];

  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));

    _sidebarCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _sidebarFade  = CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOut);
    _sidebarSlide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOutCubic));

    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _entranceFade  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();

    // Auto-advance banners
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return false;
      final next = (_bannerIndex + 1) % _banners.length;
      _bannerCtrl.animateToPage(next,
          duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic);
      return true;
    });
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    _entranceCtrl.dispose();
    _bannerCtrl.dispose();
    super.dispose();
  }

  void _openSidebar()  { setState(() => _sidebarOpen = true); _sidebarCtrl.forward(); }
  void _closeSidebar() {
    _sidebarCtrl.reverse().then((_) { if (mounted) setState(() => _sidebarOpen = false); });
  }
  void _navigate(String route) {
    _closeSidebar();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) Navigator.pushNamed(context, route);
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName {
    final name = _user?.displayName ?? 'Artist';
    return name.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _navIndex,
            children: [
              _buildHomeTab(),
              const _PlaceholderTab(icon: Icons.bar_chart_rounded,              label: 'Analytics'),
              const _PlaceholderTab(icon: Icons.cloud_upload_rounded,           label: 'Upload'),
              const _PlaceholderTab(icon: Icons.account_balance_wallet_rounded, label: 'Earnings'),
              const _PlaceholderTab(icon: Icons.person_rounded,                 label: 'Profile'),
            ],
          ),

          // Bottom nav
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomNav(
              current: _navIndex,
              onTap: (i) {
                if (i == 1) { Navigator.pushNamed(context, '/analytics'); return; }
                if (i == 2) { Navigator.pushNamed(context, '/upload');    return; }
                if (i == 3) { Navigator.pushNamed(context, '/earnings');  return; }
                if (i == 4) { Navigator.pushNamed(context, '/profile');   return; }
                setState(() => _navIndex = i);
              },
            ),
          ),

          // Sidebar overlay
          if (_sidebarOpen)
            GestureDetector(
              onTap: _closeSidebar,
              child: FadeTransition(
                opacity: _sidebarFade,
                child: Container(color: Colors.black.withOpacity(0.6)),
              ),
            ),

          // Sidebar drawer
          if (_sidebarOpen)
            Positioned(
              top: 0, right: 0, bottom: 0,
              child: SlideTransition(
                position: _sidebarSlide,
                child: _SidebarPanel(
                  onClose: _closeSidebar,
                  onNavigate: _navigate,
                  userName:  _user?.displayName ?? 'Artist',
                  userEmail: _user?.email ?? '',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final top = MediaQuery.of(context).padding.top;
    return SlideTransition(
      position: _entranceSlide,
      child: FadeTransition(
        opacity: _entranceFade,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: top + 16),

              // ── TOP BAR ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _black3,
                        border: Border.all(color: _white20, width: 1.5),
                      ),
                      child: const Icon(Icons.person_rounded, color: _white70, size: 22),
                    ),
                    const Spacer(),
                    _IconBtn(icon: Icons.search_rounded, onTap: () => _navigate('/search')),
                    const SizedBox(width: 10),
                    _IconBtn(icon: Icons.menu_rounded, onTap: _openSidebar),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── GREETING ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: GoogleFonts.outfit(
                        color: _grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Hi, $_firstName',
                      style: GoogleFonts.outfit(
                        color: _white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── FILTER PILLS ──
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final active = i == _filterIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _filterIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? _white : _black2,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: active ? _white : _white10),
                        ),
                        child: Text(
                          _filters[i],
                          style: GoogleFonts.outfit(
                            color: active ? _black : _grey,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 26),

              // ── SECTION LABEL ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _SectionTitle(title: 'Curated & trending'),
              ),

              const SizedBox(height: 14),

              // ── FEATURED BANNERS ──
              SizedBox(
                height: 210,
                child: PageView.builder(
                  controller: _bannerCtrl,
                  onPageChanged: (i) => setState(() => _bannerIndex = i),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _banners.length,
                  itemBuilder: (_, i) => _BannerCard(
                    banner: _banners[i],
                    onTap: _launchVisitUrl,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Page indicator
              Center(
                child: SmoothPageIndicator(
                  controller: _bannerCtrl,
                  count: _banners.length,
                  effect: ExpandingDotsEffect(
                    dotColor: _white20,
                    activeDotColor: _white,
                    dotHeight: 4, dotWidth: 4,
                    expansionFactor: 4, spacing: 5,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── TOP PLAYLISTS ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    _SectionTitle(title: 'Top daily playlists'),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _navigate('/releases'),
                      child: Text(
                        'See all',
                        style: GoogleFonts.outfit(
                          color: _grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Playlist rows — play button redirects to visit URL
              ...List.generate(_playlists.length, (i) => _PlaylistRow(
                playlist: _playlists[i],
                index: i + 1,
                onTap:     () => _navigate('/releases'),
                onPlayTap: _launchVisitUrl,   // ← redirect to visit.html
              )),

              const SizedBox(height: 32),

              // ── PLATFORM COVERS ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _SectionTitle(title: 'Stream on every platform'),
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _platformCovers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _PlatformCoverCard(cover: _platformCovers[i]),
                ),
              ),

              const SizedBox(height: 32),

              // ── WHY 444MUSIC ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _SectionTitle(title: 'Why 444Music?'),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    _DistroRow(icon: Icons.public_rounded,                 title: 'Global Distribution',   sub: '30+ stores worldwide including Spotify, Apple Music & Boomplay'),
                    _DistroRow(icon: Icons.account_balance_wallet_rounded, title: '100% Royalties Yours',  sub: 'Keep every dollar. Monthly payouts with full transparency'),
                    _DistroRow(icon: Icons.bolt_rounded,                   title: 'Fast Delivery',         sub: 'Upload today, go live in days — not weeks'),
                    _DistroRow(icon: Icons.verified_user_rounded,          title: 'Full Ownership',        sub: 'Your masters, your rights. Always and forever'),
                    _DistroRow(icon: Icons.insights_rounded,               title: 'Real-Time Analytics',   sub: 'Track streams & revenue across all platforms in one dashboard'),
                    _DistroRow(icon: Icons.support_agent_rounded,          title: 'Artist Support',        sub: 'Dedicated support via WhatsApp. Real humans who care'),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── STATS ROW ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    Expanded(child: _StatChip(value: '150+', label: 'Artists')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatChip(value: '30+',  label: 'Stores')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatChip(value: '100%', label: 'Ownership')),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── DASHBOARD CTA ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _DashboardCta(onTap: () => _navigate('/dashboard')),
              ),

              const SizedBox(height: 110),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  BANNER CARD
// ════════════════════════════════════════════════════════════════════
class _BannerCard extends StatelessWidget {
  final _Banner banner;
  final VoidCallback onTap;
  const _BannerCard({required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: banner.image,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: _black3),
                errorWidget: (_, __, ___) => Container(color: _black3),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Colors.transparent, banner.accent.withOpacity(0.92)],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _white20,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        banner.tag,
                        style: GoogleFonts.outfit(
                          color: _white90,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      banner.title,
                      style: GoogleFonts.outfit(
                        color: _white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      banner.sub,
                      style: GoogleFonts.outfit(
                        color: _white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _PlayerBtn(icon: Icons.play_arrow_rounded,      filled: true,  onTap: _launchVisitUrl),
                        const SizedBox(width: 10),
                        _PlayerBtn(icon: Icons.favorite_border_rounded, filled: false, onTap: _launchVisitUrl),
                        const SizedBox(width: 10),
                        _PlayerBtn(icon: Icons.more_horiz_rounded,      filled: false, onTap: _launchVisitUrl),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerBtn extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  const _PlayerBtn({required this.icon, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: filled ? 40 : 34,
        height: filled ? 40 : 34,
        decoration: BoxDecoration(
          color: filled ? _white : _white20,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: filled ? _black : _white, size: filled ? 20 : 16),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PLAYLIST ROW  — onPlayTap redirects to visit.html
// ════════════════════════════════════════════════════════════════════
class _PlaylistRow extends StatefulWidget {
  final _Playlist    playlist;
  final int          index;
  final VoidCallback onTap;
  final VoidCallback onPlayTap;   // ← separate callback for the play button
  const _PlaylistRow({
    required this.playlist,
    required this.index,
    required this.onTap,
    required this.onPlayTap,
  });
  @override
  State<_PlaylistRow> createState() => _PlaylistRowState();
}

class _PlaylistRowState extends State<_PlaylistRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _pressed ? _white06 : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        child: Row(
          children: [
            // Cover art
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: widget.playlist.cover,
                width: 56, height: 56,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(width: 56, height: 56, color: _black3),
                errorWidget: (_, __, ___) => Container(
                  width: 56, height: 56, color: _black3,
                  child: const Icon(Icons.music_note_rounded, color: _grey, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.playlist.title,
                    style: GoogleFonts.outfit(
                      color: _white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.playlist.sub,
                    style: GoogleFonts.outfit(
                      color: _grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.playlist.plays,
                    style: GoogleFonts.outfit(
                      color: _greyDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Play button → opens visit.html
            GestureDetector(
              onTap: widget.onPlayTap,   // ← uses the dedicated play callback
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _white.withOpacity(0.15),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: _black, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PLATFORM COVER CARD
// ════════════════════════════════════════════════════════════════════
class _PlatformCoverCard extends StatelessWidget {
  final _PlatformCover cover;
  const _PlatformCoverCard({required this.cover});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _black2,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: cover.image,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: _black3),
              errorWidget: (_, __, ___) => Container(color: _black3),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, _black.withOpacity(0.85)],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 12, left: 12, right: 12,
              child: Row(
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: cover.color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(cover.icon, color: _white, size: 12),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cover.platform,
                      style: GoogleFonts.outfit(
                        color: _white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  DISTRIBUTION ROW
// ════════════════════════════════════════════════════════════════════
class _DistroRow extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const _DistroRow({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _black3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _white10),
            ),
            child: Icon(icon, color: _white70, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: _white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: GoogleFonts.outfit(
                    color: _grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  STAT CHIP
// ════════════════════════════════════════════════════════════════════
class _StatChip extends StatelessWidget {
  final String value, label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _black2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _white10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              color: _white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: _grey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  DASHBOARD CTA
// ════════════════════════════════════════════════════════════════════
class _DashboardCta extends StatelessWidget {
  final VoidCallback onTap;
  const _DashboardCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to drop\nyour next release?',
                  style: GoogleFonts.outfit(
                    color: _black,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join 150+ artists on 444Music.',
                  style: GoogleFonts.outfit(
                    color: Color(0xFF666666),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: _black,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.dashboard_rounded, color: _white, size: 15),
                        const SizedBox(width: 8),
                        Text(
                          'Go to Dashboard',
                          style: GoogleFonts.outfit(
                            color: _white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(
              color: _black,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: _white, size: 28),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ════════════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: _white,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _white06,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _white10),
        ),
        child: Icon(icon, color: _white, size: 20),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  BOTTOM NAVIGATION BAR
// ════════════════════════════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  static const _items = [
    (Icons.home_rounded,                   Icons.home_outlined,                   'Home'),
    (Icons.bar_chart_rounded,              Icons.bar_chart_outlined,              'Analytics'),
    (Icons.cloud_upload_rounded,           Icons.cloud_upload_outlined,           'Upload'),
    (Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Earnings'),
    (Icons.person_rounded,                 Icons.person_outline_rounded,          'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(8, 10, 8, bottom + 10),
          decoration: BoxDecoration(
            color: _black.withOpacity(0.85),
            border: const Border(top: BorderSide(color: _white10)),
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final (activeIcon, inactiveIcon, label) = _items[i];
              final isActive = i == current;
              final isUpload = i == 2;

              if (isUpload) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    child: Center(
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: _white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _white.withOpacity(0.2),
                              blurRadius: 16, spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.cloud_upload_rounded, color: _black, size: 24),
                      ),
                    ),
                  ),
                );
              }

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          isActive ? activeIcon : inactiveIcon,
                          key: ValueKey(isActive),
                          color: isActive ? _white : _greyDark,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: GoogleFonts.outfit(
                          color: isActive ? _white : _greyDark,
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                        ),
                        child: Text(label),
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        height: 3, width: isActive ? 18 : 0,
                        decoration: BoxDecoration(
                          color: _white,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SIDEBAR
// ════════════════════════════════════════════════════════════════════
class _SidebarPanel extends StatelessWidget {
  final VoidCallback onClose;
  final void Function(String) onNavigate;
  final String userName, userEmail;

  const _SidebarPanel({required this.onClose, required this.onNavigate,
    required this.userName, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final w      = MediaQuery.of(context).size.width * 0.78;

    return Container(
      width: w, height: double.infinity,
      color: _black1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(24, top + 20, 24, 20),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _white10))),
            child: Row(
              children: [
                CachedNetworkImage(
                  imageUrl: 'https://444music-distribution.vercel.app/black.png',
                  height: 26, color: _white, colorBlendMode: BlendMode.srcIn,
                  errorWidget: (_, __, ___) => Text(
                    '444Music',
                    style: GoogleFonts.outfit(
                      color: _white, fontSize: 20, fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _white10),
                    ),
                    child: const Icon(Icons.close_rounded, color: _grey, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // User badge
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _white06,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _white10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _white20,
                      border: Border.all(color: _white20),
                    ),
                    child: const Icon(Icons.person_rounded, color: _white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: GoogleFonts.outfit(
                            color: _white, fontSize: 14, fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userEmail,
                          style: GoogleFonts.outfit(
                            color: _grey, fontSize: 11, fontWeight: FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Nav items
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NavSection(label: 'Navigation'),
                  _NavItem(icon: Icons.home_rounded,                  label: 'Home',            route: '/home',      onTap: onNavigate),
                  _NavItem(icon: Icons.person_rounded,                 label: 'Account',         route: '/profile',   onTap: onNavigate),
                  _NavItem(icon: Icons.speed_rounded,                  label: 'Dashboard',       route: '/dashboard', onTap: onNavigate),
                  _NavItem(icon: Icons.cloud_upload_rounded,           label: 'Upload Release',  route: '/upload',    onTap: onNavigate),
                  _NavItem(icon: Icons.bar_chart_rounded,              label: 'Analytics',       route: '/analytics', onTap: onNavigate),
                  _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Earnings',        route: '/earnings',  onTap: onNavigate),
                  const _SidebarDivider(),
                  _NavSection(label: 'More'),
                  _NavItem(icon: Icons.build_rounded,         label: 'More Tools',      route: '/tools',    onTap: onNavigate),
                  _NavItem(icon: Icons.info_outline_rounded,  label: 'About Us',        route: '/legal',    onTap: onNavigate),
                  _NavItem(icon: Icons.mail_outline_rounded,  label: 'Contact Support', route: '/support',  onTap: onNavigate),
                  _NavItem(icon: Icons.library_music_rounded, label: 'My Releases',     route: '/releases', onTap: onNavigate),
                  const _SidebarDivider(),
                ],
              ),
            ),
          ),

          // Logout
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
            child: GestureDetector(
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                onClose();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.red.shade900.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded,
                        color: Color(0xFFFF6B6B), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Logout',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFF6B6B),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavSection extends StatelessWidget {
  final String label;
  const _NavSection({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
    child: Text(
      label.toUpperCase(),
      style: GoogleFonts.outfit(
        color: _greyDark,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
    ),
  );
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label, route;
  final void Function(String) onTap;
  const _NavItem({required this.icon, required this.label,
    required this.route, required this.onTap});
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _hover = true),
      onTapUp:     (_) { setState(() => _hover = false); widget.onTap(widget.route); },
      onTapCancel: ()  => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _hover ? _white10 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(widget.icon, color: _hover ? _white : _grey, size: 18),
            const SizedBox(width: 14),
            Text(
              widget.label,
              style: GoogleFonts.outfit(
                color: _hover ? _white : _grey,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                color: _hover ? _white40 : Colors.transparent, size: 12),
          ],
        ),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
    height: 1,
    color: _white10,
  );
}

// ════════════════════════════════════════════════════════════════════
//  PLACEHOLDER TABS
// ════════════════════════════════════════════════════════════════════
class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _grey, size: 48),
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: _white, fontSize: 24, fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon',
            style: GoogleFonts.outfit(
              color: _grey, fontSize: 13, fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}