import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'login.dart';

// ─────────────────────────────────────────
//  COLOURS — refined black & white theme
// ─────────────────────────────────────────
const _bg       = Color(0xFF060606);
const _surface  = Color(0xFF0F0F0F);
const _surface2 = Color(0xFF141414);
const _white    = Color(0xFFF8F8F8);
const _dim      = Color(0xFF9A9A9A);
const _dim2     = Color(0xFF4A4A4A);
const _border   = Color(0x18FFFFFF);
const _border2  = Color(0x0EFFFFFF);

// ─────────────────────────────────────────
//  LANDING SCREEN
// ─────────────────────────────────────────
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {

  late VideoPlayerController _videoCtrl;
  bool _videoReady = false;

  late AnimationController _heroCtrl;
  late Animation<double>   _heroFade;
  late Animation<Offset>   _heroSlide;

  late AnimationController _dotCtrl;
  late AnimationController _tickerCtrl;

  late AnimationController _statsCtrl;
  late Animation<double>   _statsFade;

  // ── Multiple fallback video URLs (tried in order until one works)
  static const _videoUrls = [
    // Pexels concert/nightclub – direct HD mp4 (confirmed working URL pattern)
    'https://videos.pexels.com/video-files/2022395/2022395-hd_1920_1080_30fps.mp4',
    // Secondary Pexels concert crowd
    'https://videos.pexels.com/video-files/3941289/3941289-hd_1920_1080_25fps.mp4',
    // Tertiary — music stage lights
    'https://videos.pexels.com/video-files/3209828/3209828-hd_1280_720_25fps.mp4',
  ];

  int _videoUrlIndex = 0;

  void _initVideo() {
    if (_videoUrlIndex >= _videoUrls.length) return; // all failed, use fallback bg

    _videoCtrl = VideoPlayerController.networkUrl(
      Uri.parse(_videoUrls[_videoUrlIndex]),
    )..initialize().then((_) {
      if (mounted) {
        setState(() => _videoReady = true);
        _videoCtrl.setLooping(true);
        _videoCtrl.setVolume(0);
        _videoCtrl.play();
      }
    }).catchError((e) {
      debugPrint('Video URL ${_videoUrls[_videoUrlIndex]} failed: $e');
      _videoCtrl.dispose();
      _videoUrlIndex++;
      if (mounted) _initVideo(); // try next URL
    });
  }

  @override
  void initState() {
    super.initState();

    _initVideo();

    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _heroFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));
    _heroSlide = Tween<Offset>(
        begin: const Offset(0, 0.05), end: Offset.zero).animate(
        CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));

    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();

    _tickerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 22))
      ..repeat();

    _statsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _statsFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _statsCtrl, curve: Curves.easeOut));

    _heroCtrl.forward();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _statsCtrl.forward();
    });
  }

  @override
  void dispose() {
    _videoCtrl.dispose();
    _heroCtrl.dispose();
    _dotCtrl.dispose();
    _tickerCtrl.dispose();
    _statsCtrl.dispose();
    super.dispose();
  }

  Future<void> _openBlog() async {
    final uri = Uri.parse('https://444musicblog.vercel.app');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _goToLogin() => Navigator.push(context, PageRouteBuilder(
    pageBuilder: (_, __, ___) => const LoginScreen(initialTab: 0),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 400),
  ));

  void _goToRegister() => Navigator.push(context, PageRouteBuilder(
    pageBuilder: (_, __, ___) => const LoginScreen(initialTab: 1),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 400),
  ));

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildHero(context),
              _buildTicker(),
              _buildStats(),
              _buildPlatforms(),
              _buildHowItWorks(),
              _buildFeatureCard(),
              _buildTools(),
              _buildTestimonials(),
              _buildPricing(),
              _buildCTABanner(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  HERO — video background
  // ══════════════════════════════════════
  Widget _buildHero(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final top  = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [

          // ── Video background
          if (_videoReady)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width:  _videoCtrl.value.size.width,
                  height: _videoCtrl.value.size.height,
                  child: VideoPlayer(_videoCtrl),
                ),
              ),
            )
          else
          // Animated dark gradient fallback while video loads
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1C1C1C), Color(0xFF060606)],
                ),
              ),
            ),

          // ── Dark overlay for readability
          Container(color: const Color(0xB2020202)),

          // ── Left-heavy gradient for text legibility
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xF0060606),
                  Color(0x70060606),
                  Color(0x10060606),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // ── Bottom fade into page
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: size.height * 0.30,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [_bg, Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Top vignette
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.25,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x88020202), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Navbar
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildNavbar(top),
          ),

          // ── Hero content — FIX: constrain width to avoid overflow
          Positioned(
            top: top + 90,
            left: 24, right: 24,
            child: FadeTransition(
              opacity: _heroFade,
              child: SlideTransition(
                position: _heroSlide,
                child: _buildHeroContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Live pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _dotCtrl,
                builder: (_, __) => Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white
                            .withOpacity(0.5 * sin(_dotCtrl.value * pi).abs()),
                        blurRadius: 8, spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Now live on 100+ global stores',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        // Headline
        const Text(
          'Distribution +\nIndustry',
          style: TextStyle(
            color: _white,
            fontSize: 50,
            fontWeight: FontWeight.w900,
            letterSpacing: -2.2,
            height: 0.93,
          ),
        ),

        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFAAAAAA)],
          ).createShader(bounds),
          child: const Text(
            'Building',
            style: TextStyle(
              color: Colors.white,
              fontSize: 60,
              fontWeight: FontWeight.w900,
              letterSpacing: -3,
              height: 1.0,
            ),
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          '444Music Distribution powers independent\nartists with global streaming access,\nreal-time royalty tracking, and\nindustry-grade tools — all in one place.',
          style: TextStyle(
            color: Color(0xAAFFFFFF),
            fontSize: 14.5,
            height: 1.7,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.1,
          ),
        ),

        const SizedBox(height: 34),

        // Create Account button
        GestureDetector(
          onTap: _goToRegister,
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rocket_launch_rounded, color: Colors.black, size: 17),
                SizedBox(width: 9),
                Text(
                  'Create Account',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Sign In button
        GestureDetector(
          onTap: _goToLogin,
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_forward_rounded, color: _white, size: 17),
                SizedBox(width: 9),
                Text(
                  'Sign In',
                  style: TextStyle(
                    color: _white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),

        // ── Social proof — FIX: use Flexible + overflow-safe text
        Row(
          children: [
            // Avatar stack — fixed overlap
            SizedBox(
              width: 5 * 32.0 - 4 * 9.0, // 5 avatars * 32 - 4 overlaps * 9
              height: 32,
              child: Stack(
                children: ['A', 'K', 'M', 'J', 'T'].asMap().entries.map((e) =>
                    Positioned(
                      left: e.key * 23.0,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.lerp(
                            const Color(0xFF2A2A2A),
                            const Color(0xFF6A6A6A),
                            e.key / 4,
                          ),
                          border: Border.all(color: _bg, width: 2),
                        ),
                        child: Center(
                          child: Text(e.value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              )),
                        ),
                      ),
                    ),
                ).toList(),
              ),
            ),
            const SizedBox(width: 10),
            // FIX: wrap in Flexible so text can't overflow
            Flexible(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: const TextSpan(
                  style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 13),
                  children: [
                    TextSpan(
                      text: '7,000+ ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: 'artists distributing'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════
  //  NAVBAR
  // ══════════════════════════════════════
  Widget _buildNavbar(double top) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          Image.network(
            'https://444music-distribution.vercel.app/black.png',
            height: 28,
            color: Colors.white,
            colorBlendMode: BlendMode.srcIn,
            errorBuilder: (_, __, ___) => const Text(
              '444',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _openBlog,
            child: const Text(
              'promo',
              style: TextStyle(
                color: Color(0xAAFFFFFF),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: _openBlog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'visit Blog',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  TICKER
  // ══════════════════════════════════════
  Widget _buildTicker() {
    final items = [
      'Spotify', 'Apple Music', 'Amazon Music', 'YouTube Music',
      'TikTok', 'Instagram', 'Boomplay', 'Audiomack',
      'Deezer', 'Shazam', 'Anghami', 'Trebel',
    ];
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _surface,
        border: Border.symmetric(horizontal: BorderSide(color: _border2)),
      ),
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _tickerCtrl,
          builder: (_, __) {
            return OverflowBox(
              maxWidth: double.infinity,
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(-_tickerCtrl.value * 900, 0),
                child: Row(
                  children: [...items, ...items].map((item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: _border2)),
                    ),
                    child: Text(item,
                        style: const TextStyle(
                          color: _dim, fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        )),
                  )).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  STATS
  // ══════════════════════════════════════
  Widget _buildStats() {
    final stats = [
      ('7K+',  'Artists Using\n444Music'),
      ('50K+', 'Releases\nDistributed'),
      ('100+', 'Digital\nStores'),
      ('100%', 'Royalties\nKept'),
    ];
    return FadeTransition(
      opacity: _statsFade,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 28, 20, 0),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border2),
        ),
        child: Row(
          children: stats.asMap().entries.map((e) => Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 10),
              decoration: BoxDecoration(
                border: Border(
                  right: e.key < 3
                      ? BorderSide(color: _border2)
                      : BorderSide.none,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FIX: use FittedBox so stat number never overflows
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(e.value.$1,
                        style: const TextStyle(
                          color: _white, fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1, height: 1,
                        )),
                  ),
                  const SizedBox(height: 5),
                  Text(e.value.$2,
                      style: const TextStyle(
                        color: _dim, fontSize: 9.5,
                        fontWeight: FontWeight.w400, height: 1.4,
                      )),
                ],
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  PLATFORMS
  // ══════════════════════════════════════
  Widget _buildPlatforms() {
    final platforms = [
      (Icons.music_note,              'Spotify'),
      (Icons.apple,                   'Apple'),
      (Icons.shopping_bag_outlined,   'Amazon'),
      (Icons.play_circle_outline,     'YouTube'),
      (Icons.video_collection_outlined,'TikTok'),
      (Icons.camera_alt_outlined,     'Instagram'),
      (Icons.headphones,              'Boomplay'),
      (Icons.hearing,                 'Audiomack'),
      (Icons.radio,                   'Deezer'),
      (Icons.search,                  'Shazam'),
      (Icons.language,                'Anghami'),
      (Icons.album,                   'Trebel'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Distribution Network'),
          const SizedBox(height: 10),
          const Text('Distribute to all major platforms',
              style: TextStyle(color: _white, fontSize: 24,
                  fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          const SizedBox(height: 8),
          const Text('One upload, infinite reach across 100+ global stores.',
              style: TextStyle(color: _dim, fontSize: 13.5, height: 1.6)),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border2),
            ),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: platforms.map((p) => Container(
                decoration: BoxDecoration(border: Border.all(color: _border2)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(p.$1, color: _dim, size: 22),
                    const SizedBox(height: 6),
                    // FIX: overflow-safe platform label
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(p.$2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _dim, fontSize: 10.5,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  HOW IT WORKS
  // ══════════════════════════════════════
  Widget _buildHowItWorks() {
    final steps = [
      ('01', 'Create Account',  'Sign up in minutes and access your full artist dashboard.'),
      ('02', 'Upload Music',    'Add audio files, cover art, and metadata. ISRC codes auto-generated.'),
      ('03', 'Select Platforms','Choose from 100+ stores. Set release date and schedule ahead.'),
      ('04', 'Start Earning',   'Track streams and royalties in real-time. Withdraw anytime.'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('The Process'),
          const SizedBox(height: 10),
          const Text('How 444Music Works',
              style: TextStyle(color: _white, fontSize: 24,
                  fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          const SizedBox(height: 24),
          ...steps.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _border2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(s.$1,
                        style: const TextStyle(
                            color: Colors.black, fontSize: 13,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$2,
                          style: const TextStyle(color: _white, fontSize: 15,
                              fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                      const SizedBox(height: 5),
                      Text(s.$3,
                          style: const TextStyle(
                              color: _dim, fontSize: 13, height: 1.55)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  FEATURE CARD
  // ══════════════════════════════════════
  Widget _buildFeatureCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Built for Creators'),
          const SizedBox(height: 10),
          const Text('Your music.\nYour money.\nYour terms.',
              style: TextStyle(color: _white, fontSize: 26,
                  fontWeight: FontWeight.w800, letterSpacing: -0.9, height: 1.1)),
          const SizedBox(height: 16),
          const Text(
            '444Music puts independent artists first. Upload once and watch your tracks go live across every major platform — while every GHS earned stays in your account.',
            style: TextStyle(color: _dim, fontSize: 13.5, height: 1.7),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              'https://images.pexels.com/photos/1105666/pexels-photo-1105666.jpeg?auto=compress&cs=tinysrgb&w=900',
              height: 200, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(height: 200, color: _surface2),
            ),
          ),
          const SizedBox(height: 20),
          ...[
            ('100% royalties',   'no cuts, no subscriptions taking your earnings'),
            ('Fast delivery',    'your release live within 2–5 business days'),
            ('ISRC & Barcode',   'auto-generated free with every release'),
            ('Withdraw anytime', 'no minimum thresholds or waiting periods'),
          ].map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.black),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(children: [
                      TextSpan(
                        text: '${b.$1} — ',
                        style: const TextStyle(
                            color: _white, fontSize: 13.5,
                            fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: b.$2,
                        style: const TextStyle(color: _dim, fontSize: 13.5),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  TOOLS — FIX: overflow in tool card text
  // ══════════════════════════════════════
  Widget _buildTools() {
    final tools = [
      (Icons.attach_money_rounded,     'Monetization',      'Earn from streaming platforms and digital services worldwide.'),
      (Icons.shield_outlined,          'Rights Protection', 'Protect your music from unauthorized use globally.'),
      (Icons.rocket_launch_outlined,   'Artist Growth',     'Promote releases and reach new fans with real analytics.'),
      (Icons.bar_chart_rounded,        'Analytics',         'Track streams, saves, and audience demographics live.'),
      (Icons.business_center_outlined, 'Label Tools',       'Manage multiple artists and releases from one dashboard.'),
      (Icons.link_rounded,             'Referral Program',  'Invite artists and earn rewards passively.'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Artist Tools'),
          const SizedBox(height: 10),
          const Text('Powerful tools for every artist',
              style: TextStyle(color: _white, fontSize: 24,
                  fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          const SizedBox(height: 24),
          // FIX: replace GridView with manual wrapping Rows to avoid childAspectRatio clipping
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: tools.map((t) => SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _surface,
                      border: Border.all(color: _border2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,   // ← key fix
                      children: [
                        Icon(t.$1, color: Colors.white, size: 26),
                        const SizedBox(height: 10),
                        Text(t.$2,
                            style: const TextStyle(color: _white, fontSize: 14,
                                fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                        const SizedBox(height: 5),
                        Text(t.$3,
                            style: const TextStyle(
                                color: _dim, fontSize: 11.5, height: 1.5)),
                      ],
                    ),
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  TESTIMONIALS
  // ══════════════════════════════════════
  Widget _buildTestimonials() {
    final cards = [
      ('KA', '444Music got my EP on Spotify within 3 days. The dashboard is so clean.',
      'Kwame Asante', 'Afrobeats · Accra'),
      ('MA', 'I love that I keep 100% of my royalties. No hidden fees, no drama.',
      'Maame Akosua', 'Gospel · Kumasi'),
      ('JB', 'The analytics tool helped me understand where my fans are.',
      'Jay Blaze', 'Hip-Hop · Lagos'),
      ('DK', 'My single hit 100K streams in two weeks after uploading through them.',
      'DJ Kofi', 'DJ/Producer · Tema'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 44, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('Artist Stories'),
                const SizedBox(height: 10),
                const Text('Artists love 444Music',
                    style: TextStyle(color: _white, fontSize: 24,
                        fontWeight: FontWeight.w800, letterSpacing: -0.8)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 185,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: cards.length,
              itemBuilder: (_, i) {
                final c = cards[i];
                return Container(
                  width: 255,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('★★★★★',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12, letterSpacing: 1)),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Text('"${c.$2}"',
                            style: const TextStyle(
                                color: _dim, fontSize: 12.5, height: 1.6)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 30, height: 30,
                            decoration: const BoxDecoration(
                                color: Color(0xFF2A2A2A), shape: BoxShape.circle),
                            child: Center(
                              child: Text(c.$1,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.$3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: _white,
                                        fontSize: 12, fontWeight: FontWeight.w600)),
                                Text(c.$4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _dim2, fontSize: 10.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  PRICING
  // ══════════════════════════════════════
  Widget _buildPricing() {
    final plans = [
      (
      false, 'FREE', 'Starter', 'GHS 0', 'No upfront payment',
      ['1 free upload', '100+ stores', 'Free ISRC & Barcode', 'Keep 100% royalties'],
      'Get Started',
      ),
      (
      true, 'POPULAR', 'Single Release', 'GHS 39.99', 'Per single release',
      ['Priority delivery', 'Global distribution', '100% royalties', 'Full analytics'],
      'Release Single',
      ),
      (
      false, 'PROJECT', 'EP / Album', 'GHS 59.55', 'Per project release',
      ['Up to 20 tracks', 'Detailed reports', 'Priority support', 'Playlist pitching'],
      'Release Project',
      ),
      (
      false, 'BEST VALUE', 'Annual Pro', 'GHS 350.00', 'Per year · unlimited releases',
      [
        'Unlimited uploads',
        'All 100+ stores',
        '100% royalties kept',
        'Advanced analytics',
        'Priority 24/7 support',
        'Playlist pitching',
      ],
      'Go Annual',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Pricing'),
          const SizedBox(height: 10),
          const Text('Simple & Transparent Pricing',
              style: TextStyle(color: _white, fontSize: 24,
                  fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          const SizedBox(height: 8),
          const Text('No hidden fees. Keep 100% royalties on every plan.',
              style: TextStyle(color: _dim, fontSize: 13.5)),
          const SizedBox(height: 28),
          ...plans.map((p) {
            final isHighlight = p.$1;
            final isAnnual    = p.$2 == 'BEST VALUE';
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isAnnual
                    ? const Color(0xFF0A0A0A)
                    : isHighlight ? _surface2 : _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isAnnual
                      ? Colors.white.withOpacity(0.22)
                      : isHighlight
                      ? Colors.white.withOpacity(0.18)
                      : _border2,
                  width: isAnnual ? 1.5 : 1,
                ),
                boxShadow: isAnnual
                    ? [BoxShadow(
                    color: Colors.white.withOpacity(0.04),
                    blurRadius: 32, offset: const Offset(0, 8))]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tag badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAnnual || isHighlight
                              ? Colors.white
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(p.$2,
                            style: TextStyle(
                              color: isAnnual || isHighlight
                                  ? Colors.black : _dim,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            )),
                      ),
                      if (isAnnual) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: _border),
                          ),
                          child: const Text('SAVE 40%',
                              style: TextStyle(
                                color: _white, fontSize: 9.5,
                                fontWeight: FontWeight.w700, letterSpacing: 0.5,
                              )),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(p.$3,
                      style: const TextStyle(color: _white, fontSize: 18,
                          fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  const SizedBox(height: 10),
                  Text(p.$4,
                      style: const TextStyle(color: _white, fontSize: 34,
                          fontWeight: FontWeight.w900, letterSpacing: -1.5)),
                  Text(p.$5,
                      style: const TextStyle(color: _dim, fontSize: 12)),
                  const SizedBox(height: 18),
                  Divider(color: _border2),
                  const SizedBox(height: 14),
                  ...p.$6.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            color: isAnnual || isHighlight
                                ? Colors.white
                                : Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(Icons.check, size: 10,
                              color: isAnnual || isHighlight
                                  ? Colors.black : Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(f,
                              style: const TextStyle(
                                  color: _dim, fontSize: 13.5)),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: _goToRegister,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isAnnual || isHighlight
                            ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isAnnual || isHighlight
                                ? Colors.white : _border),
                      ),
                      child: Center(
                        child: Text(p.$7,
                            style: TextStyle(
                              color: isAnnual || isHighlight
                                  ? Colors.black : _white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            )),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  CTA BANNER
  // ══════════════════════════════════════
  Widget _buildCTABanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 44, 20, 0),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Text('Ready to go global?',
              textAlign: TextAlign.center,
              style: TextStyle(color: _white, fontSize: 28,
                  fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 6),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFCCCCCC), Color(0xFF555555)],
            ).createShader(bounds),
            child: const Text('Start distributing today.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 28,
                    fontWeight: FontWeight.w900, letterSpacing: -1)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Join 7,000+ independent artists who trust\n444Music to reach their fans worldwide.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _dim, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _goToRegister,
            child: Container(
              width: double.infinity, height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch_rounded, color: Colors.black, size: 16),
                  SizedBox(width: 8),
                  Text('Create Free Account',
                      style: TextStyle(color: Colors.black, fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _goToLogin,
            child: Container(
              width: double.infinity, height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_forward_rounded, color: _white, size: 16),
                  SizedBox(width: 8),
                  Text('Sign In',
                      style: TextStyle(color: _white, fontSize: 15,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  FOOTER
  // ══════════════════════════════════════
  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.only(top: 44),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: _border2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            'https://444music-distribution.vercel.app/white.png',
            height: 28,
            errorBuilder: (_, __, ___) => const Text('444Music',
                style: TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Global music distribution platform for independent artists. Upload once — distribute everywhere.',
            style: TextStyle(color: _dim, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: ['About', 'Pricing', 'FAQ', 'Contact']
                .map((l) => Text(l,
                style: const TextStyle(color: _dim, fontSize: 13)))
                .toList(),
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0x0DFFFFFF)),
          const SizedBox(height: 16),
          const Text(
            '© 2026 444Music Distribution. All rights reserved.',
            style: TextStyle(color: _dim2, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Row(
    children: [
      Container(width: 18, height: 1.5, color: Colors.white),
      const SizedBox(width: 8),
      Text(text.toUpperCase(),
          style: const TextStyle(
            color: Colors.white, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 0.8,
          )),
    ],
  );
}