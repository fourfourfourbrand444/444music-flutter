import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────
//  PALETTE
// ─────────────────────────────────────────────────────────────
const _bg            = Color(0xFF080808);
const _surface       = Color(0xFF111111);
const _card          = Color(0xFF1A1A1A);
const _border        = Color(0xFF2A2A2A);
const _borderChecked = Color(0xFF585858);
const _textPrimary   = Color(0xFFF5F5F5);
const _textSecondary = Color(0xFF9A9A9A);
const _textMuted     = Color(0xFF555555);
const _white         = Colors.white;

// ─────────────────────────────────────────────────────────────
//  CONFIRM SCREEN
// ─────────────────────────────────────────────────────────────
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key});

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen>
    with TickerProviderStateMixin {
  final List<bool> _checked = [false, false, false];

  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late List<AnimationController> _itemCtrl;
  late List<Animation<double>> _itemFades;
  late List<Animation<Offset>> _itemSlides;

  int  get _checkedCount => _checked.where((v) => v).length;
  bool get _allChecked   => _checkedCount == 3;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();

    _itemCtrl = List.generate(
      3,
          (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 450)),
    );
    _itemFades = _itemCtrl
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();
    _itemSlides = _itemCtrl
        .map((c) => Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)))
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: 200 + i * 100), () {
        if (mounted) _itemCtrl[i].forward();
      });
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    for (final c in _itemCtrl) c.dispose();
    super.dispose();
  }

  void _toggle(int index) {
    HapticFeedback.selectionClick();
    setState(() => _checked[index] = !_checked[index]);
  }

  void _confirm() {
    if (!_allChecked) return;
    HapticFeedback.mediumImpact();
    // Navigate to saving screen — replace so back goes to home
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const SavingReleaseScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 28),
                      _buildTitleBlock(),
                      const SizedBox(height: 24),
                      _buildDivider(),
                      const SizedBox(height: 20),
                      _buildProgress(),
                      const SizedBox(height: 16),
                      _buildTermsList(),
                      const SizedBox(height: 14),
                      _buildNotice(),
                      const Spacer(),
                      const SizedBox(height: 16),
                      _buildButtons(),
                      const SizedBox(height: 8),
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Image.network(
          'https://444music-distribution.vercel.app/black.png',
          height: 32,
          color: Colors.white,
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (_, __, ___) => const Text(
            '444Music',
            style: TextStyle(
              color: _white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.close_rounded, color: _textSecondary, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleBlock() {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
          .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.shield_outlined, color: _white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirmation Required',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Read and confirm all terms below before distributing your release.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, _border, Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final pct = _checkedCount / 3;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'AGREEMENT PROGRESS',
              style: TextStyle(
                color: _textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              '$_checkedCount of 3',
              style: const TextStyle(
                color: _white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (_, val, __) => LinearProgressIndicator(
              value: val,
              minHeight: 3,
              backgroundColor: _surface,
              valueColor: const AlwaysStoppedAnimation<Color>(_white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsList() {
    final items = [
      _TermData(
        icon: Icons.description_outlined,
        title: 'Copyright Ownership',
        body: 'I own or have legally licensed all copyrights to the sound recordings, compositions and artwork embodied in this release and agree to all terms in the distribution agreement.',
      ),
      _TermData(
        icon: Icons.tune_rounded,
        title: 'Track Accuracy',
        body: 'I confirm that I have truthfully indicated the Track Origin and Track Properties for each track to ensure full compliance with DSP requirements.',
      ),
      _TermData(
        icon: Icons.warning_amber_rounded,
        title: 'Streaming Integrity',
        body: 'I acknowledge that artificial streaming and misleading promotion violates platform policies and may result in content removal, withheld royalties, or account penalties.',
      ),
    ];

    return Column(
      children: List.generate(items.length, (i) {
        return Padding(
          padding: EdgeInsets.only(bottom: i < 2 ? 10 : 0),
          child: FadeTransition(
            opacity: _itemFades[i],
            child: SlideTransition(
              position: _itemSlides[i],
              child: _TermTile(
                data: items[i],
                checked: _checked[i],
                onTap: () => _toggle(i),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: _textMuted, size: 14),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'This agreement is legally binding once confirmed. Review all terms carefully.',
              style: TextStyle(
                color: _textMuted,
                fontSize: 11.5,
                height: 1.5,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: _OutlineButton(
            label: 'Cancel',
            icon: Icons.close_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _ConfirmButton(
            enabled: _allChecked,
            onTap: _confirm,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SAVING RELEASE SCREEN
// ─────────────────────────────────────────────────────────────
class SavingReleaseScreen extends StatefulWidget {
  const SavingReleaseScreen({super.key});

  @override
  State<SavingReleaseScreen> createState() => _SavingReleaseScreenState();
}

class _SavingReleaseScreenState extends State<SavingReleaseScreen>
    with TickerProviderStateMixin {

  // 4 steps
  final List<String> _stepLabels = [
    'Uploading release files',
    'Checking metadata',
    'Preparing distribution',
    'Finalising submission',
  ];
  final List<IconData> _stepIcons = [
    Icons.cloud_upload_outlined,
    Icons.shield_outlined,
    Icons.public_outlined,
    Icons.rocket_launch_outlined,
  ];

  int _activeStep = 0; // 0-3 active, 4 = all done

  // Ring animation
  late AnimationController _ringCtrl;
  late Animation<double>    _ringProgress;

  // Progress bar
  late AnimationController _barCtrl;
  late Animation<double>    _barProgress;

  // Fade-in controller
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3800));
    _ringProgress = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeInOut);
    _ringCtrl.forward();

    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3800));
    _barProgress = CurvedAnimation(parent: _barCtrl, curve: Curves.easeInOut);
    _barCtrl.forward();

    _runSteps();
  }

  Future<void> _runSteps() async {
    for (int i = 0; i < 4; i++) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _activeStep = i + 1);
    }
    // Small pause then navigate to success
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const ReleaseSuccessScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _barCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.network(
                    'https://444music-distribution.vercel.app/black.png',
                    height: 28,
                    color: Colors.white,
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (_, __, ___) => const Text(
                      '444MUSIC',
                      style: TextStyle(
                        color: _white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 44),

                  // Animated ring
                  _buildRing(),
                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    'Saving Your Release',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Please wait while we process your submission',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Steps
                  _buildSteps(),
                  const SizedBox(height: 28),

                  // Progress bar
                  _buildProgressBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRing() {
    return SizedBox(
      width: 90, height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ringProgress,
            builder: (_, __) => CustomPaint(
              size: const Size(90, 90),
              painter: _RingPainter(progress: _ringProgress.value),
            ),
          ),
          // Pulsing icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            onEnd: () => setState(() {}), // retrigger
            builder: (_, scale, __) => Transform.scale(
              scale: scale,
              child: const Icon(Icons.cloud_upload_outlined,
                  color: _white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: List.generate(_stepLabels.length, (i) {
          final isDone   = _activeStep > i + 1;
          final isActive = _activeStep == i + 1;
          return _StepRow(
            icon:     _stepIcons[i],
            label:    _stepLabels[i],
            isDone:   isDone,
            isActive: isActive,
            isLast:   i == _stepLabels.length - 1,
          );
        }),
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _barProgress,
      builder: (_, __) => Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: _barProgress.value,
              minHeight: 2,
              backgroundColor: _surface,
              valueColor: const AlwaysStoppedAnimation<Color>(_white),
            ),
          ),
        ],
      ),
    );
  }
}

// Ring painter
class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 4;

    // Background ring
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = const Color(0xFF222222)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -1.5708, // -π/2 (top)
      progress * 6.2832,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// Step row widget
class _StepRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     isDone;
  final bool     isActive;
  final bool     isLast;

  const _StepRow({
    required this.icon,
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF1E1E1E)
            : isDone
            ? const Color(0xFF151515)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(0),
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: Color(0xFF1E1E1E)),
        ),
      ),
      child: Row(
        children: [
          // Icon container
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF1A2A20)
                  : isActive
                  ? const Color(0xFF222222)
                  : const Color(0xFF161616),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDone
                    ? const Color(0xFF2A4A35)
                    : isActive
                    ? const Color(0xFF383838)
                    : const Color(0xFF202020),
              ),
            ),
            child: Icon(
              isDone ? Icons.check_rounded : icon,
              size: 15,
              color: isDone
                  ? const Color(0xFF4ADE80)
                  : isActive
                  ? _white
                  : _textMuted,
            ),
          ),
          const SizedBox(width: 12),

          // Label
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: isDone
                    ? const Color(0xFF4ADE80)
                    : isActive
                    ? _textPrimary
                    : _textMuted,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.1,
              ),
              child: Text(label),
            ),
          ),

          // Pulse dot when active
          if (isActive)
            _PulseDot()
          else if (isDone)
            const Icon(Icons.check_circle_outline_rounded,
                size: 14, color: Color(0xFF4ADE80)),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
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
        width: 7, height: 7,
        decoration: const BoxDecoration(
          color: _white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  RELEASE SUCCESS SCREEN
// ─────────────────────────────────────────────────────────────
class ReleaseSuccessScreen extends StatefulWidget {
  const ReleaseSuccessScreen({super.key});

  @override
  State<ReleaseSuccessScreen> createState() => _ReleaseSuccessScreenState();
}

class _ReleaseSuccessScreenState extends State<ReleaseSuccessScreen>
    with TickerProviderStateMixin {

  late AnimationController _fadeCtrl;
  late AnimationController _checkCtrl;
  late AnimationController _contentCtrl;

  late Animation<double> _checkScale;
  late Animation<double> _checkFade;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();

    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _checkScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut));
    _checkFade  = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeOut);

    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _contentFade  = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    _contentSlide = Tween<Offset>(
        begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
        CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));

    // Stagger check → content
    _checkCtrl.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _checkCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _goToDashboard() {
    HapticFeedback.mediumImpact();
    // Push named route to dashboard and clear stack
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/dashboard',
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Check circle
                  FadeTransition(
                    opacity: _checkFade,
                    child: ScaleTransition(
                      scale: _checkScale,
                      child: Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(
                          color: _white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.15),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.black,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Content
                  FadeTransition(
                    opacity: _contentFade,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: Column(
                        children: [
                          const Text(
                            'Release Submitted',
                            style: TextStyle(
                              color: _white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your release has been confirmed and is being distributed to all platforms.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 14,
                              height: 1.65,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Status pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1F18),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                  color: const Color(0xFF1A3A28)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle,
                                    color: Color(0xFF4ADE80), size: 7),
                                SizedBox(width: 7),
                                Text(
                                  'Under Review',
                                  style: TextStyle(
                                    color: Color(0xFF4ADE80),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Go to Dashboard button
                          GestureDetector(
                            onTap: _goToDashboard,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: _white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.1),
                                    blurRadius: 24,
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.dashboard_outlined,
                                      color: Colors.black, size: 17),
                                  SizedBox(width: 9),
                                  Text(
                                    'Go to Dashboard',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Secondary: view releases
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/releases',
                                    (route) => false,
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _border),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.library_music_outlined,
                                      color: _textSecondary, size: 17),
                                  SizedBox(width: 9),
                                  Text(
                                    'View My Releases',
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

// ─────────────────────────────────────────────────────────────
//  TERM TILE
// ─────────────────────────────────────────────────────────────
class _TermData {
  final IconData icon;
  final String title;
  final String body;
  const _TermData({required this.icon, required this.title, required this.body});
}

class _TermTile extends StatefulWidget {
  final _TermData data;
  final bool checked;
  final VoidCallback onTap;

  const _TermTile({
    required this.data,
    required this.checked,
    required this.onTap,
  });

  @override
  State<_TermTile> createState() => _TermTileState();
}

class _TermTileState extends State<_TermTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkAnim;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _checkScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _checkAnim, curve: Curves.elasticOut));
    if (widget.checked) _checkAnim.value = 1.0;
  }

  @override
  void didUpdateWidget(_TermTile old) {
    super.didUpdateWidget(old);
    if (widget.checked && !old.checked)       _checkAnim.forward(from: 0);
    else if (!widget.checked && old.checked)  _checkAnim.reverse();
  }

  @override
  void dispose() {
    _checkAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.checked ? const Color(0xFF1F1F1F) : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.checked ? _borderChecked : _border,
            width: widget.checked ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: widget.checked ? _white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.checked ? _white : const Color(0xFF484848),
                  width: 1.5,
                ),
              ),
              child: widget.checked
                  ? ScaleTransition(
                scale: _checkScale,
                child: const Icon(Icons.check_rounded,
                    color: Colors.black, size: 14),
              )
                  : null,
            ),
            const SizedBox(width: 12),

            // Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: widget.checked
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFF242424),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.checked
                      ? Colors.white.withOpacity(0.2)
                      : const Color(0xFF303030),
                ),
              ),
              child: Icon(
                widget.data.icon,
                color: widget.checked ? _white : const Color(0xFF808080),
                size: 16,
              ),
            ),
            const SizedBox(width: 11),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: widget.checked ? _white : _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                    child: Text(widget.data.title),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '', // placeholder; body set below
                    style: TextStyle(fontSize: 0),
                  ),
                  Text(
                    widget.data.body,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.6,
                      letterSpacing: 0.1,
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

// ─────────────────────────────────────────────────────────────
//  OUTLINE BUTTON
// ─────────────────────────────────────────────────────────────
class _OutlineButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_OutlineButton> createState() => _OutlineButtonState();
}

class _OutlineButtonState extends State<_OutlineButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
        lowerBound: 0.95,
        upperBound: 1.0,
        value: 1.0);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:  (_) => _press.reverse(),
      onTapUp:    (_) { _press.forward(); widget.onTap(); },
      onTapCancel: () => _press.forward(),
      child: ScaleTransition(
        scale: _press,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: _textSecondary, size: 16),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CONFIRM BUTTON
// ─────────────────────────────────────────────────────────────
class _ConfirmButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ConfirmButton({required this.enabled, required this.onTap});

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 90),
        lowerBound: 0.96,
        upperBound: 1.0,
        value: 1.0);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:  widget.enabled ? (_) => _press.reverse()     : null,
      onTapUp:    widget.enabled ? (_) { _press.forward(); widget.onTap(); } : null,
      onTapCancel: widget.enabled ? () => _press.forward()     : null,
      child: ScaleTransition(
        scale: _press,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 52,
          decoration: BoxDecoration(
            color: widget.enabled ? Colors.white : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.enabled ? Colors.white : _border,
            ),
            boxShadow: widget.enabled
                ? [
              BoxShadow(
                color: Colors.white.withOpacity(0.12),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_rounded,
                  color: widget.enabled ? Colors.black : _textMuted,
                  size: 18),
              const SizedBox(width: 8),
              Text(
                'Confirm & Distribute',
                style: TextStyle(
                  color: widget.enabled ? Colors.black : _textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}