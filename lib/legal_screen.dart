//  444MUSIC — Legal / About Screen
//  File:   lib/screens/legal_screen.dart
//  Route:  '/legal'
//  Add to main.dart routes:
//    '/legal': (context) => const LegalScreen(),
// ═══════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── PALETTE (matches home_screen.dart exactly) ─────────────────────
const _black      = Color(0xFF000000);
const _black1     = Color(0xFF0A0A0A);
const _black2     = Color(0xFF111111);
const _black3     = Color(0xFF1A1A1A);
const _white      = Color(0xFFFFFFFF);
const _white70    = Color(0xB3FFFFFF);
const _white40    = Color(0x66FFFFFF);
const _white20    = Color(0x33FFFFFF);
const _white10    = Color(0x1AFFFFFF);
const _white06    = Color(0x0FFFFFFF);
const _grey       = Color(0xFF888888);
const _greyDark   = Color(0xFF444444);
const _greyLight  = Color(0xFFAAAAAA);
const _green      = Color(0xFF22C55E);
const _greenDim   = Color(0x1A22C55E);
const _greenBorder= Color(0x4022C55E);
const _red        = Color(0xFFF87171);
const _redDim     = Color(0x1AF87171);

// ─── TAB MODEL ──────────────────────────────────────────────────────
enum _Tab { about, privacy, terms, contact }

// ════════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════════
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});
  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen>
    with TickerProviderStateMixin {

  _Tab _tab = _Tab.about;
  final _scrollCtrl = ScrollController();

  late AnimationController _entranceCtrl;
  late Animation<double>   _entranceFade;
  late Animation<Offset>   _entranceSlide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _entranceFade  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(
        begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _switchTab(_Tab t) {
    setState(() => _tab = t);
    _scrollCtrl.animateTo(0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _black,
      body: Column(
        children: [

          // ── TOP BAR ─────────────────────────────────────────────
          RepaintBoundary(
            child: Container(
              padding: EdgeInsets.only(top: top),
              color: _black,
              child: Container(
                height: 64,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _white10)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: _white06,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _white10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: _white, size: 15),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text('Legal & About',
                        style: GoogleFonts.outfit(
                            color: _white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    // Shield badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _white06,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: _white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined,
                              color: _grey, size: 13),
                          const SizedBox(width: 5),
                          Text('Trust Center',
                              style: GoogleFonts.outfit(
                                  color: _grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── TAB BAR ─────────────────────────────────────────────
          RepaintBoundary(
            child: Container(
              height: 52,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _white10)),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _TabChip(label: 'About',   icon: Icons.info_outline_rounded,      active: _tab == _Tab.about,   onTap: () => _switchTab(_Tab.about)),
                  const SizedBox(width: 8),
                  _TabChip(label: 'Privacy', icon: Icons.lock_outline_rounded,       active: _tab == _Tab.privacy, onTap: () => _switchTab(_Tab.privacy)),
                  const SizedBox(width: 8),
                  _TabChip(label: 'Terms',   icon: Icons.description_outlined,       active: _tab == _Tab.terms,   onTap: () => _switchTab(_Tab.terms)),
                  const SizedBox(width: 8),
                  _TabChip(label: 'Contact', icon: Icons.headset_mic_outlined,       active: _tab == _Tab.contact, onTap: () => _switchTab(_Tab.contact)),
                ],
              ),
            ),
          ),

          // ── CONTENT ─────────────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _entranceFade,
              child: SlideTransition(
                position: _entranceSlide,
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(18, 24, 18, bottom + 40),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate.fixed(
                          _buildContent(),
                        ),
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

  List<Widget> _buildContent() {
    switch (_tab) {
      case _Tab.about:   return _aboutContent();
      case _Tab.privacy: return _privacyContent();
      case _Tab.terms:   return _termsContent();
      case _Tab.contact: return _contactContent();
    }
  }

  // ── ABOUT ────────────────────────────────────────────────────────
  List<Widget> _aboutContent() => [

    // Stats row
    RepaintBoundary(
      child: Row(
        children: [
          Expanded(child: _StatCard(value: '150+', label: 'Platforms',  icon: Icons.wifi_tethering_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: '100%', label: 'Royalties',  icon: Icons.paid_outlined)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: '190+', label: 'Countries',  icon: Icons.public_rounded)),
        ],
      ),
    ),
    const SizedBox(height: 24),

    _SectionLabel(icon: Icons.info_outline_rounded, label: 'About Us'),
    const SizedBox(height: 14),

    _AccordionBlock(
      icon: Icons.album_rounded,
      title: 'Who We Are',
      children: [
        _BodyText('444Music Distribution is an independent artist platform built to close the gap between emerging talent and global audiences. We give you the infrastructure that major labels have — without the gatekeeping.'),
        const SizedBox(height: 12),
        _BodyText('Founded by music lovers and technology builders, our mission is simple: put artists in control of their careers, their royalties, and their fanbase — completely and without compromise.'),
        const SizedBox(height: 18),
        _FeatureGrid(items: const [
          _FeatureData(icon: Icons.rocket_launch_rounded,      title: 'Fast Delivery',       sub: 'Your music live on 30+ platforms within 24–48 hours.'),
          _FeatureData(icon: Icons.bar_chart_rounded,          title: 'Real-Time Analytics', sub: 'Track streams, saves, and revenue in one dashboard.'),
          _FeatureData(icon: Icons.verified_user_rounded,      title: 'Rights Protection',   sub: 'Content ID and ISRC registration included free.'),
          _FeatureData(icon: Icons.headset_mic_rounded,        title: 'Artist Support',      sub: 'Dedicated support team available 7 days a week.'),
        ]),
      ],
    ),
    const SizedBox(height: 14),

    _AccordionBlock(
      icon: Icons.my_location_rounded,
      title: 'Our Mission',
      children: [
        _BodyText('We believe that great music deserves to be heard — regardless of budget, connections, or geography. 444Music exists to make professional-grade distribution accessible to every independent artist on the planet.'),
        const SizedBox(height: 10),
        _BodyText('Our platform is built on three pillars:'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _PillarChip(label: 'Speed',          icon: Icons.bolt_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _PillarChip(label: 'Transparency',   icon: Icons.visibility_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _PillarChip(label: 'Fair Pay',       icon: Icons.handshake_outlined)),
          ],
        ),
        const SizedBox(height: 12),
        _BodyText('We take nothing from your royalties. Every stream, every playlist add, every download — 100% of your earnings flow back to you.'),
      ],
    ),
  ];

  // ── PRIVACY ──────────────────────────────────────────────────────
  List<Widget> _privacyContent() => [

    _SectionLabel(icon: Icons.lock_outline_rounded, label: 'Privacy Policy'),
    const SizedBox(height: 14),

    _AccordionBlock(
      icon: Icons.storage_rounded,
      title: 'Data We Collect',
      children: [
        _PolicyListItem(icon: Icons.person_outline_rounded,       type: _PolicyType.info,    text: 'Account registration details — name, email address, and artist profile information.'),
        _PolicyListItem(icon: Icons.credit_card_outlined,         type: _PolicyType.info,    text: 'Payment information processed securely via PCI-DSS compliant providers. We never store your card details.'),
        _PolicyListItem(icon: Icons.bar_chart_rounded,            type: _PolicyType.info,    text: 'Platform usage analytics to improve your experience and optimise our distribution network.'),
        _PolicyListItem(icon: Icons.music_note_rounded,           type: _PolicyType.info,    text: 'Music metadata — title, ISRC, release date, genre — required to distribute your content accurately.'),
        const SizedBox(height: 12),
        _NoticeBox(
          icon: Icons.info_outline_rounded,
          text: 'Your data is never sold, rented, or shared with third parties for advertising. We collect only what is necessary to operate our service.',
        ),
      ],
    ),
    const SizedBox(height: 14),

    _AccordionBlock(
      icon: Icons.shield_outlined,
      title: 'Your Rights & Protections',
      children: [
        _PolicyListItem(icon: Icons.check_rounded,  type: _PolicyType.good, boldPrefix: 'Right to Access:',     text: 'Request a full export of your personal data at any time via account settings.'),
        _PolicyListItem(icon: Icons.check_rounded,  type: _PolicyType.good, boldPrefix: 'Right to Deletion:',   text: 'Close your account and request permanent deletion of all data within 30 days.'),
        _PolicyListItem(icon: Icons.check_rounded,  type: _PolicyType.good, boldPrefix: 'Right to Correction:', text: 'Update or correct any inaccurate personal information from your profile dashboard.'),
        _PolicyListItem(icon: Icons.check_rounded,  type: _PolicyType.good, boldPrefix: 'Security:',            text: 'All data encrypted at rest (AES-256) and in transit (TLS 1.3). Regular third-party audits.'),
        _PolicyListItem(icon: Icons.check_rounded,  type: _PolicyType.good, boldPrefix: 'GDPR & CCPA:',         text: 'We honour all applicable data protection regulations globally, including EU and California residents.'),
      ],
    ),
    const SizedBox(height: 14),

    _AccordionBlock(
      icon: Icons.cookie_outlined,
      title: 'Cookies & Tracking',
      children: [
        _BodyText('We use essential cookies necessary for the platform to function, and optional analytics cookies to improve our product. You can manage cookie preferences at any time through your browser or our cookie consent panel.'),
        const SizedBox(height: 10),
        _BodyText('We do not use cross-site advertising trackers or sell browsing data to any third party.'),
      ],
    ),
  ];

  // ── TERMS ────────────────────────────────────────────────────────
  List<Widget> _termsContent() => [

    _SectionLabel(icon: Icons.description_outlined, label: 'Terms & Conditions'),
    const SizedBox(height: 14),

    _AccordionBlock(
      icon: Icons.rule_rounded,
      title: 'Artist Eligibility & Content Rules',
      children: [
        _PolicyListItem(icon: Icons.check_rounded,  type: _PolicyType.good, text: 'You must hold full copyright ownership or exclusive distribution rights to any content you upload.'),
        _PolicyListItem(icon: Icons.close_rounded,  type: _PolicyType.bad,  text: 'No copyrighted samples, cover songs without a licence, or AI-generated content presented as original.'),
        _PolicyListItem(icon: Icons.close_rounded,  type: _PolicyType.bad,  text: 'Content violating community standards — hate speech, explicit violence, or illegal material — removed without notice.'),
        _PolicyListItem(icon: Icons.check_rounded,  type: _PolicyType.good, text: 'Each release must include accurate metadata: correct artist name, title, genre, and release date.'),
      ],
    ),
    const SizedBox(height: 14),

    _AccordionBlock(
      icon: Icons.payments_outlined,
      title: 'Royalties & Payouts',
      children: [
        _TermsTableRow(rule: 'Royalty Rate',      detail: '100% of net royalties to the artist — no platform cut.',                            badge: _Badge.green,  badgeLabel: 'Guaranteed'),
        _TermsTableRow(rule: 'Payout Threshold',  detail: 'Minimum \$10 USD required to trigger a withdrawal.',                               badge: _Badge.neutral, badgeLabel: 'Standard'),
        _TermsTableRow(rule: 'Processing Time',   detail: '3–7 working days after withdrawal request is submitted.',                          badge: _Badge.neutral, badgeLabel: 'Variable'),
        _TermsTableRow(rule: 'Payment Methods',   detail: 'Bank transfer, PayPal, and Mobile Money (select regions).',                        badge: _Badge.green,  badgeLabel: 'Available'),
        _TermsTableRow(rule: 'Reporting Lag',     detail: 'Platforms typically report earnings 45–60 days after month end.',                  badge: _Badge.neutral, badgeLabel: 'Industry Norm'),
        _TermsTableRow(rule: 'Stream Fraud',      detail: 'Artificially inflated streams result in permanent suspension and royalty forfeiture.', badge: _Badge.red, badgeLabel: 'Zero Tolerance'),
        const SizedBox(height: 12),
        _NoticeBox(
          icon: Icons.warning_amber_rounded,
          text: 'Royalties from streaming platforms may take up to 60 days to appear in your dashboard due to reporting cycles outside our control.',
        ),
      ],
    ),
    const SizedBox(height: 14),

    _AccordionBlock(
      icon: Icons.gavel_rounded,
      title: 'Account Suspension & Termination',
      children: [
        _PolicyListItem(icon: Icons.close_rounded, type: _PolicyType.bad,  text: 'Accounts using stream-farming services, bots, or artificial engagement will be permanently banned.'),
        _PolicyListItem(icon: Icons.close_rounded, type: _PolicyType.bad,  text: 'Repeated copyright infringement will result in suspension and takedown requests filed with all platforms.'),
        _PolicyListItem(icon: Icons.check_rounded, type: _PolicyType.good, text: 'Artists may voluntarily close accounts at any time. Pending royalties paid out after verification.'),
        _PolicyListItem(icon: Icons.info_outline_rounded, type: _PolicyType.info, text: '444Music reserves the right to update these terms with 30 days notice via email to registered artists.'),
      ],
    ),
  ];

  // ── CONTACT ──────────────────────────────────────────────────────
  List<Widget> _contactContent() => [

    _SectionLabel(icon: Icons.headset_mic_outlined, label: 'Contact & Support'),
    const SizedBox(height: 14),

    _AccordionBlock(
      icon: Icons.mail_outline_rounded,
      title: 'Get in Touch',
      children: [
        _BodyText('Our team is available seven days a week to support artists with distribution queries, royalty questions, and technical issues.'),
        const SizedBox(height: 16),
        _ContactCard(icon: Icons.email_outlined,           title: 'Email Support',      sub: 'support@444music.com'),
        const SizedBox(height: 10),
        _ContactCard(icon: Icons.chat_bubble_outline_rounded, title: 'WhatsApp Chat',   sub: 'Quick response · 9am–9pm'),
        const SizedBox(height: 10),
        _ContactCard(icon: Icons.camera_alt_outlined,      title: 'Instagram DMs',      sub: '@444musicdist'),
        const SizedBox(height: 10),
        _ContactCard(icon: Icons.groups_outlined,          title: 'Artist Community',   sub: 'Join our Discord server'),
        const SizedBox(height: 16),
        _NoticeBox(
          icon: Icons.access_time_rounded,
          text: 'Average response time is under 4 hours on business days. For urgent copyright issues, mark your email subject as URGENT.',
        ),
      ],
    ),

    const SizedBox(height: 24),

    // Security footer
    RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: _black2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, color: _greyDark, size: 13),
            const SizedBox(width: 7),
            Text('Secured by SSL · Your data is never sold',
                style: GoogleFonts.outfit(
                    color: _greyDark, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    ),
  ];
}

// ════════════════════════════════════════════════════════════════════
//  TAB CHIP
// ════════════════════════════════════════════════════════════════════
class _TabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.icon,
    required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _white : _black2,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? _white : _white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: active ? _black : _grey, size: 13),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.outfit(
                    color: active ? _black : _grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SECTION LABEL
// ════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _white06,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _white10),
          ),
          child: Icon(icon, color: _grey, size: 14),
        ),
        const SizedBox(width: 10),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
              color: _greyDark,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  ACCORDION BLOCK
// ════════════════════════════════════════════════════════════════════
class _AccordionBlock extends StatefulWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _AccordionBlock({required this.icon, required this.title, required this.children});

  @override
  State<_AccordionBlock> createState() => _AccordionBlockState();
}

class _AccordionBlockState extends State<_AccordionBlock>
    with SingleTickerProviderStateMixin {

  bool _open = true;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _fade   = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _rotate = Tween<double>(begin: 0, end: 0.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    // Start open
    _ctrl.value = 0;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.reverse() : _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _black2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Header row — tappable
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _white06,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _white10),
                    ),
                    child: Icon(widget.icon, color: _grey, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title,
                        style: GoogleFonts.outfit(
                            color: _white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                  RotationTransition(
                    turns: _rotate,
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _grey, size: 20),
                  ),
                ],
              ),
            ),
          ),

          // Body — animated size
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: _open
                ? Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _white10)),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  STAT CARD
// ════════════════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  const _StatCard({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: _black2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: _grey, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.outfit(
                  color: _white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 3),
          Text(label,
              style: GoogleFonts.outfit(
                  color: _grey, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  FEATURE GRID
// ════════════════════════════════════════════════════════════════════
class _FeatureData {
  final IconData icon;
  final String title, sub;
  const _FeatureData({required this.icon, required this.title, required this.sub});
}

class _FeatureGrid extends StatelessWidget {
  final List<_FeatureData> items;
  const _FeatureGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((item) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _black3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: _white06,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: _grey, size: 14),
            ),
            const SizedBox(height: 8),
            Text(item.title,
                style: GoogleFonts.outfit(
                    color: _white, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(item.sub,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    color: _grey, fontSize: 10.5, height: 1.4)),
          ],
        ),
      )).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PILLAR CHIP
// ════════════════════════════════════════════════════════════════════
class _PillarChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PillarChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _black3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: _white70, size: 18),
          const SizedBox(height: 5),
          Text(label,
              style: GoogleFonts.outfit(
                  color: _white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  POLICY LIST ITEM
// ════════════════════════════════════════════════════════════════════
enum _PolicyType { good, bad, info }

class _PolicyListItem extends StatelessWidget {
  final IconData icon;
  final _PolicyType type;
  final String text;
  final String boldPrefix;
  const _PolicyListItem({
    required this.icon,
    required this.type,
    required this.text,
    this.boldPrefix = '',
  });

  Color get _iconBg => type == _PolicyType.good
      ? _greenDim
      : type == _PolicyType.bad
      ? _redDim
      : _white06;

  Color get _iconColor => type == _PolicyType.good
      ? _green
      : type == _PolicyType.bad
      ? _red
      : _grey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22, height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: _iconBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: _iconColor, size: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: boldPrefix.isNotEmpty
                ? RichText(
              text: TextSpan(
                style: GoogleFonts.outfit(
                    color: _grey, fontSize: 13, height: 1.6),
                children: [
                  TextSpan(
                    text: '$boldPrefix ',
                    style: GoogleFonts.outfit(
                        color: _white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: text),
                ],
              ),
            )
                : Text(text,
                style: GoogleFonts.outfit(
                    color: _grey, fontSize: 13, height: 1.6)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  NOTICE BOX
// ════════════════════════════════════════════════════════════════════
class _NoticeBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NoticeBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white06,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _grey, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.outfit(
                    color: _greyLight, fontSize: 12.5, height: 1.6)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  TERMS TABLE ROW
// ════════════════════════════════════════════════════════════════════
enum _Badge { green, red, neutral }

class _TermsTableRow extends StatelessWidget {
  final String rule, detail, badgeLabel;
  final _Badge badge;
  const _TermsTableRow({
    required this.rule,
    required this.detail,
    required this.badge,
    required this.badgeLabel,
  });

  Color get _badgeBg   => badge == _Badge.green ? _greenDim : badge == _Badge.red ? _redDim : _white06;
  Color get _badgeFg   => badge == _Badge.green ? _green    : badge == _Badge.red ? _red    : _grey;
  IconData get _badgeIcon => badge == _Badge.green
      ? Icons.check_rounded
      : badge == _Badge.red
      ? Icons.close_rounded
      : Icons.info_outline_rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _black3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule,
                    style: GoogleFonts.outfit(
                        color: _white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(detail,
                    style: GoogleFonts.outfit(
                        color: _grey, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _badgeBg,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_badgeIcon, color: _badgeFg, size: 10),
                const SizedBox(width: 4),
                Text(badgeLabel,
                    style: GoogleFonts.outfit(
                        color: _badgeFg,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  CONTACT CARD
// ════════════════════════════════════════════════════════════════════
class _ContactCard extends StatefulWidget {
  final IconData icon;
  final String title, sub;
  const _ContactCard({required this.icon, required this.title, required this.sub});

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _pressed ? _white10 : _black3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _pressed ? _white20 : _white10),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _white06,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _white10),
              ),
              child: Icon(widget.icon, color: _grey, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: GoogleFonts.outfit(
                          color: _white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(widget.sub,
                      style: GoogleFonts.outfit(
                          color: _grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: _greyDark, size: 12),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  BODY TEXT (reusable paragraph)
// ════════════════════════════════════════════════════════════════════
class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.outfit(
            color: _grey, fontSize: 13.5, height: 1.7));
  }
}