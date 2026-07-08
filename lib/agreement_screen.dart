import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const _black       = Color(0xFF000000);
const _black1      = Color(0xFF0A0A0A);
const _black2      = Color(0xFF111111);
const _black3      = Color(0xFF1A1A1A);
const _white       = Color(0xFFFFFFFF);
const _white70     = Color(0xB3FFFFFF);
const _white40     = Color(0x66FFFFFF);
const _white20     = Color(0x33FFFFFF);
const _white10     = Color(0x1AFFFFFF);
const _white06     = Color(0x0FFFFFFF);
const _grey        = Color(0xFF888888);
const _greyDark    = Color(0xFF444444);
const _green       = Color(0xFF22C55E);
const _amber       = Color(0xFFF59E0B);
const _amberDim    = Color(0x18F59E0B);
const _amberBorder = Color(0x33F59E0B);

class AgreementScreen extends StatefulWidget {
  const AgreementScreen({super.key});
  @override
  State<AgreementScreen> createState() => _AgreementScreenState();
}

class _AgreementScreenState extends State<AgreementScreen> {
  bool _check1   = false;
  bool _check2   = false;
  bool _showWarn = false;

  // Pre-build static content so scroll never rebuilds it
  static const _terms = [
    (Icons.pause_circle_outline_rounded,
    'Your music stays in pending status — not visible on any store.'),
    (Icons.credit_card_rounded,
    'Distribution only begins after payment is confirmed.'),
    (Icons.rocket_launch_rounded,
    'Once paid, your music goes out to 100+ stores immediately.'),
    (Icons.lock_outline_rounded,
    'Your content and ownership rights are always fully yours.'),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));
  }

  bool get _canProceed => _check1 && _check2;

  void _onContinue() {
    if (!_canProceed) {
      setState(() => _showWarn = true);
      return;
    }
    Navigator.pushNamed(context, '/upload-files');
  }

  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _black,
      // ── Use a Stack so the top bar is never inside the scroll tree
      body: Column(
        children: [

          // ── TOP BAR — completely outside scroll, never redrawn
          RepaintBoundary(
            child: Container(
              padding: EdgeInsets.only(top: top),
              color: _black,
              child: Container(
                height: 64,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _white10)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
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
                            color: _white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text('Agreement',
                        style: GoogleFonts.nunito(
                            color: _white, fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('444Music',
                        style: GoogleFonts.nunito(
                            color: _grey, fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),

          // ── SCROLLABLE BODY
          Expanded(
            child: CustomScrollView(
              // Best physics combo: momentum on iOS feel, no overscroll jank
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(22, 28, 22, bottom + 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([

                      // ── Step indicator
                      RepaintBoundary(child: _StepIndicator()),
                      const SizedBox(height: 24),

                      // ── Heading (never changes — const)
                      Text('Release\nAgreement',
                          style: GoogleFonts.nunito(
                              color: _white, fontSize: 32,
                              fontWeight: FontWeight.w800, height: 1.1)),
                      const SizedBox(height: 8),
                      Text(
                        'Confirm the terms below before uploading your release.',
                        style: GoogleFonts.nunito(
                            color: _grey, fontSize: 13,
                            fontWeight: FontWeight.w500, height: 1.6),
                      ),
                      const SizedBox(height: 28),

                      // ── Notice banner (static — RepaintBoundary)
                      const RepaintBoundary(child: _NoticeBanner()),
                      const SizedBox(height: 24),

                      Container(height: 1, color: _white10),
                      const SizedBox(height: 24),

                      Text('WHAT HAPPENS WITH PAY LATER',
                          style: GoogleFonts.nunito(
                              color: _greyDark, fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 12),

                      // ── Terms list (static — RepaintBoundary)
                      RepaintBoundary(
                        child: Column(
                          children: _terms.map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: _black2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _white10),
                            ),
                            child: Row(
                              children: [
                                Icon(item.$1, color: _grey, size: 16),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(item.$2,
                                      style: GoogleFonts.nunito(
                                          color: const Color(0xFFAAAAAB),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          height: 1.5)),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Container(height: 1, color: _white10),
                      const SizedBox(height: 24),

                      Text('ACKNOWLEDGEMENT',
                          style: GoogleFonts.nunito(
                              color: _greyDark, fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 12),

                      // ── Checkboxes — only this rebuilds on tap
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _black2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _white10),
                        ),
                        child: Column(
                          children: [
                            _CheckRow(
                              checked: _check1,
                              onTap: () => setState(() {
                                _check1 = !_check1;
                                _showWarn = false;
                              }),
                              text: 'My release will only go live after payment '
                                  'confirmation and stays pending until then.',
                            ),
                            const SizedBox(height: 10),
                            _CheckRow(
                              checked: _check2,
                              onTap: () => setState(() {
                                _check2 = !_check2;
                                _showWarn = false;
                              }),
                              text: 'I agree to the 444Music Distribution Terms of '
                                  'Service. Uploading alone does not activate my release.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Warning
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: _showWarn
                            ? Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: _amberDim,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _amberBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                    Icons.warning_amber_rounded,
                                    color: _amber, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Please check both boxes to continue.',
                                    style: GoogleFonts.nunito(
                                        color: _amber,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            : const SizedBox.shrink(),
                      ),

                      // ── Button
                      _ContinueButton(
                          enabled: _canProceed, onTap: _onContinue),
                      const SizedBox(height: 12),

                      // ── Footer hint
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              color: _greyDark, size: 12),
                          const SizedBox(width: 5),
                          Text('Secured by SSL · Your data is never sold',
                              style: GoogleFonts.nunito(
                                  color: _greyDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),

                    ]),
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

// ── STEP INDICATOR — extracted so it never triggers parent rebuild
class _StepIndicator extends StatelessWidget {
  const _StepIndicator();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(4, (i) => Container(
          width: i <= 1 ? 20 : 6,
          height: 6,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(
            color: i <= 1 ? _white : _greyDark,
            borderRadius: BorderRadius.circular(99),
          ),
        )),
        const SizedBox(width: 8),
        Text('Step 2 of 4',
            style: GoogleFonts.nunito(
                color: _grey, fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── NOTICE BANNER — fully static, isolated repaint
class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _amberDim,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: const BorderSide(color: _amber, width: 3),
          top: BorderSide(color: _amberBorder),
          right: BorderSide(color: _amberBorder),
          bottom: BorderSide(color: _amberBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: _amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.nunito(
                  color: const Color(0xFFC4A44A),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                ),
                children: const [
                  TextSpan(text: 'If you chose '),
                  TextSpan(
                    text: '"Pay Later"',
                    style: TextStyle(
                        color: _amber, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                      text:
                      ', your music will NOT go live until payment is confirmed.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── CHECK ROW
class _CheckRow extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  final String text;
  const _CheckRow(
      {required this.checked, required this.onTap, required this.text});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: checked ? _white06 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: checked ? _white20 : Colors.transparent),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: 20, height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: checked ? _white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: checked ? _white : _greyDark, width: 1.5),
              ),
              child: checked
                  ? const Icon(Icons.check_rounded, color: _black, size: 13)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.nunito(
                      color: checked ? _white70 : _grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.55)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CONTINUE BUTTON
class _ContinueButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _ContinueButton({required this.enabled, required this.onTap});
  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:  widget.enabled ? (_) => setState(() => _pressed = true)  : null,
      onTapUp:    widget.enabled ? (_) { setState(() => _pressed = false); widget.onTap(); } : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: widget.enabled
              ? (_pressed ? const Color(0xFFE0E0E0) : _white)
              : _black3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: widget.enabled ? _white : _white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'CONTINUE TO UPLOAD',
              style: GoogleFonts.nunito(
                color: widget.enabled ? _black : _greyDark,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded,
                color: widget.enabled ? _black : _greyDark, size: 16),
          ],
        ),
      ),
    );
  }
}