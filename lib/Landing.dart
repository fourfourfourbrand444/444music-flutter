import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login.dart';

// ─────────────────────────────────────────
//  COLOURS — mirrors the web's monochrome system
// ─────────────────────────────────────────
const _bg        = Color(0xFF020202);
const _surface   = Color(0xFF0A0A0A);
const _surface2  = Color(0xFF0E0E0E);
const _surface3  = Color(0xFF131313);
const _white     = Color(0xFFF5F5F5);
const _text      = Color(0xFFF2F2F2);
const _text2     = Color(0xFF8F8F8F);
const _text3     = Color(0xFF454545);
const _border    = Color(0x14FFFFFF);
const _border2   = Color(0x0DFFFFFF);

// "light-section" palette (the web's white blocks)
const _lightBg     = Color(0xFFFFFFFF);
const _lightText   = Color(0xFF0A0A0A);
const _lightText2  = Color(0xFF545454);
const _lightText3  = Color(0xFF6B6B6B);
const _lightBorder = Color(0x17000000);
const _lightSurf2  = Color(0xFFF3F3F3);

const _logoBlack = 'https://www.444musicdistro.com/black.png';
const _logoWhite = 'https://444music-distribution.vercel.app/white.png';

class _HeroSlide {
  final List<String>? lines;
  final List<IconData>? icons;
  final String? caption;
  const _HeroSlide({this.lines, this.icons, this.caption});
}

class _ToolItem {
  final IconData icon;
  final String title;
  final String desc;
  const _ToolItem(this.icon, this.title, this.desc);
}

class _Testimonial {
  final String initials, quote, name, role;
  const _Testimonial(this.initials, this.quote, this.name, this.role);
}

class _FaqItem {
  final String cat, q, a;
  const _FaqItem(this.cat, this.q, this.a);
}

class _Platform {
  final IconData icon;
  final String label;
  const _Platform(this.icon, this.label);
}

const List<_Platform> _platforms = [
  _Platform(Icons.music_note, 'Spotify'),
  _Platform(Icons.apple, 'Apple Music'),
  _Platform(Icons.shopping_bag_outlined, 'Amazon'),
  _Platform(Icons.play_circle_outline, 'YouTube'),
  _Platform(Icons.video_collection_outlined, 'TikTok'),
  _Platform(Icons.camera_alt_outlined, 'Instagram'),
  _Platform(Icons.headphones, 'Boomplay'),
  _Platform(Icons.hearing, 'Audiomack'),
  _Platform(Icons.radio, 'Deezer'),
  _Platform(Icons.search, 'Shazam'),
  _Platform(Icons.language, 'Anghami'),
  _Platform(Icons.album, 'Trebel'),
];

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

  // ── Ticker
  late AnimationController _tickerCtrl;

  // ── Hero title slideshow
  final List<_HeroSlide> _heroSlides = const [
    _HeroSlide(lines: ['We', 'amplify', 'creative', 'music', 'brands']),
    _HeroSlide(lines: ['Upload once.', 'Reach every', 'platform.']),
    _HeroSlide(lines: ['Your music.', 'Your money.', 'Your terms.']),
    _HeroSlide(lines: ['Keep 100%', 'of your', 'royalties.']),
    _HeroSlide(lines: ['From Accra', 'to the world.']),
    _HeroSlide(lines: ['Distribution', 'without limits.']),
    _HeroSlide(lines: ['Built for', 'independent', 'artists.']),
    _HeroSlide(lines: ['Global reach.', 'Zero cuts.']),
    _HeroSlide(
      caption: 'LIVE ON 100+ STORES',
      icons: [
        Icons.music_note, Icons.apple, Icons.play_circle_outline,
        Icons.shopping_bag_outlined, Icons.video_collection_outlined,
        Icons.play_circle_fill,
      ],
    ),
  ];
  late List<int> _heroOrder;
  int _heroPos = 0;
  Timer? _heroTimer;

  // ── Nav overlay
  bool _navOpen = false;

  // ── FAQ
  String _faqFilter = 'all';
  int? _faqOpenIndex;
  final List<_FaqItem> _faqItems = const [
    _FaqItem('distribution', 'How do I upload my music to 444Music?',
        'Log in to your dashboard, create a new release, upload your audio file, cover art, and fill in the required details such as artist name, release date, and genre.'),
    _FaqItem('distribution', 'Which stores will my music be sent to?',
        'Your music can be delivered to major streaming platforms including Spotify, Apple Music, TikTok, YouTube Music, Audiomack, Boomplay, and many more global stores — 100+ in total.'),
    _FaqItem('distribution', 'How long does it take for my release to go live?',
        'Most releases are processed within 2–5 business days. We recommend submitting at least 7 days before your target release date.'),
    _FaqItem('distribution', 'What audio format should I upload?',
        'We recommend WAV files (16-bit or 24-bit) for best quality. FLAC is also accepted. We transcode to the required format for each store automatically.'),
    _FaqItem('payments', 'How do I earn money from my music?',
        "You earn royalties whenever people stream or download your music on supported platforms. Earnings are collected and shown in your dashboard — you keep 100% of what's yours."),
    _FaqItem('payments', 'When will I receive my royalties?',
        'Streaming platforms usually report earnings monthly, but some may take 2–3 months before the first royalties appear in your dashboard.'),
    _FaqItem('account', 'Can labels use 444Music Distribution?',
        'Yes. Labels can manage multiple artists and releases from a single dashboard, with separate royalty tracking for each artist.'),
    _FaqItem('account', 'Is my music ownership protected?',
        'Yes. You keep 100% ownership of your music. We only distribute your content to digital stores — we never claim any ownership or rights.'),
    _FaqItem('referrals', 'How does the referral program work?',
        'Share your referral link with new artists. When they join and release music through 444Music, you earn referral rewards from their activity — passively.'),
    _FaqItem('referrals', 'Where can I find my referral link?',
        'Your referral link is inside your dashboard under the Referrals section. You can share it directly or copy it for social media.'),
  ];

  // ── Releases slideshow (from Firestore)
  List<Map<String, dynamic>> _releases = [];
  int _releaseIndex = 0;
  Timer? _releaseTimer;
  bool _releasesLoading = true;

  @override
  void initState() {
    super.initState();
    _tickerCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 26))
          ..repeat();

    _heroOrder = _shuffle(List.generate(_heroSlides.length, (i) => i));
    _heroTimer = Timer.periodic(const Duration(milliseconds: 4200), (_) {
      if (!mounted) return;
      setState(() {
        _heroPos++;
        if (_heroPos >= _heroOrder.length) {
          _heroPos = 0;
          _heroOrder = _shuffle(List.generate(_heroSlides.length, (i) => i));
        }
      });
    });

    _loadReleases();
  }

  @override
  void dispose() {
    _tickerCtrl.dispose();
    _heroTimer?.cancel();
    _releaseTimer?.cancel();
    super.dispose();
  }

  List<int> _shuffle(List<int> list) {
    final r = Random();
    for (int i = list.length - 1; i > 0; i--) {
      final j = r.nextInt(i + 1);
      final tmp = list[i]; list[i] = list[j]; list[j] = tmp;
    }
    return list;
  }

  Future<void> _loadReleases() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('submissions')
          .limit(30)
          .get();
      final items = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final cover = d['coverURL'];
        if (cover == null || (cover is String && cover.trim().isEmpty)) continue;
        items.add({
          'cover': cover,
          'title': d['releaseTitle'] ?? d['title'] ?? 'New Release',
          'artist': d['artistName'] ?? d['artist'] ?? 'Artist',
        });
      }
      if (!mounted) return;
      setState(() {
        _releases = items;
        _releasesLoading = false;
      });
      if (_releases.length > 1) {
        _releaseTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
          if (!mounted) return;
          setState(() => _releaseIndex = (_releaseIndex + 1) % _releases.length);
        });
      }
    } catch (e) {
      debugPrint('Failed to load releases: $e');
      if (mounted) setState(() => _releasesLoading = false);
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
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

  // ══════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildWhiteHeroBlock(context),
                  _buildTicker(),
                  _buildStatsLight(),
                  _buildPhotoStrip(),
                  _buildPlatformsLight(),
                  _buildHowItWorks(),
                  _buildFeatureSplit(
                    imageUrl:
                        'https://images.unsplash.com/photo-1525201548942-d8732f6617a0?w=900&q=80&auto=format&fit=crop',
                    badgeIcon: Icons.podcasts,
                    badgeText: 'Live on Spotify · Apple Music',
                    label: 'Built for Creators',
                    heading: 'Your music. Your money. Your terms.',
                    body:
                        '444Music puts independent artists first. Upload once and watch your tracks go live across every major platform — while every GHS earned stays in your account.',
                    bullets: const [
                      ('100% royalties', 'no cuts, no subscriptions taking your earnings'),
                      ('Fast delivery', 'your release live within 2–5 business days'),
                      ('ISRC & Barcode', 'auto-generated free with every release'),
                      ('Withdraw anytime', 'no minimum thresholds or waiting periods'),
                    ],
                  ),
                  _buildFeatureSplit(
                    imageUrl:
                        'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=900&q=80&auto=format&fit=crop',
                    badgeIcon: Icons.shield_outlined,
                    badgeText: 'Rights protected',
                    label: 'Studio to Store',
                    heading: 'From the booth to every speaker on earth',
                    body:
                        "Whether you're recording in Accra, Lagos, or London — 444Music delivers your sound to 100+ streaming stores worldwide with zero technical headaches.",
                    bullets: const [
                      ('WAV & FLAC support', 'professional quality, lossless delivery'),
                      ('African platforms first', 'Boomplay, Audiomack, Mdundo & more'),
                      ('Label & solo friendly', 'manage one artist or an entire roster'),
                      ('Playlist pitching', 'editorial support on Pro plan'),
                    ],
                  ),
                  _buildUploadFlow(),
                  _buildToolsGrid(),
                  _buildTestimonialsLight(),
                  _buildBentoGrid(),
                  _buildReleasesSlideshow(),
                  _buildFaqLight(),
                  _buildCTA(),
                  _buildFooter(),
                ],
              ),
            ),
            if (_navOpen) _buildNavOverlay(),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  WHITE HEADER + HERO
  // ══════════════════════════════════════
  Widget _buildWhiteHeroBlock(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: _lightBg,
      padding: EdgeInsets.only(top: top),
      child: Column(
        children: [
          // header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _navOpen = true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Column(
                      children: [
                        Container(width: 30, height: 2.5, color: const Color(0xFF17171F)),
                        const SizedBox(height: 7),
                        Container(width: 30, height: 2.5, color: const Color(0xFF17171F)),
                      ],
                    ),
                  ),
                ),
                Image.network(
                  _logoBlack, height: 34,
                  errorBuilder: (_, __, ___) => const Text('444',
                      style: TextStyle(color: Color(0xFF1a1a2e), fontSize: 20,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          // hero title slideshow + buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.30,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.12), end: Offset.zero,
                        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                    ),
                    child: _buildHeroSlideContent(
                      key: ValueKey(_heroPos),
                      slide: _heroSlides[_heroOrder[_heroPos]],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _whiteOutlineButton('LOGIN', wide: true, onTap: _goToLogin),
                const SizedBox(height: 14),
                _whiteOutlineButton('SIGN UP', wide: false, onTap: _goToRegister),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSlideContent({required Key key, required _HeroSlide slide}) {
    if (slide.icons != null) {
      return Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Wrap(
            spacing: 22, runSpacing: 14,
            children: slide.icons!
                .map((ic) => Icon(ic, size: 46, color: const Color(0xFF1a1a2e)))
                .toList(),
          ),
          const SizedBox(height: 14),
          Text(slide.caption ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12,
                letterSpacing: 2.4, color: Color(0xFF5c5c62),
              )),
        ],
      );
    }
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: (slide.lines ?? []).map((line) => Text(
        line,
        style: const TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w900,
          fontSize: 44,
          height: 0.98,
          letterSpacing: -1.4,
          color: Color(0xFF1a1a2e),
        ),
      )).toList(),
    );
  }

  Widget _whiteOutlineButton(String label, {required bool wide, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: wide ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: wide ? 0 : 40, vertical: 17),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF1a1a2e), width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: const TextStyle(
              color: Color(0xFF1a1a2e), fontSize: 16, fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            )),
      ),
    );
  }

  // ══════════════════════════════════════
  //  FULL-SCREEN NAV OVERLAY
  // ══════════════════════════════════════
  Widget _buildNavOverlay() {
    final links = <(String, IconData, VoidCallback)>[
      ('Pricing', Icons.arrow_forward, () => setState(() => _navOpen = false)),
      ('About', Icons.arrow_forward, () => setState(() => _navOpen = false)),
      ('FAQ', Icons.arrow_forward, () => setState(() => _navOpen = false)),
      ('Watch Tutorials', Icons.play_circle_outline,
          () { setState(() => _navOpen = false); _launch('https://www.youtube.com/@444musicdistribution'); }),
      ('Contact', Icons.email_outlined,
          () { setState(() => _navOpen = false); _launch('mailto:444musicdistro@gmail.com'); }),
    ];
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.99),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('444MUSIC',
                        style: TextStyle(color: _white, fontWeight: FontWeight.w800,
                            fontSize: 17, letterSpacing: -0.3)),
                    GestureDetector(
                      onTap: () => setState(() => _navOpen = false),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: const Icon(Icons.close, color: _white, size: 18),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: links.map((l) => GestureDetector(
                      onTap: l.$3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: _border2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(l.$1,
                                  style: const TextStyle(
                                    color: _white, fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w800, fontSize: 30,
                                    letterSpacing: -1,
                                  )),
                            ),
                            Icon(l.$2, color: _text2, size: 18),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () { setState(() => _navOpen = false); _goToRegister(); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.north_east, size: 15, color: Colors.black),
                            SizedBox(width: 9),
                            Text('Create Account',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700,
                                    fontSize: 14.5)),
                          ],
                        ),
                      ),
                    ),
                    const Text('444Music Distribution',
                        style: TextStyle(color: _text3, fontSize: 12.5, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  TICKER
  // ══════════════════════════════════════
  Widget _buildTicker() {
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
                offset: Offset(-_tickerCtrl.value * 1400, 0),
                child: Row(
                  children: [..._platforms, ..._platforms].map((p) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: _border2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(p.icon, size: 15, color: _text2),
                        const SizedBox(width: 8),
                        Text(p.label,
                            style: const TextStyle(color: _text2, fontSize: 12.5,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
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
  //  STATS (light)
  // ══════════════════════════════════════
  Widget _buildStatsLight() {
    final stats = [
      ('7K+', 'Artists Using 444Music'),
      ('50K+', 'Releases Distributed'),
      ('100+', 'Digital Stores'),
      ('100%', 'Royalties Kept by Artists'),
    ];
    return Container(
      color: _lightBg,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Wrap(
        children: stats.map((s) => FractionallySizedBox(
          widthFactor: 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: _lightBorder), bottom: BorderSide(color: _lightBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.$1, style: const TextStyle(fontFamily: 'Outfit', fontSize: 34,
                    fontWeight: FontWeight.w900, letterSpacing: -1.5, color: _lightText)),
                const SizedBox(height: 6),
                Text(s.$2, style: const TextStyle(fontSize: 12.5, color: _lightText2)),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  // ══════════════════════════════════════
  //  PHOTO STRIP
  // ══════════════════════════════════════
  Widget _buildPhotoStrip() {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 260,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=900&q=80&auto=format&fit=crop',
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.25),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (_, __, ___) => Container(color: _surface2),
              ),
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 40, 18, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Color(0xCC000000), Colors.transparent],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('From upload to stage',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      SizedBox(height: 2),
                      Text('Global reach in days',
                          style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  PLATFORMS (light)
  // ══════════════════════════════════════
  Widget _buildPlatformsLight() {
    return Container(
      color: _lightBg,
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _label('Distribution Network', light: true, centered: true),
          const SizedBox(height: 10),
          _heading('Distribute to all major platforms', light: true, align: TextAlign.center),
          const SizedBox(height: 8),
          _para('Your music, everywhere your fans are. One upload, infinite reach across 100+ global stores.',
              light: true, align: TextAlign.center),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _lightBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: _platforms.map((p) => Container(
                decoration: BoxDecoration(border: Border.all(color: _lightBorder)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(p.icon, color: _lightText3, size: 22),
                    const SizedBox(height: 8),
                    Text(p.label, style: const TextStyle(color: _lightText3, fontSize: 10.5,
                        fontWeight: FontWeight.w500)),
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
      ('01', 'Create an Account', 'Sign up in minutes and access your full artist dashboard with all tools ready to use.'),
      ('02', 'Upload Your Music', 'Add your audio files, cover artwork, and metadata. ISRC codes are included automatically.'),
      ('03', 'Select Platforms', 'Choose from 100+ stores and streaming services. Set your release date and schedule ahead.'),
      ('04', 'Start Earning', 'Track streams, downloads, and royalties in real-time. Withdraw your earnings anytime.'),
    ];
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('The Process'),
          const SizedBox(height: 10),
          _heading('How 444Music Works'),
          const SizedBox(height: 8),
          _para('From upload to global — four simple steps to get your music everywhere.'),
          const SizedBox(height: 24),
          ...steps.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface, border: Border.all(color: _border2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text(s.$1, style: const TextStyle(color: Colors.black, fontSize: 13,
                        fontFamily: 'Outfit', fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$2, style: const TextStyle(color: _white, fontSize: 15,
                          fontFamily: 'Outfit', fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                      const SizedBox(height: 5),
                      Text(s.$3, style: const TextStyle(color: _text2, fontSize: 13, height: 1.55)),
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
  //  FEATURE SPLIT (reused for both split sections)
  // ══════════════════════════════════════
  Widget _buildFeatureSplit({
    required String imageUrl,
    required IconData badgeIcon,
    required String badgeText,
    required String label,
    required String heading,
    required String body,
    required List<(String, String)> bullets,
  }) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Image.network(imageUrl, height: 220, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 220, color: _surface2)),
                Positioned(
                  top: 14, left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeIcon, size: 13, color: _text2),
                        const SizedBox(width: 7),
                        Text(badgeText, style: const TextStyle(color: _white, fontSize: 11.5,
                            fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _label(label),
          const SizedBox(height: 12),
          Text(heading, style: const TextStyle(color: _white, fontFamily: 'Outfit', fontSize: 25,
              fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.15)),
          const SizedBox(height: 14),
          Text(body, style: const TextStyle(color: _text2, fontSize: 13.5, height: 1.7)),
          const SizedBox(height: 18),
          ...bullets.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.check, size: 13, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(children: [
                      TextSpan(text: '${b.$1} — ',
                          style: const TextStyle(color: _white, fontSize: 13.5, fontWeight: FontWeight.w600)),
                      TextSpan(text: b.$2, style: const TextStyle(color: _text2, fontSize: 13.5)),
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
  //  UPLOAD FLOW — steps list only (form is hidden on mobile in the web version)
  // ══════════════════════════════════════
  Widget _buildUploadFlow() {
    final steps = [
      ('1', 'Add Track Info', 'Enter title, artist name, genre, release date, and credits. Auto-generate ISRC codes.'),
      ('2', 'Upload Audio & Cover Art', 'Drop your WAV or FLAC file and a 3000×3000px cover image. Quality check included.'),
      ('3', 'Choose Your Stores', 'Select from 100+ platforms or go global with one click. Territory restrictions available.'),
      ('4', 'Review & Submit', 'Our team reviews your release and delivers it on schedule. Track status in dashboard.'),
    ];
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Release Manager'),
          const SizedBox(height: 10),
          _heading('The easiest release workflow'),
          const SizedBox(height: 8),
          _para('Upload once and we handle delivery, metadata, and store submission for you.'),
          const SizedBox(height: 20),
          ...steps.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: _surface, border: Border.all(color: _border2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _surface3, border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(s.$1, style: const TextStyle(color: _text2, fontSize: 13,
                        fontFamily: 'Outfit', fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$2, style: const TextStyle(color: _white, fontSize: 14.5,
                          fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                      const SizedBox(height: 5),
                      Text(s.$3, style: const TextStyle(color: _text2, fontSize: 12.5, height: 1.55)),
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
  //  TOOLS
  // ══════════════════════════════════════
  Widget _buildToolsGrid() {
    final tools = const [
      _ToolItem(Icons.attach_money_rounded, 'Music Monetization',
          'Earn from streaming platforms, social media, and digital music services worldwide. Transparent royalty splits.'),
      _ToolItem(Icons.shield_outlined, 'Rights Protection',
          'Protect your music from unauthorized use and ensure you receive accurate royalties from every platform globally.'),
      _ToolItem(Icons.show_chart_rounded, 'Artist Growth',
          'Promote releases, pitch to editorial playlists, and reach new fans across global platforms with real analytics.'),
      _ToolItem(Icons.bar_chart_rounded, 'Real-Time Analytics',
          'Track streams, saves, playlists, and audience demographics live across all your releases and platforms.'),
      _ToolItem(Icons.groups_outlined, 'Label Management',
          'Manage multiple artists and releases from one dashboard. Perfect for labels, collectives, and managers.'),
      _ToolItem(Icons.link_rounded, 'Referral Program',
          'Invite other artists and earn rewards when they release music through 444Music. Build passive income.'),
    ];
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Artist Tools'),
          const SizedBox(height: 10),
          _heading('Powerful tools for every artist'),
          const SizedBox(height: 8),
          _para('Everything you need to grow, protect, and monetize your music — in one platform.'),
          const SizedBox(height: 20),
          ...tools.map((t) => Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface, border: Border.all(color: _border2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(t.icon, color: Colors.white, size: 24),
                const SizedBox(height: 12),
                Text(t.title, style: const TextStyle(color: _white, fontFamily: 'Outfit',
                    fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 8),
                Text(t.desc, style: const TextStyle(color: _text2, fontSize: 13, height: 1.6)),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('Learn more', style: TextStyle(color: _white, fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 13, color: _white),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  TESTIMONIALS (light)
  // ══════════════════════════════════════
  Widget _buildTestimonialsLight() {
    final cards = const [
      _Testimonial('KA', '444Music got my EP on Spotify and Apple Music within 3 days. The dashboard is so clean and easy to use.', 'Kwame Asante', 'Afrobeats Artist · Accra'),
      _Testimonial('MA', 'I love that I keep 100% of my royalties. No hidden fees, no drama. Just pure distribution.', 'Maame Akosua', 'Gospel Artist · Kumasi'),
      _Testimonial('JB', 'The analytics tool helped me understand where my fans are. Now I know exactly who to target.', 'Jay Blaze', 'Hip-Hop Artist · Lagos'),
      _Testimonial('TA', 'Best music distribution for African artists. The Boomplay and Audiomack integration is top tier.', 'Temi A.', 'Afropop Artist · Abuja'),
      _Testimonial('DK', 'My single hit 100K streams in two weeks after I uploaded through them.', 'DJ Kofi', 'DJ / Producer · Tema'),
    ];
    return Container(
      color: _lightBg,
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _label('Artist Stories', light: true, centered: true),
                const SizedBox(height: 10),
                _heading('Artists love 444Music', light: true, align: TextAlign.center),
                const SizedBox(height: 8),
                _para('Thousands of independent artists trust us to get their music to the world.',
                    light: true, align: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: cards.length,
              itemBuilder: (_, i) {
                final c = cards[i];
                return Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _lightSurf2, border: Border.all(color: _lightBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('★★★★★', style: TextStyle(color: _lightText, fontSize: 12, letterSpacing: 1)),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Text('"${c.quote}"',
                            style: const TextStyle(color: Color(0xFF4A4A4A), fontSize: 12.5, height: 1.55)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(color: const Color(0xFFECECEC), shape: BoxShape.circle,
                                border: Border.all(color: _lightBorder)),
                            child: Center(
                              child: Text(c.initials, style: const TextStyle(color: _lightText,
                                  fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: _lightText, fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                Text(c.role, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: _lightText3, fontSize: 10.5)),
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
  //  BENTO PHOTO GRID
  // ══════════════════════════════════════
  Widget _buildBentoGrid() {
    final items = const [
      ('https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?w=1000&q=80&auto=format&fit=crop', 'Upload & Distribute'),
      ('https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80&auto=format&fit=crop', 'Earn Royalties'),
      ('https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80&auto=format&fit=crop', 'Grow Your Fanbase'),
      ('https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80&auto=format&fit=crop', 'Studio Quality'),
      ('https://images.unsplash.com/photo-1614680376573-df3480f0c6ff?w=600&q=80&auto=format&fit=crop', 'Real-Time Analytics'),
    ];
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _label('The Artist Journey', centered: true),
          const SizedBox(height: 10),
          _heading('Built for every stage of your career', align: TextAlign.center),
          const SizedBox(height: 8),
          _para('From bedroom producer to festival headliner — 444Music scales with you.',
              align: TextAlign.center),
          const SizedBox(height: 20),
          ...items.map((it) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 190, width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(it.$1, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: _surface2)),
                    Positioned(
                      left: 12, bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(it.$2, style: const TextStyle(color: Color(0xFF0A0A0A),
                            fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  RELEASES — single-cover slideshow with dots
  // ══════════════════════════════════════
  Widget _buildReleasesSlideshow() {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Latest'),
          const SizedBox(height: 10),
          _heading('Latest Releases'),
          const SizedBox(height: 8),
          _para('Fresh music distributed through 444Music. Every day, new artists go global.'),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Container(
                  width: 260,
                  decoration: BoxDecoration(
                    color: _surface, border: Border.all(color: _border2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: _releasesLoading
                            ? Container(color: _surface2,
                                child: const Center(child: CircularProgressIndicator(
                                    color: _white, strokeWidth: 2)))
                            : _releases.isEmpty
                                ? Container(color: _surface2,
                                    child: const Center(child: Icon(Icons.album, color: _text2, size: 36)))
                                : AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 400),
                                    child: Image.network(
                                      _releases[_releaseIndex]['cover'],
                                      key: ValueKey(_releaseIndex),
                                      fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                                      errorBuilder: (_, __, ___) => Container(color: _surface2),
                                    ),
                                  ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _releases.isEmpty ? (_releasesLoading ? 'Loading...' : 'No releases yet')
                                  : _releases[_releaseIndex]['title'],
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _white, fontSize: 14.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _releases.isEmpty ? (_releasesLoading ? 'Artist' : 'Be the first to upload')
                                  : _releases[_releaseIndex]['artist'],
                              style: const TextStyle(color: _text2, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_releases.length > 1) ...[
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_releases.length, (i) {
                      final active = i == _releaseIndex;
                      return GestureDetector(
                        onTap: () => setState(() => _releaseIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 20 : 6, height: 6,
                          decoration: BoxDecoration(
                            color: active ? _white : _border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  FAQ (light)
  // ══════════════════════════════════════
  Widget _buildFaqLight() {
    final filters = const [
      ('all', 'All'), ('distribution', 'Distribution'), ('payments', 'Payments'),
      ('account', 'Account'), ('referrals', 'Referrals'),
    ];
    final visible = _faqFilter == 'all'
        ? _faqItems
        : _faqItems.where((f) => f.cat == _faqFilter).toList();

    return Container(
      color: _lightBg,
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
      child: Column(
        children: [
          _label('FAQ', light: true, centered: true),
          const SizedBox(height: 10),
          _heading('Frequently Asked Questions', light: true, align: TextAlign.center),
          const SizedBox(height: 8),
          _para('Everything you need to know about releasing music with 444Music.',
              light: true, align: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: filters.map((f) {
                final active = _faqFilter == f.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() { _faqFilter = f.$1; _faqOpenIndex = null; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF0A0A0A) : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: active ? const Color(0xFF0A0A0A) : _lightBorder),
                      ),
                      child: Text(f.$2, style: TextStyle(
                          color: active ? Colors.white : const Color(0xFF555555),
                          fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          Column(
            children: List.generate(visible.length, (i) {
              final item = visible[i];
              final open = _faqOpenIndex == i;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: _lightSurf2,
                  border: Border.all(color: open ? Colors.black.withOpacity(0.3) : _lightBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _faqOpenIndex = open ? null : i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(item.q, style: const TextStyle(
                                  color: _lightText, fontSize: 14, fontWeight: FontWeight.w500)),
                            ),
                            const SizedBox(width: 10),
                            AnimatedRotation(
                              turns: open ? 0.125 : 0,
                              duration: const Duration(milliseconds: 250),
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: open ? const Color(0xFF0A0A0A) : const Color(0xFFECECEC),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(Icons.add, size: 15,
                                    color: open ? Colors.white : const Color(0xFF444444)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                      firstChild: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(item.a, style: const TextStyle(
                              color: Color(0xFF4A4A4A), fontSize: 13, height: 1.6)),
                        ),
                      ),
                      secondChild: const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  CTA
  // ══════════════════════════════════════
  Widget _buildCTA() {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _surface, border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const Text('Ready to go global?', textAlign: TextAlign.center,
                style: TextStyle(color: _white, fontFamily: 'Outfit', fontSize: 26,
                    fontWeight: FontWeight.w900, letterSpacing: -0.8)),
            const SizedBox(height: 4),
            const Text('Start distributing today.', textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFCCCCCC), fontFamily: 'Outfit', fontSize: 26,
                    fontWeight: FontWeight.w900, letterSpacing: -0.8)),
            const SizedBox(height: 12),
            const Text('Join 7,000+ independent artists who trust 444Music to reach their fans worldwide.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _text2, fontSize: 13.5, height: 1.6)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _goToRegister,
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.north_east, color: Colors.black, size: 16),
                    SizedBox(width: 8),
                    Text('Create Free Account', style: TextStyle(color: Colors.black, fontSize: 14.5,
                        fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _goToLogin,
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_forward, color: _white, size: 16),
                    SizedBox(width: 8),
                    Text('Sign In', style: TextStyle(color: _white, fontSize: 14.5, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  FOOTER
  // ══════════════════════════════════════
  Widget _buildFooter() {
    final companyLinks = <(String, String?)>[
      ('About', 'https://444music-distribution.vercel.app/about.html'),
      ('Pricing', 'https://444music-distribution.vercel.app/login.html'),
      ('Contact', 'https://444music-distribution.vercel.app/support.html'),
      ('FAQ', 'https://444music-distribution.vercel.app/faq.html'),
      ('Developer', 'https://ofbluhface.vercel.app/'),
    ];
    final legalLinks = <(String, String?)>[
      ('Terms of Service', 'https://444music-distribution.vercel.app/legal.html'),
      ('Privacy Policy', 'https://444music-distribution.vercel.app/legal.html'),
      ('Cookie Policy', 'https://444music-distribution.vercel.app/legal.html'),
    ];
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(_logoWhite, height: 26,
              errorBuilder: (_, __, ___) => const Text('444Music',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit',
                      fontWeight: FontWeight.w900))),
          const SizedBox(height: 12),
          const Text(
            'Global music distribution platform for independent artists. Upload once — distribute everywhere.',
            style: TextStyle(color: _text2, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _socialIcon(Icons.camera_alt_outlined, 'https://www.instagram.com/444music_distribution?igsh=cDdhbTJzYXdkd2lp'),
              const SizedBox(width: 8),
              _socialIcon(Icons.alternate_email, null),
              const SizedBox(width: 8),
              _socialIcon(Icons.facebook_outlined, 'https://www.facebook.com/share/g/1BogQQDH5P/'),
              const SizedBox(width: 8),
              _socialIcon(Icons.video_collection_outlined, 'https://www.tiktok.com/@444musicdistribution?_r=1&_t=ZS-957m4qSvgj2'),
            ],
          ),
          const SizedBox(height: 32),
          _footerCol('Company', companyLinks),
          const SizedBox(height: 24),
          _footerCol('Legal', legalLinks),
          const SizedBox(height: 24),
          _footerColActions('Artists', [
            ('Create Account', _goToRegister),
            ('Login', _goToLogin),
            ('Dashboard', _goToLogin),
            ('Analytics', _goToLogin),
          ]),
          const SizedBox(height: 28),
          const Divider(color: _border2),
          const SizedBox(height: 16),
          const Text('© 2026 444Music Distribution. All rights reserved.',
              style: TextStyle(color: _text3, fontSize: 11.5)),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.shield_outlined, size: 13, color: _text2),
              SizedBox(width: 6),
              Text('Secured & Independent', style: TextStyle(color: _text2, fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _socialIcon(IconData icon, String? url) {
    return GestureDetector(
      onTap: url != null ? () => _launch(url) : null,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _surface2, border: Border.all(color: _border2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: _text2),
      ),
    );
  }

  Widget _footerCol(String title, List<(String, String?)> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: _white, fontFamily: 'Outfit', fontSize: 14,
            fontWeight: FontWeight.w700, letterSpacing: -0.2)),
        const SizedBox(height: 14),
        ...links.map((l) => Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: GestureDetector(
            onTap: l.$2 != null ? () => _launch(l.$2!) : null,
            child: Text(l.$1, style: const TextStyle(color: _text2, fontSize: 13.5)),
          ),
        )),
      ],
    );
  }

  Widget _footerColActions(String title, List<(String, VoidCallback)> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: _white, fontFamily: 'Outfit', fontSize: 14,
            fontWeight: FontWeight.w700, letterSpacing: -0.2)),
        const SizedBox(height: 14),
        ...links.map((l) => Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: GestureDetector(
            onTap: l.$2,
            child: Text(l.$1, style: const TextStyle(color: _text2, fontSize: 13.5)),
          ),
        )),
      ],
    );
  }

  // ══════════════════════════════════════
  //  SHARED TEXT HELPERS
  // ══════════════════════════════════════
  Widget _label(String text, {bool light = false, bool centered = false}) {
    final color = light ? _lightText3 : _text2;
    if (centered) {
      return Text(text.toUpperCase(), textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.8));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 18, height: 1.5, color: color),
        const SizedBox(width: 8),
        Text(text.toUpperCase(),
            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      ],
    );
  }

  Widget _heading(String text, {bool light = false, TextAlign align = TextAlign.left}) {
    return Text(text, textAlign: align,
        style: TextStyle(
          color: light ? _lightText : _white,
          fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.w800,
          letterSpacing: -0.8, height: 1.15,
        ));
  }

  Widget _para(String text, {bool light = false, TextAlign align = TextAlign.left}) {
    return Text(text, textAlign: align,
        style: TextStyle(color: light ? _lightText2 : _text2, fontSize: 13.5, height: 1.65));
  }
}