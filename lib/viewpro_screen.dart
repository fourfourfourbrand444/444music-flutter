// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — View Profile Screen (viewpro_screen.dart)
//  Ported 1:1 from web's viewpro/profile.html: same Firestore reads/
//  writes (users, posts, comments, likes, followers/following
//  subcollections) so this screen and web always show identical data.
//
//  Handles BOTH roles the web file does, gated by _isOwn:
//   - Someone else's profile → Follow button, no edit fields
//   - Your own profile → "Complete Profile" expandable panel (bio,
//     phone, public email, country, Spotify/Apple/YouTube links)
//
//  Reuses UserInfoCache, sendNotification, timeAgo, verifiedTick from
//  home_screen.dart — single source of truth, not duplicated logic.
//
//  v2 — parity fixes vs web:
//   • store links (Spotify/Apple/YouTube) now actually open via
//     url_launcher, matching web's <a target="_blank">
//   • hashtags in post body + comments are linkified/colored blue,
//     matching web's linkifyHashtags()
//   • grid tiles show a small always-visible like/comment count
//     badge (web shows this on hover; mobile has no hover, so it's
//     always-on here — same info, better fit for touch)
//   • tapping the "Posts" stat scrolls smoothly to the grid, matching
//     web's postsStatBtn → scrollIntoView behavior
// ═══════════════════════════════════════════════════════════════════
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'home_screen.dart' show UserInfoCache, sendNotification, timeAgo, verifiedTick;

// ─── PALETTE (matches home_screen.dart's values) ────────────────────
const _black    = Color(0xFF000000);
const _black1   = Color(0xFF0A0A0A);
const _black2   = Color(0xFF111111);
const _black3   = Color(0xFF1A1A1A);
const _black4   = Color(0xFF222222);
const _white    = Color(0xFFFFFFFF);
const _white90  = Color(0xE6FFFFFF);
const _white70  = Color(0xB3FFFFFF);
const _white40  = Color(0x66FFFFFF);
const _white20  = Color(0x33FFFFFF);
const _white10  = Color(0x1AFFFFFF);
const _white06  = Color(0x0FFFFFFF);
const _grey     = Color(0xFF888888);
const _greyDark = Color(0xFF444444);
const _rose     = Color(0xFFF87171);
const _blue     = Color(0xFF4DA3FF); // matches web's --blue, used for hashtags + verified tick
const _green    = Color(0xFF22C55E);

// Matches web's linkifyHashtags(): splits on (^|\s)(#word) and colors
// the tag blue. Returns an inline span list usable in RichText/Text.rich.
List<InlineSpan> _hashtagSpans(String text, {required TextStyle base, TextStyle? tagStyle}) {
  if (text.isEmpty) return [TextSpan(text: text, style: base)];
  final regex = RegExp(r'(^|\s)(#[a-zA-Z0-9_]+)');
  final spans = <InlineSpan>[];
  int last = 0;
  for (final m in regex.allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start), style: base));
    spans.add(TextSpan(text: m.group(1), style: base)); // leading whitespace / start
    spans.add(TextSpan(text: m.group(2), style: tagStyle ?? base.copyWith(color: _blue, fontWeight: FontWeight.w700)));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: base));
  return spans;
}

// Matches web's _launchUrl: opens store/profile links in an external
// browser/app, same as target="_blank" on <a>.
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
  } catch (_) {
    // Swallow — matches web's silent no-op on bad/blocked links.
  }
}

class ViewProScreen extends StatefulWidget {
  final String uid;
  const ViewProScreen({super.key, required this.uid});
  @override
  State<ViewProScreen> createState() => _ViewProScreenState();
}

class _ViewProScreenState extends State<ViewProScreen> with TickerProviderStateMixin {
  final _me = FirebaseAuth.instance.currentUser;
  late String _targetUid;
  bool get _isOwn => _targetUid == _me?.uid;

  bool _loading = true;
  Map<String, dynamic> _userData = {};
  int _followersCount = 0;
  int _followingCount = 0;
  List<Map<String, dynamic>> _posts = [];
  Set<String> _followingSet = {}; // who the CURRENT user follows

  // Scroll + posts-section anchor (for the Posts stat tap → scroll-to-grid)
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _postsSectionKey = GlobalKey();

  // Sidebar
  bool _sidebarOpen = false;
  late AnimationController _sidebarCtrl;
  late Animation<double> _sidebarFade;
  late Animation<Offset> _sidebarSlide;

  // Complete-profile form
  bool _completeOpen = false;
  late TextEditingController _bioCtrl, _phoneCtrl, _emailCtrl, _countryCtrl, _spotifyCtrl, _appleCtrl, _youtubeCtrl;
  bool _saving = false;
  String? _saveStatus;
  bool _saveError = false;

  @override
  void initState() {
    super.initState();
    _targetUid = widget.uid;
    _sidebarCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _sidebarFade = CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOut);
    _sidebarSlide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOutCubic));
    _bioCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _countryCtrl = TextEditingController();
    _spotifyCtrl = TextEditingController();
    _appleCtrl = TextEditingController();
    _youtubeCtrl = TextEditingController();
    _bootstrap();
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
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

  Future<void> _bootstrap() async {
    if (_me == null) return;
    await _loadFollowingSet();
    await _loadProfile();
  }

  Future<void> _loadFollowingSet() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(_me!.uid).collection('following').get();
      _followingSet = snap.docs.map((d) => d.id).toSet();
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _loading = true);

    Map<String, dynamic> data = {};
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(_targetUid).get();
      if (snap.exists) data = snap.data()!;
    } catch (_) {}

    int followersCount = 0, followingCount = 0;
    List<Map<String, dynamic>> posts = [];

    try {
      final s = await FirebaseFirestore.instance.collection('users').doc(_targetUid).collection('followers').get();
      followersCount = s.docs.length;
    } catch (_) {}

    try {
      final s = await FirebaseFirestore.instance.collection('users').doc(_targetUid).collection('following').get();
      followingCount = s.docs.length;
    } catch (_) {}

    try {
      final s = await FirebaseFirestore.instance.collection('posts').where('authorUid', isEqualTo: _targetUid).get();
      posts = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      posts.sort((a, b) {
        final ta = (a['createdAt'] is Timestamp) ? (a['createdAt'] as Timestamp).millisecondsSinceEpoch : 0;
        final tb = (b['createdAt'] is Timestamp) ? (b['createdAt'] as Timestamp).millisecondsSinceEpoch : 0;
        return tb.compareTo(ta);
      });
    } catch (_) {}

    // Force a fresh read for this uid so the header/avatar never lags
    // behind a just-saved edit — same reasoning web's getUserInfo cache has.
    UserInfoCache.instance.invalidate(_targetUid);
    await UserInfoCache.instance.get(_targetUid);

    if (!mounted) return;
    setState(() {
      _userData = data;
      _followersCount = followersCount;
      _followingCount = followingCount;
      _posts = posts;
      _bioCtrl.text = data['bio'] ?? '';
      _phoneCtrl.text = data['phone'] ?? '';
      _emailCtrl.text = data['publicEmail'] ?? '';
      _countryCtrl.text = data['country'] ?? '';
      _spotifyCtrl.text = data['spotifyUrl'] ?? '';
      _appleCtrl.text = data['appleMusicUrl'] ?? '';
      _youtubeCtrl.text = data['youtubeUrl'] ?? '';
      if (_isOwn) _completeOpen = !_hasPublicInfo(data);
      _loading = false;
    });
  }

  bool _hasPublicInfo(Map<String, dynamic> d) =>
      (d['phone'] ?? '').toString().isNotEmpty ||
      (d['publicEmail'] ?? '').toString().isNotEmpty ||
      (d['country'] ?? '').toString().isNotEmpty ||
      (d['spotifyUrl'] ?? '').toString().isNotEmpty ||
      (d['appleMusicUrl'] ?? '').toString().isNotEmpty ||
      (d['youtubeUrl'] ?? '').toString().isNotEmpty;

  Future<void> _toggleFollow(String uid) async {
    if (_me == null) return;
    final wasFollowing = _followingSet.contains(uid);
    setState(() => wasFollowing ? _followingSet.remove(uid) : _followingSet.add(uid));
    try {
      if (wasFollowing) {
        await FirebaseFirestore.instance.collection('users').doc(_me!.uid).collection('following').doc(uid).delete();
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('followers').doc(_me!.uid).delete();
      } else {
        await FirebaseFirestore.instance.collection('users').doc(_me!.uid).collection('following').doc(uid)
            .set({'since': FieldValue.serverTimestamp()});
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('followers').doc(_me!.uid)
            .set({'since': FieldValue.serverTimestamp()});
        sendNotification(uid, 'follow');
      }
      if (uid == _targetUid) _loadProfile(); // refresh counts on screen, matches web behavior
    } catch (_) {
      setState(() => wasFollowing ? _followingSet.add(uid) : _followingSet.remove(uid));
    }
  }

  Future<void> _saveCompleteProfile() async {
    if (_me == null) return;
    setState(() {
      _saving = true;
      _saveStatus = 'Saving…';
      _saveError = false;
    });
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
      setState(() {
        _userData = {..._userData, ...payload};
        _saveStatus = '✓ Saved';
        _saveError = false;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saveStatus = null);
      });
    } catch (_) {
      setState(() {
        _saveStatus = "Couldn't save — try again";
        _saveError = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openLightbox() {
    final url = (_userData['profilePic'] ?? '').toString();
    if (url.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => Stack(children: [
        Positioned.fill(child: InteractiveViewer(child: Center(child: CachedNetworkImage(imageUrl: url)))),
        Positioned(
          top: 40, right: 20,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54, border: Border.all(color: _white20)),
              child: const Icon(Icons.close, color: _white, size: 18),
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
        myUid: _me?.uid, onToggleFollow: _toggleFollow,
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

  // Matches web's postsStatBtn → scrollIntoView({behavior:'smooth', block:'start'})
  void _scrollToPosts() {
    final ctx = _postsSectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      alignment: 0, // 'start' alignment, matches web
    );
  }

  void _openSidebar() {
    setState(() => _sidebarOpen = true);
    _sidebarCtrl.forward();
  }

  void _closeSidebar() {
    _sidebarCtrl.reverse().then((_) {
      if (mounted) setState(() => _sidebarOpen = false);
    });
  }

  void _navigate(String route) {
    _closeSidebar();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) Navigator.pushNamed(context, route);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      extendBody: true,
      body: Stack(children: [
        SafeArea(
          bottom: false,
          child: Column(children: [
            _buildTopBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _white))
                  : RefreshIndicator(
                      color: _white, backgroundColor: _black2,
                      onRefresh: _loadProfile,
                      child: SingleChildScrollView(
                        controller: _scrollCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 110),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _buildProfileCard(),
                          if (_hasPublicInfo(_userData)) ...[
                            const SizedBox(height: 14),
                            _buildPublicInfoCard(),
                          ],
                          if (_isOwn) ...[
                            const SizedBox(height: 14),
                            _buildCompleteCard(),
                          ],
                          const SizedBox(height: 14),
                          _buildPostsSection(),
                        ]),
                      ),
                    ),
            ),
          ]),
        ),
        Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
        if (_sidebarOpen)
          GestureDetector(
            onTap: _closeSidebar,
            child: FadeTransition(opacity: _sidebarFade, child: Container(color: Colors.black.withOpacity(0.6))),
          ),
        if (_sidebarOpen)
          Positioned(
            top: 0, right: 0, bottom: 0,
            child: SlideTransition(position: _sidebarSlide, child: _buildSidebar()),
          ),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _white10))),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.canPop(context)
              ? Navigator.pop(context)
              : Navigator.pushReplacementNamed(context, '/home'),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _white06, borderRadius: BorderRadius.circular(10), border: Border.all(color: _white10)),
            child: const Icon(Icons.arrow_back_rounded, color: _white70, size: 18),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            (_userData['name'] ?? 'Profile').toString(),
            style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 16),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: _openSidebar,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _white06, borderRadius: BorderRadius.circular(10), border: Border.all(color: _white10)),
            child: const Icon(Icons.menu_rounded, color: _white70, size: 18),
          ),
        ),
      ]),
    );
  }

  Widget _buildProfileCard() {
    final name = (_userData['name'] ?? 'Artist').toString();
    final avatar = (_userData['profilePic'] ?? '').toString();
    final verified = _userData['verified'] == true;
    final bio = (_userData['bio'] ?? '').toString();
    final isFollowing = _followingSet.contains(_targetUid);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: _black2, borderRadius: BorderRadius.circular(22), border: Border.all(color: _white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          GestureDetector(
            onTap: _openLightbox,
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _black3, border: Border.all(color: _white20, width: 2)),
              clipBehavior: Clip.antiAlias,
              child: avatar.isNotEmpty
                  ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'A',
                        style: GoogleFonts.outfit(color: _white70, fontWeight: FontWeight.w800, fontSize: 30),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _statItem('${_posts.length}', 'Posts', _scrollToPosts),
              _statItem('$_followersCount', 'Followers', () => _openPeopleModal('followers')),
              _statItem('$_followingCount', 'Following', () => _openPeopleModal('following')),
            ]),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Row(children: [
            Flexible(child: Text(name, style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 20), overflow: TextOverflow.ellipsis)),
            if (verified) Padding(padding: const EdgeInsets.only(left: 7), child: verifiedTick(size: 15)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: bio.isNotEmpty
              ? Text(bio, style: GoogleFonts.nunito(color: _white70, fontSize: 13.5, height: 1.55))
              : (_isOwn
                  ? TextButton.icon(
                      onPressed: () => setState(() => _completeOpen = true),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero, minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.add, color: _grey, size: 14),
                      label: Text('Add a bio', style: GoogleFonts.nunito(color: _grey, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    )
                  : const SizedBox.shrink()),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _isOwn
              ? SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _completeOpen = true),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _white06, side: const BorderSide(color: _white10),
                      foregroundColor: _white70, padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: Text('Complete Profile', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _toggleFollow(_targetUid),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? Colors.transparent : _white,
                      foregroundColor: isFollowing ? _white70 : _black,
                      side: isFollowing ? const BorderSide(color: _white40) : null,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      elevation: 0,
                    ),
                    child: Text(isFollowing ? 'Following' : 'Follow', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _statItem(String num, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(children: [
        Text(num, style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.nunito(color: _grey, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _buildPublicInfoCard() {
    final country = (_userData['country'] ?? '').toString();
    final phone = (_userData['phone'] ?? '').toString();
    final email = (_userData['publicEmail'] ?? '').toString();
    final spotify = (_userData['spotifyUrl'] ?? '').toString();
    final apple = (_userData['appleMusicUrl'] ?? '').toString();
    final youtube = (_userData['youtubeUrl'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(color: _black2, borderRadius: BorderRadius.circular(18), border: Border.all(color: _white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (country.isNotEmpty) _infoRow(Icons.location_on_outlined, country),
        if (phone.isNotEmpty) _infoRow(Icons.phone_outlined, phone, onTap: () => _launchUrlAction('tel:$phone')),
        if (email.isNotEmpty) _infoRow(Icons.mail_outline_rounded, email, onTap: () => _launchUrlAction('mailto:$email')),
        if (spotify.isNotEmpty || apple.isNotEmpty || youtube.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _white10))),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
               if (spotify.isNotEmpty) _storeLink('spotify', 'Spotify', '1DB954', spotify),
               if (apple.isNotEmpty) _storeLink('applemusic', 'Apple Music', 'FC3C44', apple),
               if (youtube.isNotEmpty) _storeLink('youtubemusic', 'YouTube', 'FF0000', youtube),
              ]),
            ),
          ),
      ]),
    );
  }

  // tel:/mailto: links bypass the https-normalizing _launchUrl helper.
  Future<void> _launchUrlAction(String rawUri) async {
    final uri = Uri.tryParse(rawUri);
    if (uri == null) return;
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  Widget _infoRow(IconData icon, String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, color: _white40, size: 16),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.nunito(color: _white90, fontSize: 13.5))),
        ]),
      ),
    );
  }
Widget _storeLink(String slug, String label, String hex, String url) {
  return GestureDetector(
    onTap: () => _launchUrl(url),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(color: _white06, borderRadius: BorderRadius.circular(100), border: Border.all(color: _white10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SvgPicture.network(
          'https://cdn.simpleicons.org/$slug/$hex',
          width: 15, height: 15,
        ),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.nunito(color: _white90, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

  Widget _buildCompleteCard() {
    return Container(
      decoration: BoxDecoration(color: _black2, borderRadius: BorderRadius.circular(18), border: Border.all(color: _white10)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _completeOpen = !_completeOpen),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Complete your profile', style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 14.5)),
                  const SizedBox(height: 3),
                  Text('Hidden from the public until you save at least one field',
                      style: GoogleFonts.nunito(color: _grey, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
              AnimatedRotation(
                turns: _completeOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.keyboard_arrow_down_rounded, color: _grey),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _completeOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _field('Bio', _bioCtrl, maxLength: 150, maxLines: 4, hint: 'Tell people about your sound…'),
              const SizedBox(height: 12),
              _field('Phone Number', _phoneCtrl, hint: '+233 …', keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _field('Public Email', _emailCtrl, hint: 'you@example.com', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _field('Country', _countryCtrl, hint: 'e.g. Ghana'),
              const SizedBox(height: 12),
              _field('Spotify Artist Link', _spotifyCtrl, hint: 'https://open.spotify.com/artist/…', keyboardType: TextInputType.url),
              const SizedBox(height: 12),
              _field('Apple Music Link', _appleCtrl, hint: 'https://music.apple.com/artist/…', keyboardType: TextInputType.url),
              const SizedBox(height: 12),
              _field('YouTube Link', _youtubeCtrl, hint: 'https://youtube.com/@…', keyboardType: TextInputType.url),
              const SizedBox(height: 14),
              Row(children: [
                ElevatedButton(
                  onPressed: _saving ? null : _saveCompleteProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _white, foregroundColor: _black,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _black))
                      : Text('Update', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                if (_saveStatus != null)
                  Text(_saveStatus!, style: GoogleFonts.nunito(color: _saveError ? _rose : _green, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, int? maxLength, int maxLines = 1, TextInputType? keyboardType}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: GoogleFonts.nunito(color: _grey, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, maxLength: maxLength, maxLines: maxLines, keyboardType: keyboardType,
        style: GoogleFonts.nunito(color: _white, fontSize: 13.5),
        decoration: InputDecoration(
          filled: true, fillColor: _black3, hintText: hint,
          hintStyle: GoogleFonts.nunito(color: _greyDark),
          counterStyle: GoogleFonts.nunito(color: _greyDark, fontSize: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _white10)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _white10)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _white40)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        ),
      ),
    ]);
  }

  Widget _buildPostsSection() {
    return Column(
      key: _postsSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 2),
        child: Row(children: [
          const Icon(Icons.grid_view_rounded, color: _grey, size: 13),
          const SizedBox(width: 8),
          Text('POSTS', style: GoogleFonts.nunito(color: _grey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        ]),
      ),
      if (_posts.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(children: [
              const Icon(Icons.image_outlined, color: _white40, size: 26),
              const SizedBox(height: 10),
              Text(
                _isOwn ? 'No posts yet — share your first one.' : 'No posts yet.',
                style: GoogleFonts.nunito(color: _grey, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ]),
          ),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 3, mainAxisSpacing: 3),
          itemCount: _posts.length,
          itemBuilder: (context, i) {
            final p = _posts[i];
            final hasImage = (p['imageUrl'] ?? '').toString().isNotEmpty;
            final likes = p['likesCount'] ?? 0;
            final comments = p['commentsCount'] ?? 0;
            return GestureDetector(
              onTap: () => _openPostModal(p['id']),
              child: Stack(fit: StackFit.expand, children: [
                Container(
                  color: _black3,
                  child: hasImage
                      ? CachedNetworkImage(imageUrl: p['imageUrl'], fit: BoxFit.cover)
                      : Container(
                          padding: const EdgeInsets.all(10),
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [_black4, _black2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          ),
                          child: Text(
                            (p['text'] ?? '').toString(),
                            textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(color: _white70, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                ),
                // Always-visible like/comment badge — web shows this on
                // hover, which doesn't exist on touch, so it's pinned
                // to the corner here instead of being lost entirely.
                if (likes > 0 || comments > 0)
                  Positioned(
                    left: 5, bottom: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.favorite_rounded, color: _white, size: 10),
                        const SizedBox(width: 3),
                        Text('$likes', style: GoogleFonts.nunito(color: _white, fontSize: 10, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        const Icon(Icons.mode_comment_rounded, color: _white, size: 10),
                        const SizedBox(width: 3),
                        Text('$comments', style: GoogleFonts.nunito(color: _white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ]),
            );
          },
        ),
    ]);
  }

  Widget _buildBottomNav() {
    final bottom = MediaQuery.of(context).padding.bottom;
    final items = <(IconData, String, VoidCallback)>[
      (Icons.home_rounded, 'Home', () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false)),
      (Icons.bar_chart_rounded, 'Analytics', () => Navigator.pushNamed(context, '/analytics')),
      (Icons.cloud_upload_rounded, 'Upload', () => Navigator.pushNamed(context, '/upload')),
      (Icons.account_balance_wallet_rounded, 'Earnings', () => Navigator.pushNamed(context, '/earnings')),
      (Icons.person_rounded, 'Profile', () {
        if (!_isOwn) Navigator.pushNamed(context, '/viewpro', arguments: _me?.uid);
      }),
    ];
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(8, 10, 8, bottom + 10),
          decoration: const BoxDecoration(color: Color(0xD9000000), border: Border(top: BorderSide(color: _white10))),
          child: Row(children: items.map((item) {
            final (icon, label, onTap) = item;
            final isUpload = label == 'Upload';
            final isActive = label == 'Profile'; // this screen IS the profile tab
            if (isUpload) {
              return Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Center(
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: _white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: _white.withOpacity(0.2), blurRadius: 16, spreadRadius: 2)],
                      ),
                      child: Icon(icon, color: _black, size: 24),
                    ),
                  ),
                ),
              );
            }
            return Expanded(
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: isActive ? _white : _greyDark, size: 24),
                  const SizedBox(height: 4),
                  Text(label, style: GoogleFonts.outfit(color: isActive ? _white : _greyDark, fontSize: 10, fontWeight: isActive ? FontWeight.w800 : FontWeight.w500)),
                ]),
              ),
            );
          }).toList()),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final w = MediaQuery.of(context).size.width * 0.78;
    return Container(
      width: w, height: double.infinity, color: _black1,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: EdgeInsets.fromLTRB(24, top + 20, 24, 20),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _white10))),
          child: Row(children: [
            Text('444Music', style: GoogleFonts.outfit(color: _white, fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            GestureDetector(
              onTap: _closeSidebar,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: _white10)),
                child: const Icon(Icons.close_rounded, color: _grey, size: 18),
              ),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sidebarLabel('Navigation'),
              _sidebarItem(Icons.home_rounded, 'Home', () {
                _closeSidebar();
                Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
              }),
             _sidebarItem(Icons.person_rounded, 'Settings', () {
               _closeSidebar();
               Navigator.pushReplacementNamed(context, '/profile');
             }),
              _sidebarItem(Icons.speed_rounded, 'Dashboard', () => _navigate('/dashboard')),
              _sidebarItem(Icons.cloud_upload_rounded, 'Upload Release', () => _navigate('/upload')),
              _sidebarItem(Icons.bar_chart_rounded, 'Analytics', () => _navigate('/analytics')),
              _sidebarItem(Icons.account_balance_wallet_rounded, 'Earnings', () => _navigate('/earnings')),
              const _SidebarDividerLocal(),
              _sidebarLabel('More'),
              _sidebarItem(Icons.build_rounded, 'More Tools', () => _navigate('/tools')),
              _sidebarItem(Icons.info_outline_rounded, 'About Us', () => _navigate('/legal')),
              _sidebarItem(Icons.mail_outline_rounded, 'Contact Support', () => _navigate('/support')),
              const _SidebarDividerLocal(),
            ]),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
          child: GestureDetector(
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              _closeSidebar();
              if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade900.withOpacity(0.25)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.logout_rounded, color: Color(0xFFFF6B6B), size: 18),
                const SizedBox(width: 10),
                Text('Logout', style: GoogleFonts.outfit(color: const Color(0xFFFF6B6B), fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sidebarLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
        child: Text(label.toUpperCase(), style: GoogleFonts.outfit(color: _greyDark, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2)),
      );

  Widget _sidebarItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Icon(icon, color: _grey, size: 18),
            const SizedBox(width: 14),
            Text(label, style: GoogleFonts.outfit(color: _grey, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _SidebarDividerLocal extends StatelessWidget {
  const _SidebarDividerLocal();
  @override
  Widget build(BuildContext context) =>
      Container(margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), height: 1, color: _white10);
}

// ═══════════════════════════════════════════════════════════════════
//  FOLLOWERS / FOLLOWING MODAL
// ═══════════════════════════════════════════════════════════════════
class _PeopleModal extends StatefulWidget {
  final String targetUid, kind;
  final Set<String> myFollowing;
  final String? myUid;
  final Future<void> Function(String uid) onToggleFollow;
  const _PeopleModal({
    required this.targetUid, required this.kind, required this.myFollowing,
    required this.myUid, required this.onToggleFollow,
  });
  @override
  State<_PeopleModal> createState() => _PeopleModalState();
}

class _PeopleModalState extends State<_PeopleModal> {
  List<Map<String, dynamic>>? _people;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(widget.targetUid).collection(widget.kind).get();
      final uids = snap.docs.map((d) => d.id).toList();
      final infos = await Future.wait(uids.map((uid) => UserInfoCache.instance.get(uid).then((info) => {'uid': uid, ...info})));
      if (mounted) setState(() => _people = infos);
    } catch (_) {
      if (mounted) setState(() => _people = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6, minChildSize: 0.35, maxChildSize: 0.92,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(color: _black1, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.kind == 'followers' ? 'Followers' : 'Following',
                style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const Divider(color: _white10, height: 1),
          Expanded(
            child: _people == null
                ? const Center(child: CircularProgressIndicator(color: _white))
                : _people!.isEmpty
                    ? Center(child: Text('No ${widget.kind} yet.', style: GoogleFonts.nunito(color: _grey)))
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: _people!.length,
                        itemBuilder: (context, i) {
                          final p = _people![i];
                          final uid = p['uid'] as String;
                          final isSelf = uid == widget.myUid;
                          final isFollowing = widget.myFollowing.contains(uid);
                          final name = (p['name'] ?? 'Artist').toString();
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            leading: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: _black3, border: Border.all(color: _white10)),
                              clipBehavior: Clip.antiAlias,
                              child: (p['avatar'] ?? '').toString().isNotEmpty
                                  ? CachedNetworkImage(imageUrl: p['avatar'], fit: BoxFit.cover)
                                  : Center(
                                      child: Text(
                                        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'A',
                                        style: GoogleFonts.outfit(color: _white70, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                            ),
                            title: Row(children: [
                              Flexible(child: Text(name, style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 14), overflow: TextOverflow.ellipsis)),
                              if (p['verified'] == true) Padding(padding: const EdgeInsets.only(left: 5), child: verifiedTick(size: 13)),
                            ]),
                            trailing: isSelf
                                ? null
                                : SizedBox(
                                    height: 32,
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await widget.onToggleFollow(uid);
                                        setState(() {});
                                      },
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: isFollowing ? Colors.transparent : _white,
                                        foregroundColor: isFollowing ? _white70 : _black,
                                        side: isFollowing ? const BorderSide(color: _white40) : BorderSide.none,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                      ),
                                      child: Text(isFollowing ? 'Following' : 'Follow', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 11.5)),
                                    ),
                                  ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/viewpro', arguments: uid);
                            },
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  POST DETAIL MODAL — flat comments (no reply-threading), matching
//  web's pm-* section in profile.html exactly.
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
      final snap = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
      if (!snap.exists) {
        if (mounted) setState(() => _post = {});
        return;
      }
      final likeSnap = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('likes').doc(widget.myUid).get();
      if (mounted) {
        setState(() {
          _post = {'id': snap.id, ...snap.data()!};
          _liked = likeSnap.exists;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _post = {});
    }
  }

  Future<void> _toggleLike() async {
    if (_post == null || _post!.isEmpty) return;
    final wasLiked = _liked;
    setState(() {
      _liked = !wasLiked;
      _post!['likesCount'] = (_post!['likesCount'] ?? 0) + (wasLiked ? -1 : 1);
    });
    try {
      final likeRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('likes').doc(widget.myUid);
      final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      if (wasLiked) {
        await likeRef.delete();
        await postRef.update({'likesCount': FieldValue.increment(-1)});
      } else {
        await likeRef.set({'uid': widget.myUid, 'likedAt': FieldValue.serverTimestamp()});
        await postRef.update({'likesCount': FieldValue.increment(1)});
        sendNotification(_post!['authorUid'], 'like', postId: widget.postId, postText: _post!['text'], postImage: _post!['imageUrl']);
      }
    } catch (_) {
      setState(() {
        _liked = wasLiked;
        _post!['likesCount'] = (_post!['likesCount'] ?? 0) + (wasLiked ? 1 : -1);
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _post == null || _post!.isEmpty || _sending) return;
    setState(() => _sending = true);
    _commentCtrl.clear();
    try {
      final myInfo = await UserInfoCache.instance.get(widget.myUid);
      final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      await postRef.collection('comments').add({
        'authorUid': widget.myUid,
        'authorName': myInfo['name'],
        'authorAvatar': myInfo['avatar'],
        'text': text, 'parentId': null, 'createdAt': FieldValue.serverTimestamp(),
      });
      await postRef.update({'commentsCount': FieldValue.increment(1)});
      setState(() => _post!['commentsCount'] = (_post!['commentsCount'] ?? 0) + 1);
      sendNotification(_post!['authorUid'], 'comment', postId: widget.postId, postText: _post!['text'], postImage: _post!['imageUrl'], commentText: text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8, minChildSize: 0.45, maxChildSize: 0.95,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(color: _black1, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: _post == null
            ? const Center(child: CircularProgressIndicator(color: _white))
            : _post!.isEmpty
                ? Center(child: Text('Post not found.', style: GoogleFonts.nunito(color: _grey)))
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Text('Post', style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 16)),
                        const Spacer(),
                        GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close_rounded, color: _grey)),
                      ]),
                    ),
                    const Divider(color: _white10, height: 1),
                    Expanded(
                      child: ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        children: [
                          FutureBuilder<Map<String, dynamic>>(
                            future: UserInfoCache.instance.get(_post!['authorUid']),
                            builder: (context, snap) {
                              final info = snap.data ?? {'name': _post!['authorName'] ?? 'Artist', 'avatar': _post!['authorAvatar'] ?? '', 'verified': false};
                              final created = (_post!['createdAt'] is Timestamp) ? (_post!['createdAt'] as Timestamp).toDate() : null;
                              final name = (info['name'] ?? 'Artist').toString();
                              return Row(children: [
                                Container(
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: _black3, border: Border.all(color: _white10)),
                                  clipBehavior: Clip.antiAlias,
                                  child: (info['avatar'] ?? '').toString().isNotEmpty
                                      ? CachedNetworkImage(imageUrl: info['avatar'], fit: BoxFit.cover)
                                      : Center(child: Text(name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'A', style: GoogleFonts.outfit(color: _white70, fontWeight: FontWeight.w800))),
                                ),
                                const SizedBox(width: 12),
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Text(name, style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 14.5)),
                                    if (info['verified'] == true) Padding(padding: const EdgeInsets.only(left: 4), child: verifiedTick(size: 12)),
                                  ]),
                                  Text(timeAgo(created), style: GoogleFonts.nunito(color: _grey, fontSize: 11.5, fontWeight: FontWeight.w600)),
                                ]),
                              ]);
                            },
                          ),
                          if ((_post!['text'] ?? '').toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text.rich(
                                TextSpan(children: _hashtagSpans(
                                  (_post!['text'] ?? '').toString(),
                                  base: GoogleFonts.nunito(color: _white90, fontSize: 14, height: 1.6),
                                )),
                              ),
                            ),
                          if ((_post!['imageUrl'] ?? '').toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedNetworkImage(imageUrl: _post!['imageUrl'], fit: BoxFit.cover)),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Row(children: [
                              GestureDetector(
                                onTap: _toggleLike,
                                child: Row(children: [
                                  Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _liked ? _rose : _grey, size: 18),
                                  const SizedBox(width: 6),
                                  Text('${_post!['likesCount'] ?? 0}', style: GoogleFonts.nunito(color: _liked ? _rose : _grey, fontSize: 12.5, fontWeight: FontWeight.w700)),
                                ]),
                              ),
                              const SizedBox(width: 20),
                              const Icon(Icons.mode_comment_outlined, color: _grey, size: 18),
                              const SizedBox(width: 6),
                              Text('${_post!['commentsCount'] ?? 0}', style: GoogleFonts.nunito(color: _grey, fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: _white10, height: 1)),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('comments')
                                .orderBy('createdAt').limit(200).snapshots(),
                            builder: (context, snap) {
                              if (!snap.hasData) {
                                return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: CircularProgressIndicator(color: _white)));
                              }
                              final comments = snap.data!.docs.map((d) => {'id': d.id, ...d.data()}).toList();
                              if (comments.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text('No comments yet.', style: GoogleFonts.nunito(color: _grey, fontSize: 12.5)),
                                );
                              }
                              return Column(
                                children: comments.map((c) {
                                  final cName = (c['authorName'] ?? 'Artist').toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Container(
                                        width: 28, height: 28,
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: _black3, border: Border.all(color: _white10)),
                                        clipBehavior: Clip.antiAlias,
                                        child: (c['authorAvatar'] ?? '').toString().isNotEmpty
                                            ? CachedNetworkImage(imageUrl: c['authorAvatar'], fit: BoxFit.cover)
                                            : Center(child: Text(cName.trim().isNotEmpty ? cName.trim()[0].toUpperCase() : 'A', style: GoogleFonts.outfit(color: _white70, fontWeight: FontWeight.w800, fontSize: 11))),
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                                          decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(14)),
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(cName, style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                                            const SizedBox(height: 2),
                                            Text.rich(
                                              TextSpan(children: _hashtagSpans(
                                                (c['text'] ?? '').toString(),
                                                base: GoogleFonts.nunito(color: _white70, fontSize: 13),
                                              )),
                                            ),
                                          ]),
                                        ),
                                      ),
                                    ]),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _commentCtrl,
                              style: GoogleFonts.nunito(color: _white, fontSize: 13.5),
                              decoration: InputDecoration(
                                isDense: true, filled: true, fillColor: _black3,
                                hintText: 'Write a comment…', hintStyle: GoogleFonts.nunito(color: _grey),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              onSubmitted: (_) => _submitComment(),
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.send_rounded, color: _white), onPressed: _submitComment),
                        ]),
                      ),
                    ),
                  ]),
      ),
    );
  }
}