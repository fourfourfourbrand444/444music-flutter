import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

// ─────────────────────────────────────────
//  BACKEND CONFIG
// ─────────────────────────────────────────
const String _backendBaseUrl = 'https://444music-backend.bonto.run';

// ─────────────────────────────────────────
//  COLOURS (matches signup_screen.dart)
// ─────────────────────────────────────────
const _bg         = Color(0xFF020203);
const _card       = Color(0xFF0D0D0F);
const _white      = Color(0xFFE8E8F0);
const _dim        = Color(0xFF555566);
const _dimLight   = Color(0xFF888899);
const _border     = Color(0x18FFFFFF);
const _borderFoc  = Color(0x75FFFFFF);
const _errorRed   = Color(0xFFF87171);
const _warnOrange = Color(0xFFFB923C);
const _successGrn = Color(0xFF4ADE80);

// ─────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────
class VerifyCodeScreen extends StatefulWidget {
  final String uid;
  final String email;
  final String name;

  const VerifyCodeScreen({
    super.key,
    required this.uid,
    required this.email,
    required this.name,
  });

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _resending = false;
  bool _hasError = false;
  String _msg = '';
  Color _msgCol = _errorRed;
  IconData? _msgIcon;

  int _cooldown = 0;
  Timer? _cooldownTimer;

  late AnimationController _shakeCtrl;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeOut));

    _startCooldown();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _shakeCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldown = 45;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) t.cancel();
      });
    });
  }

  void _showMsg(String t, Color c, {IconData? icon}) =>
      setState(() { _msg = t; _msgCol = c; _msgIcon = icon; });

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_hasError) setState(() => _hasError = false);
    if (_code.length == 6) {
      FocusScope.of(context).unfocus();
      _doVerify();
    }
  }

  Future<void> _doVerify() async {
    final code = _code;
    if (code.length != 6) {
      setState(() => _hasError = true);
      _shakeCtrl.forward(from: 0);
      _showMsg('Enter the full 6-digit code.', _warnOrange,
          icon: Icons.error_outline);
      return;
    }

    setState(() { _loading = true; _msg = ''; });

    try {
      final res = await http.post(
        Uri.parse('$_backendBaseUrl/api/verification/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': widget.uid, 'code': code}),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && body['success'] == true) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .update({'emailVerified': true});

        _showMsg('Email verified.', _successGrn,
            icon: Icons.check_circle_outline);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/home', (route) => false);
        }
      } else {
        setState(() => _hasError = true);
        _shakeCtrl.forward(from: 0);
        for (final c in _controllers) c.clear();
        _focusNodes[0].requestFocus();

        final reason = (body['message'] as String?) ?? '';
        if (reason.toLowerCase().contains('expired')) {
          _showMsg('Code expired. Tap resend below.', _errorRed,
              icon: Icons.error_outline);
        } else {
          _showMsg('Incorrect code. Try again.', _errorRed,
              icon: Icons.error_outline);
        }
      }
    } catch (_) {
      setState(() => _hasError = true);
      _shakeCtrl.forward(from: 0);
      _showMsg('Network error. Check your connection.', _errorRed,
          icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doResend() async {
    if (_cooldown > 0 || _resending) return;
    setState(() { _resending = true; _msg = ''; });

    try {
      final res = await http.post(
        Uri.parse('$_backendBaseUrl/api/verification/send-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': widget.uid,
          'email': widget.email,
          'name': widget.name,
        }),
      );

      if (res.statusCode == 200) {
        for (final c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
        _showMsg(
          'New code sent. Check your inbox — or spam/junk folder.',
          _successGrn,
          icon: Icons.mark_email_read_outlined,
        );
        _startCooldown();
      } else {
        _showMsg('Could not resend. Try again shortly.', _errorRed,
            icon: Icons.error_outline);
      }
    } catch (_) {
      _showMsg('Network error. Try again.', _errorRed,
          icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(26, 20, 26, 36),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: _dimLight, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(height: 28),

                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                        ),
                        child: const Icon(
                          Icons.mark_email_unread_outlined,
                          color: _white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Verify your email',
                        style: TextStyle(
                          color: _white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            color: _dimLight,
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: 'We sent a 6-digit code to '),
                            TextSpan(
                              text: widget.email,
                              style: const TextStyle(
                                color: _white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  '. If you don\'t see it within a minute, check your spam or junk folder.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      AnimatedBuilder(
                        animation: _shake,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(_shake.value, 0),
                          child: child,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (i) => _digitBox(i)),
                        ),
                      ),

                      if (_msg.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_msgIcon != null) ...[
                              Icon(_msgIcon, size: 15, color: _msgCol),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                _msg,
                                style: TextStyle(
                                  color: _msgCol,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 36),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _doVerify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF08080A),
                            disabledBackgroundColor:
                                Colors.white.withOpacity(0.15),
                            elevation: 0,
                            shape: const StadiumBorder(),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF08080A),
                                  ),
                                )
                              : const Text(
                                  'Verify',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Didn\'t get a code? ',
                              style: TextStyle(color: _dim, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: (_cooldown > 0 || _resending)
                                  ? null
                                  : _doResend,
                              child: _resending
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.6,
                                        color: _dimLight,
                                      ),
                                    )
                                  : Text(
                                      _cooldown > 0
                                          ? 'Resend in ${_cooldown}s'
                                          : 'Resend code',
                                      style: TextStyle(
                                        color: _cooldown > 0
                                            ? _dim
                                            : const Color(0xFF8888AA),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      Center(
                        child: Text(
                          'Remember to check spam/junk before resending.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _dim.withOpacity(0.7),
                            fontSize: 11,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _digitBox(int i) {
    final filled = _controllers[i].text.isNotEmpty;
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: _controllers[i],
        focusNode: _focusNodes[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        onChanged: (v) => _onDigitChanged(i, v),
        style: const TextStyle(
          color: _white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: _card,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _hasError ? _errorRed.withOpacity(0.5) : _border,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _hasError ? _errorRed.withOpacity(0.5) : _border,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _hasError ? _errorRed.withOpacity(0.5) : _border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _borderFoc, width: 1.4),
          ),
        ),
      ),
    );
  }
}