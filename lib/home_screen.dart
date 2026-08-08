// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Premium Home Screen v5
//  Sliding hero (analytics-style images, auto-advance every 5s, caption
//  slides with it) → wave-curve divider → trimmed "This release" panel
//  (stores + 100% yours only, no plays count, short caption so it never
//  overflows). Rest of the screen (stats row, why-us, dashboard CTA,
//  bottom nav, sidebar) is unchanged from v4.
// ═══════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── PALETTE ────────────────────────────────────────────────────────
const _black      = Color(0xFF000000);
const _black1     = Color(0xFF0A0A0A);
const _black2     = Color(0xFF111111);
const _black3     = Color(0xFF1A1A1A);
const _white      = Color(0xFFFFFFFF);
const _white90    = Color(0xE6FFFFFF);
const _white70    = Color(0xB3FFFFFF);
const _white40    = Color(0x66FFFFFF);
const _white20    = Color(0x33FFFFFF);
const _white10    = Color(0x1AFFFFFF);
const _white06    = Color(0x0FFFFFFF);
const _grey       = Color(0xFF888888);
const _greyDark   = Color(0xFF444444);
const _gold       = Color(0xFFCBA135);
const _gold70     = Color(0xB3CBA135);

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

  bool _sidebarOpen = false;
  late AnimationController _sidebarCtrl;
  late Animation<double>   _sidebarFade;
  late Animation<Offset>   _sidebarSlide;

  late AnimationController _entranceCtrl;
  late Animation<double>   _entranceFade;
  late Animation<Offset>   _entranceSlide;

  final _user = FirebaseAuth.instance.currentUser;

  String? _liveName;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _nameSub;

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

    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entranceFade  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();

    if (_user != null) {
      _nameSub = FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .snapshots()
          .listen((doc) {
        final name = doc.data()?['name'] as String?;
        if (mounted && name != null && name.isNotEmpty && name != _liveName) {
          setState(() => _liveName = name);
        }
      });
    }
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    _entranceCtrl.dispose();
    _nameSub?.cancel();
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
    final name = _liveName ?? _user?.displayName ?? 'Artist';
    return name.trim().isEmpty ? 'Artist' : name.split(' ').first;
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

          if (_sidebarOpen)
            GestureDetector(
              onTap: _closeSidebar,
              child: FadeTransition(
                opacity: _sidebarFade,
                child: Container(color: Colors.black.withOpacity(0.6)),
              ),
            ),

          if (_sidebarOpen)
            Positioned(
              top: 0, right: 0, bottom: 0,
              child: SlideTransition(
                position: _sidebarSlide,
                child: _SidebarPanel(
                  onClose: _closeSidebar,
                  onNavigate: _navigate,
                  userName:  _liveName ?? _user?.displayName ?? 'Artist',
                  userEmail: _user?.email ?? '',
                  uid: _user?.uid,
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

              // ── TOP BAR: avatar + greeting (left) · search + menu (right) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    _ProfileAvatar(uid: _user?.uid, authPhotoUrl: _user?.photoURL),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting,
                            style: GoogleFonts.outfit(
                              color: _grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _firstName,
                            style: GoogleFonts.outfit(
                              color: _white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _IconBtn(icon: Icons.search_rounded, onTap: () => _navigate('/search')),
                    const SizedBox(width: 10),
                    _IconBtn(icon: Icons.menu_rounded, onTap: _openSidebar),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── SLIDING HERO ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: const _SlideHero(),
              ),

              // ── WAVE CURVE ──
              const _WaveDivider(),

              // ── RELEASE PANEL (stores + 100% yours only, short caption) ──
              const _ReleasePanel(),

              const SizedBox(height: 24),

              // ── STATS ROW ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: const [
                    Expanded(child: _StatChip(value: '150+', label: 'Artists')),
                    SizedBox(width: 10),
                    Expanded(child: _StatChip(value: '30+',  label: 'Stores')),
                    SizedBox(width: 10),
                    Expanded(child: _StatChip(value: '100%', label: 'Ownership')),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  'WHY 444MUSIC',
                  style: GoogleFonts.outfit(
                    color: _gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _black2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _white10),
                  ),
                  child: Column(
                    children: const [
                      _WhyRow(icon: Icons.public_rounded,                 text: 'Global distribution to 30+ platforms'),
                      _WhyDivider(),
                      _WhyRow(icon: Icons.account_balance_wallet_rounded, text: '100% royalties, paid monthly'),
                      _WhyDivider(),
                      _WhyRow(icon: Icons.bolt_rounded,                   text: 'Live on stores within days'),
                      _WhyDivider(),
                      _WhyRow(icon: Icons.verified_user_rounded,         text: 'Your masters, full ownership always'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

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
//  SLIDING HERO — auto-advances every 5s, caption cross-fades with image
//  Swap the imageAsset paths below for your own professional analytics
//  style images (a Spotify for Artists-style dashboard shot, an Apple
//  Music for Artists-style dashboard shot, a laptop displaying a song
//  analytics chart). Use your own screenshots or licensed stock photos —
//  not scraped Apple/Spotify app screenshots, since those are their
//  trademarked UI, not yours to redistribute in a commercial app.
// ════════════════════════════════════════════════════════════════════
class _HeroSlide {
  final String imageAsset;
  final String title;
  final String caption;
  const _HeroSlide({required this.imageAsset, required this.title, required this.caption});
}

final List<_HeroSlide> _heroSlides = [
  _HeroSlide(
    imageAsset: 'assets/images/slide_streaming_dashboard.jpg',
    title: 'Streaming dashboard',
    caption: 'Live stream counts, updated daily',
  ),
  _HeroSlide(
    imageAsset: 'assets/images/slide_fan_insights.jpg',
    title: 'Fan insights',
    caption: 'See exactly where your fans are',
  ),
  _HeroSlide(
    imageAsset: 'assets/images/slide_full_reports.jpg',
    title: 'Full reports',
    caption: 'Every store, one dashboard',
  ),
];

class _SlideHero extends StatefulWidget {
  const _SlideHero();
  @override
  State<_SlideHero> createState() => _SlideHeroState();
}

class _SlideHeroState extends State<_SlideHero> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_index + 1) % _heroSlides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _heroSlides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final s = _heroSlides[i];
                return Image.asset(
                  s.imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: _black3),
                );
              },
            ),

            Positioned(
              top: 10, right: 12,
              child: Row(
                children: List.generate(_heroSlides.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(left: 4),
                    width: active ? 14 : 5,
                    height: 3,
                    decoration: BoxDecoration(
                      color: active ? _white : _white40,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 26, 14, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Column(
                    key: ValueKey(_index),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _heroSlides[_index].title,
                        style: GoogleFonts.outfit(
                          color: _white, fontSize: 13, fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _heroSlides[_index].caption,
                        style: GoogleFonts.outfit(
                          color: _white70, fontSize: 11, fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  WAVE DIVIDER — black-to-white curve
// ════════════════════════════════════════════════════════════════════
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.55);
    path.cubicTo(
      size.width * 0.25, size.height * 1.25,
      size.width * 0.55, -size.height * 0.25,
      size.width, size.height * 0.55,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _WaveDivider extends StatelessWidget {
  const _WaveDivider();
  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaveClipper(),
      child: Container(height: 34, width: double.infinity, color: _white),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  RELEASE PANEL — stores + 100% yours only, brief caption (no overflow)
// ════════════════════════════════════════════════════════════════════
class _ReleasePanel extends StatelessWidget {
  const _ReleasePanel();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This release',
            style: GoogleFonts.outfit(
              color: _black, fontSize: 17, fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(child: _ReleaseStat(icon: Icons.public_rounded, value: '30+',  label: 'stores')),
              Expanded(child: _ReleaseStat(icon: Icons.star_rounded,   value: '100%', label: 'yours')),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Your catalog and payouts, tracked in one place.',
            style: GoogleFonts.outfit(
              color: const Color(0xFF555555),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ReleaseStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _ReleaseStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _black, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(color: _black, fontSize: 14, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(color: const Color(0xFF777777), fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PROFILE AVATAR — live Firestore photo
// ════════════════════════════════════════════════════════════════════
class _ProfileAvatar extends StatelessWidget {
  final String? uid;
  final String? authPhotoUrl;
  const _ProfileAvatar({required this.uid, required this.authPhotoUrl});

  @override
  Widget build(BuildContext context) {
    if (uid == null) return _shell(_imageFor(authPhotoUrl));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        String? src = authPhotoUrl;
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data();
          src = data?['profilePic'] as String? ?? src;
        }
        return _shell(_imageFor(src));
      },
    );
  }

  Widget? _imageFor(String? src) {
    if (src == null || src.isEmpty) return null;

    if (src.startsWith('data:image')) {
      try {
        final bytes = base64Decode(src.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover, width: 44, height: 44);
      } catch (_) {
        return null;
      }
    }

    return CachedNetworkImage(
      imageUrl: src,
      fit: BoxFit.cover,
      placeholder: (_, __) => const Icon(Icons.person_rounded, color: _white70, size: 22),
      errorWidget: (_, __, ___) => const Icon(Icons.person_rounded, color: _white70, size: 22),
    );
  }

  Widget _shell(Widget? image) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _black3,
        border: Border.all(color: _white20, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: image ?? const Icon(Icons.person_rounded, color: _white70, size: 22),
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
              color: _white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.outfit(color: _grey, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  WHY ROW
// ════════════════════════════════════════════════════════════════════
class _WhyRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _WhyRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _gold70, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(color: _white90, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhyDivider extends StatelessWidget {
  const _WhyDivider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: Divider(color: _white10, height: 1),
  );
}

// ════════════════════════════════════════════════════════════════════
//  DASHBOARD HANDOFF CTA
// ════════════════════════════════════════════════════════════════════
class _DashboardCta extends StatelessWidget {
  final VoidCallback onTap;
  const _DashboardCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
                    'See your full dashboard',
                    style: GoogleFonts.outfit(
                      color: _black, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Releases, streams and earnings',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF666666), fontSize: 12, fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(color: _black, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, color: _white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ════════════════════════════════════════════════════════════════════
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
//  BOTTOM NAVIGATION BAR (unchanged)
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
                            BoxShadow(color: _white.withOpacity(0.2), blurRadius: 16, spreadRadius: 2),
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
                        decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(99)),
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
//  SIDEBAR (unchanged)
// ════════════════════════════════════════════════════════════════════
class _SidebarPanel extends StatelessWidget {
  final VoidCallback onClose;
  final void Function(String) onNavigate;
  final String userName, userEmail;
  final String? uid;

  const _SidebarPanel({required this.onClose, required this.onNavigate,
    required this.userName, required this.userEmail, required this.uid});

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
          Container(
            padding: EdgeInsets.fromLTRB(24, top + 20, 24, 20),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _white10))),
            child: Row(
              children: [
                CachedNetworkImage(
                  imageUrl: 'https://444music-distribution.vercel.app/black.png',
                  height: 26, color: _white, colorBlendMode: BlendMode.srcIn,
                  errorWidget: (_, __, ___) => Text(
                    '444Music',
                    style: GoogleFonts.outfit(color: _white, fontSize: 20, fontWeight: FontWeight.w800),
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
                  _ProfileAvatar(uid: uid, authPhotoUrl: FirebaseAuth.instance.currentUser?.photoURL),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: GoogleFonts.outfit(color: _white, fontSize: 14, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userEmail,
                          style: GoogleFonts.outfit(color: _grey, fontSize: 11, fontWeight: FontWeight.w400),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
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
                  border: Border.all(color: Colors.red.shade900.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, color: Color(0xFFFF6B6B), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Logout',
                      style: GoogleFonts.outfit(color: const Color(0xFFFF6B6B), fontSize: 14, fontWeight: FontWeight.w700),
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
      style: GoogleFonts.outfit(color: _greyDark, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2),
    ),
  );
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label, route;
  final void Function(String) onTap;
  const _NavItem({required this.icon, required this.label, required this.route, required this.onTap});
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
              style: GoogleFonts.outfit(color: _hover ? _white : _grey, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: _hover ? _white40 : Colors.transparent, size: 12),
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
//  PLACEHOLDER TABS (unchanged)
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
          Text(label, style: GoogleFonts.outfit(color: _white, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Coming soon', style: GoogleFonts.outfit(color: _grey, fontSize: 13, fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }
}