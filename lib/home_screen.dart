// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Home Screen v7 (Feed rebuild) — with threaded comment replies
//
//  The marketing hero / wave-divider / release-panel / why-us layout is
//  GONE. The feed itself is now the home screen, matching wey.html on
//  web: same Firestore collections (posts, stories, notifications,
//  users, siteAds) so mobile and web show the exact same live data.
//
//  Ported from web: ad banner on load, stories bar + full-screen story
//  viewer (press-and-hold to pause, delete own / like others / viewers
//  list for own), working search (posts by text/author, people by
//  name), For You / Following / People tabs, post like/comment/share/
//  follow/edit/delete, comment delete (not on web yet before this pass),
//  THREADED COMMENT REPLIES (parentId, matches web's reply UX — new in
//  this pass), verified badge shown everywhere a name appears (post
//  cards, comments, replies, story viewer) driven by users/{uid}.verified,
//  notification bell + panel moved up next to the search bar, and a "+"
//  composer button next to it for new posts.
//
//  Bottom nav, sidebar, and Upload's destination are UNCHANGED per
//  request — only the Profile tab's destination changes (now points at
//  a future '/viewpro' route instead of '/profile'), and the sidebar's
//  own-account label changes from "Account" to "Settings".
// ═══════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// ─── PALETTE ────────────────────────────────────────────────────────
const _black      = Color(0xFF000000);
const _black1     = Color(0xFF0A0A0A);
const _black2     = Color(0xFF111111);
const _black3     = Color(0xFF1A1A1A);
const _white      = Color(0xFFFFFFFF);
const _white90    = Color(0xE6FFFFFF);
const _white70    = Color(0xB3FFFFFF);
const _white40    = Color(0x66FFFFFF);
const _white20    = Color(0x33FFFFFF);
const _white10    = Color(0x1AFFFFFF);
const _white06    = Color(0x0FFFFFFF);
const _grey       = Color(0xFF888888);
const _greyDark   = Color(0xFF444444);
const _gold       = Color(0xFFCBA135);
const _gold70     = Color(0xB3CBA135);
const _blue       = Color(0xFF4DA3FF);  // verified badge, links — matches web
const _rose       = Color(0xFFF87171);

// ─── Cloudinary (same unsigned preset used everywhere else in the app) ──
const _cloudName    = 'dlbgqtvqg';
const _uploadPreset = 'glmamp2y';

Future<String?> _uploadToCloudinary(XFile file) async {
  try {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['secure_url'] as String?;
  } catch (_) {
    return null;
  }
}

// ─── Shared user-info cache (name/avatar/verified) ─────────────────────
// A single app-wide cache so the verified tick and current avatar/name
// are consistent everywhere a uid is rendered: feed cards, comments,
// replies, story viewer, people list, notifications.
class UserInfoCache {
  UserInfoCache._();
  static final UserInfoCache instance = UserInfoCache._();
  final Map<String, Map<String, dynamic>> _cache = {};

  Future<Map<String, dynamic>> get(String uid) async {
    if (_cache.containsKey(uid)) return _cache[uid]!;
    Map<String, dynamic> info = {'name': 'Artist', 'avatar': '', 'verified': false};
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (snap.exists) {
        final d = snap.data()!;
        info = {
          'name': (d['name'] as String?)?.trim().isNotEmpty == true ? d['name'] : 'Artist',
          'avatar': d['profilePic'] ?? '',
          'verified': d['verified'] == true,
        };
      }
    } catch (_) {}
    _cache[uid] = info;
    return info;
  }

  void invalidate(String uid) => _cache.remove(uid);
}

Widget verifiedTick({double size = 13}) =>
    Icon(Icons.verified_rounded, color: _blue, size: size);

String timeAgo(DateTime? date) {
  if (date == null) return 'just now';
  final secs = DateTime.now().difference(date).inSeconds;
  if (secs < 60) return 'just now';
  final mins = secs ~/ 60;
  if (mins < 60) return '${mins}m ago';
  final hrs = mins ~/ 60;
  if (hrs < 24) return '${hrs}h ago';
  final days = hrs ~/ 24;
  if (days < 7) return '${days}d ago';
  final weeks = days ~/ 7;
  if (weeks < 5) return '${weeks}w ago';
  final months = days ~/ 30;
  if (months < 12) return '${months}mo ago';
  return '${days ~/ 365}y ago';
}

Future<void> sendNotification(String targetUid, String type, {
  String? postId, String? postText, String? postImage, String? commentText,
}) async {
  final me = FirebaseAuth.instance.currentUser;
  if (me == null || targetUid == me.uid) return;
  final myInfo = await UserInfoCache.instance.get(me.uid);
  try {
    await FirebaseFirestore.instance
        .collection('notifications').doc(targetUid).collection('items').add({
      'type': type,
      'fromUid': me.uid,
      'fromName': myInfo['name'],
      'fromAvatar': myInfo['avatar'],
      'postId': postId,
      'postText': postText != null && postText.length > 120 ? postText.substring(0, 120) : postText,
      'postImage': postImage,
      'commentText': commentText != null && commentText.length > 140 ? commentText.substring(0, 140) : commentText,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  } catch (_) {}
}

// ════════════════════════════════════════════════════════════════════
//  HOME SCREEN — shell (sidebar + bottom nav) unchanged in spirit;
//  content is now the feed, not the marketing hero.
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
  late Animation<double>   _sidebarFade;
  late Animation<Offset>   _sidebarSlide;

  final _user = FirebaseAuth.instance.currentUser;
  String? _liveName;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _nameSub;

  final GlobalKey<_FeedHomeState> _feedKey = GlobalKey<_FeedHomeState>();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _black,
    ));

    _sidebarCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _sidebarFade  = CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOut);
    _sidebarSlide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOutCubic));

    if (_user != null) {
      _nameSub = FirebaseFirestore.instance
          .collection('users').doc(_user!.uid).snapshots()
          .listen((doc) {
        final name = doc.data()?['name'] as String?;
        if (mounted && name != null && name.isNotEmpty && name != _liveName) {
          setState(() => _liveName = name);
        }
      });
    }
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    _nameSub?.cancel();
    super.dispose();
  }

  void _openSidebar()  { setState(() => _sidebarOpen = true); _sidebarCtrl.forward(); }
  void _closeSidebar() {
    _sidebarCtrl.reverse().then((_) { if (mounted) setState(() => _sidebarOpen = false); });
  }
  void _navigate(String route) {
    _closeSidebar();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) Navigator.pushNamed(context, route);
    });
  }

  void _onBottomNavTap(int i) {
    if (i == 0) {
      if (_navIndex == 0) {
        // Already on Home — Instagram-style: scroll to top and pull fresh
        // posts, rather than doing nothing.
        _feedKey.currentState?.scrollToTopAndRefresh();
      } else {
        setState(() => _navIndex = 0);
      }
      return;
    }
    if (i == 1) { Navigator.pushNamed(context, '/analytics'); return; }
    if (i == 2) { Navigator.pushNamed(context, '/upload');    return; } // untouched — goes to pricing
    if (i == 3) { Navigator.pushNamed(context, '/earnings');  return; }
    if (i == 4) {
      // Bottom-nav "Profile" now opens the profile VIEWER (viewpro), not
      // the settings screen — mirrors the web app's split between
      // viewpro.html (viewer) and profile.html (settings).
      Navigator.pushNamed(context, '/viewpro', arguments: _user?.uid);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _navIndex,
            children: [
              _FeedHome(key: _feedKey, currentUser: _user),
              const _PlaceholderTab(icon: Icons.bar_chart_rounded,              label: 'Analytics'),
              const _PlaceholderTab(icon: Icons.cloud_upload_rounded,           label: 'Upload'),
              const _PlaceholderTab(icon: Icons.account_balance_wallet_rounded, label: 'Earnings'),
              const _PlaceholderTab(icon: Icons.person_rounded,                 label: 'Profile'),
            ],
          ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomNav(current: _navIndex, onTap: _onBottomNavTap),
          ),

          if (_sidebarOpen)
            GestureDetector(
              onTap: _closeSidebar,
              child: FadeTransition(
                opacity: _sidebarFade,
                child: Container(color: Colors.black.withOpacity(0.6)),
              ),
            ),

          if (_sidebarOpen)
            Positioned(
              top: 0, right: 0, bottom: 0,
              child: SlideTransition(
                position: _sidebarSlide,
                child: _SidebarPanel(
                  onClose: _closeSidebar,
                  onNavigate: _navigate,
                  userName:  _liveName ?? _user?.displayName ?? 'Artist',
                  userEmail: _user?.email ?? '',
                  uid: _user?.uid,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  FEED HOME — everything that used to live above the fold on web
//  (ad banner, stories bar, search+notif+compose bar, the feed itself)
// ════════════════════════════════════════════════════════════════════
enum _FeedTab { forYou, following, people }

class _FeedHome extends StatefulWidget {
  final User? currentUser;
  const _FeedHome({super.key, required this.currentUser});
  @override
  State<_FeedHome> createState() => _FeedHomeState();
}

class _FeedHomeState extends State<_FeedHome> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  _FeedTab _tab = _FeedTab.forYou;
  String _myName = 'Artist';
  String _myAvatar = '';

  Set<String> _followingSet = {};
  StreamSubscription? _postsSub;
  StreamSubscription? _storiesSub;
  StreamSubscription? _notifSub;

  List<Map<String, dynamic>> _allPosts = [];
  List<Map<String, dynamic>> _filteredPosts = [];
  List<Map<String, dynamic>> _people = [];
  Map<String, List<Map<String, dynamic>>> _storiesByAuthor = {};

  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifs = [];

  Map<String, dynamic>? _ad;
  bool _adDismissed = false;
  bool _refreshing = false;

  User? get _user => widget.currentUser;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_user == null) return;
    _loadAd();
    final info = await UserInfoCache.instance.get(_user!.uid);
    _myName = info['name']; _myAvatar = info['avatar'];
    await _loadFollowing();
    _listenPosts();
    _listenNotifs();
    _listenStories();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _postsSub?.cancel();
    _storiesSub?.cancel();
    _notifSub?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Called from the bottom-nav "Home" tap while already on Home.
  void scrollToTopAndRefresh() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
    setState(() => _refreshing = true);
    // Posts already stream live; this just re-primes the People list and
    // gives a brief refresh affordance so it *feels* like a manual pull,
    // the way Instagram's re-tap-home does.
    Future.wait([_loadFollowing(), if (_tab == _FeedTab.people) _loadPeople()]).then((_) {
      if (mounted) setState(() => _refreshing = false);
    });
  }

  Future<void> _loadAd() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('siteAds').orderBy('createdAt', descending: true).limit(1).get();
      if (snap.docs.isEmpty) return;
      final d = snap.docs.first.data();
      if ((d['imageUrl'] ?? '').toString().isEmpty || (d['linkUrl'] ?? '').toString().isEmpty) return;
      if (mounted) setState(() => _ad = d);
    } catch (_) {}
  }

  Future<void> _loadFollowing() async {
    if (_user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(_user!.uid).collection('following').get();
      _followingSet = snap.docs.map((d) => d.id).toSet();
    } catch (_) {}
  }

  void _listenPosts() {
    _postsSub?.cancel();
    _postsSub = FirebaseFirestore.instance
        .collection('posts').orderBy('createdAt', descending: true).limit(50)
        .snapshots().listen((snap) {
      var posts = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (_tab == _FeedTab.following) {
        posts = posts.where((p) => _followingSet.contains(p['authorUid']) || p['authorUid'] == _user?.uid).toList();
      }
      _allPosts = posts;
      _applySearch();
    });
  }

  void _listenStories() {
    _storiesSub?.cancel();
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
    _storiesSub = FirebaseFirestore.instance
        .collection('stories').where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt').snapshots().listen((snap) {
      final map = <String, List<Map<String, dynamic>>>{};
      for (final d in snap.docs) {
        final s = {'id': d.id, ...d.data()};
        map.putIfAbsent(s['authorUid'], () => []).add(s);
      }
      if (mounted) setState(() => _storiesByAuthor = map);
    });
  }

  void _listenNotifs() {
    if (_user == null) return;
    _notifSub?.cancel();
    _notifSub = FirebaseFirestore.instance
        .collection('notifications').doc(_user!.uid).collection('items')
        .orderBy('createdAt', descending: true).limit(50)
        .snapshots().listen((snap) {
      _notifs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (mounted) setState(() => _unreadCount = _notifs.where((n) => n['read'] != true).length);
    });
  }

  Future<void> _loadPeople() async {
    if (_user == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').limit(200).get();
      _people = snap.docs.where((d) => d.id != _user!.uid).map((d) {
        final u = d.data();
        return {'uid': d.id, 'name': u['name'] ?? 'Artist', 'avatar': u['profilePic'] ?? ''};
      }).toList();
      _applySearch();
    } catch (_) {}
  }

  void _applySearch() {
    final term = _searchCtrl.text.trim().toLowerCase();
    if (_tab == _FeedTab.people) {
      _people = term.isEmpty ? _people : _people.where((p) => (p['name'] as String).toLowerCase().contains(term)).toList();
    } else {
      _filteredPosts = term.isEmpty
          ? _allPosts
          : _allPosts.where((p) =>
              (p['text'] ?? '').toString().toLowerCase().contains(term) ||
              (p['authorName'] ?? '').toString().toLowerCase().contains(term)).toList();
    }
    if (mounted) setState(() {});
  }

  void _onTabChange(_FeedTab t) {
    setState(() => _tab = t);
    _searchCtrl.clear();
    if (t == _FeedTab.people) {
      _loadPeople();
    } else {
      _listenPosts();
    }
  }

  Future<void> _toggleFollow(String targetUid) async {
    final wasFollowing = _followingSet.contains(targetUid);
    setState(() => wasFollowing ? _followingSet.remove(targetUid) : _followingSet.add(targetUid));
    try {
      final me = _user!.uid;
      if (wasFollowing) {
        await FirebaseFirestore.instance.collection('users').doc(me).collection('following').doc(targetUid).delete();
        await FirebaseFirestore.instance.collection('users').doc(targetUid).collection('followers').doc(me).delete();
      } else {
        await FirebaseFirestore.instance.collection('users').doc(me).collection('following').doc(targetUid)
            .set({'since': FieldValue.serverTimestamp()});
        await FirebaseFirestore.instance.collection('users').doc(targetUid).collection('followers').doc(me)
            .set({'since': FieldValue.serverTimestamp()});
        sendNotification(targetUid, 'follow');
      }
    } catch (_) {
      setState(() => wasFollowing ? _followingSet.add(targetUid) : _followingSet.remove(targetUid));
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final postId = post['id'] as String;
    final likeRef = FirebaseFirestore.instance.collection('posts').doc(postId).collection('likes').doc(_user!.uid);
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final existing = await likeRef.get();
    if (existing.exists) {
      await likeRef.delete();
      await postRef.update({'likesCount': FieldValue.increment(-1)});
    } else {
      await likeRef.set({'uid': _user!.uid, 'likedAt': FieldValue.serverTimestamp()});
      await postRef.update({'likesCount': FieldValue.increment(1)});
      sendNotification(post['authorUid'], 'like', postId: postId, postText: post['text'], postImage: post['imageUrl']);
    }
  }

  Future<void> _deletePost(String postId) async {
    await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
  }

  Future<void> _saveEditedPost(String postId, String newText) async {
    await FirebaseFirestore.instance.collection('posts').doc(postId)
        .update({'text': newText, 'edited': true});
  }

  void _openComments(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(post: post, myUid: _user!.uid, myName: _myName, myAvatar: _myAvatar),
    );
  }

  void _openShare(Map<String, dynamic> post) {
    // Minimal share sheet: copy-link + "Add to Your Story", matching the
    // web app's two most-used share paths without needing a contacts UI.
    showModalBottomSheet(
      context: context, backgroundColor: _black1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded, color: _white),
              title: Text('Add to Your Story', style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w700)),
              onTap: () async {
                Navigator.pop(ctx);
                await _addPostToStory(post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: _white),
              title: Text('Copy Link', style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(ctx),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _addPostToStory(Map<String, dynamic> post) async {
    final authorInfo = await UserInfoCache.instance.get(post['authorUid']);
    final payload = {
      'authorUid': _user!.uid, 'authorName': _myName, 'authorAvatar': _myAvatar,
      'type': post['imageUrl'] != null ? 'image' : 'text',
      'createdAt': FieldValue.serverTimestamp(),
      'sharedPostId': post['id'], 'sharedFromUid': post['authorUid'],
      'sharedFromName': authorInfo['name'], 'sharedFromAvatar': authorInfo['avatar'],
      if (post['imageUrl'] != null) 'imageUrl': post['imageUrl'],
      if (post['imageUrl'] == null) 'text': post['text'] ?? '',
    };
    await FirebaseFirestore.instance.collection('stories').add(payload);
    if (post['authorUid'] != _user!.uid) {
      sendNotification(post['authorUid'], 'story_share', postId: post['id'], postText: post['text'], postImage: post['imageUrl']);
    }
  }

  void _openNewPostComposer() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _NewPostScreen(myName: _myName, myAvatar: _myAvatar)));
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: _black1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _NotificationsSheet(notifs: _notifs, uid: _user!.uid),
    );
  }

  void _openStoryComposer() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _StoryComposerScreen(myName: _myName, myAvatar: _myAvatar),
    ));
  }

  void _openStoryViewer(String uid) {
    final stories = _storiesByAuthor[uid] ?? [];
    if (stories.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _StoryViewerScreen(
        stories: stories, myUid: _user!.uid,
        onDeleted: () => setState(() {}),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Top bar: search + notif + compose ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: _black2, borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: _white10),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => _applySearch(),
                        style: GoogleFonts.nunito(color: _white, fontSize: 13.5),
                        decoration: InputDecoration(
                          isDense: true, border: InputBorder.none,
                          prefixIcon: const Icon(Icons.search_rounded, color: _grey, size: 19),
                          hintText: 'Search artists, posts, hashtags…',
                          hintStyle: GoogleFonts.nunito(color: _grey, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _NotifBell(count: _unreadCount, onTap: _openNotifications),
                  const SizedBox(width: 8),
                  _IconBtn(icon: Icons.add_rounded, onTap: _openNewPostComposer),
                ]),
              ),

              // ── Stories bar ──
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _StoryBubble(
                      label: 'Your Story', uid: _user?.uid, avatarUrl: _myAvatar, name: _myName,
                      hasStory: (_storiesByAuthor[_user?.uid] ?? []).isNotEmpty,
                      isOwn: true,
                      onTap: () {
                        final mine = _storiesByAuthor[_user?.uid] ?? [];
                        if (mine.isNotEmpty) { _openStoryViewer(_user!.uid); } else { _openStoryComposer(); }
                      },
                      onAddTap: _openStoryComposer,
                    ),
                    ..._storiesByAuthor.keys.where((uid) => uid != _user?.uid).map((uid) {
                      final info = _storiesByAuthor[uid]!.last;
                      return FutureBuilder<Map<String, dynamic>>(
                        future: UserInfoCache.instance.get(uid),
                        builder: (context, snap) {
                          final d = snap.data ?? {'name': info['authorName'] ?? 'Artist', 'avatar': info['authorAvatar'] ?? ''};
                          return _StoryBubble(
                            label: d['name'], uid: uid, avatarUrl: d['avatar'], name: d['name'],
                            hasStory: true, isOwn: false,
                            onTap: () => _openStoryViewer(uid),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),

              // ── Feed tabs ──
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _white10))),
                child: Row(children: [
                  _FeedTabBtn(label: 'For You',    active: _tab == _FeedTab.forYou,    onTap: () => _onTabChange(_FeedTab.forYou)),
                  _FeedTabBtn(label: 'Following',   active: _tab == _FeedTab.following, onTap: () => _onTabChange(_FeedTab.following)),
                  _FeedTabBtn(label: 'People',      active: _tab == _FeedTab.people,    onTap: () => _onTabChange(_FeedTab.people)),
                ]),
              ),

              if (_refreshing) const LinearProgressIndicator(minHeight: 2, color: _white, backgroundColor: _black3),

              // ── Body ──
              Expanded(
                child: _tab == _FeedTab.people ? _buildPeopleList() : _buildPostsList(),
              ),
            ],
          ),
        ),

        // Ad overlay
        if (_ad != null && !_adDismissed)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.72),
              padding: EdgeInsets.only(top: top + 40),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: GestureDetector(
                      onTap: () {}, // external link handling left to existing url-launcher setup
                      child: CachedNetworkImage(imageUrl: _ad!['imageUrl'], fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => setState(() => _adDismissed = true),
                  child: Text('dismiss', style: GoogleFonts.nunito(color: _white70, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildPostsList() {
    if (_filteredPosts.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.forum_outlined, color: _white40, size: 30),
          const SizedBox(height: 10),
          Text('No posts yet — be the first to share something.',
              style: GoogleFonts.nunito(color: _grey, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
      itemCount: _filteredPosts.length,
      itemBuilder: (context, i) => _PostCard(
        post: _filteredPosts[i],
        isFollowing: _followingSet.contains(_filteredPosts[i]['authorUid']),
        isSelf: _filteredPosts[i]['authorUid'] == _user?.uid,
        onFollow: () => _toggleFollow(_filteredPosts[i]['authorUid']),
        onLike: () => _toggleLike(_filteredPosts[i]),
        onComment: () => _openComments(_filteredPosts[i]),
        onShare: () => _openShare(_filteredPosts[i]),
        onDelete: () => _deletePost(_filteredPosts[i]['id']),
        onEdit: (newText) => _saveEditedPost(_filteredPosts[i]['id'], newText),
      ),
    );
  }

  Widget _buildPeopleList() {
    if (_people.isEmpty) {
      return FutureBuilder(
        future: _loadPeople(),
        builder: (context, snap) => const Center(child: CircularProgressIndicator(color: _white)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
      itemCount: _people.length,
      itemBuilder: (context, i) {
        final p = _people[i];
        final isFollowing = _followingSet.contains(p['uid']);
        return FutureBuilder<Map<String, dynamic>>(
          future: UserInfoCache.instance.get(p['uid']),
          builder: (context, snap) {
            final verified = snap.data?['verified'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _black2, borderRadius: BorderRadius.circular(18), border: Border.all(color: _white10)),
              child: Row(children: [
                _Avatar(url: p['avatar'], name: p['name'], size: 46),
                const SizedBox(width: 12),
                Expanded(child: Row(children: [
                  Flexible(child: Text(p['name'], style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 14.5), overflow: TextOverflow.ellipsis)),
                  if (verified) Padding(padding: const EdgeInsets.only(left: 4), child: verifiedTick()),
                ])),
                _FollowBtn(following: isFollowing, onTap: () => _toggleFollow(p['uid'])),
              ]),
            );
          },
        );
      },
    );
  }
}

// ─── Small shared widgets ──────────────────────────────────────────────

class _NotifBell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _NotifBell({required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: _white06, borderRadius: BorderRadius.circular(12), border: Border.all(color: _white10)),
        child: Stack(clipBehavior: Clip.none, children: [
          const Center(child: Icon(Icons.notifications_rounded, color: _white, size: 20)),
          if (count > 0)
            Positioned(
              top: -2, right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: _rose, borderRadius: BorderRadius.circular(20), border: Border.all(color: _black1, width: 1.5)),
                child: Text(count > 99 ? '99+' : '$count', style: GoogleFonts.nunito(color: _white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      ),
    );
  }
}

class _FeedTabBtn extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _FeedTabBtn({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? _white : Colors.transparent, width: 3))),
          child: Center(child: Text(label, style: GoogleFonts.nunito(color: active ? _white : _grey, fontWeight: FontWeight.w800, fontSize: 13.5))),
        ),
      ),
    );
  }
}

class _FollowBtn extends StatelessWidget {
  final bool following; final VoidCallback onTap;
  const _FollowBtn({required this.following, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        decoration: BoxDecoration(
          color: following ? Colors.transparent : _white,
          border: following ? Border.all(color: _white40) : null,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(following ? 'Following' : 'Follow',
            style: GoogleFonts.nunito(color: following ? _white70 : _black, fontSize: 12, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url; final String? name; final double size;
  const _Avatar({required this.url, required this.name, this.size = 44});
  @override
  Widget build(BuildContext context) {
    final initials = (name ?? 'A').trim().isNotEmpty ? name!.trim()[0].toUpperCase() : 'A';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _black3, border: Border.all(color: _white10)),
      clipBehavior: Clip.antiAlias,
      child: (url != null && url!.isNotEmpty)
          ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover,
              placeholder: (_, __) => Center(child: Text(initials, style: GoogleFonts.outfit(color: _white70, fontWeight: FontWeight.w800))),
              errorWidget: (_, __, ___) => Center(child: Text(initials, style: GoogleFonts.outfit(color: _white70, fontWeight: FontWeight.w800))))
          : Center(child: Text(initials, style: GoogleFonts.outfit(color: _white70, fontWeight: FontWeight.w800))),
    );
  }
}

// ─── Post card ──────────────────────────────────────────────────────────
class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isFollowing, isSelf;
  final VoidCallback onFollow, onLike, onComment, onShare, onDelete;
  final void Function(String newText) onEdit;
  const _PostCard({
    required this.post, required this.isFollowing, required this.isSelf,
    required this.onFollow, required this.onLike, required this.onComment,
    required this.onShare, required this.onDelete, required this.onEdit,
  });
  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _liked = false;
  bool _editing = false;
  late TextEditingController _editCtrl;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(text: widget.post['text'] ?? '');
    _checkLiked();
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkLiked() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('posts').doc(widget.post['id']).collection('likes').doc(me.uid).get();
    if (mounted) setState(() => _liked = snap.exists);
  }

  void _saveEdit() {
    final text = _editCtrl.text.trim();
    if (text.isEmpty) return;
    widget.onEdit(text);
    setState(() {
      widget.post['text'] = text;
      widget.post['edited'] = true;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final createdAt = (p['createdAt'] is Timestamp) ? (p['createdAt'] as Timestamp).toDate() : null;
    return FutureBuilder<Map<String, dynamic>>(
      future: UserInfoCache.instance.get(p['authorUid']),
      builder: (context, snap) {
        final info = snap.data ?? {'name': p['authorName'] ?? 'Artist', 'avatar': p['authorAvatar'] ?? '', 'verified': false};
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _black2, borderRadius: BorderRadius.circular(20), border: Border.all(color: _white10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/viewpro', arguments: p['authorUid']),
                child: _Avatar(url: info['avatar'], name: info['name'], size: 44),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(info['name'], style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 14.5), overflow: TextOverflow.ellipsis)),
                    if (info['verified'] == true) Padding(padding: const EdgeInsets.only(left: 4), child: verifiedTick()),
                  ]),
                  Text(timeAgo(createdAt), style: GoogleFonts.nunito(color: _grey, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ]),
              ),
              if (!widget.isSelf) _FollowBtn(following: widget.isFollowing, onTap: widget.onFollow),
              if (widget.isSelf)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, color: _grey),
                  color: _black3,
                  onSelected: (v) {
                    if (v == 'delete') widget.onDelete();
                    if (v == 'edit') setState(() => _editing = true);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text('Edit', style: GoogleFonts.nunito(color: _white90, fontWeight: FontWeight.w700))),
                    PopupMenuItem(value: 'delete', child: Text('Delete', style: GoogleFonts.nunito(color: _rose, fontWeight: FontWeight.w700))),
                  ],
                ),
            ]),
            if (_editing)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(
                    controller: _editCtrl, maxLines: 5, minLines: 1, maxLength: 500,
                    style: GoogleFonts.nunito(color: _white, fontSize: 14.5),
                    decoration: InputDecoration(
                      filled: true, fillColor: _black3,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _white40)),
                    ),
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                      onPressed: () => setState(() { _editCtrl.text = p['text'] ?? ''; _editing = false; }),
                      child: Text('Cancel', style: GoogleFonts.nunito(color: _white70, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: _saveEdit,
                      style: ElevatedButton.styleFrom(backgroundColor: _white, foregroundColor: _black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                      child: Text('Save', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ]),
              )
            else ...[
              if ((p['text'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: RichText(
                    text: TextSpan(children: [
                      TextSpan(text: p['text'], style: GoogleFonts.nunito(color: _white90, fontSize: 14.5, height: 1.5)),
                      if (p['edited'] == true)
                        TextSpan(text: '  (edited)', style: GoogleFonts.nunito(color: _grey, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ],
            if ((p['imageUrl'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(borderRadius: BorderRadius.circular(16), child: CachedNetworkImage(imageUrl: p['imageUrl'], fit: BoxFit.cover)),
              ),
            if ((p['linkUrl'] ?? '').toString().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(14), border: Border.all(color: _white10)),
                child: Row(children: [
                  const Icon(Icons.link_rounded, color: _blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p['linkUrl'], style: GoogleFonts.nunito(color: _white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: [
                _ActionBtn(icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _liked ? _rose : _grey, label: '${p['likesCount'] ?? 0}',
                    onTap: () { setState(() => _liked = !_liked); widget.onLike(); }),
                _ActionBtn(icon: Icons.mode_comment_outlined, color: _grey, label: '${p['commentsCount'] ?? 0}', onTap: widget.onComment),
                _ActionBtn(icon: Icons.share_outlined, color: _grey, label: 'Share', onTap: widget.onShare),
                const Spacer(),
                Icon(Icons.visibility_outlined, color: _grey, size: 15),
                const SizedBox(width: 4),
                Text('${p['viewsCount'] ?? 0}', style: GoogleFonts.nunito(color: _grey, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final Color color; final String label; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Row(children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.nunito(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  COMMENTS SHEET — top-level comments + THREADED REPLIES (parentId)
// ═══════════════════════════════════════════════════════════════════════
class _CommentsSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  final String myUid, myName, myAvatar;
  const _CommentsSheet({required this.post, required this.myUid, required this.myName, required this.myAvatar});
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _inputCtrl = TextEditingController();
  bool _sending = false;

  Future<void> _submit() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    try {
      final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.post['id']);
      await postRef.collection('comments').add({
        'authorUid': widget.myUid, 'authorName': widget.myName, 'authorAvatar': widget.myAvatar,
        'text': text, 'parentId': null, 'createdAt': FieldValue.serverTimestamp(),
      });
      await postRef.update({'commentsCount': FieldValue.increment(1)});
      sendNotification(widget.post['authorUid'], 'comment',
          postId: widget.post['id'], postText: widget.post['text'], postImage: widget.post['imageUrl'], commentText: text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Reply target is a specific top-level comment. Posted as a normal doc
  // in the same flat 'comments' subcollection with parentId set — the
  // stream already fetches everything, we just group by parentId client
  // side, same as web's renderCommentRow/renderReplyRow split.
  Future<void> _submitReply(String parentId, String parentAuthorUid, String text) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.post['id']);
    await postRef.collection('comments').add({
      'authorUid': widget.myUid, 'authorName': widget.myName, 'authorAvatar': widget.myAvatar,
      'text': text, 'parentId': parentId, 'createdAt': FieldValue.serverTimestamp(),
    });
    await postRef.update({'commentsCount': FieldValue.increment(1)});
    sendNotification(parentAuthorUid, 'reply',
        postId: widget.post['id'], postText: widget.post['text'], postImage: widget.post['imageUrl'], commentText: text);
  }

  Future<void> _deleteComment(String commentId) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.post['id']);
    await postRef.collection('comments').doc(commentId).delete();
    await postRef.update({'commentsCount': FieldValue.increment(-1)});
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: _black1, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Comments', style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const Divider(color: _white10, height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('posts').doc(widget.post['id']).collection('comments')
                  .orderBy('createdAt').limit(200).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _white));
                final all = snap.data!.docs.map((d) => {'id': d.id, ...d.data()}).toList();
                final top = all.where((c) => c['parentId'] == null).toList();

                // Group replies by their parent comment id.
                final repliesByParent = <String, List<Map<String, dynamic>>>{};
                for (final c in all) {
                  if (c['parentId'] != null) {
                    repliesByParent.putIfAbsent(c['parentId'] as String, () => []).add(c);
                  }
                }

                if (top.isEmpty) {
                  return Center(child: Text('No comments yet.', style: GoogleFonts.nunito(color: _grey)));
                }
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: top.length,
                  itemBuilder: (context, i) {
                    final comment = top[i];
                    return _CommentRow(
                      comment: comment,
                      replies: repliesByParent[comment['id']] ?? [],
                      myUid: widget.myUid,
                      onDelete: () => _deleteComment(comment['id'] as String),
                      onDeleteReply: (replyId) => _deleteComment(replyId),
                      onReply: (text) => _submitReply(comment['id'] as String, comment['authorUid'] as String, text),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: GoogleFonts.nunito(color: _white, fontSize: 13.5),
                    decoration: InputDecoration(
                      isDense: true, filled: true, fillColor: _black3,
                      hintText: 'Write a comment…', hintStyle: GoogleFonts.nunito(color: _grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send_rounded, color: _white), onPressed: _submit),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// One top-level comment + its indented replies. Stateful so it can own
// its own "reply box open/closed" toggle and reply-text controller
// without the whole comments sheet rebuilding.
class _CommentRow extends StatefulWidget {
  final Map<String, dynamic> comment;
  final List<Map<String, dynamic>> replies;
  final String myUid;
  final VoidCallback onDelete;
  final void Function(String replyId) onDeleteReply;
  final void Function(String text) onReply;
  const _CommentRow({
    required this.comment,
    required this.replies,
    required this.myUid,
    required this.onDelete,
    required this.onDeleteReply,
    required this.onReply,
  });
  @override
  State<_CommentRow> createState() => _CommentRowState();
}

class _CommentRowState extends State<_CommentRow> {
  bool _replyOpen = false;
  final _replyCtrl = TextEditingController();

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  void _submitReply() {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    widget.onReply(text);
    _replyCtrl.clear();
    setState(() => _replyOpen = false);
  }

  Future<void> _confirmDelete(BuildContext context, {required bool isReply, required VoidCallback onConfirmed}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _black2,
        title: Text(isReply ? 'Delete reply?' : 'Delete comment?', style: GoogleFonts.outfit(color: _white)),
        content: Text('This can\'t be undone.', style: GoogleFonts.nunito(color: _white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.nunito(color: _rose))),
        ],
      ),
    );
    if (ok == true) onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final isMine = comment['authorUid'] == widget.myUid;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FutureBuilder<Map<String, dynamic>>(
          future: UserInfoCache.instance.get(comment['authorUid']),
          builder: (context, snap) {
            final info = snap.data ?? {'name': comment['authorName'] ?? 'Artist', 'avatar': comment['authorAvatar'] ?? ''};
            return _Avatar(url: info['avatar'], name: info['name'], size: 32);
          },
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Comment bubble ──
            FutureBuilder<Map<String, dynamic>>(
              future: UserInfoCache.instance.get(comment['authorUid']),
              builder: (context, snap) {
                final info = snap.data ?? {'name': comment['authorName'] ?? 'Artist', 'avatar': comment['authorAvatar'] ?? '', 'verified': false};
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(info['name'], style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                      if (info['verified'] == true) Padding(padding: const EdgeInsets.only(left: 4), child: verifiedTick(size: 11)),
                    ]),
                    const SizedBox(height: 2),
                    Text(comment['text'] ?? '', style: GoogleFonts.nunito(color: _white70, fontSize: 13)),
                  ]),
                );
              },
            ),

            // ── Reply toggle ──
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: GestureDetector(
                onTap: () => setState(() => _replyOpen = !_replyOpen),
                child: Text('Reply', style: GoogleFonts.nunito(color: _grey, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ),

            // ── Inline reply input ──
            if (_replyOpen)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      autofocus: true,
                      style: GoogleFonts.nunito(color: _white, fontSize: 12.5),
                      decoration: InputDecoration(
                        isDense: true, filled: true, fillColor: _black3,
                        hintText: 'Write a reply…', hintStyle: GoogleFonts.nunito(color: _grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onSubmitted: (_) => _submitReply(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: _white70, size: 18),
                    onPressed: _submitReply,
                  ),
                ]),
              ),

            // ── Replies, indented under the parent comment ──
            if (widget.replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: widget.replies.map((r) {
                    final replyIsMine = r['authorUid'] == widget.myUid;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        FutureBuilder<Map<String, dynamic>>(
                          future: UserInfoCache.instance.get(r['authorUid']),
                          builder: (context, snap) {
                            final info = snap.data ?? {'name': r['authorName'] ?? 'Artist', 'avatar': r['authorAvatar'] ?? ''};
                            return _Avatar(url: info['avatar'], name: info['name'], size: 26);
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FutureBuilder<Map<String, dynamic>>(
                            future: UserInfoCache.instance.get(r['authorUid']),
                            builder: (context, snap) {
                              final info = snap.data ?? {'name': r['authorName'] ?? 'Artist', 'avatar': r['authorAvatar'] ?? '', 'verified': false};
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(13)),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Flexible(child: Text(info['name'], style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                    if (info['verified'] == true) Padding(padding: const EdgeInsets.only(left: 4), child: verifiedTick(size: 10)),
                                  ]),
                                  const SizedBox(height: 2),
                                  Text(r['text'] ?? '', style: GoogleFonts.nunito(color: _white70, fontSize: 12.5)),
                                ]),
                              );
                            },
                          ),
                        ),
                        if (replyIsMine)
                          GestureDetector(
                            onTap: () => _confirmDelete(
                              context, isReply: true,
                              onConfirmed: () => widget.onDeleteReply(r['id'] as String),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 6, top: 6),
                              child: Icon(Icons.delete_outline_rounded, color: _grey, size: 15),
                            ),
                          ),
                      ]),
                    );
                  }).toList(),
                ),
              ),
          ]),
        ),
        if (isMine)
          GestureDetector(
            onTap: () => _confirmDelete(context, isReply: false, onConfirmed: widget.onDelete),
            child: const Padding(
              padding: EdgeInsets.only(left: 8, top: 6),
              child: Icon(Icons.delete_outline_rounded, color: _grey, size: 17),
            ),
          ),
      ]),
    );
  }
}

// ─── Notifications sheet ────────────────────────────────────────────────
class _NotificationsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> notifs; final String uid;
  const _NotificationsSheet({required this.notifs, required this.uid});
  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  @override
  void initState() {
    super.initState();
    _markAllRead();
  }

  Future<void> _markAllRead() async {
    final unread = widget.notifs.where((n) => n['read'] != true);
    for (final n in unread) {
      FirebaseFirestore.instance.collection('notifications').doc(widget.uid).collection('items').doc(n['id']).update({'read': true});
    }
  }

  String _textFor(Map<String, dynamic> n) {
    switch (n['type']) {
      case 'follow': return '${n['fromName'] ?? 'Someone'} started following you';
      case 'like': return '${n['fromName'] ?? 'Someone'} liked your post';
      case 'story_like': return '${n['fromName'] ?? 'Someone'} liked your story';
      case 'comment': return '${n['fromName'] ?? 'Someone'} commented on your post';
      case 'reply': return '${n['fromName'] ?? 'Someone'} replied to your comment';
      case 'story_share': return '${n['fromName'] ?? 'Someone'} added your post to their story';
      default: return '${n['fromName'] ?? 'Someone'} sent you a notification';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: _black1, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Notifications', style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 16))),
          const Divider(color: _white10, height: 1),
          Expanded(
            child: widget.notifs.isEmpty
                ? Center(child: Text('No notifications yet.', style: GoogleFonts.nunito(color: _grey)))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: widget.notifs.length,
                    itemBuilder: (context, i) {
                      final n = widget.notifs[i];
                      final created = (n['createdAt'] is Timestamp) ? (n['createdAt'] as Timestamp).toDate() : null;
                      return ListTile(
                        leading: _Avatar(url: n['fromAvatar'], name: n['fromName'], size: 40),
                        title: Text(_textFor(n), style: GoogleFonts.nunito(color: _white90, fontSize: 13.5)),
                        subtitle: Text(timeAgo(created), style: GoogleFonts.nunito(color: _grey, fontSize: 11.5)),
                        onTap: () {
                          Navigator.pop(context);
                          if (n['fromUid'] != null) Navigator.pushNamed(context, '/viewpro', arguments: n['fromUid']);
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

// ─── New post composer ──────────────────────────────────────────────────
class _NewPostScreen extends StatefulWidget {
  final String myName, myAvatar;
  const _NewPostScreen({required this.myName, required this.myAvatar});
  @override
  State<_NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<_NewPostScreen> {
  final _textCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  XFile? _image;
  bool _showLinkField = false;
  bool _publishing = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _image = picked);
  }

  Future<void> _publish() async {
    final text = _textCtrl.text.trim();
    final link = _linkCtrl.text.trim();
    if (text.isEmpty && _image == null && link.isEmpty) return;
    setState(() => _publishing = true);
    try {
      final me = FirebaseAuth.instance.currentUser!;
      String? imageUrl;
      if (_image != null) imageUrl = await _uploadToCloudinary(_image!);
      await FirebaseFirestore.instance.collection('posts').add({
        'authorUid': me.uid, 'authorName': widget.myName, 'authorAvatar': widget.myAvatar,
        'text': text, 'imageUrl': imageUrl, 'linkUrl': link.isEmpty ? null : link,
        'likesCount': 0, 'commentsCount': 0, 'viewsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't publish. Please try again.")));
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      appBar: AppBar(
        backgroundColor: _black, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: _white), onPressed: () => Navigator.pop(context)),
        title: Text('New Post', style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _publishing ? null : _publish,
            child: _publishing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _white))
                : Text('Post', style: GoogleFonts.nunito(color: _white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _Avatar(url: widget.myAvatar, name: widget.myName, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _textCtrl, maxLines: 5, minLines: 1,
                style: GoogleFonts.nunito(color: _white, fontSize: 15),
                decoration: InputDecoration(border: InputBorder.none, hintText: "What's new?", hintStyle: GoogleFonts.nunito(color: _grey)),
              ),
            ),
          ]),
          if (_image != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(io.File(_image!.path), height: 200, width: double.infinity, fit: BoxFit.cover)),
                Positioned(top: 8, right: 8, child: GestureDetector(onTap: () => setState(() => _image = null), child: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.close, color: _white, size: 16)))),
              ]),
            ),
          if (_showLinkField)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _linkCtrl,
                style: GoogleFonts.nunito(color: _white, fontSize: 13.5),
                decoration: InputDecoration(
                  filled: true, fillColor: _black3, hintText: 'Paste a link…', hintStyle: GoogleFonts.nunito(color: _grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(children: [
            TextButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image_outlined, color: _blue), label: Text('Photo', style: GoogleFonts.nunito(color: _white70, fontWeight: FontWeight.w700))),
            TextButton.icon(onPressed: () => setState(() => _showLinkField = !_showLinkField), icon: const Icon(Icons.link_rounded, color: Colors.orange), label: Text('Link', style: GoogleFonts.nunito(color: _white70, fontWeight: FontWeight.w700))),
          ]),
        ]),
      ),
    );
  }
}

// ─── Story composer ──────────────────────────────────────────────────────
class _StoryComposerScreen extends StatefulWidget {
  final String myName, myAvatar;
  const _StoryComposerScreen({required this.myName, required this.myAvatar});
  @override
  State<_StoryComposerScreen> createState() => _StoryComposerScreenState();
}

class _StoryComposerScreenState extends State<_StoryComposerScreen> {
  String _type = 'image';
  XFile? _image;
  final _textCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  bool _sharing = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _image = picked);
  }

  bool get _canShare {
    if (_type == 'image') return _image != null;
    if (_type == 'text') return _textCtrl.text.trim().isNotEmpty;
    return _linkCtrl.text.trim().isNotEmpty;
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final me = FirebaseAuth.instance.currentUser!;
      final payload = <String, dynamic>{
        'authorUid': me.uid, 'authorName': widget.myName, 'authorAvatar': widget.myAvatar,
        'type': _type, 'createdAt': FieldValue.serverTimestamp(),
      };
      if (_type == 'image') {
        final url = await _uploadToCloudinary(_image!);
        if (url == null) throw Exception('upload failed');
        payload['imageUrl'] = url;
      } else if (_type == 'text') {
        payload['text'] = _textCtrl.text.trim();
      } else {
        payload['linkUrl'] = _linkCtrl.text.trim();
      }
      await FirebaseFirestore.instance.collection('stories').add(payload);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't share your story.")));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      appBar: AppBar(backgroundColor: _black, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: _white), onPressed: () => Navigator.pop(context)),
        title: Text('Add to Your Story', style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            for (final t in ['image', 'text', 'link'])
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _type == t ? _white : _white06, borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: _white10),
                    ),
                    child: Center(child: Text(t == 'image' ? 'Photo' : t == 'text' ? 'Text' : 'Link',
                        style: GoogleFonts.nunito(color: _type == t ? _black : _white70, fontWeight: FontWeight.w700, fontSize: 12.5))),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          if (_type == 'image')
            _image == null
                ? GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(border: Border.all(color: _white40, style: BorderStyle.solid), borderRadius: BorderRadius.circular(14)),
                      child: Column(children: [
                        const Icon(Icons.image_outlined, color: _grey, size: 26),
                        const SizedBox(height: 8),
                        Text('Tap to choose a photo', style: GoogleFonts.nunito(color: _white70, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  )
                : ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(io.File(_image!.path), height: 220, width: double.infinity, fit: BoxFit.cover)),
          if (_type == 'text')
            TextField(
              controller: _textCtrl, maxLength: 280, maxLines: 6,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.nunito(color: _white),
              decoration: InputDecoration(filled: true, fillColor: _black3, hintText: 'Share something…', hintStyle: GoogleFonts.nunito(color: _grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            ),
          if (_type == 'link')
            TextField(
              controller: _linkCtrl,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.nunito(color: _white),
              decoration: InputDecoration(filled: true, fillColor: _black3, hintText: 'Paste a link…', hintStyle: GoogleFonts.nunito(color: _grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_canShare && !_sharing) ? _share : null,
              style: ElevatedButton.styleFrom(backgroundColor: _white, foregroundColor: _black, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
              child: _sharing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Share to Story', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Story bubble ────────────────────────────────────────────────────────
class _StoryBubble extends StatelessWidget {
  final String label; final String? uid; final String? avatarUrl; final String? name;
  final bool hasStory, isOwn; final VoidCallback onTap; final VoidCallback? onAddTap;
  const _StoryBubble({required this.label, required this.uid, required this.avatarUrl, required this.name,
    required this.hasStory, required this.isOwn, required this.onTap, this.onAddTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 6),
        child: Column(children: [
          Stack(children: [
            Container(
              width: 62, height: 62, padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(shape: BoxShape.circle, color: hasStory ? _white : _white20),
              child: _Avatar(url: avatarUrl, name: name, size: 57),
            ),
            if (isOwn)
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: onAddTap,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _white, border: Border.all(color: _black, width: 2)),
                    child: const Icon(Icons.add, size: 12, color: _black),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 5),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.nunito(color: _white70, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ─── Story viewer (full screen, press-and-hold to pause) ───────────────
class _StoryViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories; final String myUid; final VoidCallback onDeleted;
  const _StoryViewerScreen({required this.stories, required this.myUid, required this.onDeleted});
  @override
  State<_StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<_StoryViewerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _index = 0;
  late List<Map<String, dynamic>> _stories;

  @override
  void initState() {
    super.initState();
    _stories = [...widget.stories];
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..addStatusListener((status) { if (status == AnimationStatus.completed) _next(); });
    _showStory(0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _showStory(int i) {
    if (i < 0 || i >= _stories.length) { Navigator.pop(context); return; }
    setState(() => _index = i);
    _ctrl.reset();
    _ctrl.forward();
    final story = _stories[i];
    final isOwn = story['authorUid'] == widget.myUid;
    if (!isOwn) {
      FirebaseFirestore.instance.collection('stories').doc(story['id']).collection('viewers').doc(widget.myUid)
          .set({'viewedAt': FieldValue.serverTimestamp()}).catchError((_) {});
    }
  }

  void _next() => _showStory(_index + 1);
  void _prev() => _showStory(_index - 1);

  // Press-and-hold pause: AnimationController.stop() freezes exactly
  // where it is; forward() with no `from` resumes from that same value —
  // no manual elapsed-time bookkeeping needed, unlike the web version's
  // requestAnimationFrame approach.
  void _pause() => _ctrl.stop();
  void _resume() => _ctrl.forward();

  Future<void> _deleteStory() async {
    final story = _stories[_index];
    if (story['authorUid'] != widget.myUid) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _black2,
        title: Text('Delete this story?', style: GoogleFonts.outfit(color: _white)),
        content: Text("This can't be undone.", style: GoogleFonts.nunito(color: _white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.nunito(color: _rose))),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('stories').doc(story['id']).delete();
    _stories.removeAt(_index);
    widget.onDeleted();
    if (_stories.isEmpty) { if (mounted) Navigator.pop(context); return; }
    _showStory(_index >= _stories.length ? _stories.length - 1 : _index);
  }

  Future<void> _toggleLike() async {
    final story = _stories[_index];
    final ref = FirebaseFirestore.instance.collection('stories').doc(story['id']).collection('likes').doc(widget.myUid);
    final existing = await ref.get();
    if (existing.exists) {
      await ref.delete();
    } else {
      await ref.set({'uid': widget.myUid, 'likedAt': FieldValue.serverTimestamp()});
      sendNotification(story['authorUid'], 'story_like');
    }
    setState(() {});
  }

  void _openViewers() {
    _pause();
    final story = _stories[_index];
    showModalBottomSheet(
      context: context, backgroundColor: _black1, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _StoryViewersSheet(storyId: story['id']),
    ).then((_) => _resume());
  }

  @override
  Widget build(BuildContext context) {
    final story = _stories[_index];
    final isOwn = story['authorUid'] == widget.myUid;
    final createdAt = (story['createdAt'] is Timestamp) ? (story['createdAt'] as Timestamp).toDate() : null;

    return Scaffold(
      backgroundColor: _black,
      body: SafeArea(
        child: GestureDetector(
          onLongPressStart: (_) => _pause(),
          onLongPressEnd: (_) => _resume(),
          child: Stack(children: [
            // progress bars
            Positioned(
              top: 8, left: 10, right: 10,
              child: Row(children: List.generate(_stories.length, (i) {
                return Expanded(
                  child: Container(
                    height: 3, margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: _white20, borderRadius: BorderRadius.circular(3)),
                    child: i < _index
                        ? Container(decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(3)))
                        : i == _index
                            ? AnimatedBuilder(
                                animation: _ctrl,
                                builder: (context, _) => FractionallySizedBox(
                                  widthFactor: _ctrl.value, alignment: Alignment.centerLeft,
                                  child: Container(decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(3))),
                                ),
                              )
                            : const SizedBox.shrink(),
                  ),
                );
              })),
            ),
            // header
            Positioned(
              top: 22, left: 14, right: 14,
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, '/viewpro', arguments: story['authorUid']),
                  child: Row(children: [
                    FutureBuilder<Map<String, dynamic>>(
                      future: UserInfoCache.instance.get(story['authorUid']),
                      builder: (context, snap) {
                        final info = snap.data ?? {'name': story['authorName'], 'avatar': story['authorAvatar'], 'verified': false};
                        return Row(children: [
                          _Avatar(url: info['avatar'], name: info['name'], size: 34),
                          const SizedBox(width: 10),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(info['name'] ?? 'Artist', style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                              if (info['verified'] == true) Padding(padding: const EdgeInsets.only(left: 4), child: verifiedTick(size: 12)),
                            ]),
                            Text(timeAgo(createdAt), style: GoogleFonts.nunito(color: _grey, fontSize: 11)),
                          ]),
                        ]);
                      },
                    ),
                  ]),
                ),
                const Spacer(),
                if (isOwn) GestureDetector(onTap: _deleteStory, child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.delete_outline_rounded, color: _white70))),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.close_rounded, color: _white))),
              ]),
            ),
            // content
            Positioned.fill(
              top: 70, bottom: 70,
              child: Center(
                child: story['type'] == 'image' && (story['imageUrl'] ?? '').toString().isNotEmpty
                    ? CachedNetworkImage(imageUrl: story['imageUrl'], fit: BoxFit.contain, width: double.infinity)
                    : story['type'] == 'link' && (story['linkUrl'] ?? '').toString().isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(16), border: Border.all(color: _white10)),
                              child: Row(children: [
                                const Icon(Icons.link_rounded, color: _blue),
                                const SizedBox(width: 10),
                                Expanded(child: Text(story['linkUrl'], style: GoogleFonts.nunito(color: _white90), overflow: TextOverflow.ellipsis)),
                              ]),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(story['text'] ?? '', textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(color: _white, fontSize: 22, fontWeight: FontWeight.w700, height: 1.5)),
                          ),
              ),
            ),
            // repost badge
            if (story['sharedFromUid'] != null)
              Positioned(
                top: 90, left: 14,
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, '/viewpro', arguments: story['sharedFromUid']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(100), border: Border.all(color: _white20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.repeat_rounded, color: _white, size: 14),
                      const SizedBox(width: 6),
                      Text(story['sharedFromName'] ?? 'Original post', style: GoogleFonts.nunito(color: _white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            // tap zones
            Positioned(top: 70, bottom: 70, left: 0, width: MediaQuery.of(context).size.width / 3,
                child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _prev)),
            Positioned(top: 70, bottom: 70, right: 0, width: MediaQuery.of(context).size.width / 3,
                child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _next)),
            // footer
            Positioned(
              bottom: 14, left: 0, right: 0,
              child: Center(
                child: isOwn
                    ? StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('stories').doc(story['id']).collection('viewers').snapshots(),
                        builder: (context, snap) {
                          final count = snap.data?.docs.length ?? 0;
                          return _pillButton(
                            icon: Icons.visibility_outlined,
                            label: '$count viewer${count == 1 ? '' : 's'}',
                            onTap: _openViewers,
                          );
                        },
                      )
                    : FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('stories').doc(story['id']).collection('likes').doc(widget.myUid).get(),
                        builder: (context, snap) {
                          final liked = snap.data?.exists == true;
                          return GestureDetector(
                            onTap: _toggleLike,
                            child: Container(
                              width: 46, height: 46,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: _white06, border: Border.all(color: liked ? _rose.withOpacity(0.4) : _white10)),
                              child: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: liked ? _rose : _white90, size: 20),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _pillButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(color: _white06, borderRadius: BorderRadius.circular(100), border: Border.all(color: _white10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _white90, size: 16),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.nunito(color: _white90, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ),
    );
  }
}

class _StoryViewersSheet extends StatelessWidget {
  final String storyId;
  const _StoryViewersSheet({required this.storyId});
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55, minChildSize: 0.3, maxChildSize: 0.9,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(color: _black1, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Viewers', style: GoogleFonts.outfit(color: _white, fontWeight: FontWeight.w800, fontSize: 15))),
          const Divider(color: _white10, height: 1),
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('stories').doc(storyId).collection('viewers').get(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _white));
                final uids = snap.data!.docs.map((d) => d.id).toList();
                if (uids.isEmpty) return Center(child: Text('No views yet.', style: GoogleFonts.nunito(color: _grey)));
                return ListView.builder(
                  controller: scrollCtrl,
                  itemCount: uids.length,
                  itemBuilder: (context, i) => FutureBuilder<Map<String, dynamic>>(
                    future: UserInfoCache.instance.get(uids[i]),
                    builder: (context, s) {
                      final info = s.data ?? {'name': 'Artist', 'avatar': ''};
                      return ListTile(
                        leading: _Avatar(url: info['avatar'], name: info['name'], size: 38),
                        title: Text(info['name'], style: GoogleFonts.nunito(color: _white90, fontWeight: FontWeight.w700)),
                        onTap: () => Navigator.pushNamed(context, '/viewpro', arguments: uids[i]),
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
//  SHARED SMALL WIDGETS (unchanged from before)
// ════════════════════════════════════════════════════════════════════
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _white06,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _white10),
        ),
        child: Icon(icon, color: _white, size: 20),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  BOTTOM NAVIGATION BAR (unchanged — app's own, per request)
// ════════════════════════════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  static const _items = [
    (Icons.home_rounded,                   Icons.home_outlined,                   'Home'),
    (Icons.bar_chart_rounded,              Icons.bar_chart_outlined,              'Analytics'),
    (Icons.cloud_upload_rounded,           Icons.cloud_upload_outlined,           'Upload'),
    (Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Earnings'),
    (Icons.person_rounded,                 Icons.person_outline_rounded,          'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(8, 10, 8, bottom + 10),
          decoration: BoxDecoration(
            color: _black.withOpacity(0.85),
            border: const Border(top: BorderSide(color: _white10)),
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final (activeIcon, inactiveIcon, label) = _items[i];
              final isActive = i == current;
              final isUpload = i == 2;

              if (isUpload) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    child: Center(
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: _white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: _white.withOpacity(0.2), blurRadius: 16, spreadRadius: 2),
                          ],
                        ),
                        child: const Icon(Icons.cloud_upload_rounded, color: _black, size: 24),
                      ),
                    ),
                  ),
                );
              }

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          isActive ? activeIcon : inactiveIcon,
                          key: ValueKey(isActive),
                          color: isActive ? _white : _greyDark,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: GoogleFonts.outfit(
                          color: isActive ? _white : _greyDark,
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                        ),
                        child: Text(label),
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        height: 3, width: isActive ? 18 : 0,
                        decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(99)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SIDEBAR — unchanged except the own-account label ("Account" → "Settings")
// ════════════════════════════════════════════════════════════════════
class _SidebarPanel extends StatelessWidget {
  final VoidCallback onClose;
  final void Function(String) onNavigate;
  final String userName, userEmail;
  final String? uid;

  const _SidebarPanel({required this.onClose, required this.onNavigate,
    required this.userName, required this.userEmail, required this.uid});

  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final w      = MediaQuery.of(context).size.width * 0.78;

    return Container(
      width: w, height: double.infinity,
      color: _black1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(24, top + 20, 24, 20),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _white10))),
            child: Row(
              children: [
                CachedNetworkImage(
                  imageUrl: 'https://444music-distribution.vercel.app/black.png',
                  height: 26, color: _white, colorBlendMode: BlendMode.srcIn,
                  errorWidget: (_, __, ___) => Text(
                    '444Music',
                    style: GoogleFonts.outfit(color: _white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _white10),
                    ),
                    child: const Icon(Icons.close_rounded, color: _grey, size: 18),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _white06,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _white10),
              ),
              child: Row(
                children: [
                  _Avatar(url: FirebaseAuth.instance.currentUser?.photoURL, name: userName, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<Map<String, dynamic>>(
                          future: uid != null ? UserInfoCache.instance.get(uid!) : null,
                          builder: (context, snap) {
                            final verified = snap.data?['verified'] == true;
                            return Row(children: [
                              Flexible(child: Text(
                                userName,
                                style: GoogleFonts.outfit(color: _white, fontSize: 14, fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis,
                              )),
                              if (verified) Padding(padding: const EdgeInsets.only(left: 4), child: verifiedTick(size: 13)),
                            ]);
                          },
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userEmail,
                          style: GoogleFonts.outfit(color: _grey, fontSize: 11, fontWeight: FontWeight.w400),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NavSection(label: 'Navigation'),
                  _NavItem(icon: Icons.home_rounded,                  label: 'Home',            route: '/home',      onTap: onNavigate),
                  _NavItem(icon: Icons.person_rounded,                 label: 'Settings',        route: '/profile',   onTap: onNavigate),
                  _NavItem(icon: Icons.speed_rounded,                  label: 'Dashboard',       route: '/dashboard', onTap: onNavigate),
                  _NavItem(icon: Icons.cloud_upload_rounded,           label: 'Upload Release',  route: '/upload',    onTap: onNavigate),
                  _NavItem(icon: Icons.bar_chart_rounded,              label: 'Analytics',       route: '/analytics', onTap: onNavigate),
                  _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Earnings',        route: '/earnings',  onTap: onNavigate),
                  const _SidebarDivider(),
                  _NavSection(label: 'More'),
                  _NavItem(icon: Icons.build_rounded,         label: 'More Tools',      route: '/tools',    onTap: onNavigate),
                  _NavItem(icon: Icons.info_outline_rounded,  label: 'About Us',        route: '/legal',    onTap: onNavigate),
                  _NavItem(icon: Icons.mail_outline_rounded,  label: 'Contact Support', route: '/support',  onTap: onNavigate),
                  _NavItem(icon: Icons.library_music_rounded, label: 'My Releases',     route: '/releases', onTap: onNavigate),
                  const _SidebarDivider(),
                ],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
            child: GestureDetector(
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                onClose();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade900.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, color: Color(0xFFFF6B6B), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Logout',
                      style: GoogleFonts.outfit(color: const Color(0xFFFF6B6B), fontSize: 14, fontWeight: FontWeight.w700),
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
}

class _NavSection extends StatelessWidget {
  final String label;
  const _NavSection({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
    child: Text(
      label.toUpperCase(),
      style: GoogleFonts.outfit(color: _greyDark, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2),
    ),
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
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _hover = true),
      onTapUp:     (_) { setState(() => _hover = false); widget.onTap(widget.route); },
      onTapCancel: ()  => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _hover ? _white10 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(widget.icon, color: _hover ? _white : _grey, size: 18),
            const SizedBox(width: 14),
            Text(
              widget.label,
              style: GoogleFonts.outfit(color: _hover ? _white : _grey, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: _hover ? _white40 : Colors.transparent, size: 12),
          ],
        ),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
    height: 1,
    color: _white10,
  );
}

// ════════════════════════════════════════════════════════════════════
//  PLACEHOLDER TABS (unused now — 1..4 always navigate away — kept only
//  so the IndexedStack has valid children)
// ════════════════════════════════════════════════════════════════════
class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _grey, size: 48),
          const SizedBox(height: 16),
          Text(label, style: GoogleFonts.outfit(color: _white, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Coming soon', style: GoogleFonts.outfit(color: _grey, fontSize: 13, fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }
}