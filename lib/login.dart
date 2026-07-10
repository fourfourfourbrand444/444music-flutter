import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ─────────────────────────────────────────
//  BACKEND CONFIG
// ─────────────────────────────────────────
const String _backendBaseUrl = 'https://444music-backend.bonto.run';

// ─────────────────────────────────────────
//  COLOURS
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
class LoginScreen extends StatefulWidget {
  final int initialTab;
  const LoginScreen({super.key, this.initialTab = 0});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {

  int _tab = 0;

  late AnimationController _headerCtrl;
  late Animation<Offset>   _headerSlide;
  late Animation<double>   _headerFade;

  late AnimationController _toggleCtrl;
  late Animation<double>   _toggleFade;
  late Animation<Offset>   _toggleSlide;

  late AnimationController _panelCtrl;
  late Animation<double>   _panelFade;
  late Animation<Offset>   _panelSlide;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;

    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _headerSlide = Tween<Offset>(
        begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _headerCtrl, curve: Curves.easeOutCubic));
    _headerFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));

    _toggleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _toggleFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _toggleCtrl, curve: Curves.easeOut));
    _toggleSlide =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
            .animate(CurvedAnimation(
            parent: _toggleCtrl, curve: Curves.easeOutCubic));

    _panelCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _panelFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOut));
    _panelSlide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(CurvedAnimation(
            parent: _panelCtrl, curve: Curves.easeOutCubic));

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _toggleCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted) _panelCtrl.forward();
    });
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _toggleCtrl.dispose();
    _panelCtrl.dispose();
    super.dispose();
  }

  Future<void> _switchTab(int idx) async {
    if (idx == _tab) return;
    await _panelCtrl.reverse();
    setState(() => _tab = idx);
    _panelCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              SlideTransition(
                position: _headerSlide,
                child: FadeTransition(
                  opacity: _headerFade,
                  child: _Header(),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(26, 32, 26, 36),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 68,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SlideTransition(
                              position: _toggleSlide,
                              child: FadeTransition(
                                opacity: _toggleFade,
                                child: _ToggleBar(
                                  current: _tab,
                                  onSwitch: _switchTab,
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),
                            SlideTransition(
                              position: _panelSlide,
                              child: FadeTransition(
                                opacity: _panelFade,
                                child: _tab == 0
                                    ? _LoginPanel(onSwitchToSignup: () => _switchTab(1))
                                    : _SignupPanel(onSwitchToLogin: () => _switchTab(0)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  HEADER
// ─────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, top + 22, 24, 26),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 40,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Image.network(
          'https://444music-distribution.vercel.app/black.png',
          height: 44,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text(
            '444Music',
            style: TextStyle(
              color: Color(0xFF0A0A0C),
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TOGGLE BAR
// ─────────────────────────────────────────
class _ToggleBar extends StatelessWidget {
  final int current;
  final Future<void> Function(int) onSwitch;
  const _ToggleBar({required this.current, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOut,
            alignment: current == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.08),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onSwitch(0),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: current == 0
                            ? const Color(0xFF0A0A0C)
                            : const Color(0xFF666677),
                      ),
                      child: const Text('Login'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onSwitch(1),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: current == 1
                            ? const Color(0xFF0A0A0C)
                            : const Color(0xFF666677),
                      ),
                      child: const Text('Sign up'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────

class _FieldInput extends StatefulWidget {
  final String label;
  final String placeholder;
  final bool isPassword;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool hasError;
  final VoidCallback? onChanged;

  const _FieldInput({
    required this.label,
    required this.placeholder,
    required this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.hasError = false,
    this.onChanged,
  });

  @override
  State<_FieldInput> createState() => _FieldInputState();
}

class _FieldInputState extends State<_FieldInput>
    with SingleTickerProviderStateMixin {
  bool _obscure = true;
  bool _focused = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -4),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4, end: 4),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0),   weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_FieldInput old) {
    super.didUpdateWidget(old);
    if (widget.hasError && !old.hasError) {
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (_, child) => Transform.translate(
        offset: Offset(_shake.value, 0),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label.toUpperCase(),
            style: const TextStyle(
              color: _dimLight,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Focus(
            onFocusChange: (v) => setState(() => _focused = v),
            child: TextField(
              controller: widget.controller,
              obscureText: widget.isPassword && _obscure,
              keyboardType: widget.keyboardType,
              onChanged: (_) => widget.onChanged?.call(),
              style: const TextStyle(
                color: _white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: const TextStyle(
                  color: Color(0xFF333344),
                  fontSize: 15,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.only(bottom: 10, top: 6),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: widget.hasError
                        ? _errorRed.withOpacity(0.5)
                        : _border,
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: _borderFoc),
                ),
                suffixIcon: widget.isPassword
                    ? GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: _focused
                          ? const Color(0xFF888899)
                          : const Color(0xFF444455),
                    ),
                  ),
                )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _msgWidget(String text, Color color, {IconData? icon}) {
  if (text.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _submitButton({
  required String label,
  required bool loading,
  required VoidCallback? onTap,
}) {
  return SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF08080A),
        disabledBackgroundColor: Colors.white.withOpacity(0.15),
        elevation: 0,
        shape: const StadiumBorder(),
      ),
      child: loading
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF08080A),
        ),
      )
          : Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    ),
  );
}

// ── Social button shared wrapper
Widget _socialButton({
  required VoidCallback onTap,
  required Widget icon,
  required String label,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 17, height: 17, child: icon),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF9999AA),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _googleButton({required VoidCallback onTap}) =>
    _socialButton(
      onTap: onTap,
      icon: CustomPaint(painter: _GoogleLogoPainter()),
      label: 'Continue with Google',
    );

Widget _appleButton({required VoidCallback onTap}) =>
    _socialButton(
      onTap: onTap,
      icon: CustomPaint(painter: _AppleLogoPainter()),
      label: 'Continue with Apple',
    );

Widget _divider() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0x12FFFFFF))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: Color(0xFF333344),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: const Color(0x12FFFFFF))),
      ],
    ),
  );
}

// ─────────────────────────────────────────
//  BACKEND: SEND VERIFICATION CODE
// ─────────────────────────────────────────
Future<void> _triggerVerificationEmail({
  required String uid,
  required String email,
  required String name,
}) async {
  try {
    await http.post(
      Uri.parse('$_backendBaseUrl/api/verification/send-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': uid, 'email': email, 'name': name}),
    );
  } catch (_) {
    // Best-effort: signup already succeeded. If this fails, the
    // verify-code screen offers a "resend" option to try again.
  }
}

// ─────────────────────────────────────────
//  LOGIN PANEL
// ─────────────────────────────────────────
class _LoginPanel extends StatefulWidget {
  final VoidCallback onSwitchToSignup;
  const _LoginPanel({required this.onSwitchToSignup});
  @override
  State<_LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends State<_LoginPanel> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool   _loading  = false;
  bool   _errEmail = false;
  bool   _errPass  = false;
  String _msg      = '';
  Color  _msgCol   = _errorRed;
  IconData? _msgIcon;

  void _showMsg(String t, Color c, {IconData? icon}) =>
      setState(() { _msg = t; _msgCol = c; _msgIcon = icon; });

  Future<void> _doLogin() async {
    setState(() { _errEmail = false; _errPass = false; _msg = ''; });
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty) {
      setState(() => _errEmail = true);
      _showMsg('Enter your email.', _warnOrange, icon: Icons.error_outline); return;
    }
    if (pass.isEmpty) {
      setState(() => _errPass = true);
      _showMsg('Enter your password.', _warnOrange, icon: Icons.error_outline); return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pass);
      _showMsg('Signing in…', _successGrn, icon: Icons.check_circle_outline);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      setState(() => _loading = false);
      final c = e.code;
      if (c == 'user-not-found' || c == 'wrong-password' || c == 'invalid-credential') {
        setState(() { _errEmail = true; _errPass = true; });
        _showMsg('Incorrect email or password.', _errorRed, icon: Icons.error_outline);
      } else if (c == 'too-many-requests') {
        _showMsg('Too many attempts. Try later.', _errorRed, icon: Icons.error_outline);
      } else {
        _showMsg('Something went wrong.', _errorRed, icon: Icons.error_outline);
      }
    }
  }

  Future<void> _doGoogle() async {
    setState(() { _msg = ''; });
    try {
      final gUser = await GoogleSignIn().signIn();
      if (gUser == null) return;
      final gAuth = await gUser.authentication;
      final cred  = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken:     gAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (_) {
      _showMsg('Google sign-in failed. Try again.', _errorRed, icon: Icons.error_outline);
    }
  }

  Future<void> _doApple() async {
    setState(() { _msg = ''; });
    try {
      // Wire up sign_in_with_apple package here:
      // final appleCredential = await SignInWithApple.getAppleIDCredential(
      //   scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      // );
      // final oauthCredential = OAuthProvider('apple.com').credential(
      //   idToken: appleCredential.identityToken,
      //   accessToken: appleCredential.authorizationCode,
      // );
      // await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      // if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (_) {
      _showMsg('Apple sign-in failed. Try again.', _errorRed, icon: Icons.error_outline);
    }
  }

  Future<void> _doForgot() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errEmail = true);
      _showMsg('Enter your email first.', _warnOrange, icon: Icons.error_outline); return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMsg('Reset link sent — check your inbox or spam folder.', _successGrn, icon: Icons.check_circle_outline);
    } on FirebaseAuthException catch (e) {
      _showMsg(e.message ?? 'Error sending reset.', _errorRed, icon: Icons.error_outline);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _googleButton(onTap: _doGoogle),
        const SizedBox(height: 12),
        _appleButton(onTap: _doApple),
        _divider(),

        _FieldInput(
          label: 'Email',
          placeholder: 'you@example.com',
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          hasError: _errEmail,
        ),
        const SizedBox(height: 26),

        _FieldInput(
          label: 'Password',
          placeholder: '••••••••',
          controller: _passCtrl,
          isPassword: true,
          hasError: _errPass,
        ),
        const SizedBox(height: 10),

        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _doForgot,
            child: const Text(
              'Forgot password?',
              style: TextStyle(
                color: Color(0xFF555566),
                fontSize: 12,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        _submitButton(label: 'Login', loading: _loading, onTap: _doLogin),

        if (_msg.isNotEmpty) _msgWidget(_msg, _msgCol, icon: _msgIcon),
        const SizedBox(height: 20),

        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              const Text(
                'No account yet? ',
                style: TextStyle(color: Color(0xFF444455), fontSize: 13),
              ),
              GestureDetector(
                onTap: widget.onSwitchToSignup,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Sign up',
                      style: TextStyle(
                        color: Color(0xFF8888AA),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.arrow_forward, size: 13, color: Color(0xFF8888AA)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  SIGN UP PANEL
// ─────────────────────────────────────────
class _SignupPanel extends StatefulWidget {
  final VoidCallback onSwitchToLogin;
  const _SignupPanel({required this.onSwitchToLogin});
  @override
  State<_SignupPanel> createState() => _SignupPanelState();
}

class _SignupPanelState extends State<_SignupPanel> {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool   _loading    = false;
  bool   _agreed     = false;
  bool   _errName    = false;
  bool   _errEmail   = false;
  bool   _errPass    = false;
  bool   _errConfirm = false;
  String _msg        = '';
  Color  _msgCol     = _errorRed;
  IconData? _msgIcon;
  int    _strength   = 0;
  String _matchHint  = '';
  bool   _matchOk    = false;

  void _showMsg(String t, Color c, {IconData? icon}) =>
      setState(() { _msg = t; _msgCol = c; _msgIcon = icon; });

  int _getStrength(String v) {
    int s = 0;
    if (v.length > 5) s++;
    if (v.length > 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[0-9]').hasMatch(v)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) s++;
    return s;
  }

  void _onPassChanged() {
    final p = _passCtrl.text;
    final c = _confirmCtrl.text;
    setState(() {
      _strength = p.isEmpty ? 0 : _getStrength(p);
      if (c.isEmpty) {
        _matchHint = '';
      } else if (p == c) {
        _matchHint = 'Passwords match';
        _matchOk = true;
      } else {
        _matchHint = 'Passwords don\'t match';
        _matchOk = false;
      }
    });
  }

  Future<void> _doSignup() async {
    setState(() {
      _errName = false; _errEmail = false;
      _errPass = false; _errConfirm = false; _msg = '';
    });
    final name    = _nameCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    final pass    = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.length < 2) {
      setState(() => _errName = true);
      _showMsg('Enter your username.', _warnOrange, icon: Icons.error_outline); return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _errEmail = true);
      _showMsg('Enter a valid email.', _warnOrange, icon: Icons.error_outline); return;
    }
    if (pass.length < 6) {
      setState(() => _errPass = true);
      _showMsg('Password must be 6+ characters.', _warnOrange, icon: Icons.error_outline); return;
    }
    if (pass != confirm) {
      setState(() => _errConfirm = true);
      _showMsg('Passwords do not match.', _errorRed, icon: Icons.error_outline); return;
    }

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);
      final uid = cred.user!.uid;
      final db  = FirebaseFirestore.instance;

      await db.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'artistType': 'Independent Artist',
        'genre': 'Afrobeats',
        'country': 'Ghana',
        'earnings': 0,
        'emailOptIn': true,
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await db.collection('analytics').doc(uid).set({
        'totalStreams': 0,
        'spotifyStreams': 0,
        'appleStreams': 0,
        'youtubeStreams': 0,
        'tiktokStreams': 0,
        'topCountry1': 'US',
        'topCountry2': 'UK',
        'topCountry3': 'GH',
        'monthlyStreams': List.filled(12, 0),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Fire off the verification code email — best-effort, doesn't
      // block navigation if it fails (user can resend from next screen).
      await _triggerVerificationEmail(uid: uid, email: email, name: name);

      _showMsg('Account created. Check your email for a code.', _successGrn, icon: Icons.check_circle_outline);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/verify-code',
          arguments: {'uid': uid, 'email': email, 'name': name},
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _loading = false);
      const msgs = {
        'email-already-in-use': 'An account with this email already exists.',
        'invalid-email':        'Invalid email address.',
        'weak-password':        'Choose a stronger password (min 6 chars).',
        'network-request-failed': 'Network error. Check your connection.',
      };
      _showMsg(msgs[e.code] ?? e.message ?? 'Error.', _errorRed, icon: Icons.error_outline);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  static const _strengthLabels = ['Too short', 'Weak', 'Fair', 'Strong'];
  static const _strengthColors = [
    _errorRed, _warnOrange, Color(0xFFFACC15), _successGrn,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        _FieldInput(
          label: 'Username',
          placeholder: 'e.g. Kwame Beats',
          controller: _nameCtrl,
          hasError: _errName,
        ),
        const SizedBox(height: 26),

        _FieldInput(
          label: 'Email',
          placeholder: 'you@example.com',
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          hasError: _errEmail,
        ),
        const SizedBox(height: 26),

        _FieldInput(
          label: 'Password',
          placeholder: 'Create a strong password',
          controller: _passCtrl,
          isPassword: true,
          hasError: _errPass,
          onChanged: _onPassChanged,
        ),
        const SizedBox(height: 10),

        // Strength bars
        if (_passCtrl.text.isNotEmpty) ...[
          Row(
            children: List.generate(4, (i) {
              final filled = i < _strength && _strength > 0;
              return Expanded(
                child: Container(
                  height: 2,
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: filled ? _strengthColors[_strength - 1] : const Color(0xFF1A1A22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 5),
          Text(
            _strength > 0 ? _strengthLabels[_strength - 1] : '',
            style: TextStyle(
              color: _strength > 0 ? _strengthColors[_strength - 1] : Colors.transparent,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 8),

        _FieldInput(
          label: 'Confirm Password',
          placeholder: 'Re-enter your password',
          controller: _confirmCtrl,
          isPassword: true,
          hasError: _errConfirm,
          onChanged: _onPassChanged,
        ),
        const SizedBox(height: 8),

        if (_matchHint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  _matchOk ? Icons.check_circle_outline : Icons.cancel_outlined,
                  size: 13,
                  color: _matchOk ? _successGrn : _errorRed,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    _matchHint,
                    style: TextStyle(
                      color: _matchOk ? _successGrn : _errorRed,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),

        // Terms checkbox
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                activeColor: Colors.white,
                checkColor: const Color(0xFF08080A),
                side: const BorderSide(color: Color(0xFF444455), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(color: Color(0xFF555566), fontSize: 12),
                  children: [
                    TextSpan(text: 'I agree to the '),
                    TextSpan(text: 'Terms', style: TextStyle(color: Color(0xFF8888AA))),
                    TextSpan(text: ' & '),
                    TextSpan(text: 'Privacy Policy', style: TextStyle(color: Color(0xFF8888AA))),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        _submitButton(
          label: 'Create Account',
          loading: _loading,
          onTap: _agreed ? _doSignup : null,
        ),

        if (_msg.isNotEmpty) _msgWidget(_msg, _msgCol, icon: _msgIcon),
        const SizedBox(height: 20),

        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              const Text(
                'Already have an account? ',
                style: TextStyle(color: Color(0xFF444455), fontSize: 13),
              ),
              GestureDetector(
                onTap: widget.onSwitchToLogin,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Login',
                      style: TextStyle(
                        color: Color(0xFF8888AA),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.arrow_forward, size: 13, color: Color(0xFF8888AA)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  GOOGLE LOGO PAINTER — proper Bézier arcs
// ─────────────────────────────────────────
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 48.0;
    final paint = Paint()..style = PaintingStyle.fill;

    Path scale(Path p) =>
        p.transform(Matrix4.diagonal3Values(k, k, 1).storage);

    // Red
    paint.color = const Color(0xFFEA4335);
    canvas.drawPath(scale(Path()
      ..moveTo(24, 9.5)
      ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
      ..lineTo(40.06, 6.25)
      ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
      ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
      ..lineTo(10.54, 19.41)
      ..cubicTo(12.43, 13.08, 17.74, 9.5, 24, 9.5)
      ..close()), paint);

    // Blue
    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(scale(Path()
      ..moveTo(46.98, 24.55)
      ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20)
      ..lineTo(24, 20)
      ..lineTo(24, 29.02)
      ..lineTo(36.94, 29.02)
      ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
      ..lineTo(39.89, 42.2)
      ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
      ..close()), paint);

    // Yellow
    paint.color = const Color(0xFFFBBC05);
    canvas.drawPath(scale(Path()
      ..moveTo(10.53, 28.59)
      ..cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24)
      ..cubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41)
      ..lineTo(2.56, 13.22)
      ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
      ..cubicTo(0, 27.88, 0.92, 31.54, 2.56, 34.78)
      ..lineTo(10.53, 28.59)
      ..close()), paint);

    // Green
    paint.color = const Color(0xFF34A853);
    canvas.drawPath(scale(Path()
      ..moveTo(24, 48)
      ..cubicTo(30.48, 48, 35.93, 45.87, 39.89, 42.2)
      ..lineTo(32.16, 36.2)
      ..cubicTo(29.98, 37.68, 27.19, 38.51, 24, 38.51)
      ..cubicTo(17.74, 38.51, 12.43, 34.92, 10.54, 29.6)
      ..lineTo(2.56, 34.78)
      ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
      ..close()), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────
//  APPLE LOGO PAINTER — official Apple glyph
// ─────────────────────────────────────────
class _AppleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 170.0;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    Path scale(Path p) =>
        p.transform(Matrix4.diagonal3Values(k, k, 1).storage);

    // Apple body
    final body = Path()
      ..moveTo(150.37, 130.25)
      ..cubicTo(147.92, 135.91, 145.02, 141.12, 141.66, 145.91)
      ..cubicTo(137.08, 152.44, 133.33, 156.96, 130.44, 159.47)
      ..cubicTo(125.96, 163.59, 121.16, 165.70, 116.02, 165.82)
      ..cubicTo(112.33, 165.82, 107.88, 164.77, 102.70, 162.64)
      ..cubicTo(97.51, 160.52, 92.74, 159.47, 88.36, 159.47)
      ..cubicTo(83.78, 159.47, 78.87, 160.52, 73.61, 162.64)
      ..cubicTo(68.35, 164.77, 64.11, 165.88, 60.87, 165.99)
      ..cubicTo(55.93, 166.20, 51.02, 163.99, 46.12, 159.47)
      ..cubicTo(42.99, 156.74, 39.07, 152.06, 34.36, 145.43)
      ..cubicTo(29.32, 138.35, 25.17, 130.14, 21.91, 120.78)
      ..cubicTo(18.42, 110.67, 16.68, 100.88, 16.68, 91.40)
      ..cubicTo(16.68, 80.54, 19.02, 71.18, 23.71, 63.34)
      ..cubicTo(27.39, 57.03, 32.29, 52.05, 38.43, 48.39)
      ..cubicTo(44.57, 44.73, 51.20, 42.87, 58.34, 42.75)
      ..cubicTo(62.25, 42.75, 67.38, 43.96, 73.76, 46.34)
      ..cubicTo(80.12, 48.73, 84.21, 49.94, 86.00, 49.94)
      ..cubicTo(87.34, 49.94, 91.87, 48.53, 99.55, 45.70)
      ..cubicTo(106.82, 43.08, 112.95, 41.99, 117.96, 42.42)
      ..cubicTo(131.56, 43.52, 141.78, 48.88, 148.57, 58.55)
      ..cubicTo(136.41, 65.92, 130.40, 76.25, 130.52, 89.50)
      ..cubicTo(130.63, 99.82, 134.38, 108.41, 141.73, 115.23)
      ..cubicTo(145.06, 118.39, 148.78, 120.84, 152.92, 122.59)
      ..cubicTo(152.02, 125.19, 151.08, 127.68, 150.08, 130.07)
      ..close();

    // Apple leaf
    final leaf = Path()
      ..moveTo(119.11, 7.24)
      ..cubicTo(119.11, 15.33, 116.15, 22.88, 110.25, 29.86)
      ..cubicTo(103.13, 38.19, 94.52, 43.00, 85.18, 42.24)
      ..cubicTo(85.06, 41.27, 85.00, 40.25, 85.00, 39.17)
      ..cubicTo(85.00, 31.40, 88.38, 23.08, 94.40, 16.29)
      ..cubicTo(97.41, 12.85, 101.24, 9.99, 105.88, 7.71)
      ..cubicTo(110.51, 5.46, 114.89, 4.22, 119.00, 4.00)
      ..cubicTo(119.07, 5.06, 119.11, 6.12, 119.11, 7.24)
      ..close();

    canvas.drawPath(scale(body), paint);
    canvas.drawPath(scale(leaf), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}