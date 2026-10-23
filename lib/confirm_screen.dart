// 444MUSIC — Confirm → Saving → Success
// Same flow as before, rebuilt in the iOS look used by the other screens:
// black page, grouped rows, yellow accent, blurred top bar and bottom dock.
//
// pubspec needs: google_fonts   (uses Flutter's built-in Cupertino spinner)

import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class _C {
  static const bg = Color(0xFF000000);
  static const s1 = Color(0xFF1C1C1E);
  static const sep = Color(0x8C545458);
  static const fill = Color(0x3D787880);
  static const t1 = Color(0xFFFFFFFF);
  static const t2 = Color(0x99EBEBF5);
  static const t3 = Color(0x4DEBEBF5);
  static const blue = Color(0xFF0A84FF);
  static const yellow = Color(0xFFFDEB0D);
  static const green = Color(0xFF30D158);
  static const bar = Color(0xB8000000);
}

TextStyle _ts(double s, FontWeight w, Color c, {double? ls, double? h}) =>
    GoogleFonts.inter(
      fontSize: s,
      fontWeight: w,
      color: c,
      letterSpacing: ls ?? -s * 0.011,
      height: h,
    );

// ─── SHARED PIECES ───────────────────────────────────────────────────
class _Tap extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final bool highlight;
  final double scale;
  const _Tap({
    required this.onTap,
    required this.child,
    this.highlight = false,
    this.scale = 1,
  });
  @override
  State<_Tap> createState() => _TapState();
}

class _TapState extends State<_Tap> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => _set(true) : null,
      onTapUp: on ? (_) => _set(false) : null,
      onTapCancel: on ? () => _set(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: (_down && widget.scale != 1) ? widget.scale : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          color: (widget.highlight && _down)
              ? const Color(0x0DFFFFFF)
              : const Color(0x00000000),
          child: widget.child,
        ),
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  final double left;
  const _Sep(this.left);
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: left),
        child: const SizedBox(
          height: 0.5,
          width: double.infinity,
          child: ColoredBox(color: _C.sep),
        ),
      );
}

Widget _group(List<Widget> rows, {double sepLeft = 16}) {
  final items = <Widget>[];
  for (var i = 0; i < rows.length; i++) {
    if (i > 0) items.add(_Sep(sepLeft));
    items.add(rows[i]);
  }
  return Container(
    decoration: BoxDecoration(
      color: _C.s1,
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
  );
}

Widget _blurBar({required Widget child, required EdgeInsets padding, double? height, bool topBorder = false}) {
  return ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: _C.bar,
          border: topBorder
              ? const Border(top: BorderSide(color: _C.sep, width: 0.5))
              : null,
        ),
        child: child,
      ),
    ),
  );
}

Widget _yellowButton(String label, VoidCallback? onTap) => _Tap(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.4 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _C.yellow,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label, style: _ts(17, FontWeight.w600, Colors.black)),
        ),
      ),
    );

Widget _textButton(String label, VoidCallback onTap) => _Tap(
      onTap: onTap,
      child: SizedBox(
        height: 42,
        child: Center(
          child: Text(label, style: _ts(17, FontWeight.w400, _C.blue)),
        ),
      ),
    );

PageRouteBuilder<T> _fade<T>(Widget page, {int ms = 400}) => PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: Duration(milliseconds: ms),
    );

// ════════════════════════════════════════════════════════════════════
//  1 · CONFIRM
// ════════════════════════════════════════════════════════════════════
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key});
  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  final List<bool> _checked = [false, false, false];

  static const _terms = [
    (
      'Copyright ownership',
      'I own or have legally licensed all copyrights to the sound recordings, compositions and artwork in this release, and I agree to all terms in the distribution agreement.'
    ),
    (
      'Track accuracy',
      'I confirm that I have truthfully indicated the Track Origin and Track Properties for each track, so my release meets DSP requirements.'
    ),
    (
      'Streaming integrity',
      'I understand that artificial streaming and misleading promotion break platform policies and can lead to content removal, withheld royalties or account penalties.'
    ),
  ];

  int get _count => _checked.where((v) => v).length;
  bool get _all => _count == 3;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _C.bg,
    ));
  }

  void _toggle(int i) {
    HapticFeedback.selectionClick();
    setState(() => _checked[i] = !_checked[i]);
  }

  void _close() {
    HapticFeedback.lightImpact();
    Navigator.maybePop(context);
  }

  void _confirm() {
    if (!_all) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(_fade(const SavingReleaseScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;
    final bottom = mq.padding.bottom;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(children: [
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, top + 56, 16, 170 + bottom),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Confirm your release',
                              style: _ts(34, FontWeight.w700, _C.t1,
                                  ls: -1.36, h: 1.1)),
                          const SizedBox(height: 6),
                          Text('Read and agree to each term before you distribute.',
                              style: _ts(17, FontWeight.w400, _C.t2, h: 1.4)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 30, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('TERMS',
                              style: _ts(13, FontWeight.w500, _C.t2, ls: 0.52)),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: _ts(13, FontWeight.w400,
                                _all ? _C.yellow : _C.t3),
                            child: Text('$_count of 3'),
                          ),
                        ],
                      ),
                    ),
                    _group(sepLeft: 54, [
                      for (var i = 0; i < _terms.length; i++)
                        _termRow(i, _terms[i].$1, _terms[i].$2),
                    ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Text(
                          'This agreement is legally binding once you confirm.',
                          style: _ts(13, FontWeight.w400, _C.t2, h: 1.4)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _blurBar(
            height: 56 + top,
            padding: EdgeInsets.fromLTRB(16, top, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Tap(
                  onTap: _close,
                  scale: 0.92,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                        color: _C.fill, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 15, color: _C.t1),
                  ),
                ),
                Text('Confirmation', style: _ts(17, FontWeight.w600, _C.t1)),
                const SizedBox(width: 36),
              ],
            ),
          ),
        ),

        // dock
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _blurBar(
            topBorder: true,
            padding: EdgeInsets.fromLTRB(16, 12, 16, 10 + bottom),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _yellowButton('Confirm & distribute', _all ? _confirm : null),
                  const SizedBox(height: 2),
                  _textButton('Cancel', _close),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _termRow(int i, String title, String body) {
    final on = _checked[i];
    return _Tap(
      onTap: () => _toggle(i),
      highlight: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: on ? _C.yellow : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: on ? _C.yellow : _C.t3, width: 1.5),
              ),
              child: AnimatedScale(
                scale: on ? 1 : 0.5,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: on ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.check_rounded,
                      size: 15, color: Colors.black),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: _ts(16, FontWeight.w600, _C.t1)),
              const SizedBox(height: 3),
              Text(body, style: _ts(15, FontWeight.w400, _C.t2, h: 1.45)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  2 · SAVING
// ════════════════════════════════════════════════════════════════════
class SavingReleaseScreen extends StatefulWidget {
  const SavingReleaseScreen({super.key});
  @override
  State<SavingReleaseScreen> createState() => _SavingReleaseScreenState();
}

class _SavingReleaseScreenState extends State<SavingReleaseScreen>
    with SingleTickerProviderStateMixin {
  static const _steps = [
    'Uploading files',
    'Checking metadata',
    'Preparing distribution',
    'Finalising',
  ];

  int _done = 0; // steps finished; step at index _done is active
  late final AnimationController _ring = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600))
    ..forward();

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (var i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _done = i + 1);
    }
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(_fade(const ReleaseSuccessScreen(), ms: 600));
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  Widget _stepRow(int i) {
    final done = i < _done;
    final active = i == _done;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: _ts(16, active ? FontWeight.w500 : FontWeight.w400,
                (done || active) ? _C.t1 : _C.t3),
            child: Text(_steps[i]),
          ),
        ),
        SizedBox(
          width: 22,
          height: 22,
          child: done
              ? const Icon(Icons.check_circle_rounded,
                  size: 22, color: _C.green)
              : active
                  ? const CupertinoActivityIndicator(
                      radius: 9, color: _C.yellow)
                  : null,
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: SizedBox(
                        width: 112,
                        height: 112,
                        child: AnimatedBuilder(
                          animation: _ring,
                          builder: (_, __) {
                            final v = Curves.easeInOut.transform(_ring.value);
                            return CustomPaint(
                              painter: _RingPainter(v),
                              child: Center(
                                child: Text('${(v * 100).round()}%',
                                    style: _ts(24, FontWeight.w600, _C.t1)
                                        .copyWith(
                                            fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ])),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text('Saving your release',
                        textAlign: TextAlign.center,
                        style: _ts(28, FontWeight.w700, _C.t1, ls: -0.8)),
                    const SizedBox(height: 6),
                    Text('This only takes a moment.',
                        textAlign: TextAlign.center,
                        style: _ts(17, FontWeight.w400, _C.t2)),
                    const SizedBox(height: 32),
                    _group([for (var i = 0; i < _steps.length; i++) _stepRow(i)]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const sw = 7.0;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - sw / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _C.fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -1.5708,
      progress * 6.2832,
      false,
      Paint()
        ..color = _C.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ════════════════════════════════════════════════════════════════════
//  3 · SUCCESS
// ════════════════════════════════════════════════════════════════════
class ReleaseSuccessScreen extends StatefulWidget {
  const ReleaseSuccessScreen({super.key});
  @override
  State<ReleaseSuccessScreen> createState() => _ReleaseSuccessScreenState();
}

class _ReleaseSuccessScreenState extends State<ReleaseSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _check = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..forward();
  late final AnimationController _content = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _content.forward();
    });
  }

  @override
  void dispose() {
    _check.dispose();
    _content.dispose();
    super.dispose();
  }

  void _dashboard() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (r) => false);
  }

  void _releases() {
    Navigator.of(context).pushNamedAndRemoveUntil('/releases', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Stack(children: [
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.4, end: 1).animate(
                          CurvedAnimation(
                              parent: _check, curve: Curves.elasticOut)),
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                            parent: _check, curve: Curves.easeOut),
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                              color: _C.yellow, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded,
                              size: 52, color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeTransition(
                      opacity: CurvedAnimation(
                          parent: _content, curve: Curves.easeOut),
                      child: SlideTransition(
                        position: Tween<Offset>(
                                begin: const Offset(0, 0.08), end: Offset.zero)
                            .animate(CurvedAnimation(
                                parent: _content, curve: Curves.easeOutCubic)),
                        child: Column(children: [
                          Text('Release submitted',
                              textAlign: TextAlign.center,
                              style: _ts(30, FontWeight.w700, _C.t1,
                                  ls: -0.9, h: 1.1)),
                          const SizedBox(height: 10),
                          Text('Your release is now under review.',
                              textAlign: TextAlign.center,
                              style: _ts(17, FontWeight.w400, _C.t2, h: 1.4)),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0x1AFDEB0D),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                      color: _C.yellow,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text('Under review',
                                  style: _ts(14, FontWeight.w600, _C.yellow)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _content, curve: Curves.easeOut),
              child: _blurBar(
                topBorder: true,
                padding: EdgeInsets.fromLTRB(16, 12, 16, 10 + bottom),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _yellowButton('Go to dashboard', _dashboard),
                      const SizedBox(height: 2),
                      _textButton('View my releases', _releases),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
