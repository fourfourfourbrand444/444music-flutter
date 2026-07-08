import 'package:flutter/material.dart';

void main() {
  runApp(const RejectionApp());
}

class RejectionApp extends StatelessWidget {
  const RejectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '444Music — Release Rejected?',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF060606),
        fontFamily: 'monospace',
      ),
      home: const RejectionScreen(),
    );
  }
}

// ─── DATA ───────────────────────────────────────────────────────
class RejectionReason {
  final String number;
  final String icon;
  final String title;
  final String whatHappened;
  final String howToFix;
  final String fixTag;

  const RejectionReason({
    required this.number,
    required this.icon,
    required this.title,
    required this.whatHappened,
    required this.howToFix,
    required this.fixTag,
  });
}

const _reasons = [
  RejectionReason(
    number: '01',
    icon: '©',
    title: 'Copyright Infringement',
    whatHappened:
    'Your release contains beats, samples, or instrumentals that belong to another rights holder and were used without proper authorization. Digital stores have automated detection systems that flag this instantly.',
    howToFix:
    'Only upload content you have created, own, or have a valid license for. If using a purchased beat, ensure your license explicitly grants distribution rights.',
    fixTag: 'Use original, licensed, or royalty-free content only',
  ),
  RejectionReason(
    number: '02',
    icon: '✎',
    title: 'Metadata Errors',
    whatHappened:
    'Your release contains inconsistent or incorrect information — misspelled artist name, wrong song title, mismatched album name, or metadata that contradicts the audio file itself.',
    howToFix:
    'Review every field carefully. Your artist name, song title, and release title must be spelled identically across all platforms and match the submitted audio exactly.',
    fixTag: 'Double-check all metadata fields before resubmitting',
  ),
  RejectionReason(
    number: '03',
    icon: '♪',
    title: 'Low Audio Quality',
    whatHappened:
    'The uploaded audio file does not meet the technical standards required by digital stores. This includes excessive background noise, distortion, clipping, poor mastering, or an unsupported file format.',
    howToFix:
    'Ensure your tracks are professionally mixed and mastered. Export as a WAV file at minimum 16-bit / 44.1kHz. Avoid over-compression and ensure there is no clipping in your master.',
    fixTag: 'Upload WAV files — 16-bit / 44.1kHz minimum',
  ),
  RejectionReason(
    number: '04',
    icon: '⟳',
    title: 'Duplicate or Previously Released Content',
    whatHappened:
    'This song has already been distributed to stores — either through another distributor, a different account, or a previous submission. Stores do not allow the same content to appear twice.',
    howToFix:
    'If you previously released this through another platform, request a full takedown first before resubmitting through 444Music. Only submit fresh, unreleased material.',
    fixTag: 'Remove existing release first, then resubmit',
  ),
  RejectionReason(
    number: '05',
    icon: '⚠',
    title: 'Misleading or Fraudulent Content',
    whatHappened:
    'Your release was flagged for using a fake artist name, impersonating an established artist, or containing misleading titles designed to trick listeners or search algorithms.',
    howToFix:
    'Always use your real artist name or registered stage name. Never mimic another artist\'s branding. Titles must accurately reflect the content of the release.',
    fixTag: 'Use accurate, truthful artist names and titles',
  ),
  RejectionReason(
    number: '06',
    icon: '▣',
    title: 'Artwork Does Not Meet Standards',
    whatHappened:
    'Your cover artwork was rejected for being blurry, containing copyrighted images, including social media handles or URLs, or not meeting the required square dimensions.',
    howToFix:
    'Create high-quality original artwork. It must be a perfect square at 3000×3000 pixels minimum, in JPG or PNG format, with no third-party logos or social media links.',
    fixTag: 'Minimum 3000×3000px, original artwork only',
  ),
  RejectionReason(
    number: '07',
    icon: '⊘',
    title: 'Explicit Content Mislabeling',
    whatHappened:
    'Your release contains explicit language or mature themes but was submitted without the correct explicit content label. Incorrect labeling also affects store editorial placement.',
    howToFix:
    'Listen through your entire track before submitting. If it contains any profanity, sexual language, or mature themes — select "Yes" for explicit content in your submission.',
    fixTag: 'Label explicit content correctly on every track',
  ),
];

// ─── MAIN PAGE ───────────────────────────────────────────────────
class RejectionScreen extends StatelessWidget {
  const RejectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060606),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TopBar(),
                    const SizedBox(height: 48),
                    const _HeroSection(),
                    const SizedBox(height: 32),
                    const _NoticeBox(),
                    const SizedBox(height: 44),
                    const _SectionHeader(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _RejectionCard(reason: _reasons[i], index: i),
                  ),
                  childCount: _reasons.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                child: const _BottomMessage(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 48),
                child: const _Footer(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TOP BAR ─────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Brand
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      '444',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '444MUSIC',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            // Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2a2a2a)),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'HELP CENTER',
                style: TextStyle(
                  color: Color(0xFF444444),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(color: Color(0xFF1e1e1e), height: 1),
      ],
    );
  }
}

// ─── HERO ─────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow
        Row(
          children: [
            Container(width: 24, height: 1, color: Colors.white),
            const SizedBox(width: 10),
            const Text(
              'RELEASE STATUS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Title
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 58,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              height: 0.92,
            ),
            children: [
              TextSpan(
                text: 'WHY WAS MY\nRELEASE ',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'REJECTED?',
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF555555),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'We understand how frustrating this can be. The good news — most rejections follow clear store guidelines and can be fixed quickly. We\'re here to walk you through exactly what to do.',
          style: TextStyle(
            color: Color(0xFF6b6b7e),
            fontSize: 14,
            fontWeight: FontWeight.w300,
            height: 1.8,
          ),
        ),
        const SizedBox(height: 32),
        const Divider(color: Color(0xFF1e1e1e), height: 1),
      ],
    );
  }
}

// ─── NOTICE BOX ───────────────────────────────────────────────────
class _NoticeBox extends StatelessWidget {
  const _NoticeBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0a0a0a),
        border: Border(
          top: BorderSide(color: const Color(0xFF1e1e1e)),
          right: BorderSide(color: const Color(0xFF1e1e1e)),
          bottom: BorderSide(color: const Color(0xFF1e1e1e)),
          left: BorderSide(color: Colors.white, width: 2),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              border: Border.all(color: const Color(0xFF2a2a2a)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('ℹ', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'IMPORTANT NOTICE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '444Music does not randomly reject releases. All rejections are strictly based on content policies and technical guidelines enforced by stores like Spotify, Apple Music, Boomplay, and others. We are simply the messenger — and we\'re here to help.',
                  style: TextStyle(
                    color: Color(0xFF6b6b7e),
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    height: 1.7,
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

// ─── SECTION HEADER ───────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COMMON REASONS',
          style: TextStyle(
            color: Color(0xFF3a3a4a),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'WHAT WENT WRONG',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// ─── REJECTION CARD ───────────────────────────────────────────────
class _RejectionCard extends StatefulWidget {
  final RejectionReason reason;
  final int index;

  const _RejectionCard({required this.reason, required this.index});

  @override
  State<_RejectionCard> createState() => _RejectionCardState();
}

class _RejectionCardState extends State<_RejectionCard>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: _isOpen ? const Color(0xFF111111) : const Color(0xFF0d0d0d),
            border: Border.all(
              color: _isOpen ? const Color(0xFF3a3a3a) : const Color(0xFF1e1e1e),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              // Header
              GestureDetector(
                onTap: _toggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Number
                      SizedBox(
                        width: 28,
                        child: Text(
                          widget.reason.number,
                          style: const TextStyle(
                            color: Color(0xFF3a3a4a),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Icon box
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _isOpen
                              ? const Color(0xFF1e1e1e)
                              : const Color(0xFF0a0a0a),
                          border: Border.all(
                            color: _isOpen
                                ? const Color(0xFF3a3a3a)
                                : const Color(0xFF1e1e1e),
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: Text(
                            widget.reason.icon,
                            style: TextStyle(
                              color: _isOpen ? Colors.white : const Color(0xFF555555),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Title
                      Expanded(
                        child: Text(
                          widget.reason.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Chevron
                      RotationTransition(
                        turns: _rotateAnimation,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _isOpen
                                ? const Color(0xFF1e1e1e)
                                : Colors.transparent,
                            border: Border.all(
                              color: _isOpen
                                  ? const Color(0xFF3a3a3a)
                                  : const Color(0xFF1e1e1e),
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: _isOpen
                                ? Colors.white
                                : const Color(0xFF444444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Body (expandable)
              SizeTransition(
                sizeFactor: _expandAnimation,
                axisAlignment: -1,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      const Divider(height: 1, color: Color(0xFF1e1e1e)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(80, 20, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // What happened
                            _ContentBlock(
                              label: 'WHAT HAPPENED',
                              labelColor: const Color(0xFF3a3a4a),
                              text: widget.reason.whatHappened,
                            ),
                            const SizedBox(height: 18),
                            // How to fix
                            _ContentBlock(
                              label: 'HOW TO FIX IT',
                              labelColor: const Color(0xFFaaaaaa),
                              text: widget.reason.howToFix,
                            ),
                            const SizedBox(height: 12),
                            // Fix tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141414),
                                border: Border.all(color: const Color(0xFF2e2e2e)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Color(0xFFaaaaaa),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      widget.reason.fixTag,
                                      style: const TextStyle(
                                        color: Color(0xFFaaaaaa),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── CONTENT BLOCK ────────────────────────────────────────────────
class _ContentBlock extends StatelessWidget {
  final String label;
  final Color labelColor;
  final String text;

  const _ContentBlock({
    required this.label,
    required this.labelColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 16, height: 1, color: labelColor),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF6b6b7e),
            fontSize: 13,
            fontWeight: FontWeight.w300,
            height: 1.75,
          ),
        ),
      ],
    );
  }
}

// ─── BOTTOM MESSAGE ───────────────────────────────────────────────
class _BottomMessage extends StatelessWidget {
  const _BottomMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0d0d0d),
        border: Border(
          top: const BorderSide(color: Colors.white, width: 2),
          left: BorderSide(color: const Color(0xFF1e1e1e)),
          right: BorderSide(color: const Color(0xFF1e1e1e)),
          bottom: BorderSide(color: const Color(0xFF1e1e1e)),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Text(
            "If your release falls under any of the reasons above, don't worry — simply correct the issue and resubmit your release. Our team reviews every submission carefully and we're always here to help you get your music live.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6b6b7e),
              fontSize: 14,
              fontWeight: FontWeight.w300,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 28),
          // Buttons
          Column(
            children: [
              _ActionButton(
                label: 'Fix & Resubmit',
                icon: Icons.arrow_forward_rounded,
                isPrimary: true,
                onTap: () {},
              ),
              const SizedBox(height: 10),
              _ActionButton(
                label: 'Contact Support',
                icon: Icons.email_outlined,
                isPrimary: false,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── ACTION BUTTON ────────────────────────────────────────────────
class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: widget.isPrimary ? Colors.white : Colors.transparent,
            border: Border.all(
              color: widget.isPrimary ? Colors.white : const Color(0xFF2a2a2a),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 15,
                color: widget.isPrimary ? Colors.black : const Color(0xFF6b6b7e),
              ),
              const SizedBox(width: 9),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isPrimary ? Colors.black : const Color(0xFF6b6b7e),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── FOOTER ───────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: Color(0xFF1e1e1e), height: 1),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 11, color: Color(0xFF3a3a4a)),
                children: [
                  TextSpan(text: '© 2026 '),
                  TextSpan(
                    text: '444Music Distribution',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const Text(
              '444musicdistro@gmail.com',
              style: TextStyle(
                color: Color(0xFF3a3a4a),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}