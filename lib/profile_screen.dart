// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Profile / Account Screen
//  Theme: Black & White Luxury  |  Font: Nunito
//  Firebase Auth + Firestore  |  Mirrors web dashboard profile
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── PALETTE ────────────────────────────────────────────────────────
const _black      = Color(0xFF000000);
const _black1     = Color(0xFF080808);
const _black2     = Color(0xFF0D0D0D);
const _black3     = Color(0xFF111111);
const _black4     = Color(0xFF161616);
const _black5     = Color(0xFF1A1A1A);
const _white      = Color(0xFFFFFFFF);
const _white90    = Color(0xE6FFFFFF);
const _white70    = Color(0xB3FFFFFF);
const _white40    = Color(0x66FFFFFF);
const _white20    = Color(0x33FFFFFF);
const _white10    = Color(0x1AFFFFFF);
const _white06    = Color(0x0FFFFFFF);
const _grey       = Color(0xFF888888);
const _greyDark   = Color(0xFF444444);
const _green      = Color(0xFF22C55E);
const _amber      = Color(0xFFF59E0B);
const _rose       = Color(0xFFEF4444);
const _cyan       = Color(0xFF06B6D4);

Future<void> _launch(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

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
  String _country      = '';
  String _phone        = '';
  String _joinDate     = '';
  String? _avatarUrl;

  // stats
  int _totalReleases  = 0;
  int _approvedCount  = 0;
  int _pendingCount   = 0;
  int _paidCount      = 0;

  bool _loading       = true;
  bool _editingName   = false;
  bool _savingName    = false;
  bool _uploadingAvatar = false;

  final _nameCtrl     = TextEditingController();
  final _nameFocus    = FocusNode();

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
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_user == null) return;
    try {
      // Load user doc
      final userDoc = await _db.collection('users').doc(_user!.uid).get();
      final userData = userDoc.data() ?? {};

      // Load releases
      final snap = await _db
          .collection('submissions')
          .where('userId', isEqualTo: _user!.uid)
          .get();

      int approved = 0, pending = 0, paid = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final s = (d['status'] ?? '').toString().toLowerCase();
        if (s == 'approved') approved++;
        if (s == 'pending')  pending++;
        if (d['paymentVerified'] == true) paid++;
      }

      final createdAt = _user!.metadata.creationTime;
      final joined    = createdAt != null
          ? '${_monthName(createdAt.month)} ${createdAt.year}'
          : '—';

      if (mounted) {
        setState(() {
          _displayName    = userData['name']       ?? _user!.displayName ?? 'Artist';
          _email          = userData['email']      ?? _user!.email ?? '';
          _country        = userData['country']    ?? '';
          _phone          = userData['phone']      ?? '';
          _avatarUrl      = userData['profilePic'] ?? _user!.photoURL;
          _joinDate       = joined;
          _totalReleases  = snap.size;
          _approvedCount  = approved;
          _pendingCount   = pending;
          _paidCount      = paid;
          _loading        = false;
        });
        _entranceCtrl.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _monthName(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m - 1];
  }

  String get _firstName {
    return _displayName.trim().split(' ').first.isNotEmpty
        ? _displayName.trim().split(' ').first
        : 'Artist';
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

  // ── UPLOAD AVATAR ──────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file   = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400, imageQuality: 85);
    if (file == null || _user == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final bytes     = await file.readAsBytes();
      final base64Str = base64Encode(bytes);
      final dataUrl   = 'data:image/jpeg;base64,$base64Str';
      await _db.collection('users').doc(_user!.uid).set({'profilePic': dataUrl}, SetOptions(merge: true));
      setState(() { _avatarUrl = dataUrl; _uploadingAvatar = false; });
      _showSnack('Profile photo updated ✓', _green);
    } catch (e) {
      setState(() => _uploadingAvatar = false);
      _showSnack('Failed to update photo', _rose);
    }
  }

  // ── LOGOUT ─────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await _showConfirmSheet(
      icon: Icons.logout_rounded,
      iconColor: _rose,
      title: 'Log Out',
      body: 'Are you sure you want to log out of your 444Music account?',
      action: 'Log Out',
      actionColor: _rose,
    );
    if (confirm != true) return;
    await _auth.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  // ── DELETE ACCOUNT ─────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final confirm = await _showConfirmSheet(
      icon: Icons.delete_forever_rounded,
      iconColor: _rose,
      title: 'Delete Account',
      body: 'This will permanently delete your account and all your data. This cannot be undone.',
      action: 'Delete Forever',
      actionColor: _rose,
    );
    if (confirm != true) return;
    try {
      await _db.collection('users').doc(_user!.uid).delete();
      await _user!.delete();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _showSnack('Re-authenticate required. Please log out and log in again.', _amber);
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

  Future<bool?> _showConfirmSheet({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required String action,
    required Color actionColor,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _black2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: _white20, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle, border: Border.all(color: iconColor.withValues(alpha: 0.3))),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.nunito(color: _white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body, style: GoogleFonts.nunito(color: _grey, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: _black3, borderRadius: BorderRadius.circular(12), border: Border.all(color: _white10)),
                  child: Center(child: Text('Cancel', style: GoogleFonts.nunito(color: _white, fontSize: 14, fontWeight: FontWeight.w700))),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: actionColor, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(action, style: GoogleFonts.nunito(color: _white, fontSize: 14, fontWeight: FontWeight.w800))),
                ),
              )),
            ]),
          ],
        ),
      ),
    );
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
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: bottom + 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHero(),
                      const SizedBox(height: 20),
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildSectionLabel('Account Info'),
                      const SizedBox(height: 10),
                      _buildInfoCard(),
                      const SizedBox(height: 24),
                      _buildSectionLabel('Quick Actions'),
                      const SizedBox(height: 10),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      _buildSectionLabel('Distribution'),
                      const SizedBox(height: 10),
                      _buildStoresCard(),
                      const SizedBox(height: 24),
                      _buildSectionLabel('Notifications'),
                      const SizedBox(height: 10),
                      _buildNotificationsCard(),
                      const SizedBox(height: 24),
                      _buildSectionLabel('Danger Zone'),
                      const SizedBox(height: 10),
                      _buildDangerCard(),
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
          Text('Profile', style: GoogleFonts.nunito(color: _white, fontSize: 17, fontWeight: FontWeight.w800)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/settings'),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: _white06, borderRadius: BorderRadius.circular(11), border: Border.all(color: _white10)),
              child: const Icon(Icons.settings_outlined, color: _white, size: 19),
            ),
          ),
        ],
      ),
    );
  }

  // ── HERO ────────────────────────────────────────────────────────
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
      child: Column(
        children: [
          // Avatar + basic info
          Row(
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
                          Expanded(
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
                    const SizedBox(height: 10),

                    // Tags
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _Tag(label: '✓ Verified',   color: _green),
                      _Tag(label: 'Free Plan',    color: _white40),
                      if (_country.isNotEmpty) _Tag(label: _country, color: _white40),
                    ]),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Container(height: 1, color: _white10),
          const SizedBox(height: 14),

          // Hero action buttons
          Row(
            children: [
              Expanded(child: _HeroBtn(
                icon: Icons.cloud_upload_rounded,
                label: 'New Release',
                onTap: () => Navigator.pushNamed(context, '/upload'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _HeroBtn(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Earnings',
                onTap: () => Navigator.pushNamed(context, '/earnings'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _HeroBtn(
                icon: Icons.library_music_rounded,
                label: 'Releases',
                onTap: () => Navigator.pushNamed(context, '/releases'),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (_avatarUrl == null || _avatarUrl!.isEmpty) {
      return Container(
        color: _black3,
        child: Center(
          child: Text(_initials, style: GoogleFonts.nunito(color: _white, fontSize: 28, fontWeight: FontWeight.w800)),
        ),
      );
    }
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

  // ── STATS ROW ───────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _StatCard(value: '$_totalReleases',  label: 'Releases', sub: 'All time',      color: _white70)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: '$_approvedCount',  label: 'Live',     sub: 'On stores',     color: _green)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: '$_pendingCount',   label: 'Pending',  sub: 'In queue',      color: _amber)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: '$_paidCount',      label: 'Paid',     sub: 'Confirmed',     color: _cyan)),
        ],
      ),
    );
  }

  // ── SECTION LABEL ───────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(width: 4, height: 14, decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.nunito(color: _white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  // ── INFO CARD ───────────────────────────────────────────────────
  Widget _buildInfoCard() {
    return _Card(
      child: Column(
        children: [
          _InfoRow(icon: Icons.person_rounded,     label: 'Display Name',  value: _displayName.isEmpty ? '—' : _displayName),
          _InfoRow(icon: Icons.mail_outline_rounded, label: 'Email',        value: _email.isEmpty ? '—' : _email),
          _InfoRow(icon: Icons.phone_rounded,        label: 'Phone',        value: _phone.isEmpty ? 'Not set' : _phone),
          _InfoRow(icon: Icons.location_on_rounded,  label: 'Country',      value: _country.isEmpty ? 'Not set' : _country),
          _InfoRow(icon: Icons.calendar_today_rounded, label: 'Member Since', value: _joinDate, last: true),
        ],
      ),
    );
  }

  // ── QUICK ACTIONS ───────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _QuickCard(icon: Icons.analytics_rounded,         label: 'Analytics',    onTap: () => Navigator.pushNamed(context, '/analytics'))),
              const SizedBox(width: 10),
              Expanded(child: _QuickCard(icon: Icons.trending_up_rounded,       label: 'Promote',      onTap: () => _launch('https://444musicblog.vercel.app'))),
              const SizedBox(width: 10),
              Expanded(child: _QuickCard(icon: Icons.link_rounded,              label: 'Smart Links',  onTap: () => Navigator.pushNamed(context, '/releases'))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _QuickCard(icon: Icons.call_split_rounded,        label: 'Royalty Split', onTap: () => Navigator.pushNamed(context, '/splits'))),
              const SizedBox(width: 10),
              Expanded(child: _QuickCard(icon: Icons.help_outline_rounded,      label: 'Support',      onTap: () => Navigator.pushNamed(context, '/support'))),
              const SizedBox(width: 10),
              Expanded(child: _QuickCard(icon: Icons.credit_card_rounded,       label: 'Pay Now',      onTap: () => _launch('https://444music-distribution.vercel.app/pay.html'))),
            ],
          ),
        ],
      ),
    );
  }

  // ── STORES CARD ─────────────────────────────────────────────────
  Widget _buildStoresCard() {
    const stores = [
      ('Spotify',       Icons.music_note_rounded,       Color(0xFF1DB954)),
      ('Apple Music',   Icons.apple_rounded,            Color(0xFFFC3C44)),
      ('YouTube Music', Icons.smart_display_rounded,    Color(0xFFFF0000)),
      ('Audiomack',     Icons.headphones_rounded,       Color(0xFFFFa200)),
      ('Boomplay',      Icons.play_circle_rounded,      Color(0xFFFF6600)),
      ('Tidal',         Icons.water_rounded,            Color(0xFF00FEFD)),
      ('Deezer',        Icons.equalizer_rounded,        Color(0xFFa238ff)),
      ('Amazon Music',  Icons.storefront_rounded,       Color(0xFF00A8E0)),
      ('TikTok',        Icons.music_video_rounded,      Color(0xFFFF0050)),
      ('SoundCloud',    Icons.cloud_rounded,            Color(0xFFFF5500)),
      ('Pandora',       Icons.radio_rounded,            Color(0xFF005483)),
      ('+38 more',      Icons.add_circle_outline_rounded, _grey),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.public_rounded, color: _white70, size: 15),
            const SizedBox(width: 7),
            Text('50+ Stores Worldwide', style: GoogleFonts.nunito(color: _white, fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: _green.withValues(alpha: 0.3))),
              child: Text('Active', style: GoogleFonts.nunito(color: _green, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
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

  // ── NOTIFICATIONS CARD ──────────────────────────────────────────
  Widget _buildNotificationsCard() {
    return _Card(
      child: Column(
        children: [
          _NotifRow(
            icon: Icons.check_circle_rounded,
            iconColor: _green,
            title: 'Release under review',
            sub: 'Your latest release is being reviewed',
            time: '2 hrs ago',
            unread: true,
          ),
          _NotifRow(
            icon: Icons.store_rounded,
            iconColor: _cyan,
            title: 'Music live on stores',
            sub: 'Now live on Spotify, Apple Music & 48 more',
            time: 'Yesterday',
            unread: false,
          ),
          _NotifRow(
            icon: Icons.attach_money_rounded,
            iconColor: _amber,
            title: 'Royalty payout available',
            sub: 'Your earnings are ready to withdraw',
            time: '3 days ago',
            unread: true,
          ),
          _NotifRow(
            icon: Icons.campaign_rounded,
            iconColor: _white70,
            title: 'Smart Links are here',
            sub: 'Create shareable links for all your releases',
            time: '1 week ago',
            unread: false,
            last: true,
          ),
        ],
      ),
    );
  }

  // ── DANGER CARD ─────────────────────────────────────────────────
  Widget _buildDangerCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Logout
          GestureDetector(
            onTap: _logout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: _black2, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _white10),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.logout_rounded, color: _white70, size: 18),
                const SizedBox(width: 10),
                Text('Log Out', style: GoogleFonts.nunito(color: _white70, fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          // Delete
          GestureDetector(
            onTap: _deleteAccount,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: _rose.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _rose.withValues(alpha: 0.25)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.delete_forever_rounded, color: _rose.withValues(alpha: 0.8), size: 18),
                const SizedBox(width: 10),
                Text('Delete Account', style: GoogleFonts.nunito(color: _rose.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ),
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
                _SkeletonBox(height: 180, radius: 22),
                const SizedBox(height: 14),
                Row(children: List.generate(4, (i) => Expanded(child: Padding(
                  padding: EdgeInsets.only(left: i > 0 ? 10 : 0),
                  child: _SkeletonBox(height: 80, radius: 14),
                )))),
                const SizedBox(height: 14),
                _SkeletonBox(height: 160, radius: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SMALL WIDGETS
// ════════════════════════════════════════════════════════════════════

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(label, style: GoogleFonts.nunito(color: color.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

class _StatCard extends StatelessWidget {
  final String value, label, sub;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.sub, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(color: _black2, borderRadius: BorderRadius.circular(14), border: Border.all(color: _white10)),
    child: Column(children: [
      Text(value, style: GoogleFonts.nunito(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.nunito(color: _white, fontSize: 11, fontWeight: FontWeight.w700)),
      const SizedBox(height: 1),
      Text(sub, style: GoogleFonts.nunito(color: _greyDark, fontSize: 9), textAlign: TextAlign.center),
    ]),
  );
}

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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool last;
  const _InfoRow({required this.icon, required this.label, required this.value, this.last = false});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Icon(icon, color: _grey, size: 16),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.nunito(color: _grey, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value, style: GoogleFonts.nunito(color: _white, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
      if (!last) Container(height: 1, color: _white10),
    ],
  );
}

class _HeroBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HeroBtn({required this.icon, required this.label, required this.onTap});
  @override
  State<_HeroBtn> createState() => _HeroBtnState();
}
class _HeroBtnState extends State<_HeroBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => setState(() => _pressed = true),
    onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
    onTapCancel: ()  => setState(() => _pressed = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: _pressed ? _white10 : _black3,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _pressed ? _white20 : _white10),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(widget.icon, color: _white70, size: 18),
        const SizedBox(height: 5),
        Text(widget.label, style: GoogleFonts.nunito(color: _white70, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

class _QuickCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickCard({required this.icon, required this.label, required this.onTap});
  @override
  State<_QuickCard> createState() => _QuickCardState();
}
class _QuickCardState extends State<_QuickCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => setState(() => _pressed = true),
    onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
    onTapCancel: ()  => setState(() => _pressed = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _pressed ? _white10 : _black2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _pressed ? _white20 : _white10),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(widget.icon, color: _white, size: 22),
        const SizedBox(height: 7),
        Text(widget.label, style: GoogleFonts.nunito(color: _white70, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _NotifRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, sub, time;
  final bool unread;
  final bool last;
  const _NotifRow({
    required this.icon, required this.iconColor,
    required this.title, required this.sub, required this.time,
    this.unread = false, this.last = false,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle,
              border: Border.all(color: iconColor.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.nunito(color: _white, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(sub, style: GoogleFonts.nunito(color: _grey, fontSize: 11, height: 1.4)),
            const SizedBox(height: 4),
            Text(time, style: GoogleFonts.nunito(color: _greyDark, fontSize: 10)),
          ])),
          if (unread) Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: _white, shape: BoxShape.circle),
          ),
        ]),
      ),
      if (!last) Container(height: 1, color: _white10),
    ],
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