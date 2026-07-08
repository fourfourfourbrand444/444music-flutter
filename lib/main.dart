import 'home_screen.dart';
import 'login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:math';
import 'withdrawal_screen.dart';
import 'upload_screen.dart';
import 'agreement_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'Landing.dart';
import 'rejection_screen.dart';
import 'dashboard.dart';
import 'profile_screen.dart';
import 'earnings_screen.dart';
import 'analytics_screen.dart';
import 'tools_screen.dart';
import 'pricing_screen.dart';
import 'package:app_links/app_links.dart';
import 'payment_success_screen.dart';
import 'release_info_screen.dart';
import 'select_screen.dart';
import 'legal_screen.dart';
import 'confirm_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey:            'AIzaSyBzUD7avh7vJfeSMRl2o9F09_qd-pl0dSg',
      authDomain:        'usersubmissionsportal.firebaseapp.com',
      projectId:         'usersubmissionsportal',
      storageBucket:     'usersubmissionsportal.firebasestorage.app',
      messagingSenderId: '734783502459',
      appId:             '1:734783502459:web:cfa2cc5de6976003b24ade',
    ),
  );

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const _channel = MethodChannel('com.example.music/deeplink');

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'paymentSuccess') {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/payment-success',
              (route) => false,
        );
      }
    });

    AppLinks().uriLinkStream.listen((uri) {
      final uriStr = uri.toString();
      if (uri.scheme == '444music' || uriStr.contains('payment-success')) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/payment-success',
              (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '444Music',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'SF Pro Display',
      ),
      home: const SplashScreen(),
      routes: {
        '/home':            (_) => const HomeScreen(),
        '/loading':         (_) => const HomeScreen(),
        '/upload':          (_) => const PricingScreen(),
        '/analytics':       (_) => const AnalyticsScreen(),
        '/earnings':        (_) => const EarningsScreen(),
        '/profile':         (_) => const ProfileScreen(),
        '/dashboard':       (_) => const ReleasesScreen(),
        '/tools':           (_) => const ToolsScreen(),
        '/support':         (_) => const HomeScreen(),
        '/releases':        (_) => const ReleasesScreen(),
        '/pricing':         (_) => const PricingScreen(),
        '/notifications':   (_) => const HomeScreen(),
        '/payment-success': (_) => const PaymentSuccessScreen(),
        '/agreement':       (_) => const AgreementScreen(),
        '/upload-files':    (_) => const UploadScreen(),
        '/release-info':    (_) => const ReleaseInfoScreen(),
        '/select':          (_) => const SelectScreen(),
        '/confirm':         (_) => const ConfirmScreen(),
        '/rejection':       (_) => const RejectionScreen(),
        '/legal':           (_) => const LegalScreen(),
        '/withdrawal': (context) => WithdrawalScreen(),
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SPLASH SCREEN
// ════════════════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _wordFade;
  late Animation<double> _wordScale;
  late Animation<double> _lineWidth;
  late Animation<double> _tagFade;
  late Animation<Offset>  _tagSlide;

  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.00, 0.38, curve: Curves.easeOut)));
    _logoScale = Tween<double>(begin: 0.78, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.00, 0.38, curve: Curves.easeOutCubic)));

    _wordFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.16, 0.60, curve: Curves.easeOut)));
    _wordScale = Tween<double>(begin: 0.90, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.16, 0.60, curve: Curves.easeOutCubic)));

    _lineWidth = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.44, 0.77, curve: Curves.easeOut)));

    _tagFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.66, 1.00, curve: Curves.easeOut)));
    _tagSlide = Tween<Offset>(
      begin: const Offset(0, 0.25), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl,
        curve: const Interval(0.66, 1.00, curve: Curves.easeOutCubic)));

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const WelcomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _SplashBgPainter())),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A0A),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '444',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                FadeTransition(
                  opacity: _wordFade,
                  child: ScaleTransition(
                    scale: _wordScale,
                    child: const Text(
                      '444Music',
                      style: TextStyle(
                        color: Color(0xFF0A0A0A),
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                        height: 1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                AnimatedBuilder(
                  animation: _lineWidth,
                  builder: (_, __) => Align(
                    child: FractionallySizedBox(
                      widthFactor: _lineWidth.value * 0.28,
                      child: Container(
                        height: 1.5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: const Color(0xFF0A0A0A),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                SlideTransition(
                  position: _tagSlide,
                  child: FadeTransition(
                    opacity: _tagFade,
                    child: const Text(
                      'Distribute. Earn. Grow.',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 56),

                AnimatedBuilder(
                  animation: _dotCtrl,
                  builder: (_, __) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final t = ((_dotCtrl.value - i * 0.25) % 1.0);
                      final scale   = 0.55 + 0.45 * sin(t * pi).clamp(0.0, 1.0);
                      final opacity = (0.2  + 0.8  * sin(t * pi)).clamp(0.2, 1.0);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Transform.scale(
                          scale: scale,
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0A0A0A),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
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

class _SplashBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x06000000);
    final rnd = Random(42);
    for (int i = 0; i < 1800; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * 1.2,
        paint,
      );
    }
  }
  @override
  bool shouldRepaint(_SplashBgPainter _) => false;
}

// ════════════════════════════════════════════════════════════════════
//  WELCOME SCREEN
// ════════════════════════════════════════════════════════════════════
class _Slide {
  final String imageUrl, headline, body;
  const _Slide(this.imageUrl, this.headline, this.body);
}

// Source list — order here doesn't matter, it's shuffled every launch
const _slideSource = [
  _Slide(
    'https://images.pexels.com/photos/9008843/pexels-photo-9008843.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
    'Release to the world',
    'Get your music on Spotify, Apple Music, YouTube and 100+ more platforms in days.',
  ),
  _Slide(
    'https://images.pexels.com/photos/17413080/pexels-photo-17413080.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
    'Keep every dollar',
    'No hidden fees. 100% of your royalties go straight to you, every time.',
  ),
  _Slide(
    'https://images.pexels.com/photos/5135100/pexels-photo-5135100.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
    'Track your growth',
    'Real-time streams, earnings and audience data — all in one clean dashboard.',
  ),
  _Slide(
    'https://images.pexels.com/photos/12448173/pexels-photo-12448173.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
    'Built for artists',
    'From bedroom producers to signed acts — 444Music scales with your career.',
  ),
];

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  // ── Shuffled on every launch — no fixed seed ──────────────────────
  late final List<_Slide> _slides;

  int _current = 0;
  bool _isTransitioning = false;

  late AnimationController _imgCtrl;
  late Animation<double> _imgFade;
  late AnimationController _txtCtrl;
  late Animation<double> _txtFade;
  late Animation<Offset> _txtSlide;
  late AnimationController _sheetCtrl;
  late Animation<Offset> _sheetSlide;
  late AnimationController _autoCtrl;

  @override
  void initState() {
    super.initState();

    // Shuffle the slide order fresh on every app launch
    _slides = List.of(_slideSource)..shuffle(Random());

    _imgCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _imgFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _imgCtrl, curve: Curves.easeInOut));

    _txtCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _txtFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _txtCtrl, curve: Curves.easeOut));
    _txtSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _txtCtrl, curve: Curves.easeOutCubic));

    _sheetCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _sheetSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOutCubic));

    _autoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3800))
      ..addStatusListener((s) { if (s == AnimationStatus.completed && mounted) _advance(); });

    _imgCtrl.value = 1;
    _txtCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () { if (mounted) _sheetCtrl.forward(); });
    Future.delayed(const Duration(milliseconds: 600), () { if (mounted) _autoCtrl.forward(); });
  }

  void _advance() {
    if (_isTransitioning) return;
    _goTo((_current + 1) % _slides.length);
  }

  void _goTo(int index) async {
    if (_isTransitioning || index == _current) return;
    _isTransitioning = true;
    _autoCtrl.reset();
    await _txtCtrl.reverse();
    _imgCtrl.reset();
    setState(() => _current = index);
    await _imgCtrl.forward();
    await _txtCtrl.forward();
    _isTransitioning = false;
    _autoCtrl.forward();
  }

  @override
  void dispose() {
    _imgCtrl.dispose();
    _txtCtrl.dispose();
    _sheetCtrl.dispose();
    _autoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_current];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.62,
            child: AnimatedBuilder(
              animation: _imgFade,
              builder: (_, __) => Opacity(
                opacity: _imgFade.value,
                child: Image.network(
                  slide.imageUrl, fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(color: const Color(0xFF1a1a1a));
                  },
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1a1a1a)),
                ),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.44, left: 0, right: 0,
            height: size.height * 0.22,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xFF0A0A0A)],
                ),
              ),
            ),
          ),
          SlideTransition(
            position: _sheetSlide,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SlideTransition(
                          position: _txtSlide,
                          child: FadeTransition(
                            opacity: _txtFade,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(slide.headline,
                                  style: const TextStyle(
                                    color: Colors.white, fontSize: 26,
                                    fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(slide.body,
                                  style: const TextStyle(
                                    color: Color(0xFF888888), fontSize: 14,
                                    fontWeight: FontWeight.w400, height: 1.55, letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: List.generate(_slides.length, (i) {
                            final active = i == _current;
                            return GestureDetector(
                              onTap: () => _goTo(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                width: active ? 22 : 6, height: 6,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: active ? Colors.white : const Color(0xFF444444),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity, height: 54,
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(context, PageRouteBuilder(
                              pageBuilder: (_, __, ___) => const LandingScreen(),
                              transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                              transitionDuration: const Duration(milliseconds: 400),
                            )),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white, foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Get Started',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity, height: 54,
                          child: TextButton(
                            onPressed: () => Navigator.push(context, PageRouteBuilder(
                              pageBuilder: (_, __, ___) => const LandingScreen(),
                              transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                              transitionDuration: const Duration(milliseconds: 400),
                            )),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF888888),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('I already have an account',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: -0.1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}