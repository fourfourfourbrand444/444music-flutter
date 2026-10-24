// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Home Screen v12 (luxury iOS look, same low-cost feed)
//
//  Same logic and Firestore / API usage as v11 (about 60-80 reads per
//  app open). Only the look changed:
//   • iOS typography (SF on iOS, Inter elsewhere) instead of Nunito/Outfit
//   • iOS segmented control, glass sidebar, sheets and alerts
//   • Logout asks "Log out?" first; back-button quit uses the same alert
//
//  Needs: shared_preferences in pubspec.yaml, cloud_firestore with count().
//  No new Firestore indexes are required.
// ═══════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── PALETTE (black & white, iOS grays) ─────────────────────────────
const _black   = Color(0xFF000000);
const _s1      = Color(0xFF1C1C1E);
const _s2      = Color(0xFF2C2C2E);
const _s3      = Color(0xFF636366);
const _sep     = Color(0x8C545458);
const _fill    = Color(0x3D787880);
const _fillSoft = Color(0x29787880);
const _white   = Color(0xFFFFFFFF);
const _white90 = Color(0xE6FFFFFF);
const _white70 = Color(0xB3EBEBF5);
const _t2      = Color(0x99EBEBF5);
const _t3      = Color(0x4DEBEBF5);
const _blue    = Color(0xFF0A84FF);
const _rose    = Color(0xFFFF453A);

const _pageSize = 20;
const _apiBase = 'https://api.444musicdistro.com';

// ─── TYPOGRAPHY — SF on iOS, Inter elsewhere ────────────────────────
bool get _isApple =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

TextStyle _ts(double size, FontWeight w, Color c, {double em = -0.01, double? height}) {
  final base = TextStyle(
    fontSize: size,
    fontWeight: w,
    color: c,
    letterSpacing: size * em,
    height: height,
    decoration: TextDecoration.none,
  );
  return _isApple ? base : GoogleFonts.inter(textStyle: base);
}

// ─── R2 upload (posts, stories) ─────────────────────────────────────
String _contentType(String name) {
  final l = name.toLowerCase();
  if (l.endsWith('.png')) return 'image/png';
  if (l.endsWith('.webp')) return 'image/webp';
  if (l.endsWith('.heic')) return 'image/heic';
  return 'image/jpeg';
}

/// Uploads straight to the feed API. Returns the file key (not a URL).
Future<String?> _uploadToR2(XFile file, {required String kind, required String uid}) async {
  try {
    final bytes = await file.readAsBytes();
    final type = _contentType(file.name);
    final folder = kind == 'story' ? 'stories' : kind == 'avatar' ? 'avatars' : 'posts';
    final tok = await FirebaseAuth.instance.currentUser?.getIdToken();
    final r = await http.post(
      Uri.parse('$_apiBase/upload?folder=$folder'),
      headers: {'Authorization': 'Bearer $tok', 'Content-Type': type},
      body: bytes,
    ).timeout(const Duration(seconds: 90));
    if (r.statusCode != 201) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['key'] as String?;
  } catch (_) {
    return null;
  }
}

/// Small client for the feed API (adds the Firebase login token to every call).
class _Api {
  static Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final tok = await FirebaseAuth.instance.currentUser?.getIdToken();
    final headers = {
      if (tok != null) 'Authorization': 'Bearer $tok',
      'Content-Type': 'application/json',
    };
    final uri = Uri.parse('$_apiBase$path');
    final data = body == null ? '{}' : jsonEncode(body);
    final http.Response r = await (switch (method) {
      'POST' => http.post(uri, headers: headers, body: data),
      'PATCH' => http.patch(uri, headers: headers, body: data),
      'DELETE' => http.delete(uri, headers: headers),
      _ => http.get(uri, headers: headers),
    }).timeout(const Duration(seconds: 20));
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('API ${r.statusCode}');
    return r.body.isEmpty ? null : jsonDecode(r.body);
  }

  static Future<dynamic> get(String path) => _send('GET', path);
  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body);
  static Future<dynamic> patch(String path, Map<String, dynamic> body) => _send('PATCH', path, body);
  static Future<dynamic> delete(String path) => _send('DELETE', path);
}

/// Width / height of a picked photo, saved on the post so the feed can reserve
/// the right space before the image has downloaded.
Future<double?> _aspectOf(XFile f) async {
  try {
    final img = await decodeImageFromList(await f.readAsBytes());
    final a = img.width / img.height;
    img.dispose();
    return a;
  } catch (_) {
    return null;
  }
}

// ─── On-device memory (likes, follows, seen stories, user info) ─────
class _Local {
  static SharedPreferences? _p;
  static Future<void>? _initFuture;
  static Future<void> init() => _initFuture ??= SharedPreferences.getInstance().then((p) { _p = p; });
  static bool has(String k) => _p?.containsKey(k) ?? false;
  static Set<String> getSet(String k) => (_p?.getStringList(k) ?? const <String>[]).toSet();
  static Future<void> putSet(String k, Set<String> v, {int max = 600}) async {
    final p = _p;
    if (p == null) return;
    final l = v.toList();
    await p.setStringList(k, l.length > max ? l.sublist(l.length - max) : l);
  }
  static String? getString(String k) => _p?.getString(k);
  static Future<void> putString(String k, String v) async {
    final p = _p;
    if (p == null) return;
    await p.setString(k, v);
  }
  static Future<void> remove(String k) async {
    final p = _p;
    if (p == null) return;
    await p.remove(k);
  }
}

// ─── Shared user-info cache (memory + 12 hours on the phone) ────────
class UserInfoCache {
  UserInfoCache._();
  static final UserInfoCache instance = UserInfoCache._();
  static const _ttlMs = 12 * 60 * 60 * 1000;
  final Map<String, Map<String, dynamic>> _cache = {};
  final Map<String, Future<Map<String, dynamic>>> _inflight = {};

  Map<String, dynamic>? peek(String uid) => _cache[uid];

  Future<Map<String, dynamic>> get(String uid) {
    final hit = _cache[uid];
    if (hit != null) return Future.value(hit);
    // Same person asked for twice at once (two posts by one author) = one read.
    return _inflight[uid] ??= _fetch(uid).whenComplete(() { _inflight.remove(uid); });
  }

  Future<Map<String, dynamic>> _fetch(String uid) async {
    await _Local.init();
    final saved = _readSaved(uid);
    if (saved != null) return _cache[uid] = saved;
    Map<String, dynamic> info = {'name': 'Artist', 'avatar': '', 'verified': false};
    try {
      final s = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (s.exists) {
        info = _infoFrom(s.data()!);
        _save(uid, info);
      }
    } catch (_) {
      return info; // do not remember a failed lookup
    }
    return _cache[uid] = info;
  }

  Map<String, dynamic>? _readSaved(String uid) {
    final raw = _Local.getString('uic_$uid');
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final t = (m['t'] as num).toInt();
      if (DateTime.now().millisecondsSinceEpoch - t > _ttlMs) return null;
      return {'name': m['n'] ?? 'Artist', 'avatar': m['a'] ?? '', 'verified': m['v'] == true};
    } catch (_) {
      return null;
    }
  }

  void _save(String uid, Map<String, dynamic> info) {
    _Local.putString('uic_$uid', jsonEncode({
      'n': info['name'], 'a': info['avatar'], 'v': info['verified'] == true,
      't': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  static Map<String, dynamic> _infoFrom(Map<String, dynamic> d) => {
        'name': (d['name'] as String?)?.trim().isNotEmpty == true ? d['name'] : 'Artist',
        'avatar': d['profilePic'] ?? '',
        'verified': d['verified'] == true,
      };

  void prime(String uid, Map<String, dynamic> info) => _cache[uid] = info;

  /// Forget a person's saved name/avatar/tick (memory and phone), so the next
  /// lookup reads fresh data. Call after a profile is edited or verified.
  void invalidate(String? uid) {
    if (uid == null) return;
    _cache.remove(uid);
    _inflight.remove(uid);
    _Local.remove('uic_$uid');
  }

  /// [persist] is used for your own doc, which was just read fresh.
  void primeFromDoc(String uid, Map<String, dynamic> d, {bool persist = false}) {
    final info = _infoFrom(d);
    _cache[uid] = info;
    if (persist) _save(uid, info);
  }
}

Widget verifiedTick({double size = 13}) => Icon(Icons.verified_rounded, color: _blue, size: size);

/// Lets other screens call the feed API.
class FeedApi {
  static Future<dynamic> get(String path) => _Api.get(path);
  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _Api.post(path, body);
  static Future<dynamic> patch(String path, Map<String, dynamic> body) => _Api.patch(path, body);
  static Future<dynamic> delete(String path) => _Api.delete(path);
}

Future<void> openExternalLink(String url) async {
  var u = url.trim();
  if (u.isEmpty) return;
  if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
  final uri = Uri.tryParse(u);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

List<InlineSpan> hashtagSpans(String text, {required TextStyle base}) {
  if (text.isEmpty) return [TextSpan(text: text, style: base)];
  final spans = <InlineSpan>[];
  int last = 0;
  for (final m in RegExp(r'(^|\s)([#@][a-zA-Z0-9_.]+)').allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start), style: base));
    spans.add(TextSpan(text: m.group(1), style: base));
    spans.add(TextSpan(text: m.group(2), style: base.copyWith(color: _blue, fontWeight: FontWeight.w600)));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: base));
  return spans;
}

String formatCount(int c) {
  if (c < 10000) {
    final s = c.toString(), b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
  String t(double v) { final s = v.toStringAsFixed(1); return s.endsWith('.0') ? s.substring(0, s.length - 2) : s; }
  return c < 1000000 ? '${t(c / 1000)}K' : '${t(c / 1000000)}M';
}

String timeAgo(DateTime? d) {
  if (d == null) return 'just now';
  final s = DateTime.now().difference(d).inSeconds;
  if (s < 60) return 'just now';
  final m = s ~/ 60;
  if (m < 60) return '${m}m ago';
  final h = m ~/ 60;
  if (h < 24) return '${h}h ago';
  final days = h ~/ 24;
  if (days < 7) return '${days}d ago';
  if (days < 35) return '${days ~/ 7}w ago';
  if (days < 365) return '${days ~/ 30}mo ago';
  return '${days ~/ 365}y ago';
}

DateTime? _dt(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  return null;
}

// docId makes repeat actions (like/unlike spam) overwrite one notification
// instead of creating a new document every time.
Future<void> sendNotification(String to, String type, {
  String? postId, String? postText, String? postImage, String? commentText, String? docId,
}) async {
  final me = FirebaseAuth.instance.currentUser;
  if (me == null || to == me.uid) return;
  final mine = await UserInfoCache.instance.get(me.uid);
  try {
    await _Api.post('/notify', {
      'to': to, 'type': type, 'docId': docId,
      'fromName': mine['name'], 'fromAvatar': mine['avatar'],
      'postId': postId, 'postText': postText, 'postImage': postImage, 'commentText': commentText,
    });
  } catch (_) {}
}

// ─── iOS ALERT + ACTION SHEET HELPERS ───────────────────────────────
class _IosAlert extends StatelessWidget {
  final String title, message, cancelLabel, confirmLabel;
  final bool destructive;
  const _IosAlert({
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget action(String label, bool primary, bool result, Color color) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context, result),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              child: Text(label, style: _ts(17, primary ? FontWeight.w600 : FontWeight.w400, color, em: -0.02)),
            ),
          ),
        );
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                color: const Color(0xF02C2C2E),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                      child: Column(children: [
                        Text(title, textAlign: TextAlign.center, style: _ts(17, FontWeight.w600, _white, em: -0.02)),
                        const SizedBox(height: 5),
                        Text(message,
                            textAlign: TextAlign.center,
                            style: _ts(13, FontWeight.w400, const Color(0xD9FFFFFF), height: 1.4)),
                      ]),
                    ),
                    Container(height: 0.5, color: _sep),
                    Row(children: [
                      action(cancelLabel, false, false, _blue),
                      Container(width: 0.5, height: 48, color: _sep),
                      action(confirmLabel, true, true, destructive ? _rose : _blue),
                    ]),
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

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String cancel,
  required String ok,
  bool destructive = false,
}) async {
  final r = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, _, __) => _IosAlert(
      title: title, message: message, cancelLabel: cancel, confirmLabel: ok, destructive: destructive,
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final c = CurvedAnimation(parent: anim, curve: const Cubic(0.32, 0.72, 0, 1));
      return FadeTransition(
        opacity: c,
        child: ScaleTransition(scale: Tween<double>(begin: 1.1, end: 1).animate(c), child: child),
      );
    },
  );
  return r == true;
}

class _Act {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Act(this.label, this.onTap, {this.color = _blue});
}

Future<void> _actionSheet(BuildContext context, List<_Act> acts, {String? title}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(color: const Color(0xF22C2C2E), borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  if (title != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      child: Text(title, style: _ts(13, FontWeight.w600, _t2)),
                    ),
                  for (int i = 0; i < acts.length; i++) ...[
                    if (i > 0 || title != null) Container(height: 0.5, color: _sep),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () { Navigator.pop(ctx); acts[i].onTap(); },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        alignment: Alignment.center,
                        child: Text(acts[i].label, style: _ts(19, FontWeight.w400, acts[i].color, em: -0.02)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: double.infinity,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(14)),
                child: Text('Cancel', style: _ts(19, FontWeight.w600, _blue, em: -0.02)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _grabber() => Container(
      width: 36, height: 5,
      decoration: BoxDecoration(color: const Color(0x4DEBEBF5), borderRadius: BorderRadius.circular(3)),
    );

Widget _sheetHeader(String title) => Column(children: [
      const SizedBox(height: 8),
      _grabber(),
      Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(title, style: _ts(17, FontWeight.w600, _white))),
      Container(height: 0.5, color: _sep),
    ]);

const _sheetDecoration = BoxDecoration(
  color: _s1,
  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
);

// ════════════════════════════════════════════════════════════════════
//  HOME SCREEN — shell (sidebar + bottom nav)
// ════════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _navIndex = 0;
  bool _sidebarOpen = false;
  late AnimationController _sidebarCtrl;
  late Animation<double> _sidebarFade;
  late Animation<Offset> _sidebarSlide;
  final _user = FirebaseAuth.instance.currentUser;
  final GlobalKey<_FeedHomeState> _feedKey = GlobalKey<_FeedHomeState>();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent, systemNavigationBarColor: _black));
    _sidebarCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _sidebarFade = CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOut);
    _sidebarSlide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _sidebarCtrl, curve: const Cubic(0.32, 0.72, 0, 1)));
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    super.dispose();
  }

  void _openSidebar() { setState(() => _sidebarOpen = true); _sidebarCtrl.forward(); }
  void _closeSidebar() { _sidebarCtrl.reverse().then((_) { if (mounted) setState(() => _sidebarOpen = false); }); }
  void _navigate(String route) {
    _closeSidebar();
    Future.delayed(const Duration(milliseconds: 300), () { if (mounted) Navigator.pushNamed(context, route); });
  }

  // ── Back button: close sidebar → go to Home tab → ask before quitting ──
  Future<void> _handleBack() async {
    if (_sidebarOpen) { _closeSidebar(); return; }
    if (_navIndex != 0) { setState(() => _navIndex = 0); return; }
    final quit = await _confirm(
      context,
      title: 'Quit 444Music?',
      message: 'Do you want to quit the app?',
      cancel: 'No',
      ok: 'Yes',
    );
    if (quit && mounted) SystemNavigator.pop();
  }

  // ── Logout from the sidebar: ask first ──
  Future<void> _logout() async {
    final ok = await _confirm(
      context,
      title: 'Log out?',
      message: 'Are you sure you want to log out of your account?',
      cancel: 'Cancel',
      ok: 'Log out',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await FirebaseAuth.instance.signOut();
    _closeSidebar();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _onBottomNavTap(int i) {
    if (i == 0) {
      if (_navIndex == 0) { _feedKey.currentState?.scrollToTopAndRefresh(); } else { setState(() => _navIndex = 0); }
      return;
    }
    if (i == 1) { Navigator.pushNamed(context, '/analytics'); return; }
    if (i == 2) { Navigator.pushNamed(context, '/upload'); return; }
    if (i == 3) { Navigator.pushNamed(context, '/earnings'); return; }
    if (i == 4) { Navigator.pushNamed(context, '/viewpro', arguments: _user?.uid); }
  }

  @override
  Widget build(BuildContext context) {
    // Your own name/avatar were read once by the feed; no extra lookup here.
    final me = _user == null ? null : UserInfoCache.instance.peek(_user!.uid);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: _black,
        extendBody: true,
        body: Stack(children: [
          IndexedStack(index: _navIndex, children: [
            _FeedHome(key: _feedKey, currentUser: _user, onMenu: _openSidebar),
            const _PlaceholderTab(icon: Icons.bar_chart_rounded, label: 'Analytics'),
            const _PlaceholderTab(icon: Icons.cloud_upload_rounded, label: 'Upload'),
            const _PlaceholderTab(icon: Icons.account_balance_wallet_rounded, label: 'Earnings'),
            const _PlaceholderTab(icon: Icons.person_rounded, label: 'Profile'),
          ]),
          Positioned(bottom: 0, left: 0, right: 0, child: _BottomNav(current: _navIndex, onTap: _onBottomNavTap)),
          if (_sidebarOpen)
            GestureDetector(
              onTap: _closeSidebar,
              child: FadeTransition(
                opacity: _sidebarFade,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(color: Colors.black.withValues(alpha: 0.5)),
                ),
              ),
            ),
          if (_sidebarOpen)
            Positioned(
              top: 0, right: 0, bottom: 0,
              child: SlideTransition(
                position: _sidebarSlide,
                child: _SidebarPanel(
                  onClose: _closeSidebar, onNavigate: _navigate, onLogout: _logout,
                  userName: (me?['name'] as String?) ?? _user?.displayName ?? 'Artist',
                  avatarUrl: (me?['avatar'] as String?) ?? _user?.photoURL,
                  userEmail: _user?.email ?? '', uid: _user?.uid,
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  FEED HOME
// ════════════════════════════════════════════════════════════════════
enum _FeedTab { forYou, following, people }

class _FeedHome extends StatefulWidget {
  final User? currentUser;
  final VoidCallback onMenu;
  const _FeedHome({super.key, required this.currentUser, required this.onMenu});
  @override
  State<_FeedHome> createState() => _FeedHomeState();
}

class _FeedHomeState extends State<_FeedHome> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  final _rng = Random();
  final _db = FirebaseFirestore.instance;

  _FeedTab _tab = _FeedTab.forYou;
  bool _searchOpen = false, _refreshing = false, _booted = false;
  String _myName = 'Artist', _myAvatar = '';
  DateTime? _lastRefresh;

  Set<String> _following = {}, _liked = {}, _seenStories = {}, _likedStories = {};
  List<Map<String, dynamic>> _pool = [], _view = [];
  // Display order (post ids). Only ever appended to between refreshes, so
  // loading more posts never moves anything you have already scrolled past.
  List<String> _order = [];
  int? _lastPostAt;
  bool _hasMore = true, _loading = false;
  int _autoPages = 0;
  final Map<String, double> _keys = {};

  Map<String, List<Map<String, dynamic>>> _stories = {};
  int _unread = 0;
  Timestamp? _seenAt;
  Map<String, dynamic>? _ad;
  bool _adGone = false;

  List<Map<String, dynamic>> _people = [], _remote = [];
  DocumentSnapshot? _peopleLast;
  bool _peopleMore = true, _peopleBusy = false;
  Timer? _debounce;

  User? get _user => widget.currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 700) _loadPosts();
    });
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && _booted) _refreshBadge();
  }

  Future<void> _bootstrap() async {
    final uid = _user?.uid;
    if (uid == null) return;
    await _Local.init();
    _liked = _Local.getSet('liked_$uid');
    _following = _Local.getSet('following_$uid');
    _seenStories = _Local.getSet('seenst_$uid');
    _likedStories = _Local.getSet('likedst_$uid');
    _loadAd();
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final d = snap.data() ?? {};
      UserInfoCache.instance.primeFromDoc(uid, d, persist: true);
      final me = UserInfoCache.instance.peek(uid)!;
      _myName = me['name']; _myAvatar = me['avatar'];
      _seenAt = d['notifSeenAt'] as Timestamp?;
      if (_seenAt == null) {
        _seenAt = Timestamp.now();
        _db.collection('users').doc(uid).set({'notifSeenAt': _seenAt}, SetOptions(merge: true)).catchError((_) {});
      }
      // Re-read the following list only if the saved copy looks out of date.
      final fc = (d['followingCount'] as num?)?.toInt();
      if (!_Local.has('following_$uid') || (fc != null && fc != _following.length)) await _syncFollowing(uid);
    } catch (_) {}
    await Future.wait([_loadPosts(reset: true), _loadStories(), _refreshBadge()]);
    _lastRefresh = DateTime.now();
    _booted = true;
    if (mounted) setState(() {});
  }

  Future<void> _syncFollowing(String uid) async {
    try {
      final s = await _db.collection('users').doc(uid).collection('following').get();
      _following = s.docs.map((d) => d.id).toSet();
      await _Local.putSet('following_$uid', _following, max: 5000);
    } catch (_) {}
  }

  Future<void> _loadAd() async {
    try {
      final s = await _db.collection('siteAds').orderBy('createdAt', descending: true).limit(1).get();
      if (s.docs.isEmpty) return;
      final d = s.docs.first.data();
      if ((d['imageUrl'] ?? '').toString().isEmpty || (d['linkUrl'] ?? '').toString().isEmpty) return;
      if (mounted) setState(() => _ad = d);
    } catch (_) {}
  }

  // Called when Home is tapped while already on Home. Scrolls up always,
  // but only goes back to Firestore if the last refresh was 45+ seconds ago.
  void scrollToTopAndRefresh() {
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    final last = _lastRefresh;
    if (last != null && DateTime.now().difference(last) < const Duration(seconds: 45)) return;
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    _lastRefresh = DateTime.now();
    if (mounted) setState(() => _refreshing = true);
    await Future.wait([_loadPosts(reset: true), _loadStories(), _refreshBadge()]);
    if (mounted) setState(() => _refreshing = false);
  }

  // ── Posts: one page at a time, shared by For You and Following ──
  Future<void> _loadPosts({bool reset = false}) async {
    if (reset) {
      // A refresh waits for a page that is mid-load instead of being dropped.
      for (var i = 0; _loading && i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_loading) return;
    } else if (_loading || !_hasMore) {
      return;
    }
    _loading = true;
    try {
      final path = (!reset && _lastPostAt != null)
          ? '/posts?limit=$_pageSize&before=$_lastPostAt'
          : '/posts?limit=$_pageSize';
      final fresh = ((await _Api.get(path)) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (final p in fresh) {
        if (p['liked'] == true) {
          _liked.add(p['id'] as String);
        } else {
          _liked.remove(p['id'] as String);
        }
      }
      if (reset) {
        _keys.clear(); _autoPages = 0;
        _pool = fresh;
        _order = _sortedIds(fresh);
      } else {
        final have = _pool.map((p) => p['id']).toSet();
        final added = fresh.where((p) => !have.contains(p['id'])).toList();
        _pool = [..._pool, ...added];
        _order = [..._order, ..._sortedIds(added)];
      }
      if (fresh.isNotEmpty) _lastPostAt = (fresh.last['createdAt'] as num).toInt();
      _hasMore = fresh.length == _pageSize;
    } catch (_) {
    } finally {
      _loading = false;
      _recompute();
    }
  }

  // Recency x random draw; accounts you follow get a 2x boost. Keys stay
  // fixed until the next refresh so the feed never reshuffles under a thumb.
  double _key(Map<String, dynamic> p) => _keys.putIfAbsent(p['id'] as String, () {
        final t = _dt(p['createdAt']);
        final hrs = t == null ? 999.0 : DateTime.now().difference(t).inMinutes / 60.0;
        var w = max(0.2, pow(0.5, hrs / 72.0).toDouble());
        if (_following.contains(p['authorUid'])) w *= 2;
        return pow(max(1e-9, _rng.nextDouble()), 1.0 / w).toDouble();
      });

  List<String> _sortedIds(List<Map<String, dynamic>> list) {
    final s = [...list]..sort((a, b) => _key(b).compareTo(_key(a)));
    return s.map((p) => p['id'] as String).toList();
  }

  void _recompute() {
    final term = _searchCtrl.text.trim().toLowerCase();
    final byId = {for (final p in _pool) p['id'] as String: p};
    Iterable<Map<String, dynamic>> list = _order.map((id) => byId[id]).whereType<Map<String, dynamic>>();
    if (_tab == _FeedTab.following) {
      list = list.where((p) => _following.contains(p['authorUid']) || p['authorUid'] == _user?.uid);
    }
    if (term.isNotEmpty && _tab != _FeedTab.people) {
      list = list.where((p) =>
          (p['text'] ?? '').toString().toLowerCase().contains(term) ||
          (p['authorName'] ?? '').toString().toLowerCase().contains(term));
    }
    _view = list.toList();
    if (mounted) setState(() {});
    if (_tab == _FeedTab.following && _view.length < 6 && _hasMore && !_loading && _autoPages < 3) {
      _autoPages++;
      _loadPosts();
    }
  }

  // ── Stories: newest 40, loaded once ──
  Future<void> _loadStories() async {
    try {
      final list = ((await _Api.get('/stories')) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final map = <String, List<Map<String, dynamic>>>{};
      for (final s in list) {
        map.putIfAbsent(s['authorUid'] as String, () => []).add(s);
        final id = s['id'] as String;
        if (s['seen'] == true) _seenStories.add(id);
        if (s['liked'] == true) {
          _likedStories.add(id);
        } else {
          _likedStories.remove(id);
        }
      }
      map.updateAll((k, v) => v.reversed.toList());
      if (mounted) setState(() => _stories = map);
    } catch (_) {}
  }

  bool _storySeen(String uid) => (_stories[uid] ?? []).every((s) => _seenStories.contains(s['id']));

  // ── Notifications: unread = newer than notifSeenAt ──
  Future<void> _refreshBadge() async {
    if (_user == null) return;
    try {
      final r = await _Api.get('/notifications/count');
      if (mounted && r is Map) setState(() => _unread = (r['count'] as num?)?.toInt() ?? 0);
    } catch (_) {}
  }

  void _openNotifications() {
    final before = _seenAt, now = Timestamp.now();
    setState(() { _unread = 0; _seenAt = now; });
    // the "seen" marker is kept on the API now
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _NotificationsSheet(uid: _user!.uid, seenBefore: before),
    );
  }

  // ── People: 20 per page, search over loaded + a small server lookup ──
  Future<void> _loadPeople({bool reset = false}) async {
    if (_user == null || _peopleBusy || (!reset && !_peopleMore)) return;
    _peopleBusy = true;
    try {
      Query<Map<String, dynamic>> q = _db.collection('users').orderBy(FieldPath.documentId).limit(_pageSize);
      if (!reset && _peopleLast != null) q = q.startAfterDocument(_peopleLast!);
      final snap = await q.get();
      final add = <Map<String, dynamic>>[];
      for (final d in snap.docs) {
        if (d.id == _user!.uid) continue;
        UserInfoCache.instance.primeFromDoc(d.id, d.data());
        add.add({'uid': d.id, ...UserInfoCache.instance.peek(d.id)!});
      }
      _people = reset ? add : [..._people, ...add];
      _peopleMore = snap.docs.length == _pageSize;
      if (snap.docs.isNotEmpty) _peopleLast = snap.docs.last;
    } catch (_) {
    } finally {
      _peopleBusy = false;
      if (mounted) setState(() {});
    }
  }

  void _onSearchChanged(String _) {
    if (_tab != _FeedTab.people) {
      _recompute();
      return;
    }
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _remoteSearch);
  }

  Future<void> _remoteSearch() async {
    final t = _searchCtrl.text.trim();
    if (t.length < 2) { if (mounted) setState(() => _remote = []); return; }
    final cap = t[0].toUpperCase() + t.substring(1);
    try {
      final found = <String, Map<String, dynamic>>{};
      for (final v in {t, cap}) {
        final s = await _db.collection('users').where('name', isGreaterThanOrEqualTo: v)
            .where('name', isLessThanOrEqualTo: '$v\uf8ff').limit(10).get();
        for (final d in s.docs) {
          if (d.id == _user?.uid) continue;
          UserInfoCache.instance.primeFromDoc(d.id, d.data());
          found[d.id] = {'uid': d.id, ...UserInfoCache.instance.peek(d.id)!};
        }
      }
      if (mounted) setState(() => _remote = found.values.toList());
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _peopleShown {
    final t = _searchCtrl.text.trim().toLowerCase();
    if (t.isEmpty) return _people;
    final local = _people.where((p) => (p['name'] as String).toLowerCase().contains(t)).toList();
    final seen = local.map((p) => p['uid']).toSet();
    return [...local, ..._remote.where((p) => !seen.contains(p['uid']))];
  }

  void _onTab(_FeedTab t) {
    setState(() => _tab = t);
    _searchCtrl.clear();
    _remote = [];
    _autoPages = 0;
    if (t == _FeedTab.people) {
      if (_people.isEmpty) _loadPeople(reset: true);
    } else {
      _recompute();
    }
  }

  // ── Follow / like / delete / edit ──
  Future<void> _toggleFollow(String target) async {
    final me = _user!.uid, was = _following.contains(target);
    setState(() => was ? _following.remove(target) : _following.add(target));
    _Local.putSet('following_$me', _following, max: 5000);
    try {
      final b = _db.batch();
      final mine = _db.collection('users').doc(me), theirs = _db.collection('users').doc(target);
      final inc = FieldValue.increment(was ? -1 : 1);
      if (was) {
        b.delete(mine.collection('following').doc(target));
        b.delete(theirs.collection('followers').doc(me));
      } else {
        b.set(mine.collection('following').doc(target), {'since': FieldValue.serverTimestamp()});
        b.set(theirs.collection('followers').doc(me), {'since': FieldValue.serverTimestamp()});
      }
      b.update(theirs, {'followersCount': inc});
      b.update(mine, {'followingCount': inc});
      await b.commit();
      if (!was) sendNotification(target, 'follow', docId: 'follow_$me');
    } catch (_) {
      if (!mounted) return;
      setState(() => was ? _following.add(target) : _following.remove(target));
      _Local.putSet('following_$me', _following, max: 5000);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final me = _user!.uid, id = post['id'] as String, was = _liked.contains(id);
    int count() => ((post['likesCount'] ?? 0) as num).toInt();
    setState(() {
      was ? _liked.remove(id) : _liked.add(id);
      post['likesCount'] = max(0, count() + (was ? -1 : 1));
    });
    try {
      final r = was ? await _Api.delete('/posts/$id/like') : await _Api.post('/posts/$id/like');
      if (mounted && r is Map && r['likesCount'] is num) {
        setState(() => post['likesCount'] = (r['likesCount'] as num).toInt());
      }
      if (!was) {
        sendNotification(post['authorUid'], 'like', postId: id, postText: post['text'],
            postImage: post['imageUrl'], docId: 'like_${id}_$me');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        was ? _liked.add(id) : _liked.remove(id);
        post['likesCount'] = max(0, count() + (was ? 1 : -1));
      });
    }
  }

  Future<void> _deletePost(String id) async {
    try { await _Api.delete('/posts/$id'); } catch (_) { return; }
    _pool.removeWhere((p) => p['id'] == id);
    _order.remove(id);
    _recompute();
  }

  Future<void> _editPost(String id, String text) async {
    try { await _Api.patch('/posts/$id', {'text': text}); } catch (_) {}
  }

  void _openComments(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _CommentsSheet(
        post: post, myUid: _user!.uid, myName: _myName, myAvatar: _myAvatar,
        onDelta: (d) { if (mounted) setState(() => post['commentsCount'] = max(0, ((post['commentsCount'] ?? 0) as num).toInt() + d)); },
      ),
    );
  }

  void _openShare(Map<String, dynamic> post) {
    _actionSheet(context, [
      _Act('Add to your story', () => _addPostToStory(post)),
    ], title: 'Share');
  }

  Future<void> _addPostToStory(Map<String, dynamic> post) async {
    final from = UserInfoCache.instance.peek(post['authorUid']) ??
        {'name': post['authorName'] ?? 'Artist', 'avatar': post['authorAvatar'] ?? ''};
    try {
      await _Api.post('/stories', {
        'sharedPostId': post['id'],
        'sharedFromName': from['name'], 'sharedFromAvatar': from['avatar'],
        'authorName': _myName, 'authorAvatar': _myAvatar,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't add to your story.")));
      }
      return;
    }
    if (post['authorUid'] != _user!.uid) {
      sendNotification(post['authorUid'], 'story_share', postId: post['id'],
          postText: post['text'], postImage: post['imageUrl'], docId: 'sshare_${post['id']}_${_user!.uid}');
    }
    _loadStories();
  }

  Future<void> _openComposer() async {
    final res = await Navigator.push<Map<String, dynamic>>(context,
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => _NewPostScreen(myName: _myName, myAvatar: _myAvatar)));
    if (res != null && mounted) {
      _pool = [res, ..._pool];
      _order = [res['id'] as String, ..._order];
      _recompute();
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  Future<void> _openStoryComposer() async {
    final ok = await Navigator.push<bool>(context,
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => _StoryComposerScreen(myName: _myName, myAvatar: _myAvatar)));
    if (ok == true) _loadStories();
  }

  void _openStoryViewer(String uid) {
    final list = _stories[uid] ?? [];
    if (list.isEmpty) return;
    final me = _user!.uid;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _StoryViewerScreen(
        stories: list, myUid: me, seen: _seenStories, liked: _likedStories,
        onPersist: () {
          _Local.putSet('seenst_$me', _seenStories);
          _Local.putSet('likedst_$me', _likedStories);
        },
        onDeleted: _loadStories,
      ),
    )).then((_) { if (mounted) setState(() {}); });
  }

  // ── UI ──
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      SafeArea(
        bottom: false,
        child: Column(children: [
          _topBar(),
          AnimatedSize(
            duration: const Duration(milliseconds: 250), curve: const Cubic(0.32, 0.72, 0, 1),
            child: _searchOpen ? _searchField() : const SizedBox(width: double.infinity),
          ),
          _storiesBar(),
          _tabs(),
          if (_refreshing) const LinearProgressIndicator(minHeight: 1.5, color: _white, backgroundColor: _s1),
          Expanded(child: _tab == _FeedTab.people ? _peopleList() : _postsList()),
        ]),
      ),
      if (_ad != null && !_adGone) _adOverlay(),
    ]);
  }

  Widget _topBar() {
    Widget icon(IconData i, VoidCallback onTap, {int badge = 0}) => GestureDetector(
          onTap: onTap, behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 36, height: 36,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(color: _fill, shape: BoxShape.circle),
                  child: Icon(i, color: _white, size: 19),
                ),
                if (badge > 0)
                  Positioned(
                    top: -3, right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: _rose, borderRadius: BorderRadius.circular(20), border: Border.all(color: _black, width: 1.5)),
                      child: Text(badge > 99 ? '99+' : '$badge', style: _ts(10, FontWeight.w700, _white, em: 0)),
                    ),
                  ),
              ]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(children: [
        Text('444Music', style: _ts(25, FontWeight.w700, _white, em: -0.04)),
        const Spacer(),
        icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded, () {
          setState(() => _searchOpen = !_searchOpen);
          if (!_searchOpen) { _searchCtrl.clear(); _remote = []; _recompute(); }
        }),
        icon(Icons.add_rounded, _openComposer),
        icon(Icons.notifications_none_rounded, _openNotifications, badge: _unread),
        icon(Icons.menu_rounded, widget.onMenu),
      ]),
    );
  }

  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Container(
          height: 40,
          decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: _searchCtrl, autofocus: true, onChanged: _onSearchChanged,
            cursorColor: _white,
            textAlignVertical: TextAlignVertical.center,
            style: _ts(16, FontWeight.w400, _white),
            decoration: InputDecoration(
              isDense: true, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
              prefixIcon: const Icon(Icons.search_rounded, color: _t2, size: 18),
              hintText: _tab == _FeedTab.people ? 'Search people' : 'Search posts and hashtags',
              hintStyle: _ts(16, FontWeight.w400, _t2),
            ),
          ),
        ),
      );

  Widget _storiesBar() {
    final uid = _user?.uid;
    final others = _stories.keys.where((k) => k != uid).toList()
      ..sort((a, b) {
        final sa = _storySeen(a) ? 1 : 0, sb = _storySeen(b) ? 1 : 0;
        if (sa != sb) return sa - sb;
        final fa = _following.contains(a) ? 0 : 1, fb = _following.contains(b) ? 0 : 1;
        if (fa != fb) return fa - fb;
        return (_dt(_stories[b]!.last['createdAt']) ?? DateTime(0)).compareTo(_dt(_stories[a]!.last['createdAt']) ?? DateTime(0));
      });
    final mine = _stories[uid] ?? [];
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        children: [
          _StoryBubble(
            label: 'Your story', avatarUrl: _myAvatar, name: _myName,
            ring: mine.isEmpty ? _fill : (_storySeen(uid!) ? _t3 : _white),
            addBadge: true,
            onTap: () => mine.isNotEmpty ? _openStoryViewer(uid!) : _openStoryComposer(),
            onAdd: _openStoryComposer,
          ),
          for (final a in others)
            _StoryBubble(
              label: (_stories[a]!.last['authorName'] ?? 'Artist').toString(),
              avatarUrl: (_stories[a]!.last['authorAvatar'] ?? '').toString(),
              name: (_stories[a]!.last['authorName'] ?? 'Artist').toString(),
              ring: _storySeen(a) ? _t3 : _white,
              onTap: () => _openStoryViewer(a),
            ),
        ],
      ),
    );
  }

  Widget _tabs() {
    Widget t(String label, _FeedTab v) {
      final on = _tab == v;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque, onTap: () => _onTab(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250), curve: const Cubic(0.32, 0.72, 0, 1),
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? _s3 : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              boxShadow: on ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))] : const [],
            ),
            child: Text(label, style: _ts(13.5, FontWeight.w600, on ? _white : _t2)),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(9)),
        child: Row(children: [t('For you', _FeedTab.forYou), t('Following', _FeedTab.following), t('People', _FeedTab.people)]),
      ),
    );
  }

  Widget _postsList() {
    final empty = _view.isEmpty;
    return RefreshIndicator(
      color: _black, backgroundColor: _white, onRefresh: _refreshAll,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6, bottom: 120),
        itemCount: empty ? 1 : _view.length + 1,
        itemBuilder: (context, i) {
          if (empty) {
            return Padding(
              padding: const EdgeInsets.only(top: 90),
              child: Center(
                child: !_booted || _loading
                    ? const CircularProgressIndicator(color: _white, strokeWidth: 2)
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(color: _s1, borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.photo_library_outlined, color: _t2, size: 28),
                        ),
                        const SizedBox(height: 14),
                        Text(_tab == _FeedTab.following ? 'Nothing from people you follow yet' : 'No posts yet',
                            style: _ts(15, FontWeight.w500, _t2)),
                      ]),
              ),
            );
          }
          if (i == _view.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: _hasMore
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _t3, strokeWidth: 2))
                    : Text("You're all caught up", style: _ts(13, FontWeight.w500, _t3)),
              ),
            );
          }
          final p = _view[i];
          return _PostCard(
            key: ValueKey(p['id']), post: p,
            liked: _liked.contains(p['id']),
            isFollowing: _following.contains(p['authorUid']),
            isSelf: p['authorUid'] == _user?.uid,
            onFollow: () => _toggleFollow(p['authorUid']),
            onLike: () => _toggleLike(p),
            onComment: () => _openComments(p),
            onShare: () => _openShare(p),
            onDelete: () => _deletePost(p['id']),
            onEdit: (t) => _editPost(p['id'], t),
          );
        },
      ),
    );
  }

  Widget _peopleList() {
    final list = _peopleShown;
    if (list.isEmpty) {
      return Center(
        child: _peopleBusy || (_people.isEmpty && _peopleMore)
            ? const CircularProgressIndicator(color: _white, strokeWidth: 2)
            : Text('No one found', style: _ts(15, FontWeight.w500, _t2)),
      );
    }
    final searching = _searchCtrl.text.trim().isNotEmpty;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!searching && _peopleMore && !_peopleBusy && n.metrics.pixels >= n.metrics.maxScrollExtent - 400) _loadPeople();
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        itemCount: list.length + (!searching && _peopleMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= list.length) {
            return const Padding(padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _t3, strokeWidth: 2))));
          }
          final p = list[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pushNamed(context, '/viewpro', arguments: p['uid']),
                  child: Row(children: [
                    _Avatar(url: p['avatar'], name: p['name'], size: 48),
                    const SizedBox(width: 12),
                    Flexible(child: Text(p['name'], overflow: TextOverflow.ellipsis,
                        style: _ts(16, FontWeight.w600, _white))),
                    if (p['verified'] == true) Padding(padding: const EdgeInsets.only(left: 4), child: verifiedTick(size: 15)),
                  ]),
                ),
              ),
              _FollowBtn(following: _following.contains(p['uid']), onTap: () => _toggleFollow(p['uid'])),
            ]),
          );
        },
      ),
    );
  }

  Widget _adOverlay() => Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Colors.black.withValues(alpha: 0.72),
            child: SafeArea(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: GestureDetector(
                      onTap: () => openExternalLink((_ad!['linkUrl'] ?? '').toString()),
                      child: CachedNetworkImage(imageUrl: _ad!['imageUrl'], fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => setState(() => _adGone = true),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(999)),
                    child: Text('Dismiss', style: _ts(15, FontWeight.w600, _white)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

// ─── Small shared widgets ──────────────────────────────────────────────
class _FollowBtn extends StatelessWidget {
  final bool following;
  final VoidCallback onTap;
  const _FollowBtn({required this.following, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: following ? _fill : _white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(following ? 'Following' : 'Follow',
              style: _ts(13.5, FontWeight.w600, following ? _white : _black)),
        ),
      );
}

class _Avatar extends StatelessWidget {
  final String? url, name;
  final double size;
  const _Avatar({required this.url, required this.name, this.size = 44});
  @override
  Widget build(BuildContext context) {
    final n = (name ?? 'A').trim();
    final initial = n.isNotEmpty ? n[0].toUpperCase() : 'A';
    Widget fallback() => Center(child: Text(initial, style: _ts(size * 0.4, FontWeight.w600, _white70, em: 0)));
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: _s2),
      clipBehavior: Clip.antiAlias,
      child: (url != null && url!.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: url!, fit: BoxFit.cover, memCacheWidth: (size * 3).round(),
              placeholder: (_, __) => fallback(), errorWidget: (_, __, ___) => fallback())
          : fallback(),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  final String label, avatarUrl, name;
  final Color ring;
  final bool addBadge;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  const _StoryBubble({required this.label, required this.avatarUrl, required this.name, required this.ring,
    required this.onTap, this.addBadge = false, this.onAdd});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 74, margin: const EdgeInsets.only(right: 4),
          child: Column(children: [
            Stack(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: 2)),
                child: _Avatar(url: avatarUrl, name: name, size: 58),
              ),
              if (addBadge)
                Positioned(
                  bottom: 0, right: 0,
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _white, border: Border.all(color: _black, width: 2)),
                      child: const Icon(Icons.add, size: 14, color: _black),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: _ts(11.5, FontWeight.w500, _white70, em: 0)),
          ]),
        ),
      );
}

// ─── Post card — edge to edge ───────────────────────────────────────────
class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool liked, isFollowing, isSelf;
  final VoidCallback onFollow, onLike, onComment, onShare, onDelete;
  final void Function(String text) onEdit;
  const _PostCard({super.key, required this.post, required this.liked, required this.isFollowing, required this.isSelf,
    required this.onFollow, required this.onLike, required this.onComment, required this.onShare,
    required this.onDelete, required this.onEdit});
  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _editing = false, _pop = false;
  late final TextEditingController _editCtrl = TextEditingController(text: widget.post['text'] ?? '');
  // Created once per card, not once per rebuild.
  late final Future<Map<String, dynamic>> _info = UserInfoCache.instance.get(widget.post['authorUid'] as String);

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  void _doubleTap() {
    if (!widget.liked) widget.onLike();
    setState(() => _pop = true);
    Future.delayed(const Duration(milliseconds: 700), () { if (mounted) setState(() => _pop = false); });
  }

  void _saveEdit() {
    final t = _editCtrl.text.trim();
    if (t.isEmpty) return;
    widget.onEdit(t);
    setState(() { widget.post['text'] = t; widget.post['edited'] = true; _editing = false; });
  }

  Widget _photo(String image, double w, double dpr) {
    final aspectRaw = (widget.post['imageAspect'] as num?)?.toDouble();
    final cache = (w * dpr).round();
    Widget broken(double h) => Container(height: h, color: _s1,
        child: const Center(child: Icon(Icons.broken_image_outlined, color: _t3)));
    if (aspectRaw != null && aspectRaw > 0) {
      // Shape is known up front, so nothing jumps when the picture arrives.
      final a = aspectRaw.clamp(0.8, 1.91).toDouble();
      return AspectRatio(
        aspectRatio: a,
        child: CachedNetworkImage(
          imageUrl: image, fit: BoxFit.cover, memCacheWidth: cache,
          fadeInDuration: const Duration(milliseconds: 180),
          placeholder: (_, __) => Container(color: _s1),
          errorWidget: (_, __, ___) => broken(w / a),
        ),
      );
    }
    // Older posts: natural height, capped at 4:5.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: w * 1.25),
      child: CachedNetworkImage(
        imageUrl: image, width: double.infinity, fit: BoxFit.cover, memCacheWidth: cache,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, __) => Container(height: w, color: _s1),
        errorWidget: (_, __, ___) => broken(w * 0.6),
      ),
    );
  }

  void _ownerMenu() {
    _actionSheet(context, [
      _Act('Edit', () => setState(() => _editing = true)),
      _Act('Delete', widget.onDelete, color: _rose),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final uid = p['authorUid'] as String;
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final text = (p['text'] ?? '').toString();
    final image = (p['imageUrl'] ?? '').toString();
    final link = (p['linkUrl'] ?? '').toString();
    final likes = ((p['likesCount'] ?? 0) as num).toInt();
    final comments = ((p['commentsCount'] ?? 0) as num).toInt();
    final created = _dt(p['createdAt']);

    return FutureBuilder<Map<String, dynamic>>(
      future: _info,
      initialData: UserInfoCache.instance.peek(uid) ??
          {'name': p['authorName'] ?? 'Artist', 'avatar': p['authorAvatar'] ?? '', 'verified': false},
      builder: (context, snap) {
        final info = snap.data!;
        final name = (info['name'] ?? 'Artist').toString();

        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 8, 10),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/viewpro', arguments: uid),
                  child: _Avatar(url: info['avatar'], name: name, size: 38),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pushNamed(context, '/viewpro', arguments: uid),
                    child: Row(children: [
                      Flexible(child: Text(name, overflow: TextOverflow.ellipsis,
                          style: _ts(15, FontWeight.w600, _white))),
                      if (info['verified'] == true) Padding(padding: const EdgeInsets.only(left: 4), child: verifiedTick(size: 15)),
                    ]),
                  ),
                ),
                if (!widget.isSelf && !widget.isFollowing)
                  GestureDetector(
                    onTap: widget.onFollow,
                    child: Container(
                      height: 28,
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(999)),
                      child: Text('Follow', style: _ts(13, FontWeight.w600, _white)),
                    ),
                  ),
                if (widget.isSelf)
                  GestureDetector(
                    onTap: _ownerMenu,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.more_horiz_rounded, color: _white70, size: 22),
                    ),
                  ),
              ]),
            ),

            // photo — full width, 4:5 at most
            if (image.isNotEmpty)
              GestureDetector(
                onDoubleTap: _doubleTap,
                child: Stack(alignment: Alignment.center, children: [
                  _photo(image, w, mq.devicePixelRatio),
                  IgnorePointer(
                    child: AnimatedScale(
                      scale: _pop ? 1 : 0.4, duration: const Duration(milliseconds: 240), curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: _pop ? 1 : 0, duration: const Duration(milliseconds: 180),
                        child: const Icon(Icons.favorite_rounded, color: _white, size: 96,
                            shadows: [Shadow(blurRadius: 28, color: Colors.black54)]),
                      ),
                    ),
                  ),
                ]),
              ),

            // text-only posts: the text is the content
            if (image.isEmpty && text.isNotEmpty && !_editing)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                child: Text.rich(TextSpan(children: [
                  ...hashtagSpans(text, base: _ts(17, FontWeight.w400, _white, em: -0.02, height: 1.45)),
                  if (p['edited'] == true) TextSpan(text: '  edited', style: _ts(12, FontWeight.w400, _t3)),
                ])),
              ),

            // actions
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(children: [
                _ActionIcon(
                  icon: widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: widget.liked ? _rose : _white, onTap: widget.onLike),
                _ActionIcon(icon: Icons.mode_comment_outlined, color: _white, onTap: widget.onComment),
                _ActionIcon(icon: Icons.send_outlined, color: _white, onTap: widget.onShare),
              ]),
            ),
            if (likes > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
                child: Text('${formatCount(likes)} like${likes == 1 ? '' : 's'}',
                    style: _ts(14, FontWeight.w600, _white)),
              ),

            // caption (under the photo) or inline editor
            if (_editing)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  TextField(
                    controller: _editCtrl, maxLines: 5, minLines: 1, maxLength: 500,
                    cursorColor: _white,
                    style: _ts(15, FontWeight.w400, _white),
                    decoration: InputDecoration(
                      filled: true, fillColor: _s2,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      counterStyle: _ts(12, FontWeight.w400, _t3)),
                  ),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    GestureDetector(
                      onTap: () => setState(() { _editCtrl.text = text; _editing = false; }),
                      child: Container(
                        height: 34, padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(999)),
                        child: Text('Cancel', style: _ts(14, FontWeight.w600, _white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _saveEdit,
                      child: Container(
                        height: 34, padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(999)),
                        child: Text('Save', style: _ts(14, FontWeight.w600, _black)),
                      ),
                    ),
                  ]),
                ]),
              )
            else if (image.isNotEmpty && text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 5, 14, 0),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '$name  ', style: _ts(15, FontWeight.w600, _white)),
                  ...hashtagSpans(text, base: _ts(15, FontWeight.w400, _white90, height: 1.4)),
                  if (p['edited'] == true) TextSpan(text: '  edited', style: _ts(12, FontWeight.w400, _t3)),
                ])),
              ),

            if (link.isNotEmpty)
              GestureDetector(
                onTap: () => openExternalLink(link),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Row(children: [
                    const Icon(Icons.link_rounded, color: _blue, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(link, overflow: TextOverflow.ellipsis,
                        style: _ts(14, FontWeight.w500, _blue))),
                  ]),
                ),
              ),

            GestureDetector(
              onTap: widget.onComment,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Text(comments > 0 ? 'View all ${formatCount(comments)} comment${comments == 1 ? '' : 's'}' : 'Add a comment…',
                    style: _ts(14, FontWeight.w400, _t2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 5, 14, 0),
              child: Text(timeAgo(created), style: _ts(12, FontWeight.w400, _t3)),
            ),
            Container(
              margin: const EdgeInsets.only(top: 18),
              height: 0.5,
              color: _sep,
            ),
          ]),
        );
      },
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionIcon({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap, behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(icon, key: ValueKey('$icon$color'), color: color, size: 26),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════
//  COMMENTS — loaded once (60), threaded replies, instant local updates
// ═══════════════════════════════════════════════════════════════════════
class _CommentsSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  final String myUid, myName, myAvatar;
  final void Function(int delta) onDelta;
  const _CommentsSheet({required this.post, required this.myUid, required this.myName, required this.myAvatar, required this.onDelta});
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _input = TextEditingController();
  List<Map<String, dynamic>> _all = [];
  bool _loading = true, _sending = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _Api.get('/posts/${widget.post['id']}/comments') as List;
      _all = r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add(String text, String? parentId, String notifyUid, String type) async {
    try {
      final res = await _Api.post('/posts/${widget.post['id']}/comments', {
        'text': text, 'parentId': parentId,
        'authorName': widget.myName, 'authorAvatar': widget.myAvatar,
      });
      if (mounted) setState(() => _all.add(Map<String, dynamic>.from(res as Map)));
      widget.onDelta(1);
      sendNotification(notifyUid, type, postId: widget.post['id'], postText: widget.post['text'],
          postImage: widget.post['imageUrl'], commentText: text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't post your comment.")));
      }
    }
  }

  Future<void> _submit() async {
    final t = _input.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      await _add(t, null, widget.post['authorUid'], 'comment');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String id) async {
    final before = List<Map<String, dynamic>>.from(_all);
    setState(() => _all.removeWhere((c) => c['id'] == id || c['parentId'] == id));
    final removed = before.length - _all.length;
    widget.onDelta(-removed);
    try {
      await _Api.delete('/comments/$id');
    } catch (_) {
      if (!mounted) return;
      setState(() => _all = before);
      widget.onDelta(removed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = _all.where((c) => c['parentId'] == null).toList();
    final replies = <String, List<Map<String, dynamic>>>{};
    for (final c in _all) {
      if (c['parentId'] != null) replies.putIfAbsent(c['parentId'] as String, () => []).add(c);
    }
    final canSend = _input.text.trim().isNotEmpty;
    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.95,
      builder: (context, scroll) => Container(
        decoration: _sheetDecoration,
        child: Column(children: [
          _sheetHeader('Comments'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _white, strokeWidth: 2))
                : top.isEmpty
                    ? Center(child: Text('No comments yet.', style: _ts(15, FontWeight.w400, _t2)))
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: top.length,
                        itemBuilder: (context, i) => _CommentRow(
                          comment: top[i], replies: replies[top[i]['id']] ?? [], myUid: widget.myUid,
                          onDelete: _delete,
                          onReply: (t) => _add(t, top[i]['id'] as String, top[i]['authorUid'] as String, 'reply'),
                        ),
                      ),
          ),
          Container(height: 0.5, color: _sep),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 12, 10 + MediaQuery.of(context).viewInsets.bottom),
              child: Row(children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(20)),
                    child: TextField(
                      controller: _input, onSubmitted: (_) => _submit(),
                      cursorColor: _white,
                      style: _ts(16, FontWeight.w400, _white),
                      decoration: InputDecoration(
                        isDense: true, hintText: 'Add a comment…',
                        hintStyle: _ts(16, FontWeight.w400, _t2),
                        border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _submit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: canSend ? _white : _fill, shape: BoxShape.circle),
                    child: Icon(Icons.arrow_upward_rounded, color: canSend ? _black : _t3, size: 20),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CommentRow extends StatefulWidget {
  final Map<String, dynamic> comment;
  final List<Map<String, dynamic>> replies;
  final String myUid;
  final void Function(String id) onDelete;
  final void Function(String text) onReply;
  const _CommentRow({required this.comment, required this.replies, required this.myUid, required this.onDelete, required this.onReply});
  @override
  State<_CommentRow> createState() => _CommentRowState();
}

class _CommentRowState extends State<_CommentRow> {
  bool _replying = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _askDelete(String id) async {
    final ok = await _confirm(
      context,
      title: 'Delete comment?',
      message: "This can't be undone.",
      cancel: 'Cancel',
      ok: 'Delete',
      destructive: true,
    );
    if (ok) widget.onDelete(id);
  }

  Widget _line(Map<String, dynamic> c, {required double avatar}) {
    final uid = c['authorUid'] as String;
    return FutureBuilder<Map<String, dynamic>>(
      future: UserInfoCache.instance.get(uid),
      initialData: UserInfoCache.instance.peek(uid) ?? {'name': c['authorName'] ?? 'Artist', 'avatar': c['authorAvatar'] ?? '', 'verified': false},
      builder: (context, snap) {
        final i = snap.data!;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Avatar(url: i['avatar'], name: i['name'], size: avatar),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(i['name'], overflow: TextOverflow.ellipsis,
                      style: _ts(13.5, FontWeight.w600, _white))),
                  if (i['verified'] == true) Padding(padding: const EdgeInsets.only(left: 3), child: verifiedTick(size: 12)),
                  const SizedBox(width: 8),
                  Text(timeAgo(_dt(c['createdAt'])), style: _ts(12, FontWeight.w400, _t3)),
                ]),
                const SizedBox(height: 2),
                Text.rich(TextSpan(children: hashtagSpans(c['text'] ?? '', base: _ts(14.5, FontWeight.w400, _white90, height: 1.4)))),
              ]),
            ),
            if (c['authorUid'] == widget.myUid)
              GestureDetector(
                onTap: () => _askDelete(c['id'] as String),
                child: const Padding(padding: EdgeInsets.only(left: 8, top: 2), child: Icon(Icons.delete_outline_rounded, color: _t2, size: 18)),
              ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _line(widget.comment, avatar: 34),
      Padding(
        padding: const EdgeInsets.only(left: 44),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => setState(() => _replying = !_replying),
            child: Text('Reply', style: _ts(12.5, FontWeight.w600, _t2)),
          ),
          if (_replying)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(18)),
                    child: TextField(
                      controller: _ctrl, autofocus: true, cursorColor: _white,
                      style: _ts(15, FontWeight.w400, _white),
                      decoration: InputDecoration(
                        isDense: true, hintText: 'Write a reply…',
                        hintStyle: _ts(15, FontWeight.w400, _t2),
                        border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(color: _white, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_upward_rounded, color: _black, size: 18),
                  ),
                ),
              ]),
            ),
          for (final r in widget.replies) _line(r, avatar: 28),
        ]),
      ),
      const SizedBox(height: 4),
    ]);
  }

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    widget.onReply(t);
    _ctrl.clear();
    setState(() => _replying = false);
  }
}

// ─── Notifications sheet ────────────────────────────────────────────────
class _NotificationsSheet extends StatefulWidget {
  final String uid;
  final Timestamp? seenBefore;
  const _NotificationsSheet({required this.uid, required this.seenBefore});
  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  int? _seenBefore;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final seen = await _Api.post('/notifications/seen');
      if (seen is Map) _seenBefore = (seen['seenBefore'] as num?)?.toInt();
      final r = await _Api.get('/notifications') as List;
      _items = r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _text(Map<String, dynamic> n) {
    final who = n['fromName'] ?? 'Someone';
    switch (n['type']) {
      case 'follow': return '$who started following you';
      case 'like': return '$who liked your post';
      case 'story_like': return '$who liked your story';
      case 'comment': return '$who commented on your post';
      case 'reply': return '$who replied to your comment';
      case 'story_share': return '$who added your post to their story';
      case 'system': return '$who: ${n['commentText'] ?? ''}';
      default: return '$who sent you a notification';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.95,
      builder: (context, scroll) => Container(
        decoration: _sheetDecoration,
        child: Column(children: [
          _sheetHeader('Notifications'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _white, strokeWidth: 2))
                : _items.isEmpty
                    ? Center(child: Text('Nothing here yet.', style: _ts(15, FontWeight.w400, _t2)))
                    : ListView.separated(
                        controller: scroll, itemCount: _items.length,
                        separatorBuilder: (_, __) => Container(height: 0.5, margin: const EdgeInsets.only(left: 72), color: _sep),
                        itemBuilder: (context, i) {
                          final n = _items[i];
                          final created = (n['createdAt'] as num?)?.toInt();
                          final unread = _seenBefore != null && created != null && created > _seenBefore!;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              Navigator.pop(context);
                              if (n['fromUid'] != null) Navigator.pushNamed(context, '/viewpro', arguments: n['fromUid']);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(children: [
                                _Avatar(url: n['fromAvatar'], name: n['fromName'], size: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(_text(n), style: _ts(15, unread ? FontWeight.w600 : FontWeight.w400, _white90, height: 1.3)),
                                    const SizedBox(height: 2),
                                    Text(timeAgo(_dt(created)), style: _ts(13, FontWeight.w400, _t2)),
                                  ]),
                                ),
                                if (unread)
                                  Container(width: 9, height: 9, margin: const EdgeInsets.only(left: 10),
                                      decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle)),
                              ]),
                            ),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

// ─── Composer top bar (Cancel · Title · Action) ─────────────────────────
Widget _composerBar(BuildContext context, {required String title, Widget? trailing}) => Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _sep, width: 0.5))),
      child: Row(children: [
        SizedBox(
          width: 70,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text('Cancel', style: _ts(17, FontWeight.w400, _blue)),
          ),
        ),
        Expanded(child: Center(child: Text(title, style: _ts(17, FontWeight.w600, _white)))),
        SizedBox(width: 70, child: Align(alignment: Alignment.centerRight, child: trailing)),
      ]),
    );

// ─── New post composer ──────────────────────────────────────────────────
class _NewPostScreen extends StatefulWidget {
  final String myName, myAvatar;
  const _NewPostScreen({required this.myName, required this.myAvatar});
  @override
  State<_NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<_NewPostScreen> {
  final _text = TextEditingController(), _link = TextEditingController();
  XFile? _image;
  bool _showLink = false, _busy = false;

  @override
  void dispose() {
    _text.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
    if (f != null) setState(() => _image = f);
  }

  Future<void> _publish() async {
    final text = _text.text.trim(), link = _link.text.trim();
    if (text.isEmpty && _image == null && link.isEmpty) return;
    setState(() => _busy = true);
    try {
      final me = FirebaseAuth.instance.currentUser!;
      String? url;
      double? aspect;
      if (_image != null) {
        url = await _uploadToR2(_image!, kind: 'post', uid: me.uid);
        if (url == null) throw Exception('upload failed');
        aspect = await _aspectOf(_image!);
      }
      final res = await _Api.post('/posts', {
        'text': text, 'mediaKey': url, 'linkUrl': link.isEmpty ? null : link,
        'imageAspect': aspect, 'authorName': widget.myName, 'authorAvatar': widget.myAvatar,
      });
      if (mounted) Navigator.pop(context, Map<String, dynamic>.from(res as Map));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't publish. Please try again.")));
        setState(() => _busy = false);
      }
    }
  }

  Widget _pill(IconData icon, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: _white, size: 17),
            const SizedBox(width: 7),
            Text(label, style: _ts(14, FontWeight.w600, _white)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      body: SafeArea(
        child: Column(children: [
          _composerBar(
            context,
            title: 'New post',
            trailing: GestureDetector(
              onTap: _busy ? null : _publish,
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _white))
                  : Text('Share', style: _ts(17, FontWeight.w600, _blue)),
            ),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Avatar(url: widget.myAvatar, name: widget.myName, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _text, maxLines: 8, minLines: 3, maxLength: 500, cursorColor: _white,
                    style: _ts(17, FontWeight.w400, _white, height: 1.4),
                    decoration: InputDecoration(
                      border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                      counterStyle: _ts(12, FontWeight.w400, _t3),
                      hintText: 'Write something…', hintStyle: _ts(17, FontWeight.w400, _t2)),
                  ),
                ),
              ]),
              if (_image != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(io.File(_image!.path), width: double.infinity, fit: BoxFit.cover)),
                    Positioned(
                      top: 10, right: 10,
                      child: GestureDetector(
                        onTap: () => setState(() => _image = null),
                        child: Container(
                          width: 30, height: 30,
                          decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, color: _white, size: 17)),
                      ),
                    ),
                  ]),
                ),
              if (_showLink)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: _link, cursorColor: _white,
                      style: _ts(16, FontWeight.w400, _white),
                      decoration: InputDecoration(
                        hintText: 'Paste a link…', hintStyle: _ts(16, FontWeight.w400, _t2),
                        border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(children: [
                _pill(Icons.image_outlined, 'Photo', _pick),
                _pill(Icons.link_rounded, 'Link', () => setState(() => _showLink = !_showLink)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Story composer ─────────────────────────────────────────────────────
class _StoryComposerScreen extends StatefulWidget {
  final String myName, myAvatar;
  const _StoryComposerScreen({required this.myName, required this.myAvatar});
  @override
  State<_StoryComposerScreen> createState() => _StoryComposerScreenState();
}

class _StoryComposerScreenState extends State<_StoryComposerScreen> {
  String _type = 'image';
  XFile? _image;
  final _text = TextEditingController(), _link = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    _link.dispose();
    super.dispose();
  }

  bool get _can => _type == 'image' ? _image != null : _type == 'text' ? _text.text.trim().isNotEmpty : _link.text.trim().isNotEmpty;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final me = FirebaseAuth.instance.currentUser!;
      final data = <String, dynamic>{
        'type': _type,
        'authorName': widget.myName, 'authorAvatar': widget.myAvatar,
      };
      if (_type == 'image') {
        final key = await _uploadToR2(_image!, kind: 'story', uid: me.uid);
        if (key == null) throw Exception('upload failed');
        data['mediaKey'] = key;
      } else if (_type == 'text') {
        data['text'] = _text.text.trim();
      } else {
        data['linkUrl'] = _link.text.trim();
      }
      await _Api.post('/stories', data);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't share your story.")));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String hint) => InputDecoration(
        filled: true, fillColor: _fill, hintText: hint, hintStyle: _ts(16, FontWeight.w400, _t2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        counterStyle: _ts(12, FontWeight.w400, _t3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));
    return Scaffold(
      backgroundColor: _black,
      body: SafeArea(
        child: Column(children: [
          _composerBar(context, title: 'Your story'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(9)),
                  child: Row(children: [
                    for (final t in ['image', 'text', 'link'])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _type = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _type == t ? _s3 : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: _type == t ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))] : const [],
                            ),
                            child: Text(t == 'image' ? 'Photo' : t == 'text' ? 'Text' : 'Link',
                                style: _ts(14, FontWeight.w600, _type == t ? _white : _t2)),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 20),
                if (_type == 'image')
                  _image == null
                      ? GestureDetector(
                          onTap: () async {
                            final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1440);
                            if (f != null) setState(() => _image = f);
                          },
                          child: Container(
                            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 40),
                            decoration: BoxDecoration(color: _s1, borderRadius: BorderRadius.circular(16)),
                            child: Column(children: [
                              Container(
                                width: 48, height: 48,
                                decoration: const BoxDecoration(color: _fill, shape: BoxShape.circle),
                                child: const Icon(Icons.image_outlined, color: _white, size: 22),
                              ),
                              const SizedBox(height: 12),
                              Text('Choose a photo', style: _ts(16, FontWeight.w500, _white)),
                            ]),
                          ),
                        )
                      : ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(io.File(_image!.path), height: 280, width: double.infinity, fit: BoxFit.cover)),
                if (_type == 'text')
                  TextField(controller: _text, maxLength: 280, maxLines: 6, onChanged: (_) => setState(() {}), cursorColor: _white,
                      style: _ts(16, FontWeight.w400, _white), decoration: deco('Share something…')),
                if (_type == 'link')
                  TextField(controller: _link, onChanged: (_) => setState(() {}), cursorColor: _white,
                      style: _ts(16, FontWeight.w400, _white), decoration: deco('Paste a link…')),
                const Spacer(),
                GestureDetector(
                  onTap: _can && !_busy ? _share : null,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _can ? 1 : 0.4,
                    child: Container(
                      width: double.infinity, height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(999)),
                      child: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: _black))
                          : Text('Share to story', style: _ts(17, FontWeight.w600, _black)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Story viewer (hold to pause, tap sides to move) ────────────────────
class _StoryViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final String myUid;
  final Set<String> seen, liked;
  final VoidCallback onPersist, onDeleted;
  const _StoryViewerScreen({required this.stories, required this.myUid, required this.seen, required this.liked,
    required this.onPersist, required this.onDeleted});
  @override
  State<_StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<_StoryViewerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Map<String, dynamic>> _stories;
  int _index = 0;
  final Map<String, int> _viewerCounts = {};

  @override
  void initState() {
    super.initState();
    _stories = [...widget.stories];
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..addStatusListener((s) { if (s == AnimationStatus.completed) _show(_index + 1); });
    // Start on the first story that hasn't been seen yet.
    final firstNew = _stories.indexWhere((s) => !widget.seen.contains(s['id']));
    _show(firstNew < 0 ? 0 : firstNew);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _show(int i) {
    if (i < 0 || i >= _stories.length) { Navigator.pop(context); return; }
    setState(() => _index = i);
    _ctrl.reset();
    _ctrl.forward();
    final s = _stories[i], id = s['id'] as String;
    if (s['authorUid'] == widget.myUid) {
      if (!_viewerCounts.containsKey(id)) {
        _Api.get('/stories/$id/viewers').then((r) {
          if (mounted && r is Map) setState(() => _viewerCounts[id] = (r['count'] as num?)?.toInt() ?? 0);
        }).catchError((_) {});
      }
    } else if (!widget.seen.contains(id)) {
      widget.seen.add(id);
      widget.onPersist();
      _Api.post('/stories/$id/view').catchError((_) {});
    }
  }

  Future<void> _toggleLike() async {
    final s = _stories[_index], id = s['id'] as String, was = widget.liked.contains(id);
    setState(() => was ? widget.liked.remove(id) : widget.liked.add(id));
    widget.onPersist();
    try {
      if (was) {
        await _Api.delete('/stories/$id/like');
      } else {
        await _Api.post('/stories/$id/like');
        sendNotification(s['authorUid'], 'story_like', docId: 'slike_${id}_${widget.myUid}');
      }
    } catch (_) {
      if (mounted) setState(() => was ? widget.liked.add(id) : widget.liked.remove(id));
      widget.onPersist();
    }
  }

  Future<void> _delete() async {
    final s = _stories[_index];
    if (s['authorUid'] != widget.myUid) return;
    _ctrl.stop();
    final ok = await _confirm(
      context,
      title: 'Delete this story?',
      message: "This can't be undone.",
      cancel: 'Cancel',
      ok: 'Delete',
      destructive: true,
    );
    if (!ok) { _ctrl.forward(); return; }
    try { await _Api.delete('/stories/${s['id']}'); } catch (_) { if (mounted) _ctrl.forward(); return; }
    _stories.removeAt(_index);
    widget.onDeleted();
    if (_stories.isEmpty) { if (mounted) Navigator.pop(context); return; }
    _show(_index >= _stories.length ? _stories.length - 1 : _index);
  }

  void _openViewers() {
    _ctrl.stop();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _StoryViewersSheet(storyId: _stories[_index]['id']),
    ).then((_) => _ctrl.forward());
  }

  @override
  Widget build(BuildContext context) {
    final s = _stories[_index], id = s['id'] as String;
    final own = s['authorUid'] == widget.myUid;
    final created = _dt(s['createdAt']);
    final w = MediaQuery.of(context).size.width;
    final liked = widget.liked.contains(id);

    return Scaffold(
      backgroundColor: _black,
      body: SafeArea(
        child: GestureDetector(
          onLongPressStart: (_) => _ctrl.stop(),
          onLongPressEnd: (_) => _ctrl.forward(),
          child: Stack(children: [
            Positioned(
              top: 8, left: 10, right: 10,
              child: Row(children: List.generate(_stories.length, (i) => Expanded(
                child: Container(
                  height: 2.5, margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(3)),
                  child: i < _index
                      ? Container(decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(3)))
                      : i == _index
                          ? AnimatedBuilder(
                              animation: _ctrl,
                              builder: (_, __) => FractionallySizedBox(
                                widthFactor: _ctrl.value, alignment: Alignment.centerLeft,
                                child: Container(decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(3)))),
                            )
                          : const SizedBox.shrink(),
                ),
              ))),
            ),
            Positioned(
              top: 20, left: 14, right: 8,
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pushReplacementNamed(context, '/viewpro', arguments: s['authorUid']),
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: UserInfoCache.instance.get(s['authorUid']),
                      initialData: UserInfoCache.instance.peek(s['authorUid']) ?? {'name': s['authorName'] ?? 'Artist', 'avatar': s['authorAvatar'] ?? '', 'verified': false},
                      builder: (context, snap) {
                        final i = snap.data!;
                        return Row(children: [
                          _Avatar(url: i['avatar'], name: i['name'], size: 36),
                          const SizedBox(width: 10),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(i['name'] ?? 'Artist', style: _ts(15, FontWeight.w600, _white)),
                              if (i['verified'] == true) Padding(padding: const EdgeInsets.only(left: 4), child: verifiedTick(size: 13)),
                            ]),
                            Text(timeAgo(created), style: _ts(12, FontWeight.w400, _t2)),
                          ]),
                        ]);
                      },
                    ),
                  ),
                ),
                if (own) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded, color: _white70)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: _white)),
              ]),
            ),
            Positioned.fill(
              top: 76, bottom: 76,
              child: Center(
                child: s['type'] == 'image' && (s['imageUrl'] ?? '').toString().isNotEmpty
                    ? CachedNetworkImage(imageUrl: s['imageUrl'], fit: BoxFit.contain, width: double.infinity)
                    : s['type'] == 'link' && (s['linkUrl'] ?? '').toString().isNotEmpty
                        ? GestureDetector(
                            onTap: () => openExternalLink((s['linkUrl'] ?? '').toString()),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(color: _s1, borderRadius: BorderRadius.circular(16)),
                              child: Row(children: [
                                const Icon(Icons.link_rounded, color: _blue),
                                const SizedBox(width: 10),
                                Expanded(child: Text(s['linkUrl'], overflow: TextOverflow.ellipsis, style: _ts(15, FontWeight.w400, _white90))),
                              ]),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(s['text'] ?? '', textAlign: TextAlign.center,
                                style: _ts(26, FontWeight.w600, _white, em: -0.03, height: 1.35)),
                          ),
              ),
            ),
            if (s['sharedFromUid'] != null)
              Positioned(
                top: 84, left: 14,
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, '/viewpro', arguments: s['sharedFromUid']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.repeat_rounded, color: _white, size: 14),
                      const SizedBox(width: 6),
                      Text(s['sharedFromName'] ?? 'Original post', style: _ts(12.5, FontWeight.w600, _white, em: 0)),
                    ]),
                  ),
                ),
              ),
            Positioned(top: 76, bottom: 76, left: 0, width: w / 3,
                child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => _show(_index - 1))),
            Positioned(top: 76, bottom: 76, right: 0, width: w / 3,
                child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => _show(_index + 1))),
            Positioned(
              bottom: 16, left: 0, right: 0,
              child: Center(
                child: own
                    ? GestureDetector(
                        onTap: _openViewers,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(999)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.visibility_outlined, color: _white90, size: 17),
                            const SizedBox(width: 8),
                            Text('${_viewerCounts[id] ?? 0} viewer${(_viewerCounts[id] ?? 0) == 1 ? '' : 's'}',
                                style: _ts(14, FontWeight.w600, _white90)),
                          ]),
                        ),
                      )
                    : GestureDetector(
                        onTap: _toggleLike,
                        child: Container(
                          width: 48, height: 48,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33FFFFFF)),
                          child: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: liked ? _rose : _white90, size: 22),
                        ),
                      ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// Loads the viewer list once per sheet (not once per rebuild).
class _StoryViewersSheet extends StatefulWidget {
  final String storyId;
  const _StoryViewersSheet({required this.storyId});
  @override
  State<_StoryViewersSheet> createState() => _StoryViewersSheetState();
}

class _StoryViewersSheetState extends State<_StoryViewersSheet> {
  late final Future<List<String>> _future = _load();

  Future<List<String>> _load() async {
    final r = await _Api.get('/stories/${widget.storyId}/viewers') as Map;
    return (r['ids'] as List).map((e) => e.toString()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55, minChildSize: 0.3, maxChildSize: 0.9,
      builder: (context, scroll) => Container(
        decoration: _sheetDecoration,
        child: Column(children: [
          _sheetHeader('Viewers'),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text("Couldn't load viewers.", style: _ts(15, FontWeight.w400, _t2)));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _white, strokeWidth: 2));
                final ids = snap.data!;
                if (ids.isEmpty) return Center(child: Text('No views yet.', style: _ts(15, FontWeight.w400, _t2)));
                return ListView.separated(
                  controller: scroll, itemCount: ids.length,
                  separatorBuilder: (_, __) => Container(height: 0.5, margin: const EdgeInsets.only(left: 68), color: _sep),
                  itemBuilder: (context, i) => FutureBuilder<Map<String, dynamic>>(
                    future: UserInfoCache.instance.get(ids[i]),
                    initialData: UserInfoCache.instance.peek(ids[i]),
                    builder: (context, s) {
                      final info = s.data ?? {'name': 'Artist', 'avatar': ''};
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.pushNamed(context, '/viewpro', arguments: ids[i]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(children: [
                            _Avatar(url: info['avatar'], name: info['name'], size: 42),
                            const SizedBox(width: 12),
                            Expanded(child: Text(info['name'], overflow: TextOverflow.ellipsis, style: _ts(16, FontWeight.w500, _white90))),
                          ]),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  BOTTOM NAVIGATION BAR — solid background (no live blur)
// ════════════════════════════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Analytics'),
    (Icons.cloud_upload_rounded, Icons.cloud_upload_outlined, 'Upload'),
    (Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Earnings'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, bottom + 6),
      decoration: BoxDecoration(
        color: _black.withValues(alpha: 0.97),
        border: const Border(top: BorderSide(color: _sep, width: 0.5)),
      ),
      child: Row(
        children: List.generate(_items.length, (i) {
          final (activeIcon, inactiveIcon, label) = _items[i];
          final isActive = i == current;
          if (i == 2) {
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: Center(
                  child: Container(
                    width: 50, height: 50,
                    decoration: const BoxDecoration(color: _white, shape: BoxShape.circle),
                    child: const Icon(Icons.cloud_upload_rounded, color: _black, size: 23),
                  ),
                ),
              ),
            );
          }
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i), behavior: HitTestBehavior.opaque,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(isActive ? activeIcon : inactiveIcon, key: ValueKey(isActive), color: isActive ? _white : _t3, size: 25),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: _ts(10.5, isActive ? FontWeight.w600 : FontWeight.w500, isActive ? _white : _t3, em: 0),
                  child: Text(label),
                ),
              ]),
            ),
          );
        }),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SIDEBAR — glass panel
// ════════════════════════════════════════════════════════════════════
class _SidebarPanel extends StatelessWidget {
  final VoidCallback onClose, onLogout;
  final void Function(String) onNavigate;
  final String userName, userEmail;
  final String? uid, avatarUrl;
  const _SidebarPanel({required this.onClose, required this.onNavigate, required this.onLogout, required this.userName,
    required this.userEmail, required this.uid, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top, bottom = MediaQuery.of(context).padding.bottom;
    final w = (MediaQuery.of(context).size.width * 0.78).clamp(260.0, 320.0);
    return SizedBox(
      width: w, height: double.infinity,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xE01C1C1E),
              border: Border(left: BorderSide(color: _sep, width: 0.5)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, top + 20, 16, 14),
                child: Row(children: [
                  CachedNetworkImage(
                    imageUrl: 'https://444music-distribution.vercel.app/black.png', height: 26, color: _white, colorBlendMode: BlendMode.srcIn,
                    errorWidget: (_, __, ___) => Text('444Music', style: _ts(21, FontWeight.w700, _white, em: -0.03)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 32, height: 32,
                      decoration: const BoxDecoration(color: _fill, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: _t2, size: 16),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    _Avatar(url: avatarUrl, name: userName, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        FutureBuilder<Map<String, dynamic>>(
                          future: uid != null ? UserInfoCache.instance.get(uid!) : null,
                          builder: (context, snap) => Row(children: [
                            Flexible(child: Text(userName, style: _ts(15, FontWeight.w600, _white), overflow: TextOverflow.ellipsis)),
                            if (snap.data?['verified'] == true) Padding(padding: const EdgeInsets.only(left: 4), child: verifiedTick(size: 14)),
                          ]),
                        ),
                        const SizedBox(height: 2),
                        Text(userEmail, style: _ts(12.5, FontWeight.w400, _t2), overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ]),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _NavSection(label: 'Navigation'),
                    _NavItem(icon: Icons.home_rounded, label: 'Home', route: '/home', onTap: onNavigate),
                    _NavItem(icon: Icons.person_rounded, label: 'Settings', route: '/profile', onTap: onNavigate),
                    _NavItem(icon: Icons.speed_rounded, label: 'Dashboard', route: '/dashboard', onTap: onNavigate),
                    _NavItem(icon: Icons.cloud_upload_rounded, label: 'Upload Release', route: '/upload', onTap: onNavigate),
                    _NavItem(icon: Icons.bar_chart_rounded, label: 'Analytics', route: '/analytics', onTap: onNavigate),
                    _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Earnings', route: '/earnings', onTap: onNavigate),
                    const _NavSection(label: 'More'),
                    _NavItem(icon: Icons.build_rounded, label: 'More Tools', route: '/tools', onTap: onNavigate),
                    _NavItem(icon: Icons.info_outline_rounded, label: 'About Us', route: '/legal', onTap: onNavigate),
                    _NavItem(icon: Icons.mail_outline_rounded, label: 'Contact Support', route: '/support', onTap: onNavigate),
                    _NavItem(icon: Icons.library_music_rounded, label: 'My Releases', route: '/releases', onTap: onNavigate),
                  ]),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
                child: GestureDetector(
                  onTap: onLogout,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: _rose.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.logout_rounded, color: _rose, size: 18),
                      const SizedBox(width: 9),
                      Text('Log out', style: _ts(16, FontWeight.w600, _rose)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavSection extends StatelessWidget {
  final String label;
  const _NavSection({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
        child: Text(label.toUpperCase(), style: _ts(12, FontWeight.w500, _t3, em: 0.04)),
      );
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label, route;
  final void Function(String) onTap;
  const _NavItem({required this.icon, required this.label, required this.route, required this.onTap});
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) { setState(() => _pressed = false); widget.onTap(widget.route); },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(color: _pressed ? _fill : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(widget.icon, color: _pressed ? _white : _t2, size: 18),
            const SizedBox(width: 12),
            Text(widget.label, style: _ts(15.5, FontWeight.w500, _pressed ? _white : _white70)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: _t3, size: 18),
          ]),
        ),
      );
}

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderTab({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: _s1, borderRadius: BorderRadius.circular(22)),
            child: Icon(icon, color: _t2, size: 32),
          ),
          const SizedBox(height: 16),
          Text(label, style: _ts(22, FontWeight.w700, _white, em: -0.03)),
          const SizedBox(height: 6),
          Text('Coming soon', style: _ts(15, FontWeight.w400, _t2)),
        ]),
      );
}
