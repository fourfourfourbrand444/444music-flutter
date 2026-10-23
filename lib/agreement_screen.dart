// 444MUSIC — Payment Agreement screen
// Mirrors the web agreement page: iOS grouped rows, large title, yellow notice,
// numbered terms, plan comparison, two round checkboxes, blurred bottom dock.
//
// pubspec needs: google_fonts

import 'dart:ui' show ImageFilter;

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

// Press feedback: gentle scale and/or row highlight, like iOS.
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

Widget _sh(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 8),
      child: Text(title.toUpperCase(),
          style: _ts(13, FontWeight.w500, _C.t2, ls: 0.52)),
    );

// Text with bold segments: pass pairs of (text, bold).
TextSpan _rich(List<(String, bool)> parts, TextStyle base) => TextSpan(
      style: base,
      children: [
        for (final p in parts)
          TextSpan(
            text: p.$1,
            style: p.$2 ? const TextStyle(fontWeight: FontWeight.w600) : null,
          ),
      ],
    );

// ════════════════════════════════════════════════════════════════════
//  AGREEMENT SCREEN
// ════════════════════════════════════════════════════════════════════
class AgreementScreen extends StatefulWidget {
  const AgreementScreen({super.key});
  @override
  State<AgreementScreen> createState() => _AgreementScreenState();
}

class _AgreementScreenState extends State<AgreementScreen> {
  bool _c1 = false;
  bool _c2 = false;
  bool _going = false;

  bool get _ok => _c1 && _c2;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _C.bg,
    ));
  }

  Future<void> _continue() async {
    if (!_ok || _going) return;
    setState(() => _going = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await Navigator.pushNamed(context, '/upload-files');
    if (mounted) setState(() => _going = false);
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
            padding: EdgeInsets.fromLTRB(16, top + 56, 16, 160 + bottom),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _content(),
              ),
            ),
          ),
        ),
        Positioned(top: 0, left: 0, right: 0, child: _topBar(top)),
        Positioned(bottom: 0, left: 0, right: 0, child: _dock(bottom)),
      ]),
    );
  }

  // ── TOP BAR ────────────────────────────────────────────────────────
  Widget _topBar(double top) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 56 + top,
          color: _C.bar,
          padding: EdgeInsets.fromLTRB(16, top, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Tap(
                onTap: () => Navigator.maybePop(context),
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
              Text('Agreement', style: _ts(17, FontWeight.w600, _C.t1)),
              const SizedBox(width: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ── CONTENT ────────────────────────────────────────────────────────
  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hero(),
        _notice(),
        _sh('If you pay later'),
        _terms(),
        _sh('Compare plans'),
        _compare(),
        _sh('Confirm'),
        _confirm(),
        _footer(),
      ],
    );
  }

  Widget _hero() => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Payment agreement',
              style: _ts(34, FontWeight.w700, _C.t1, ls: -1.36, h: 1.1)),
          const SizedBox(height: 6),
          Text('Review the terms before you upload your release.',
              style: _ts(17, FontWeight.w400, _C.t2, h: 1.4)),
        ]),
      );

  Widget _notice() => Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0x1AFDEB0D),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.warning_amber_rounded,
                size: 20, color: _C.yellow),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(_rich([
              ('If you choose ', false),
              ('Release & Pay Later (GHS 0)', true),
              (', your music ', false),
              ("won't go live", true),
              (' on any store until payment is confirmed.', false),
            ], _ts(15, FontWeight.w400, _C.t1, h: 1.45))),
          ),
        ]),
      );

  // ── TERMS ──────────────────────────────────────────────────────────
  Widget _terms() {
    final base = _ts(16, FontWeight.w400, _C.t1, h: 1.4);
    final items = <List<(String, bool)>>[
      [('Our team reviews your release and prepares the metadata.', false)],
      [('Your music stays ', false), ('pending', true), (" and isn't visible on any store.", false)],
      [('Distribution starts only after payment is confirmed.', true)],
      [('Once paid, your music goes to ', false), ('100+ stores', true), (' right away.', false)],
      [('Stores can take ', false), ('3–7 business days', true), (' to show your release.', false)],
      [('Your content and ownership rights always stay yours.', false)],
    ];
    return _group(sepLeft: 54, [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24,
              height: 24,
              decoration:
                  const BoxDecoration(color: _C.fill, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('${i + 1}', style: _ts(13, FontWeight.w600, _C.t2)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text.rich(_rich(items[i], base))),
          ]),
        ),
    ]);
  }

  // ── COMPARISON ─────────────────────────────────────────────────────
  Widget _cmpRow(Widget a, Widget b, Widget c, {double minH = 48}) =>
      Container(
        constraints: BoxConstraints(minHeight: minH),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(flex: 12, child: a),
          const SizedBox(width: 8),
          Expanded(flex: 10, child: b),
          const SizedBox(width: 8),
          Expanded(flex: 10, child: c),
        ]),
      );

  Widget _txt(String s, Color c) => Text(s, style: _ts(15, FontWeight.w400, c));

  Widget _check() =>
      const Align(
        alignment: Alignment.centerLeft,
        child: Icon(Icons.check_rounded, size: 18, color: _C.green),
      );

  Widget _head(String label, String value, Color valueColor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: _ts(13, FontWeight.w500, _C.t2)),
          const SizedBox(height: 1),
          Text(value, style: _ts(16, FontWeight.w600, valueColor)),
        ],
      );

  Widget _compare() {
    return _group([
      _cmpRow(
        const SizedBox.shrink(),
        _head('Pay later', 'GHS 0', _C.t1),
        _head('Paid plan', 'Instant', _C.yellow),
        minH: 58,
      ),
      _cmpRow(_txt('Submission', _C.t1), _txt('Instant', _C.t2),
          _txt('After payment', _C.t1)),
      _cmpRow(_txt('Review', _C.t1), _check(), _check()),
      _cmpRow(_txt('Distribution', _C.t1), _txt('After payment', _C.t3),
          _txt('Right away', _C.t1)),
      _cmpRow(_txt('Goes live', _C.t1), _txt('After payment', _C.t2),
          _txt('ASAP', _C.t1)),
      _cmpRow(_txt('Store coverage', _C.t1), _txt('100+ stores', _C.t2),
          _txt('100+ stores', _C.t1)),
    ]);
  }

  // ── CONFIRM ────────────────────────────────────────────────────────
  Widget _agree(bool on, VoidCallback onTap, List<(String, bool)> parts) {
    return _Tap(
      onTap: onTap,
      highlight: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: on ? _C.yellow : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                  color: on ? _C.yellow : _C.t3, width: 1.5),
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
          const SizedBox(width: 14),
          Expanded(
            child: Text.rich(
                _rich(parts, _ts(15, FontWeight.w400, _C.t1, h: 1.45))),
          ),
        ]),
      ),
    );
  }

  Widget _confirm() {
    return _group(sepLeft: 54, [
      _agree(_c1, () => setState(() => _c1 = !_c1), [
        ('I understand my release goes live only ', false),
        ('after payment is confirmed', true),
        (' and stays pending until then.', false),
      ]),
      _agree(_c2, () => setState(() => _c2 = !_c2), [
        ('I agree to the ', false),
        ('444Music Distribution Terms of Service', true),
        (" and understand that uploading alone doesn't activate my release.", false),
      ]),
    ]);
  }

  Widget _footer() => Padding(
        padding: const EdgeInsets.only(top: 34),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final s in ['Terms', 'Privacy', 'FAQ', 'Support']) ...[
              Text(s, style: _ts(14, FontWeight.w400, _C.t2)),
              if (s != 'Support') const SizedBox(width: 22),
            ],
          ]),
          const SizedBox(height: 10),
          Text('© 2026 444Music Distribution',
              style: _ts(12, FontWeight.w400, _C.t3)),
        ]),
      );

  // ── DOCK ───────────────────────────────────────────────────────────
  Widget _dock(double bottom) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
          decoration: const BoxDecoration(
            color: _C.bar,
            border: Border(top: BorderSide(color: _C.sep, width: 0.5)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _Tap(
                  onTap: (_ok && !_going) ? _continue : null,
                  scale: 0.98,
                  child: AnimatedOpacity(
                    opacity: (_ok && !_going) ? 1 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _C.yellow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _going ? 'Redirecting…' : 'Continue to upload',
                        style: _ts(17, FontWeight.w600, Colors.black),
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: _ok
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Check both boxes to continue.',
                              textAlign: TextAlign.center,
                              style: _ts(13, FontWeight.w400, _C.t2)),
                        ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
