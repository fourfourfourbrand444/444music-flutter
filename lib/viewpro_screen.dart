// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — View Profile Screen (viewpro_screen.dart)
//  iOS rebuild. ALL data logic is unchanged from v3: same Firestore
//  reads/writes, FeedApi calls, follow guard, people cache, counter
//  self-heal and 2-minute list cache. Only the UI was rebuilt.
//
//  Own profile → "Edit profile" sheet. Someone else's → Follow button.
//  Reuses UserInfoCache, sendNotification, timeAgo, verifiedTick,
//  formatCount and FeedApi from home_screen.dart.
// ═══════════════════════════════════════════════════════════════════
import 'dart:ui' show ImageFilter;
import 'dart:math' show min;
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'home_screen.dart' show UserInfoCache, sendNotification, timeAgo, verifiedTick, formatCount, FeedApi;

// ─── PALETTE (iOS dark, no yellow on this screen) ───────────────────
const _bg    = Color(0xFF000000);
const _s1    = Color(0xFF1C1C1E);
const _s2    = Color(0xFF2C2C2E);
const _sep   = Color(0x8C545458);
const _fill  = Color(0x3D787880);
const _t1    = Color(0xFFFFFFFF);
const _t2    = Color(0x99EBEBF5);
const _t3    = Color(0x4DEBEBF5);
const _blue  = Color(0xFF0A84FF);
const _rose  = Color(0xFFFF453A);
const _gray  = Color(0xFF8E8E93);
const _bar   = Color(0xB8000000);

TextStyle _ts(double s, FontWeight w, Color c, {double? ls, double? h}) =>
    GoogleFonts.inter(
      fontSize: s,
      fontWeight: w,
      color: c,
      letterSpacing: ls ?? -s * 0.011,
      height: h,
    );

// ─── COST CONTROLS ──────────────────────────────────────────────────
const _kPeopleMax = 50;   // most people ever shown in a followers/following list
const _kPeoplePage = 15;  // how many load per scroll step
const _kPostsPage = 24;   // posts per page in the grid

int _nonNeg(int v) => v < 0 ? 0 : v;

// ─── FOLLOW GUARD (anti mass follow / unfollow) ─────────────────────
// Client-side only: it stops accidental spam and casual abuse. For
// real enforcement also add Firestore rules / a Cloud Function.
class _FollowGuard {
  static const _minGap = Duration(milliseconds: 1500);
  static const _window = Duration(minutes: 10);
  static const _maxPerWindow = 20;
  static const _perUserCooldown = Duration(seconds: 30);
  static const _notifyQuiet = Duration(minutes: 10);

  static final List<DateTime> _recent = [];
  static final Map<String, DateTime> _perUser = {};
  static DateTime? _last;

  /// Returns a message if the action must be blocked, else null.
  static String? check(String uid) {
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < _minGap) {
      return 'Slow down a little.';
    }
    final u = _perUser[uid];
    if (u != null && now.difference(u) < _perUserCooldown) {
      return 'Please wait a bit before changing this again.';
    }
    _recent.removeWhere((t) => now.difference(t) > _window);
    if (_recent.length >= _maxPerWindow) {
      return 'Too many follow actions. Try again in a few minutes.';
    }
    return null;
  }

  /// True if this person was toggled recently (used to skip repeat notifications).
  static bool toggledRecently(String uid) {
    final u = _perUser[uid];
    return u != null && DateTime.now().difference(u) < _notifyQuiet;
  }

  static void record(String uid) {
    final now = DateTime.now();
    _last = now;
    _recent.add(now);
    _perUser[uid] = now;
  }
}

// ─── PEOPLE LIST CACHE (2 min) ──────────────────────────────────────
class _PeopleCacheEntry {
  final List<Map<String, dynamic>> people;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool exhausted;
  final bool ordered;
  final DateTime at;
  _PeopleCacheEntry(this.people, this.lastDoc, this.exhausted, this.ordered) : at = DateTime.now();
}

class _PeopleCache {
  static const _ttl = Duration(minutes: 2);
  static final Map<String, _PeopleCacheEntry> _m = {};

  static _PeopleCacheEntry? get(String key) {
    final e = _m[key];
    if (e == null) return null;
    if (DateTime.now().difference(e.at) > _ttl) {
      _m.remove(key);
      return null;
    }
    return e;
  }

  static void put(String key, _PeopleCacheEntry e) => _m[key] = e;

  static void invalidateUser(String uid) {
    _m.remove('$uid/followers');
    _m.remove('$uid/following');
  }
}

// Matches web's linkifyHashtags()
List<InlineSpan> _hashtagSpans(String text, {required TextStyle base, TextStyle? tagStyle}) {
  if (text.isEmpty) return [TextSpan(text: text, style: base)];
  final regex = RegExp(r'(^|\s)(#[a-zA-Z0-9_]+)');
  final spans = <InlineSpan>[];
  int last = 0;
  for (final m in regex.allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start), style: base));
    spans.add(TextSpan(text: m.group(1), style: base));
    spans.add(TextSpan(text: m.group(2), style: tagStyle ?? base.copyWith(color: _blue, fontWeight: FontWeight.w600)));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: base));
  return spans;
}

Future<void> _launchUrl(String url) async {
  if (url.isEmpty) return;
  var normalized = url.trim();
  if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
    normalized = 'https://$normalized';
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

// ─── SHARED UI PIECES ───────────────────────────────────────────────
class _Tap extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final bool highlight;
  final double scale;
  const _Tap({required this.onTap, required this.child, this.highlight = false, this.scale = 1});
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
          color: (widget.highlight && _down) ? const Color(0x0DFFFFFF) : const Color(0x00000000),
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
        child: const SizedBox(height: 0.5, width: double.infinity, child: ColoredBox(color: _sep)),
      );
}

Widget _group(List<Widget> rows, {double sepLeft = 16, Color color = _s1}) {
  final items = <Widget>[];
  for (var i = 0; i < rows.length; i++) {
    if (i > 0) items.add(_Sep(sepLeft));
    items.add(rows[i]);
  }
  return Container(
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
  );
}

Widget _sh(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 8),
      child: Text(title.toUpperCase(), style: _ts(13, FontWeight.w500, _t2, ls: 0.52)),
    );

Widget _grabber() => Center(
      child: Container(
        width: 36, height: 5,
        margin: const EdgeInsets.only(top: 8, bottom: 6),
        decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(3)),
      ),
    );

Widget _pill(String label, bool blue, VoidCallback onTap, {double h = 30, double fs = 13, bool full = false}) {
  return _Tap(
    onTap: onTap,
    scale: 0.96,
    child: Container(
      height: h,
      width: full ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: full ? 0 : 16),
      decoration: BoxDecoration(color: blue ? _blue : _fill, borderRadius: BorderRadius.circular(999)),
      child: Center(widthFactor: full ? null : 1, child: Text(label, style: _ts(fs, FontWeight.w600, _t1))),
    ),
  );
}

class _Avatar extends StatelessWidget {
  final String url, name;
  final double size;
  const _Avatar({required this.url, required this.name, required this.size});
  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'A';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _s2,
        border: Border.all(color: const Color(0x1AFFFFFF), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
          : Center(child: Text(initial, style: _ts(size * 0.38, FontWeight.w600, _t2))),
    );
  }
}

Widget _bareField({
  required TextEditingController c,
  required String hint,
  TextInputType? type,
}) =>
    TextField(
      controller: c,
      keyboardType: type,
      autocorrect: type == null,
      textAlign: TextAlign.right,
      cursorColor: _blue,
      style: _ts(16, FontWeight.w400, _t1),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: _ts(16, FontWeight.w400, _t3),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );

class ViewProScreen extends StatefulWidget {
  final String uid;
  const ViewProScreen({super.key, required this.uid});
  @override
  State<ViewProScreen> createState() => _ViewProScreenState();
}

class _ViewProScreenState extends State<ViewProScreen> {
  final _me = FirebaseAuth.instance.currentUser;
  late String _targetUid;
  bool get _isOwn => _targetUid == _me?.uid;

  // Counter self-heal runs once per app session per account.
  static final Set<String> _healedUids = {};

  bool _loading = true;
  DateTime? _lastLoad;
  Map<String, dynamic> _userData = {};
  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;
  List<Map<String, dynamic>> _posts = [];
  int? _postsBefore;
  bool _hasMorePosts = false;
  bool _loadingMorePosts = false;

  // Follow state is filled lazily, only for people on screen.
  final Set<String> _followingSet = {};   // known: I follow them
  final Set<String> _notFollowing = {};   // known: I do NOT follow them
  final Set<String> _busy = {};           // follow actions in flight

  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _postsSectionKey = GlobalKey();

  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _spotifyCtrl = TextEditingController();
  final _appleCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _targetUid = widget.uid;
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _countryCtrl.dispose();
    _spotifyCtrl.dispose();
    _appleCtrl.dispose();
    _youtubeCtrl.dispose();
    super.dispose();
  }

  void _fillControllers(Map<String, dynamic> data) {
    _bioCtrl.text = data['bio'] ?? '';
    _phoneCtrl.text = data['phone'] ?? '';
    _emailCtrl.text = data['publicEmail'] ?? '';
    _countryCtrl.text = data['country'] ?? '';
    _spotifyCtrl.text = data['spotifyUrl'] ?? '';
    _appleCtrl.text = data['appleMusicUrl'] ?? '';
    _youtubeCtrl.text = data['youtubeUrl'] ?? '';
  }

  Future<void> _bootstrap() async {
    if (_me == null) return;
    await Future.wait([
      _loadProfile(force: true),
      if (!_isOwn) _resolveFollowStates([_targetUid]),
    ]);
    if (mounted) setState(() {});
  }

  // Checks follow state ONLY for the given people. Unknown ones are looked
  // up in chunks of 30 against my "following" collection — you pay one read
  // per match (min 1 per query), never the whole collection.
  Future<void> _resolveFollowStates(List<String> uids) async {
    if (_me == null) return;
    final unknown = uids
        .where((u) => u != _me!.uid && !_followingSet.contains(u) && !_notFollowing.contains(u))
        .toSet()
        .toList();
    for (int i = 0; i < unknown.length; i += 30) {
      final chunk = unknown.sublist(i, min(i + 30, unknown.length));
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users').doc(_me!.uid).collection('following')
            .where(FieldPath.documentId, whereIn: chunk).get();
        final found = snap.docs.map((d) => d.id).toSet();
        _followingSet.addAll(found);
        _notFollowing.addAll(chunk.where((u) => !found.contains(u)));
      } catch (_) {}
    }
  }

  Future<void> _loadProfile({bool force = false}) async {
    if (!mounted) return;
    if (!force && _lastLoad != null && DateTime.now().difference(_lastLoad!) < const Duration(seconds: 20)) {
      return; // refresh throttle — saves reads on repeated pulls
    }
    _lastLoad = DateTime.now();

    Map<String, dynamic> data = {};
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(_targetUid).get();
      if (snap.exists) data = snap.data()!;
    } catch (_) {}

    int followersCount = _nonNeg((data['followersCount'] as num?)?.toInt() ?? 0);
    int followingCount = _nonNeg((data['followingCount'] as num?)?.toInt() ?? 0);

    List<Map<String, dynamic>> posts = [];
    bool hasMore = false;
    try {
      final r = await FeedApi.get('/posts?author=$_targetUid&limit=$_kPostsPage') as List;
      posts = r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      hasMore = posts.length == _kPostsPage;
    } catch (_) {}

    int postsCount = posts.length;
    if (hasMore) {
      try {
        final c = await FeedApi.get('/posts/count/$_targetUid') as Map;
        postsCount = (c['count'] as num?)?.toInt() ?? posts.length;
      } catch (_) {}
    }

    UserInfoCache.instance.invalidate(_targetUid);

    if (!mounted) return;
    setState(() {
      _userData = data;
      _followersCount = followersCount;
      _followingCount = followingCount;
      _posts = posts;
      _postsBefore = posts.isNotEmpty ? (posts.last['createdAt'] as num?)?.toInt() : null;
      _hasMorePosts = hasMore;
      _postsCount = postsCount;
      _fillControllers(data);
      _loading = false;
    });

    _healOwnCounts(followersCount, followingCount);
  }

  // Fixes drifted counters on YOUR profile. count() costs ~1 read per
  // 1000 docs, and this runs once per app session.
  Future<void> _healOwnCounts(int storedFollowers, int storedFollowing) async {
    if (!_isOwn || _me == null || _healedUids.contains(_me!.uid)) return;
    _healedUids.add(_me!.uid);
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(_me!.uid);
      final f = await ref.collection('following').count().get();
      final r = await ref.collection('followers').count().get();
      final realFollowing = f.count ?? storedFollowing;
      final realFollowers = r.count ?? storedFollowers;
      final fix = <String, dynamic>{};
      if (realFollowing != storedFollowing) fix['followingCount'] = realFollowing;
      if (realFollowers != storedFollowers) fix['followersCount'] = realFollowers;
      if (fix.isEmpty) return;
      await ref.update(fix);
      if (!mounted) return;
      setState(() {
        _followingCount = realFollowing;
        _followersCount = realFollowers;
      });
    } catch (e) {
      debugPrint('count heal failed: $e');
      _healedUids.remove(_me!.uid); // allow retry next time
    }
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMorePosts || !_hasMorePosts || _postsBefore == null) return;
    setState(() => _loadingMorePosts = true);
    try {
      final r = await FeedApi.get('/posts?author=$_targetUid&limit=$_kPostsPage&before=$_postsBefore') as List;
      final more = r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (!mounted) return;
      setState(() {
        _posts = [..._posts, ...more];
        if (more.isNotEmpty) _postsBefore = (more.last['createdAt'] as num).toInt();
        _hasMorePosts = more.length == _kPostsPage;
        _loadingMorePosts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMorePosts = false);
    }
  }

  bool _hasPublicInfo(Map<String, dynamic> d) =>
      (d['phone'] ?? '').toString().isNotEmpty ||
      (d['publicEmail'] ?? '').toString().isNotEmpty ||
      (d['country'] ?? '').toString().isNotEmpty ||
      (d['spotifyUrl'] ?? '').toString().isNotEmpty ||
      (d['appleMusicUrl'] ?? '').toString().isNotEmpty ||
      (d['youtubeUrl'] ?? '').toString().isNotEmpty;

  void _setFollowing(String uid, bool following) {
    if (following) {
      _followingSet.add(uid);
      _notFollowing.remove(uid);
    } else {
      _followingSet.remove(uid);
      _notFollowing.add(uid);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _ts(14, FontWeight.w500, _t1)),
      backgroundColor: _s2,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 2),
    ));
  }

  /// Returns a message if the action was blocked or failed, otherwise null.
  /// [info] = the other person's {name, avatar, verified}, saved on the
  /// follow doc so lists never need to re-read their user doc.
  Future<String?> _toggleFollow(String uid, Map<String, dynamic> info) async {
    if (_me == null || uid == _me!.uid) return null;
    if (_busy.contains(uid)) return null;
    _busy.add(uid);
    try {
      // Never guess the state — a wrong guess would double-count the counters.
      await _resolveFollowStates([uid]);

      final blocked = _FollowGuard.check(uid);
      if (blocked != null) return blocked;
      final quiet = _FollowGuard.toggledRecently(uid);
      _FollowGuard.record(uid);

      final wasFollowing = _followingSet.contains(uid);
      if (mounted) setState(() => _setFollowing(uid, !wasFollowing));

      try {
        final db = FirebaseFirestore.instance;
        final myRef = db.collection('users').doc(_me!.uid);
        final theirRef = db.collection('users').doc(uid);
        final myFollowingDoc = myRef.collection('following').doc(uid);
        final theirFollowerDoc = theirRef.collection('followers').doc(_me!.uid);
        final batch = db.batch();

        if (wasFollowing) {
          batch.delete(myFollowingDoc);
          batch.delete(theirFollowerDoc);
          batch.update(theirRef, {'followersCount': FieldValue.increment(-1)});
          batch.update(myRef, {'followingCount': FieldValue.increment(-1)});
        } else {
          final myInfo = await UserInfoCache.instance.get(_me!.uid);
          batch.set(myFollowingDoc, {
            'since': FieldValue.serverTimestamp(),
            'name': (info['name'] ?? 'Artist').toString(),
            'avatar': (info['avatar'] ?? '').toString(),
            'verified': info['verified'] == true,
          });
          batch.set(theirFollowerDoc, {
            'since': FieldValue.serverTimestamp(),
            'name': (myInfo['name'] ?? 'Artist').toString(),
            'avatar': (myInfo['avatar'] ?? '').toString(),
            'verified': myInfo['verified'] == true,
          });
          batch.update(theirRef, {'followersCount': FieldValue.increment(1)});
          batch.update(myRef, {'followingCount': FieldValue.increment(1)});
        }
        await batch.commit();

        if (!wasFollowing && !quiet) sendNotification(uid, 'follow');

        _PeopleCache.invalidateUser(uid);
        _PeopleCache.invalidateUser(_me!.uid);

        if (mounted) {
          setState(() {
            final d = wasFollowing ? -1 : 1;
            if (uid == _targetUid) _followersCount = _nonNeg(_followersCount + d);
            if (_me!.uid == _targetUid) _followingCount = _nonNeg(_followingCount + d);
          });
        }
        return null;
      } catch (_) {
        if (mounted) setState(() => _setFollowing(uid, wasFollowing));
        return "Couldn't update. Please try again.";
      }
    } finally {
      _busy.remove(uid);
    }
  }

  /// Saves the edit-profile fields. Returns true on success.
  Future<bool> _saveCompleteProfile() async {
    if (_me == null) return false;
    final payload = {
      'bio': _bioCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'publicEmail': _emailCtrl.text.trim(),
      'country': _countryCtrl.text.trim(),
      'spotifyUrl': _spotifyCtrl.text.trim(),
      'appleMusicUrl': _appleCtrl.text.trim(),
      'youtubeUrl': _youtubeCtrl.text.trim(),
    };
    try {
      await FirebaseFirestore.instance.collection('users').doc(_me!.uid).update(payload);
      UserInfoCache.instance.invalidate(_me!.uid);
      if (mounted) setState(() => _userData = {..._userData, ...payload});
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── OPENERS ────────────────────────────────────────────────────────
  void _openLightbox() {
    final url = (_userData['profilePic'] ?? '').toString();
    if (url.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black,
      useSafeArea: false,
      builder: (ctx) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: InteractiveViewer(child: Center(child: CachedNetworkImage(imageUrl: url))),
          ),
        ),
        Positioned(
          top: MediaQuery.of(ctx).padding.top + 8,
          right: 16,
          child: _Tap(
            onTap: () => Navigator.pop(ctx),
            scale: 0.9,
            child: Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(color: _fill, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, color: _t1, size: 18),
            ),
          ),
        ),
      ]),
    );
  }

  void _openPeopleModal(String kind) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _PeopleModal(
        targetUid: _targetUid, kind: kind, myFollowing: _followingSet,
        myUid: _me?.uid, onToggleFollow: _toggleFollow, resolveStates: _resolveFollowStates,
      ),
    );
  }

  void _openPostModal(String postId) {
    if (_me == null) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _PostDetailModal(postId: postId, myUid: _me!.uid),
    );
  }

  void _openEdit() {
    _fillControllers(_userData); // discard any earlier unsaved edits
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        bio: _bioCtrl, phone: _phoneCtrl, email: _emailCtrl, country: _countryCtrl,
        spotify: _spotifyCtrl, apple: _appleCtrl, youtube: _youtubeCtrl,
        onSave: _saveCompleteProfile,
      ),
    );
  }

  void _scrollToPosts() {
    final ctx = _postsSectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic, alignment: 0);
  }

  void _openMore() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        void go(String route, {bool replace = false}) {
          Navigator.pop(ctx);
          if (!mounted) return;
          if (replace) {
            Navigator.pushReplacementNamed(context, route);
          } else {
            Navigator.pushNamed(context, route);
          }
        }

        return Container(
          decoration: const BoxDecoration(color: _s1, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).padding.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _grabber(),
            const SizedBox(height: 8),
            _group(color: _s2, sepLeft: 52, [
              _moreRow(Icons.speed_rounded, 'Dashboard', () => go('/dashboard')),
              _moreRow(Icons.settings_outlined, 'Settings', () => go('/profile', replace: true)),
              _moreRow(Icons.build_outlined, 'More tools', () => go('/tools')),
              _moreRow(Icons.info_outline_rounded, 'About us', () => go('/legal')),
              _moreRow(Icons.mail_outline_rounded, 'Contact support', () => go('/support')),
            ]),
            const SizedBox(height: 12),
            _group(color: _s2, [
              _moreRow(Icons.logout_rounded, 'Log out', () async {
                Navigator.pop(ctx);
                await FirebaseAuth.instance.signOut();
                if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
              }, color: _rose, chevron: false),
            ]),
          ]),
        );
      },
    );
  }

  Widget _moreRow(IconData icon, String label, VoidCallback onTap, {Color color = _t1, bool chevron = true}) {
    return _Tap(
      onTap: onTap,
      highlight: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Icon(icon, size: 20, color: color == _t1 ? _gray : color),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: _ts(16, FontWeight.w400, color))),
          if (chevron) const Icon(Icons.chevron_right_rounded, size: 20, color: _t3),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;
    final bottom = mq.padding.bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        Positioned.fill(
          child: _loading
              ? const Center(child: CupertinoActivityIndicator(radius: 12, color: _t2))
              : RefreshIndicator(
                  color: _t1,
                  backgroundColor: _s2,
                  edgeOffset: top + 56,
                  onRefresh: () => _loadProfile(),
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.fromLTRB(16, top + 64, 16, 100 + bottom),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          _header(),
                          if (_isOwn && !_hasPublicInfo(_userData)) ...[
                            const SizedBox(height: 24),
                            _completePrompt(),
                          ],
                          if (_hasPublicInfo(_userData)) ...[
                            const SizedBox(height: 24),
                            _infoGroup(),
                          ],
                          _postsSection(),
                        ]),
                      ),
                    ),
                  ),
                ),
        ),
        Positioned(top: 0, left: 0, right: 0, child: _topBar(top)),
        Positioned(bottom: 0, left: 0, right: 0, child: _tabBar(bottom)),
      ]),
    );
  }

  // ── TOP BAR ────────────────────────────────────────────────────────
  Widget _topBar(double top) {
    Widget circle(IconData icon, VoidCallback onTap) => _Tap(
          onTap: onTap,
          scale: 0.92,
          child: Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: _fill, shape: BoxShape.circle),
            child: Icon(icon, size: icon == Icons.more_horiz_rounded ? 20 : 15, color: _t1),
          ),
        );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 56 + top,
          color: _bar,
          padding: EdgeInsets.fromLTRB(16, top, 16, 0),
          child: Row(children: [
            circle(Icons.arrow_back_ios_new_rounded, () => Navigator.canPop(context)
                ? Navigator.pop(context)
                : Navigator.pushReplacementNamed(context, '/home')),
            Expanded(
              child: Text(
                (_userData['name'] ?? 'Profile').toString(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ts(17, FontWeight.w600, _t1),
              ),
            ),
            circle(Icons.more_horiz_rounded, _openMore),
          ]),
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────
  Widget _header() {
    final name = (_userData['name'] ?? 'Artist').toString();
    final avatar = (_userData['profilePic'] ?? '').toString();
    final verified = _userData['verified'] == true;
    final bio = (_userData['bio'] ?? '').toString();
    final isFollowing = _followingSet.contains(_targetUid);

    return Column(children: [
      _Tap(
        onTap: _openLightbox,
        scale: 0.97,
        child: _Avatar(url: avatar, name: name, size: 96),
      ),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Flexible(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _ts(26, FontWeight.w700, _t1, ls: -0.6)),
        ),
        if (verified) Padding(padding: const EdgeInsets.only(left: 6), child: verifiedTick(size: 16)),
      ]),
      if (bio.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(bio, textAlign: TextAlign.center, style: _ts(15, FontWeight.w400, _t2, h: 1.4)),
        )
      else if (_isOwn)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _Tap(
            onTap: _openEdit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Text('Add a bio', style: _ts(15, FontWeight.w400, _blue)),
            ),
          ),
        ),
      const SizedBox(height: 20),
      _group([
        Row(children: [
          _statCell(formatCount(_postsCount), 'Posts', _scrollToPosts),
          Container(width: 0.5, height: 28, color: _sep),
          _statCell(formatCount(_followersCount), 'Followers', () => _openPeopleModal('followers')),
          Container(width: 0.5, height: 28, color: _sep),
          _statCell(formatCount(_followingCount), 'Following', () => _openPeopleModal('following')),
        ]),
      ]),
      const SizedBox(height: 16),
      if (_isOwn)
        _pill('Edit profile', false, _openEdit, h: 46, fs: 16, full: true)
      else
        _pill(isFollowing ? 'Following' : 'Follow', !isFollowing, () async {
          final msg = await _toggleFollow(_targetUid, {'name': name, 'avatar': avatar, 'verified': verified});
          if (msg != null) _toast(msg);
        }, h: 46, fs: 16, full: true),
    ]);
  }

  Widget _statCell(String num, String label, VoidCallback onTap) => Expanded(
        child: _Tap(
          onTap: onTap,
          highlight: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Text(num, style: _ts(20, FontWeight.w700, _t1)),
              const SizedBox(height: 2),
              Text(label, style: _ts(13, FontWeight.w400, _t2)),
            ]),
          ),
        ),
      );

  // ── COMPLETE PROMPT (own profile, no info yet) ─────────────────────
  Widget _completePrompt() {
    return _group([
      _Tap(
        onTap: _openEdit,
        highlight: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Complete your profile', style: _ts(16, FontWeight.w500, _t1)),
                const SizedBox(height: 2),
                Text('Add contact info and music links.', style: _ts(13, FontWeight.w400, _t2)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: _t3),
          ]),
        ),
      ),
    ]);
  }

  // ── PUBLIC INFO ────────────────────────────────────────────────────
  Widget _infoGroup() {
    final country = (_userData['country'] ?? '').toString();
    final phone = (_userData['phone'] ?? '').toString();
    final email = (_userData['publicEmail'] ?? '').toString();
    final spotify = (_userData['spotifyUrl'] ?? '').toString();
    final apple = (_userData['appleMusicUrl'] ?? '').toString();
    final youtube = (_userData['youtubeUrl'] ?? '').toString();

    return _group(sepLeft: 52, [
      if (country.isNotEmpty) _infoRow(const Icon(Icons.location_on_outlined, size: 20, color: _gray), country),
      if (phone.isNotEmpty)
        _infoRow(const Icon(Icons.phone_outlined, size: 20, color: _gray), phone, onTap: () => _launchUrlAction('tel:$phone')),
      if (email.isNotEmpty)
        _infoRow(const Icon(Icons.mail_outline_rounded, size: 20, color: _gray), email, onTap: () => _launchUrlAction('mailto:$email')),
      if (spotify.isNotEmpty) _storeRow('spotify', 'Spotify', '1DB954', spotify),
      if (apple.isNotEmpty) _storeRow('applemusic', 'Apple Music', 'FC3C44', apple),
      if (youtube.isNotEmpty) _storeRow('youtubemusic', 'YouTube', 'FF0000', youtube),
    ]);
  }

  Future<void> _launchUrlAction(String rawUri) async {
    final uri = Uri.tryParse(rawUri);
    if (uri == null) return;
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  Widget _infoRow(Widget icon, String text, {VoidCallback? onTap}) {
    return _Tap(
      onTap: onTap,
      highlight: onTap != null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          SizedBox(width: 22, child: icon),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: _ts(16, FontWeight.w400, onTap != null ? _blue : _t1))),
        ]),
      ),
    );
  }

  Widget _storeRow(String slug, String label, String hex, String url) {
    return _Tap(
      onTap: () => _launchUrl(url),
      highlight: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          SizedBox(
            width: 22,
            child: SvgPicture.network('https://cdn.simpleicons.org/$slug/$hex', width: 20, height: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: _ts(16, FontWeight.w400, _t1))),
          const Icon(Icons.chevron_right_rounded, size: 20, color: _t3),
        ]),
      ),
    );
  }

  // ── POSTS ──────────────────────────────────────────────────────────
  Widget _postsSection() {
    return Column(
      key: _postsSectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sh('Posts'),
        if (_posts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(children: [
                const Icon(Icons.image_outlined, color: _t3, size: 28),
                const SizedBox(height: 10),
                Text(_isOwn ? 'No posts yet. Share your first one.' : 'No posts yet.',
                    style: _ts(15, FontWeight.w400, _t2)),
              ]),
            ),
          )
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
              itemCount: _posts.length,
              itemBuilder: (context, i) => _postTile(_posts[i]),
            ),
          ),
          if (_hasMorePosts)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: _loadingMorePosts
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CupertinoActivityIndicator(radius: 10, color: _t2),
                      )
                    : _Tap(
                        onTap: _loadMorePosts,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('Load more', style: _ts(16, FontWeight.w400, _blue)),
                        ),
                      ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _postTile(Map<String, dynamic> p) {
    final hasImage = (p['imageUrl'] ?? '').toString().isNotEmpty;
    final likes = p['likesCount'] ?? 0;
    final comments = p['commentsCount'] ?? 0;
    return GestureDetector(
      onTap: () => _openPostModal(p['id'].toString()),
      child: Stack(fit: StackFit.expand, children: [
        Container(
          color: _s1,
          child: hasImage
              ? CachedNetworkImage(imageUrl: p['imageUrl'], fit: BoxFit.cover)
              : Container(
                  padding: const EdgeInsets.all(10),
                  alignment: Alignment.center,
                  child: Text(
                    (p['text'] ?? '').toString(),
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(11, FontWeight.w500, _t2),
                  ),
                ),
        ),
        if (likes > 0 || comments > 0)
          Positioned(
            left: 5, bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: const Color(0x8C000000), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.favorite_rounded, color: _t1, size: 10),
                const SizedBox(width: 3),
                Text('$likes', style: _ts(10, FontWeight.w600, _t1)),
                const SizedBox(width: 8),
                const Icon(Icons.mode_comment_rounded, color: _t1, size: 10),
                const SizedBox(width: 3),
                Text('$comments', style: _ts(10, FontWeight.w600, _t1)),
              ]),
            ),
          ),
      ]),
    );
  }

  // ── TAB BAR ────────────────────────────────────────────────────────
  Widget _tabBar(double bottom) {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.home_rounded, 'Home', () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false)),
      (Icons.bar_chart_rounded, 'Analytics', () => Navigator.pushNamed(context, '/analytics')),
      (Icons.cloud_upload_outlined, 'Upload', () => Navigator.pushNamed(context, '/upload')),
      (Icons.account_balance_wallet_outlined, 'Earnings', () => Navigator.pushNamed(context, '/earnings')),
      (Icons.person_rounded, 'Profile', () {
        if (!_isOwn) Navigator.pushNamed(context, '/viewpro', arguments: _me?.uid);
      }),
    ];
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(8, 8, 8, bottom + 6),
          decoration: const BoxDecoration(
            color: _bar,
            border: Border(top: BorderSide(color: _sep, width: 0.5)),
          ),
          child: Row(
            children: items.map((item) {
              final (icon, label, onTap) = item;
              final active = label == 'Profile' && _isOwn;
              final c = active ? _t1 : _gray;
              return Expanded(
                child: _Tap(
                  onTap: onTap,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, color: c, size: 25),
                    const SizedBox(height: 3),
                    Text(label, style: _ts(10, active ? FontWeight.w600 : FontWeight.w500, c, ls: 0)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  EDIT PROFILE SHEET
// ═══════════════════════════════════════════════════════════════════
class _EditProfileSheet extends StatefulWidget {
  final TextEditingController bio, phone, email, country, spotify, apple, youtube;
  final Future<bool> Function() onSave;
  const _EditProfileSheet({
    required this.bio, required this.phone, required this.email, required this.country,
    required this.spotify, required this.apple, required this.youtube, required this.onSave,
  });
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    final ok = await widget.onSave();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  Widget _row(String label, TextEditingController c, String hint, {TextInputType? type, Widget? lead}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        if (lead != null) ...[SizedBox(width: 22, child: lead), const SizedBox(width: 12)],
        if (label.isNotEmpty) SizedBox(width: 92, child: Text(label, style: _ts(16, FontWeight.w400, _t1))),
        Expanded(child: _bareField(c: c, hint: hint, type: type)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
        decoration: const BoxDecoration(color: _s1, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _grabber(),
          SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _Tap(
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text('Cancel', style: _ts(17, FontWeight.w400, _blue)),
                      ),
                    ),
                  ),
                ),
                Text('Edit profile', style: _ts(17, FontWeight.w600, _t1)),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _saving
                        ? const CupertinoActivityIndicator(radius: 9, color: _t2)
                        : _Tap(
                            onTap: _save,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text('Save', style: _ts(17, FontWeight.w600, _blue)),
                            ),
                          ),
                  ),
                ),
              ]),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _sh('About'),
                _group(color: _s2, [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: widget.bio,
                      maxLength: 150,
                      minLines: 3,
                      maxLines: 5,
                      cursorColor: _blue,
                      style: _ts(16, FontWeight.w400, _t1, h: 1.4),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Tell people about your sound',
                        hintStyle: _ts(16, FontWeight.w400, _t3),
                        counterStyle: _ts(12, FontWeight.w400, _t3),
                        contentPadding: const EdgeInsets.only(top: 14),
                      ),
                    ),
                  ),
                ]),
                _sh('Contact'),
                _group(color: _s2, [
                  _row('Phone', widget.phone, '+233 …', type: TextInputType.phone),
                  _row('Email', widget.email, 'you@example.com', type: TextInputType.emailAddress),
                  _row('Country', widget.country, 'e.g. Ghana'),
                ]),
                _sh('Music links'),
                _group(color: _s2, [
                  _row('', widget.spotify, 'Spotify artist link',
                      type: TextInputType.url,
                      lead: SvgPicture.network('https://cdn.simpleicons.org/spotify/1DB954', width: 20, height: 20)),
                  _row('', widget.apple, 'Apple Music link',
                      type: TextInputType.url,
                      lead: SvgPicture.network('https://cdn.simpleicons.org/applemusic/FC3C44', width: 20, height: 20)),
                  _row('', widget.youtube, 'YouTube link',
                      type: TextInputType.url,
                      lead: SvgPicture.network('https://cdn.simpleicons.org/youtubemusic/FF0000', width: 20, height: 20)),
                ]),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text('Only filled fields are shown on your public profile.',
                      style: TextStyle(color: _t2, fontSize: 13, height: 1.4)),
                ),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, size: 14, color: _rose),
                      const SizedBox(width: 6),
                      Text("Couldn't save. Try again.", style: _ts(13, FontWeight.w500, _rose)),
                    ]),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  FOLLOWERS / FOLLOWING MODAL
//  • newest first, max 50 people, 15 per scroll step
//  • rows come from the follow doc itself (1 read per person)
//  • cached for 2 minutes
// ═══════════════════════════════════════════════════════════════════
class _PeopleModal extends StatefulWidget {
  final String targetUid, kind;
  final Set<String> myFollowing;
  final String? myUid;
  final Future<String?> Function(String uid, Map<String, dynamic> info) onToggleFollow;
  final Future<void> Function(List<String> uids) resolveStates;
  const _PeopleModal({
    required this.targetUid, required this.kind, required this.myFollowing,
    required this.myUid, required this.onToggleFollow, required this.resolveStates,
  });
  @override
  State<_PeopleModal> createState() => _PeopleModalState();
}

class _PeopleModalState extends State<_PeopleModal> {
  final List<Map<String, dynamic>> _people = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _exhausted = false;
  bool _ordered = true;
  bool _loading = false;
  bool _ready = false;
  String? _notice;

  String get _cacheKey => '${widget.targetUid}/${widget.kind}';

  @override
  void initState() {
    super.initState();
    final cached = _PeopleCache.get(_cacheKey);
    if (cached != null) {
      _people.addAll(cached.people.map((e) => Map<String, dynamic>.from(e)));
      _lastDoc = cached.lastDoc;
      _exhausted = cached.exhausted;
      _ordered = cached.ordered;
      _ready = true;
      _syncFollowStates(_people.map((p) => p['uid'] as String).toList());
    } else {
      _loadMore();
    }
  }

  Future<void> _syncFollowStates(List<String> uids) async {
    if (widget.targetUid == widget.myUid && widget.kind == 'following') {
      widget.myFollowing.addAll(uids); // everyone in my own following list is followed — no reads
    } else {
      await widget.resolveStates(uids);
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadMore() async {
    if (_loading || _exhausted) return;
    final room = _kPeopleMax - _people.length;
    if (room <= 0) {
      if (mounted) setState(() => _exhausted = true);
      return;
    }
    if (mounted) setState(() => _loading = true);
    final take = room < _kPeoplePage ? room : _kPeoplePage;

    try {
      final col = FirebaseFirestore.instance.collection('users').doc(widget.targetUid).collection(widget.kind);
      Query<Map<String, dynamic>> q = _ordered ? col.orderBy('since', descending: true) : col;
      if (_lastDoc != null) q = q.startAfterDocument(_lastDoc!);
      var snap = await q.limit(take).get();

      // Old follow docs without a "since" field are skipped by orderBy —
      // fall back to plain document order if the ordered query is empty.
      if (snap.docs.isEmpty && _people.isEmpty && _ordered) {
        _ordered = false;
        snap = await col.limit(take).get();
      }

      final fresh = <Map<String, dynamic>>[];
      final needInfo = <Map<String, dynamic>>[];
      for (final d in snap.docs) {
        final data = d.data();
        final row = <String, dynamic>{
          'uid': d.id,
          'name': data['name'],
          'avatar': data['avatar'],
          'verified': data['verified'] == true,
        };
        fresh.add(row);
        if (data['name'] == null) needInfo.add(row); // old doc: no snapshot saved
      }
      if (needInfo.isNotEmpty) {
        await Future.wait(needInfo.map((row) async {
          try {
            final info = await UserInfoCache.instance.get(row['uid'] as String);
            row['name'] = info['name'];
            row['avatar'] = info['avatar'];
            row['verified'] = info['verified'] == true;
          } catch (_) {}
        }));
      }

      if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
      _people.addAll(fresh);
      _exhausted = snap.docs.length < take || _people.length >= _kPeopleMax;

      await _syncFollowStates(fresh.map((p) => p['uid'] as String).toList());

      _PeopleCache.put(_cacheKey, _PeopleCacheEntry(
        _people.map((e) => Map<String, dynamic>.from(e)).toList(), _lastDoc, _exhausted, _ordered,
      ));
    } catch (_) {
      _exhausted = true;
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _ready = true;
      });
    }
  }

  void _showNotice(String msg) {
    setState(() => _notice = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _notice == msg) setState(() => _notice = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6, minChildSize: 0.35, maxChildSize: 0.92,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(color: _s1, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: Column(children: [
          _grabber(),
          SizedBox(
            height: 44,
            child: Center(
              child: Text(widget.kind == 'followers' ? 'Followers' : 'Following',
                  style: _ts(17, FontWeight.w600, _t1)),
            ),
          ),
          const SizedBox(height: 0.5, width: double.infinity, child: ColoredBox(color: _sep)),
          if (_notice != null)
            Container(
              width: double.infinity,
              color: _s2,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(_notice!, style: _ts(13, FontWeight.w500, _t2)),
            ),
          Expanded(
            child: !_ready
                ? const Center(child: CupertinoActivityIndicator(radius: 12, color: _t2))
                : _people.isEmpty
                    ? Center(child: Text('No ${widget.kind} yet.', style: _ts(15, FontWeight.w400, _t2)))
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.extentAfter < 250) _loadMore();
                          return false;
                        },
                        child: ListView.builder(
                          controller: scrollCtrl,
                          itemCount: _people.length + 1,
                          itemBuilder: (context, i) {
                            if (i == _people.length) {
                              if (_loading) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 18),
                                  child: Center(child: CupertinoActivityIndicator(radius: 10, color: _t2)),
                                );
                              }
                              if (_people.length >= _kPeopleMax) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  child: Center(child: Text('Showing the latest $_kPeopleMax', style: _ts(13, FontWeight.w400, _t2))),
                                );
                              }
                              return const SizedBox(height: 24);
                            }
                            return Column(children: [
                              if (i > 0) const _Sep(76),
                              _personRow(_people[i]),
                            ]);
                          },
                        ),
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _personRow(Map<String, dynamic> p) {
    final uid = p['uid'] as String;
    final isSelf = uid == widget.myUid;
    final isFollowing = widget.myFollowing.contains(uid);
    final name = (p['name'] ?? 'Artist').toString();
    final avatar = (p['avatar'] ?? '').toString();

    return _Tap(
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, '/viewpro', arguments: uid);
      },
      highlight: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _Avatar(url: avatar, name: name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Row(children: [
              Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ts(16, FontWeight.w500, _t1))),
              if (p['verified'] == true) Padding(padding: const EdgeInsets.only(left: 5), child: verifiedTick(size: 13)),
            ]),
          ),
          if (!isSelf) ...[
            const SizedBox(width: 10),
            _pill(isFollowing ? 'Following' : 'Follow', !isFollowing, () async {
              final msg = await widget.onToggleFollow(uid, {
                'name': name, 'avatar': avatar, 'verified': p['verified'] == true,
              });
              if (!mounted) return;
              if (msg != null) {
                _showNotice(msg);
              } else {
                setState(() {});
              }
            }),
          ],
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  POST DETAIL MODAL — flat comments (no reply-threading).
//  Post, likes and comments all go through FeedApi.
// ═══════════════════════════════════════════════════════════════════
class _PostDetailModal extends StatefulWidget {
  final String postId, myUid;
  const _PostDetailModal({required this.postId, required this.myUid});
  @override
  State<_PostDetailModal> createState() => _PostDetailModalState();
}

class _PostDetailModalState extends State<_PostDetailModal> {
  Map<String, dynamic>? _post;
  bool _liked = false;
  final _commentCtrl = TextEditingController();
  bool _sending = false;
  bool _liking = false;
  List<Map<String, dynamic>>? _comments;
  Future<Map<String, dynamic>>? _authorFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final post = Map<String, dynamic>.from(await FeedApi.get('/posts/${widget.postId}') as Map);
      if (mounted) {
        setState(() {
          _post = post;
          _liked = post['liked'] == true;
          _authorFuture = UserInfoCache.instance.get(post['authorUid']);
        });
      }
      final r = await FeedApi.get('/posts/${widget.postId}/comments') as List;
      if (mounted) setState(() => _comments = r.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {
      if (mounted) {
        setState(() {
          _post ??= {};
          _comments ??= [];
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_post == null || _post!.isEmpty || _liking) return;
    _liking = true;
    final wasLiked = _liked;
    setState(() {
      _liked = !wasLiked;
      _post!['likesCount'] = _nonNeg(((_post!['likesCount'] ?? 0) as num).toInt() + (wasLiked ? -1 : 1));
    });
    try {
      final r = wasLiked
          ? await FeedApi.delete('/posts/${widget.postId}/like')
          : await FeedApi.post('/posts/${widget.postId}/like');
      if (mounted && r is Map && r['likesCount'] is num) {
        setState(() => _post!['likesCount'] = (r['likesCount'] as num).toInt());
      }
      if (!wasLiked) {
        sendNotification(_post!['authorUid'], 'like', postId: widget.postId, postText: _post!['text'],
            postImage: _post!['imageUrl'], docId: 'like_${widget.postId}_${widget.myUid}');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = wasLiked;
          _post!['likesCount'] = _nonNeg(((_post!['likesCount'] ?? 0) as num).toInt() + (wasLiked ? 1 : -1));
        });
      }
    } finally {
      _liking = false;
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _post == null || _post!.isEmpty || _sending) return;
    setState(() => _sending = true);
    _commentCtrl.clear();
    try {
      final myInfo = await UserInfoCache.instance.get(widget.myUid);
      final res = await FeedApi.post('/posts/${widget.postId}/comments', {
        'text': text, 'authorName': myInfo['name'], 'authorAvatar': myInfo['avatar'],
      });
      if (mounted) {
        setState(() {
          _comments = [...?_comments, Map<String, dynamic>.from(res as Map)];
          _post!['commentsCount'] = ((_post!['commentsCount'] ?? 0) as num).toInt() + 1;
        });
      }
      sendNotification(_post!['authorUid'], 'comment', postId: widget.postId, postText: _post!['text'],
          postImage: _post!['imageUrl'], commentText: text);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.8, minChildSize: 0.45, maxChildSize: 0.95,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(color: _s1, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: _post == null
            ? const Center(child: CupertinoActivityIndicator(radius: 12, color: _t2))
            : _post!.isEmpty
                ? Center(child: Text('Post not found.', style: _ts(15, FontWeight.w400, _t2)))
                : Column(children: [
                    _grabber(),
                    SizedBox(
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          const SizedBox(width: 30),
                          Expanded(child: Center(child: Text('Post', style: _ts(17, FontWeight.w600, _t1)))),
                          _Tap(
                            onTap: () => Navigator.pop(context),
                            scale: 0.9,
                            child: Container(
                              width: 30, height: 30,
                              decoration: const BoxDecoration(color: _fill, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, size: 16, color: _t2),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 0.5, width: double.infinity, child: ColoredBox(color: _sep)),
                    Expanded(
                      child: ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        children: [
                          _authorRow(),
                          if ((_post!['text'] ?? '').toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text.rich(TextSpan(children: _hashtagSpans(
                                (_post!['text'] ?? '').toString(),
                                base: _ts(16, FontWeight.w400, _t1, h: 1.45),
                              ))),
                            ),
                          if ((_post!['imageUrl'] ?? '').toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: CachedNetworkImage(imageUrl: _post!['imageUrl'], fit: BoxFit.cover),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Row(children: [
                              _Tap(
                                onTap: _toggleLike,
                                scale: 0.94,
                                child: Row(children: [
                                  Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: _liked ? _rose : _gray, size: 22),
                                  const SizedBox(width: 6),
                                  Text('${_post!['likesCount'] ?? 0}',
                                      style: _ts(14, FontWeight.w500, _liked ? _rose : _t2)),
                                ]),
                              ),
                              const SizedBox(width: 22),
                              const Icon(Icons.mode_comment_outlined, color: _gray, size: 21),
                              const SizedBox(width: 6),
                              Text('${_post!['commentsCount'] ?? 0}', style: _ts(14, FontWeight.w500, _t2)),
                            ]),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: SizedBox(height: 0.5, child: ColoredBox(color: _sep)),
                          ),
                          if (_comments == null)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: CupertinoActivityIndicator(radius: 10, color: _t2)),
                            )
                          else if (_comments!.isEmpty)
                            Text('No comments yet.', style: _ts(15, FontWeight.w400, _t2))
                          else
                            ..._comments!.map(_commentRow),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 10 + (mq.viewInsets.bottom > 0 ? mq.viewInsets.bottom : mq.padding.bottom)),
                      child: Row(children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _commentCtrl,
                              cursorColor: _blue,
                              style: _ts(16, FontWeight.w400, _t1),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Add a comment',
                                hintStyle: _ts(16, FontWeight.w400, _t3),
                                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                              onSubmitted: (_) => _submitComment(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _commentCtrl,
                          builder: (_, v, __) {
                            final can = v.text.trim().isNotEmpty && !_sending;
                            return _Tap(
                              onTap: can ? _submitComment : null,
                              scale: 0.9,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 34, height: 34,
                                decoration: BoxDecoration(color: can ? _blue : _fill, shape: BoxShape.circle),
                                child: const Icon(Icons.arrow_upward_rounded, size: 18, color: _t1),
                              ),
                            );
                          },
                        ),
                      ]),
                    ),
                  ]),
      ),
    );
  }

  Widget _authorRow() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _authorFuture,
      builder: (context, snap) {
        final info = snap.data ?? {'name': _post!['authorName'] ?? 'Artist', 'avatar': _post!['authorAvatar'] ?? '', 'verified': false};
        final ca = _post!['createdAt'];
        final created = ca is num ? DateTime.fromMillisecondsSinceEpoch(ca.toInt()) : null;
        final name = (info['name'] ?? 'Artist').toString();
        return Row(children: [
          _Avatar(url: (info['avatar'] ?? '').toString(), name: name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ts(16, FontWeight.w600, _t1))),
                if (info['verified'] == true) Padding(padding: const EdgeInsets.only(left: 5), child: verifiedTick(size: 13)),
              ]),
              Text(timeAgo(created), style: _ts(13, FontWeight.w400, _t2)),
            ]),
          ),
        ]);
      },
    );
  }

  Widget _commentRow(Map<String, dynamic> c) {
    final cName = (c['authorName'] ?? 'Artist').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Avatar(url: (c['authorAvatar'] ?? '').toString(), name: cName, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cName, style: _ts(14, FontWeight.w600, _t1)),
            const SizedBox(height: 2),
            Text.rich(TextSpan(children: _hashtagSpans(
              (c['text'] ?? '').toString(),
              base: _ts(15, FontWeight.w400, _t2, h: 1.4),
            ))),
          ]),
        ),
      ]),
    );
  }
}
