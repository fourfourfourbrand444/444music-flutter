// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Profile / Settings Screen
//  Theme: Black & White Luxury  |  Font: Nunito
//  Firebase Auth + Firestore  |  1:1 parity with web's profile.html
//
//  v3 — trimmed to EXACT web parity. Removed everything web's
//  profile.html does not have: stats row, Account Info card (phone/
//  country/join date), Quick Actions grid, Notifications card,
//  Danger Zone (logout/delete), hero action buttons, and the "Free
//  Plan"/country tag chips. Also removed the duplicate outer section
//  labels above Verification and Stores — those cards already carry
//  their own title internally (matching web's .settings-card-title),
//  so the outer label was a second, redundant heading web doesn't have.
//
//  What's left, matching web feature-for-feature:
//   • Avatar upload via Cloudinary (same cloud name + unsigned preset
//     as web), with instant local preview while it uploads.
//   • Verified badge shown only when users/{uid}.verified is true.
//   • Inline artist-name editing, same Firestore field.
//   • Verification card: verified / eligible / locked states, same
//     copy, same 10-release threshold, same case-insensitive "live"
//     status check, progress bar when locked, same 5-item benefits list.
//   • Distribution Stores card: same store list, same order, same
//     "+33 more" tail chip.
//   • Settings search: toggles open and filters the three cards by
//     the same keyword sets as web's data-search attributes.
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:typed_data';
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
const _black2     = Color(0xFF0D0D0D);
const _black3     = Color(0xFF111111);
const _black4     = Color(0xFF161616);
const _white      = Color(0xFFFFFFFF);
const _white70    = Color(0xB3FFFFFF);
const _white40    = Color(0x66FFFFFF);
const _white20    = Color(0x33FFFFFF);
const _white10    = Color(0x1AFFFFFF);
const _white06    = Color(0x0FFFFFFF);
const _grey       = Color(0xFF888888);
const _greyDark   = Color(0xFF444444);
const _green      = Color(0xFF22C55E);
const _rose       = Color(0xFFEF4444);
const _blue       = Color(0xFF4DA3FF); // matches web's --blue (verified badge)

// Same unsigned Cloudinary preset used everywhere else in the app (posts,
// stories, ad images, resubmit uploads, and web's profile picture too).
// Matches web's CLOUD_NAME / UPLOAD_PRESET exactly.
const _kCloudName = 'dlbgqtvqg';
const _kUploadPreset = 'glmamp2y';
const _kVerificationThreshold = 10;

// ════════════════════════════════════════════════════════════════════
//  PROFILE SCREEN
// ════════════════════════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  User? get _user => _auth.currentUser;

  // user data
  String _displayName  = '';
  String _email        = '';
  String? _avatarUrl;
  bool _verified        = false;

  // drives verification eligibility, matches web
  int _approvedCount  = 0;

  bool _loading       = true;
  bool _editingName   = false;
  bool _savingName    = false;
  bool _uploadingAvatar = false;
  bool _verifying       = false;
  Uint8List? _localAvatarPreview;

  final _nameCtrl     = TextEditingController();
  final _nameFocus    = FocusNode();

  // Settings search — mirrors web's topbar search filtering settings cards
  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

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
    _entranceCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entranceFade  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _loadData();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _nameCtrl.dispose();
    _nameFocus.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_user == null) return;
    try {
      // Load user doc
      final userDoc = await _db.collection('users').doc(_user!.uid).get();
      final userData = userDoc.data() ?? {};

      // Load releases — only need the approved ("live") count, since
      // that's the only thing verification eligibility depends on.
      // Matches web's eligibility count exactly: case-insensitive
      // comparison against 'live' (not 'approved').
      final snap = await _db
          .collection('submissions')
          .where('userId', isEqualTo: _user!.uid)
          .get();

      int approved = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final s = (d['status'] ?? '').toString().toLowerCase();
        if (s == 'live') approved++;
      }

      if (mounted) {
        setState(() {
          _displayName    = userData['name']       ?? _user!.displayName ?? 'Artist';
          _email          = userData['email']      ?? _user!.email ?? '';
          _avatarUrl      = userData['profilePic'] ?? _user!.photoURL;
          _verified       = userData['verified'] == true;
          _approvedCount  = approved;
          _loading        = false;
        });
        _entranceCtrl.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _initials {
    final parts = _displayName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'A';
  }

  // ── SAVE NAME ──────────────────────────────────────────────────
  Future<void> _saveName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty || _user == null) return;
    setState(() => _savingName = true);
    try {
      await _db.collection('users').doc(_user!.uid).set({'name': newName}, SetOptions(merge: true));
      await _user!.updateDisplayName(newName);
      setState(() { _displayName = newName; _editingName = false; _savingName = false; });
      _showSnack('Name updated ✓', _green);
    } catch (e) {
      setState(() => _savingName = false);
      _showSnack('Failed to update name', _rose);
    }
  }

  // ── UPLOAD AVATAR — Cloudinary, matching web exactly ────────────
  Future<String?> _uploadToCloudinary(Uint8List bytes, String filename) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_kCloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _kUploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) return null;
    final respStr = await streamed.stream.bytesToString();
    final data = jsonDecode(respStr) as Map<String, dynamic>;
    return data['secure_url'] as String?;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file   = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file == null || _user == null) return;

    // Instant local preview while the real upload runs in the background
    // — same idea as web's FileReader preview.
    final bytes = await file.readAsBytes();
    setState(() {
      _localAvatarPreview = bytes;
      _uploadingAvatar = true;
    });

    try {
      final url = await _uploadToCloudinary(bytes, file.name);
      if (url == null) throw Exception('Image upload failed');
      await _db.collection('users').doc(_user!.uid).set({'profilePic': url}, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _localAvatarPreview = null;
        _uploadingAvatar = false;
      });
      _showSnack('Profile photo updated ✓', _green);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingAvatar = false;
        _localAvatarPreview = null;
      });
      _showSnack("Couldn't update your profile picture. Please try again.", _rose);
    }
  }

  // ── VERIFICATION — mirrors web's requestVerification() exactly ──
  Future<void> _requestVerification() async {
    if (_user == null || _verifying) return;
    setState(() => _verifying = true);
    try {
      await _db.collection('users').doc(_user!.uid).update({'verified': true});
      if (!mounted) return;
      setState(() {
        _verified = true;
        _verifying = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      _showSnack("Couldn't verify your account right now. Please try again.", _rose);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito(color: _white, fontWeight: FontWeight.w700)),
      backgroundColor: color.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // Mirrors web's data-search matching: keyword string (+ visible text)
  // contains the query. Empty query always matches.
  bool _matches(String keywords) {
    if (_searchQuery.trim().isEmpty) return true;
    return keywords.toLowerCase().contains(_searchQuery.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _black,
      body: _loading
          ? _buildSkeleton(top)
          : SlideTransition(
        position: _entranceSlide,
        child: FadeTransition(
          opacity: _entranceFade,
          child: Column(
            children: [
              SizedBox(height: top),
              _buildTopBar(),
              if (_searchOpen) _buildSearchBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: bottom + 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_matches('profile name email picture avatar photo account')) ...[
                        _buildHero(),
                        const SizedBox(height: 20),
                      ],
                      if (_matches('verification verified badge apply request eligibility curated playlist campaign boost')) ...[
                        _buildVerificationCard(),
                        const SizedBox(height: 20),
                      ],
                      if (_matches('distribution stores spotify apple music youtube tiktok amazon tidal deezer'))
                        _buildStoresCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TOP BAR ─────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: _black,
        border: Border(bottom: BorderSide(color: _white10)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: _white06, borderRadius: BorderRadius.circular(11), border: Border.all(color: _white10)),
              child: const Icon(Icons.arrow_back_ios_rounded, color: _white, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Text('Settings', style: GoogleFonts.nunito(color: _white, fontSize: 17, fontWeight: FontWeight.w800)),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() => _searchOpen = !_searchOpen);
              if (_searchOpen) {
                Future.delayed(const Duration(milliseconds: 80), () => _searchFocus.requestFocus());
              } else {
                _searchCtrl.clear();
                _searchQuery = '';
              }
            },
            child: Container(
              width: 38, height: 38,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: _searchOpen ? _white10 : _white06,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _searchOpen ? _white20 : _white10),
              ),
              child: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded, color: _white, size: 18),
            ),
          ),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _white20)),
            child: ClipOval(child: _buildAvatar()),
          ),
        ],
      ),
    );
  }

  // ── SEARCH BAR (mirrors web's topbar-search filtering settings cards) ──
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: const BoxDecoration(color: _black, border: Border(bottom: BorderSide(color: _white10))),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        style: GoogleFonts.nunito(color: _white, fontSize: 13.5),
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: _black2,
          hintText: 'Search settings…',
          hintStyle: GoogleFonts.nunito(color: _grey),
          prefixIcon: const Icon(Icons.search_rounded, color: _grey, size: 18),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: const BorderSide(color: _white10)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: const BorderSide(color: _white10)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: const BorderSide(color: _white40)),
        ),
      ),
    );
  }

  // ── HERO — matches web's profile-row exactly: avatar, name, email ──
  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _black2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _white10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _white20, width: 2),
                    color: _black3,
                  ),
                  child: ClipOval(child: _buildAvatar()),
                ),
                // Camera overlay
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: _white, shape: BoxShape.circle,
                      border: Border.all(color: _black, width: 2),
                    ),
                    child: _uploadingAvatar
                        ? const Padding(
                      padding: EdgeInsets.all(5),
                      child: CircularProgressIndicator(strokeWidth: 2, color: _black),
                    )
                        : const Icon(Icons.camera_alt_rounded, color: _black, size: 13),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row
                if (!_editingName) ...[
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _displayName.isEmpty ? 'Artist' : _displayName,
                          style: GoogleFonts.nunito(color: _white, fontSize: 20, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() { _editingName = true; _nameCtrl.text = _displayName; });
                          Future.delayed(const Duration(milliseconds: 80), () => _nameFocus.requestFocus());
                        },
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: _white10, borderRadius: BorderRadius.circular(7), border: Border.all(color: _white20)),
                          child: const Icon(Icons.edit_rounded, color: _white70, size: 13),
                        ),
                      ),
                      // Verified badge — only ever rendered when
                      // _verified is actually true, matching web's
                      // strict .show toggle.
                      if (_verified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded, color: _blue, size: 18),
                      ],
                    ],
                  ),
                ] else ...[
                  // Editing mode
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          focusNode: _nameFocus,
                          style: GoogleFonts.nunito(color: _white, fontSize: 18, fontWeight: FontWeight.w800),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            filled: true,
                            fillColor: _black3,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _white20)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _white40)),
                            hintText: 'Artist name',
                            hintStyle: GoogleFonts.nunito(color: _greyDark),
                          ),
                          onSubmitted: (_) => _saveName(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _savingName ? null : _saveName,
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(8)),
                          child: _savingName
                              ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: _black))
                              : const Icon(Icons.check_rounded, color: _black, size: 17),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _editingName = false),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(color: _rose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _rose.withValues(alpha: 0.3))),
                          child: Icon(Icons.close_rounded, color: _rose, size: 17),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 5),
                Text(_email, style: GoogleFonts.nunito(color: _grey, fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    // Local preview while a fresh upload is in flight — matches web's
    // instant FileReader preview before the Cloudinary URL comes back.
    if (_localAvatarPreview != null) {
      return Image.memory(_localAvatarPreview!, fit: BoxFit.cover);
    }
    if (_avatarUrl == null || _avatarUrl!.isEmpty) {
      return Container(
        color: _black3,
        child: Center(
          child: Text(_initials, style: GoogleFonts.nunito(color: _white, fontSize: 28, fontWeight: FontWeight.w800)),
        ),
      );
    }
    // Backward-compat: some older accounts may still have a base64
    // data: URI saved from before this screen switched to Cloudinary.
    if (_avatarUrl!.startsWith('data:image')) {
      try {
        final bytes = base64Decode(_avatarUrl!.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }
    return CachedNetworkImage(
      imageUrl: _avatarUrl!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: _black3),
      errorWidget: (_, __, ___) => Container(
        color: _black3,
        child: Center(child: Text(_initials, style: GoogleFonts.nunito(color: _white, fontSize: 28, fontWeight: FontWeight.w800))),
      ),
    );
  }

  // ── VERIFICATION CARD — mirrors web's #verifyStateSlot exactly ──
  Widget _buildVerificationCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.verified_rounded, color: _blue, size: 16),
            const SizedBox(width: 8),
            Text('Verification', style: GoogleFonts.nunito(color: _white, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          Text(
            "A verified badge tells fans and partners your account is authentic.",
            style: GoogleFonts.nunito(color: _grey, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 16),
          _buildVerifyState(),
          const SizedBox(height: 18),
          Text('BENEFITS OF BEING VERIFIED',
              style: GoogleFonts.nunito(color: _greyDark, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 10),
          ..._kVerificationBenefits.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle_rounded, color: _green, size: 13),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(b, style: GoogleFonts.nunito(color: _white70, fontSize: 12.5, height: 1.5))),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _buildVerifyState() {
    if (_verified) {
      return _VerifyStateBox(
        color: _blue,
        bg: _blue.withValues(alpha: 0.08),
        border: _blue.withValues(alpha: 0.25),
        icon: Icons.check_circle_rounded,
        title: 'Your account is verified',
        sub: 'Your verified badge is now showing on your profile and posts.',
      );
    }

    if (_approvedCount >= _kVerificationThreshold) {
      return _VerifyStateBox(
        color: _green,
        bg: _green.withValues(alpha: 0.1),
        border: _green.withValues(alpha: 0.28),
        icon: Icons.star_rounded,
        title: "You're eligible for verification",
        sub: 'You have $_approvedCount approved release${_approvedCount == 1 ? "" : "s"} — you qualify for a verified badge.',
        trailing: GestureDetector(
          onTap: _verifying ? null : _requestVerification,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: _verifying ? _white40 : _white,
              borderRadius: BorderRadius.circular(100),
            ),
            child: _verifying
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _black))
                : Text('Get Verified', style: GoogleFonts.nunito(color: _black, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
        ),
      );
    }

    final pct = (_approvedCount / _kVerificationThreshold * 100).clamp(0, 100).round();
    return _VerifyStateBox(
      color: _grey,
      bg: _black3,
      border: _white10,
      icon: Icons.lock_rounded,
      title: 'Not eligible yet',
      sub: 'You can apply for verification once you have at least $_kVerificationThreshold approved releases. '
          'You currently have $_approvedCount of $_kVerificationThreshold.',
      progressPct: pct,
    );
  }

  // ── STORES CARD — exact same store list/order as web ────────────
  Widget _buildStoresCard() {
    const stores = [
      ('Spotify',       Icons.music_note_rounded,       Color(0xFF1DB954)),
      ('Apple Music',   Icons.apple_rounded,            Color(0xFFFC3C44)),
      ('YouTube Music', Icons.smart_display_rounded,    Color(0xFFFF0000)),
      ('Amazon Music',  Icons.storefront_rounded,       Color(0xFF00A8E0)),
      ('Tidal',         Icons.water_drop_rounded,       Color(0xFF00FEFD)),
      ('Deezer',        Icons.equalizer_rounded,        Color(0xFFa238ff)),
      ('Audiomack',     Icons.headphones_rounded,       _white),
      ('SoundCloud',    Icons.cloud_rounded,            Color(0xFFFF5500)),
      ('Boomplay',      Icons.play_circle_rounded,      _white),
      ('iTunes',        Icons.music_note_rounded,       _white),
      ('Pandora',       Icons.radio_rounded,             Color(0xFF005483)),
      ('iHeartRadio',   Icons.favorite_rounded,         _white),
      ('Napster',       Icons.graphic_eq_rounded,       _white),
      ('FB Audio',      Icons.groups_rounded,           _white),
      ('TikTok',        Icons.music_video_rounded,      _white),
      ('Anghami',       Icons.audiotrack_rounded,       _white),
      ('Resso',         Icons.graphic_eq_rounded,       _white),
      ('+33 more',      Icons.add_circle_outline_rounded, _grey),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.public_rounded, color: _white70, size: 15),
            const SizedBox(width: 7),
            Text('Distribution Stores', style: GoogleFonts.nunito(color: _white, fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: _green.withValues(alpha: 0.3))),
              child: Text('Active', style: GoogleFonts.nunito(color: _green, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Your music is distributed to 50+ stores worldwide, automatically.',
              style: GoogleFonts.nunito(color: _grey, fontSize: 12, height: 1.5)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7, runSpacing: 7,
            children: stores.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _black3, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _white10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(s.$2, color: s.$3, size: 12),
                const SizedBox(width: 5),
                Text(s.$1, style: GoogleFonts.nunito(color: _white70, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ── SKELETON ────────────────────────────────────────────────────
  Widget _buildSkeleton(double top) {
    return Column(
      children: [
        SizedBox(height: top),
        _buildTopBar(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _SkeletonBox(height: 160, radius: 22),
                const SizedBox(height: 14),
                _SkeletonBox(height: 220, radius: 16),
                const SizedBox(height: 14),
                _SkeletonBox(height: 140, radius: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Exact copy matches web's <ul class="benefits-list">
const _kVerificationBenefits = <String>[
  "Priority consideration for 444Music's free curated playlists",
  "Boosted visibility for your new releases across the app",
  "Featured opportunities in 444 Campaigns",
  "A recognizable verified badge on your profile and every post",
  "Priority access to support from the 444Music team",
];

// ════════════════════════════════════════════════════════════════════
//  SMALL WIDGETS
// ════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _black2, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _white10),
    ),
    child: child,
  );
}

// Verification state box — one shared shape for verified/eligible/locked,
// matching web's .verify-state / .verify-state.verified / .eligible / .locked
class _VerifyStateBox extends StatelessWidget {
  final Color color, bg, border;
  final IconData icon;
  final String title, sub;
  final Widget? trailing;
  final int? progressPct;
  const _VerifyStateBox({
    required this.color, required this.bg, required this.border,
    required this.icon, required this.title, required this.sub,
    this.trailing, this.progressPct,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.nunito(color: _white, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(sub, style: GoogleFonts.nunito(color: _grey, fontSize: 12.5, height: 1.5)),
          if (progressPct != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressPct! / 100,
                minHeight: 6,
                backgroundColor: _black4,
                valueColor: const AlwaysStoppedAnimation(_green),
              ),
            ),
          ],
        ]),
      ),
      if (trailing != null) ...[
        const SizedBox(width: 12),
        trailing!,
      ],
    ]),
  );
}

class _SkeletonBox extends StatefulWidget {
  final double height;
  final double radius;
  const _SkeletonBox({required this.height, required this.radius});
  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}
class _SkeletonBoxState extends State<_SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _a = Tween<double>(begin: -2, end: 2).animate(_c);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment(_a.value - 1, 0), end: Alignment(_a.value + 1, 0),
          colors: const [_black2, _black3, _black2],
        ),
      ),
    ),
  );
}