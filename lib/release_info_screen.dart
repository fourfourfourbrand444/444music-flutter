import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─── PALETTE ────────────────────────────────────────────────────────────────
const _bg          = Color(0xFF080808);
const _surface     = Color(0xFF0E0E0E);
const _card        = Color(0xFF111111);
const _input       = Color(0xFF171717);
const _border      = Color(0x1AFFFFFF);
const _borderFocus = Color(0x66FFFFFF);
const _white       = Color(0xFFFFFFFF);
const _white70     = Color(0xB3FFFFFF);
const _white40     = Color(0x66FFFFFF);
const _white20     = Color(0x33FFFFFF);
const _white10     = Color(0x1AFFFFFF);
const _white06     = Color(0x0FFFFFFF);
const _grey        = Color(0xFF888888);
const _greyDark    = Color(0xFF444444);
const _green       = Color(0xFF4ADE80);
const _red         = Color(0xFFF87171);
const _amber       = Color(0xFFF59E0B);

// ─── BRAND ICONS (Simple Icons CDN) ──────────────────────────────────────────
const _spotifyIconUrl     = 'https://cdn.simpleicons.org/spotify/1DB954';
const _appleMusicIconUrl  = 'https://cdn.simpleicons.org/applemusic/fc3c44';

// ─── MODELS ─────────────────────────────────────────────────────────────────
class ArtistResult {
  final String name;
  final String genre;
  final String imageUrl;
  const ArtistResult({
    required this.name,
    required this.genre,
    required this.imageUrl,
  });
}

class CreditEntry {
  String name;
  String role;
  String ipi;
  CreditEntry({this.name = '', this.role = '', this.ipi = ''});
}

// NEW — featured / secondary artist entry
class _FeaturedArtistEntry {
  ArtistResult artist;
  String role; // 'Featuring Artist' or 'Secondary Artist'
  String url;  // optional Spotify/Apple Music profile link
  _FeaturedArtistEntry({
    required this.artist,
    this.role = 'Featuring Artist',
    this.url = '',
  });
}

// ─── CONSTANTS ──────────────────────────────────────────────────────────────
const _genres = [
  'Pop', 'Indie Pop', 'Afropop', 'Hip-Hop', 'Rap', 'Trap', 'Drill',
  'Afro Trap', 'R&B', 'Soul', 'Neo Soul', 'Gospel', 'Electronic', 'EDM',
  'Afro House', 'House', 'Rock', 'Alternative Rock', 'Indie Rock',
  'Afrobeats', 'Afroswing', 'Highlife', 'Amapiano', 'Reggae', 'Dancehall',
  'Jazz', 'Blues', 'Classical', 'Lo-Fi', 'Other',
];

const _countries = [
  'Ghana', 'Nigeria', 'Kenya', 'South Africa', 'Uganda', 'Tanzania',
  'Cameroon', 'United States of America', 'United Kingdom, The', 'Canada',
  'Australia', 'France', 'Germany', 'Brazil', 'India', 'Jamaica',
  'Trinidad and Tobago', 'Senegal', 'Ethiopia', 'Zimbabwe', 'Other',
];

const _producerRoles = [
  'Producer', 'Executive Producer', 'Co-Producer', 'Beat Maker',
  'Mixing Engineer', 'Mastering Engineer', 'Recording Engineer',
  'Vocal Producer', 'Sound Designer', 'Re-mixer', 'Programmer', 'Audio Editor',
];
const _musicianRoles = [
  'Vocalist', 'Background Vocalist', 'Lead Vocalist', 'Rapper',
  'Guitarist', 'Bassist', 'Drummer', 'Pianist', 'Keyboardist',
  'DJ / Turntablist', 'Session Musician', 'String Arranger',
];
const _writerRoles = [
  'Songwriter', 'Lyricist', 'Composer', 'Co-Writer', 'Melody Writer',
  'Arranger', 'Top-Liner', 'Concept Writer',
];

// Version options for the release (single / EP / album track version)
const _versionOptions = [
  'Original', 'Radio Edit', 'Extended Mix', 'Remix', 'Acoustic',
  'Live', 'Instrumental', 'Remastered', 'Cover', 'Sped Up', 'Slowed',
  'Other',
];

// NEW — featured artist role options
const _featuredRoleOptions = ['Featuring Artist', 'Secondary Artist'];

// ── SHARED ARTIST SEARCH (no state — used by both Main and Featured) ───────
// Extracted so both search boxes can share the exact same logic without
// duplicating it, and so we can guard against out-of-order responses.
Future<List<ArtistResult>> _searchArtistsRemote(String q) async {
  final itunesUrl = Uri.parse(
      'https://itunes.apple.com/search?term=${Uri.encodeComponent(q)}'
          '&entity=musicArtist&limit=8&media=music');
  final proxies = [
    'https://corsproxy.io/?${Uri.encodeComponent(itunesUrl.toString())}',
    'https://api.allorigins.win/raw?url=${Uri.encodeComponent(itunesUrl.toString())}',
  ];
  for (final proxy in proxies) {
    try {
      final res = await http
          .get(Uri.parse(proxy))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        var body = res.body;
        try {
          final outer = jsonDecode(body) as Map?;
          if (outer != null && outer.containsKey('contents')) {
            body = outer['contents'] as String;
          }
        } catch (_) {}
        final data    = jsonDecode(body) as Map?;
        final results = (data?['results'] as List?) ?? [];
        if (results.isNotEmpty) {
          return results
              .where((r) => r['artistName'] != null)
              .map((r) => ArtistResult(
            name: r['artistName'] as String,
            genre: (r['primaryGenreName'] as String?) ?? '',
            imageUrl: ((r['artworkUrl100'] as String?) ?? '')
                .replaceAll('100x100bb', '300x300bb'),
          ))
              .toList();
        }
      }
    } catch (_) {}
  }
  return [];
}

// ════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════════════════
class ReleaseInfoScreen extends StatefulWidget {
  const ReleaseInfoScreen({super.key});

  @override
  State<ReleaseInfoScreen> createState() => _ReleaseInfoScreenState();
}

class _ReleaseInfoScreenState extends State<ReleaseInfoScreen>
    with TickerProviderStateMixin {

  // ── controllers ─────────────────────────────────────────────────────────
  final _artistCtrl    = TextEditingController();
  final _titleCtrl     = TextEditingController();
  final _languageCtrl  = TextEditingController();
  final _labelCtrl     = TextEditingController();
  final _copyrightCtrl = TextEditingController();
  final _isrcCtrl      = TextEditingController();
  final _upcCtrl       = TextEditingController();
  final _catalogCtrl   = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _lyricsCtrl    = TextEditingController();

  // ── state ────────────────────────────────────────────────────────────────
  String    _releaseType = 'Single';
  String    _genre       = 'Afrobeats';
  String    _country     = 'Ghana';
  String    _explicit    = 'No';
  DateTime? _releaseDate;

  // song details / ownership state
  String     _previouslyReleased        = 'No';       // Yes / No radio
  String     _version                   = 'Original'; // dropdown, required
  String     _vocalType                 = 'Vocals';   // Vocals / Instrumental radio
  bool       _originalOwnershipConfirmed = false;      // agreement checkbox, required
  DateTime?  _previousReleaseDate;                     // only used when previouslyReleased == 'Yes'

  final List<ArtistResult> _selectedArtists = [];
  List<ArtistResult>       _searchResults   = [];
  bool                     _searching       = false;
  Timer?                   _searchTimer;
  int                      _mainSearchGen   = 0; // guards against stale responses

  final _artistFocus     = FocusNode();
  final _artistLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // NEW — Featured / Secondary Artists state
  String _hasFeaturedArtists = 'No';
  final List<_FeaturedArtistEntry> _featuredArtists = [];
  final _featArtistCtrl    = TextEditingController();
  final _featArtistFocus   = FocusNode();
  final _featArtistLayerLink = LayerLink();
  OverlayEntry? _featOverlayEntry;
  List<ArtistResult> _featSearchResults = [];
  bool                _featSearching     = false;
  Timer?              _featSearchTimer;
  int                 _featSearchGen     = 0;

  // NEW — payment verification state
  String? _paymentReference;
  bool    _paymentVerified  = false;
  bool    _paymentArgLoaded = false;

  // producer, musician, writer only (no publishing)
  final Map<String, List<CreditEntry>> _credits = {
    'producer': [],
    'musician': [],
    'writer':   [],
  };

  bool   _submitting = false;
  String _statusMsg  = '';

  late AnimationController _entranceCtrl;
  late Animation<double>   _entranceFade;
  late Animation<Offset>   _entranceSlide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _bg,
      ),
    );
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _entranceFade = CurvedAnimation(
        parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
            .animate(CurvedAnimation(
            parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();
    _artistFocus.addListener(_onArtistFocusChange);
    _featArtistFocus.addListener(_onFeatArtistFocusChange);
  }

  // NEW — reads the payment reference passed from Upload, then verifies it
  // against the pendingPayments collection written by the webhook.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_paymentArgLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        _paymentReference = args;
        _verifyPayment(args);
      }
      _paymentArgLoaded = true;
    }
  }

  Future<void> _verifyPayment(String reference) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('pendingPayments')
          .doc(reference)
          .get();
      if (doc.exists && doc.data()?['paid'] == true) {
        if (mounted) setState(() => _paymentVerified = true);
      }
    } catch (e) {
      debugPrint('[Payment verify] ERROR: $e');
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _artistFocus.removeListener(_onArtistFocusChange);
    _artistFocus.dispose();
    _searchTimer?.cancel();
    _removeOverlay();
    _featArtistFocus.removeListener(_onFeatArtistFocusChange);
    _featArtistFocus.dispose();
    _featSearchTimer?.cancel();
    _removeFeatOverlay();
    _featArtistCtrl.dispose();
    for (final c in [
      _artistCtrl, _titleCtrl, _languageCtrl,
      _labelCtrl, _copyrightCtrl, _isrcCtrl, _upcCtrl, _catalogCtrl,
      _emailCtrl, _phoneCtrl, _lyricsCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── MAIN ARTIST SEARCH ──────────────────────────────────────────────────
  void _onArtistFocusChange() {
    if (!_artistFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), _removeOverlay);
    }
  }

  void _onArtistInput(String q) {
    _searchTimer?.cancel();
    if (q.trim().length < 2) { _removeOverlay(); return; }
    _searchTimer = Timer(
        const Duration(milliseconds: 400), () => _doSearch(q.trim()));
  }

  // FIXED — guards against stale/out-of-order responses using a generation
  // counter. Previously, a slower earlier request could overwrite a faster
  // later one with empty results, making it look like search needed
  // several retries before it "worked".
  Future<void> _doSearch(String q) async {
    final myGen = ++_mainSearchGen;
    setState(() { _searching = true; _searchResults = []; });
    _showOverlay();
    final results = await _searchArtistsRemote(q);
    if (myGen != _mainSearchGen) return; // a newer search superseded this one
    if (!mounted) return;
    setState(() { _searchResults = results; _searching = false; });
    _showOverlay();
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (_) => _ArtistDropdown(
        link:      _artistLayerLink,
        results:   _searchResults,
        searching: _searching,
        query:     _artistCtrl.text.trim(),
        onSelect: (artist) {
          _addArtist(artist);
          _removeOverlay();
          _artistCtrl.clear();
        },
        onAddNew: (name) {
          _addArtist(ArtistResult(name: name, genre: '', imageUrl: ''));
          _removeOverlay();
          _artistCtrl.clear();
        },
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _addArtist(ArtistResult a) {
    if (_selectedArtists
        .any((x) => x.name.toLowerCase() == a.name.toLowerCase())) return;
    setState(() => _selectedArtists.add(a));
  }

  // ── FEATURED / SECONDARY ARTIST SEARCH (mirrors main artist search) ─────
  void _onFeatArtistFocusChange() {
    if (!_featArtistFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), _removeFeatOverlay);
    }
  }

  void _onFeatArtistInput(String q) {
    _featSearchTimer?.cancel();
    if (q.trim().length < 2) { _removeFeatOverlay(); return; }
    _featSearchTimer = Timer(
        const Duration(milliseconds: 400), () => _doFeatSearch(q.trim()));
  }

  Future<void> _doFeatSearch(String q) async {
    final myGen = ++_featSearchGen;
    setState(() { _featSearching = true; _featSearchResults = []; });
    _showFeatOverlay();
    final results = await _searchArtistsRemote(q);
    if (myGen != _featSearchGen) return;
    if (!mounted) return;
    setState(() { _featSearchResults = results; _featSearching = false; });
    _showFeatOverlay();
  }

  void _showFeatOverlay() {
    _removeFeatOverlay();
    final overlay = Overlay.of(context);
    _featOverlayEntry = OverlayEntry(
      builder: (_) => _ArtistDropdown(
        link:      _featArtistLayerLink,
        results:   _featSearchResults,
        searching: _featSearching,
        query:     _featArtistCtrl.text.trim(),
        onSelect: (artist) {
          _addFeaturedArtist(artist);
          _removeFeatOverlay();
          _featArtistCtrl.clear();
        },
        onAddNew: (name) {
          _addFeaturedArtist(ArtistResult(name: name, genre: '', imageUrl: ''));
          _removeFeatOverlay();
          _featArtistCtrl.clear();
        },
      ),
    );
    overlay.insert(_featOverlayEntry!);
  }

  void _removeFeatOverlay() {
    _featOverlayEntry?.remove();
    _featOverlayEntry = null;
  }

  void _addFeaturedArtist(ArtistResult a) {
    if (_featuredArtists
        .any((x) => x.artist.name.toLowerCase() == a.name.toLowerCase())) return;
    setState(() => _featuredArtists.add(_FeaturedArtistEntry(artist: a)));
  }

  String _formatFeaturedArtists() {
    if (_featuredArtists.isEmpty) return 'None';
    return _featuredArtists.map((e) {
      var line = '${e.artist.name} (${e.role})';
      if (e.url.trim().isNotEmpty) line += ' — ${e.url.trim()}';
      return line;
    }).join('\n');
  }

  // ── CREDITS ──────────────────────────────────────────────────────────────
  void _addCredit(String type) =>
      setState(() => _credits[type]!.add(CreditEntry()));

  void _removeCredit(String type, int idx) =>
      setState(() => _credits[type]!.removeAt(idx));

  // ── EARLY RELEASE DATE WARNING (non-blocking) ───────────────────────────
  void _showEarlyDateWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171717),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0x1AF59E0B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x33F59E0B)),
              ),
              child: const Icon(Icons.info_outline_rounded,
                  color: _amber, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Early Release Date',
                  style: GoogleFonts.outfit(
                      color: _white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Text(
          'For the best chance at playlist placement, stores recommend submitting your release at least 5 days ahead of the release date. You can still continue with this date if you prefer.',
          style: GoogleFonts.inter(color: _white70, fontSize: 13, height: 1.55),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Ignore',
                style: GoogleFonts.outfit(
                    color: _white, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── NOTIFICATIONS (own backend) ────────────────────────────────────────
  static const _notifyUrl = 'https://444music-backend.bonto.run/api/submissions/notify';
  static const _appSecret = 'e993b17f0762667e27d5298839dacff4a7409bb74e11e9ecaf0bb2bb647120a8';

  String _formatCredits(List<CreditEntry> list) {
    if (list.isEmpty) return 'None';
    final lines = list
        .where((c) => c.name.trim().isNotEmpty)
        .map((c) {
      var line = '• ${c.name}';
      if (c.role.isNotEmpty) line += ' — ${c.role}';
      if (c.ipi.isNotEmpty)  line += ' (IPI: ${c.ipi})';
      return line;
    })
        .toList();
    return lines.isEmpty ? 'None' : lines.join('\n');
  }

  Future<void> _sendEmails(Map<String, dynamic> data) async {
    final params = {
      'email':          data['email'],
      'artist_name':    data['artistName'],
      'release_title':  data['releaseTitle'],
      'featuring':      _formatFeaturedArtists(),
      'release_type':   data['releaseType'],
      'genre':          data['genre'],
      'language':       (data['language'] as String).isEmpty
          ? 'Not specified' : data['language'],
      'release_date':   (data['releaseDate'] as String).isEmpty
          ? 'Not set' : data['releaseDate'],
      'explicit':       data['explicit'],
      'country':        data['country'],
      'phone':          (data['phone'] as String).isEmpty
          ? 'Not provided' : data['phone'],
      'label':          (data['label'] as String).isEmpty
          ? 'Independent' : data['label'],
      'copyright':      (data['copyright'] as String).isEmpty
          ? 'Not provided' : data['copyright'],
      'isrc':           (data['isrc'] as String).isEmpty
          ? 'Not provided' : data['isrc'],
      'upc':            (data['upc'] as String).isEmpty
          ? 'Auto-assign' : data['upc'],
      'catalog_number': (data['catalogNumber'] as String).isEmpty
          ? 'Not provided' : data['catalogNumber'],
      // song details / ownership fields
      'version':               data['version'],
      'previously_released':   data['previouslyReleased'],
      'previous_release_date': (data['previousReleaseDate'] as String).isEmpty
          ? 'N/A' : data['previousReleaseDate'],
      'vocal_type':            data['vocalType'],
      'ownership_confirmed':   (data['ownershipConfirmed'] == true)
          ? 'Yes — confirmed original work'
          : 'Not confirmed',
      'producers':      _formatCredits(_credits['producer']!),
      'musicians':      _formatCredits(_credits['musician']!),
      'songwriters':    _formatCredits(_credits['writer']!),
      'publishers':     'N/A',
      'lyrics':         (data['lyrics'] as String).isEmpty
          ? 'Not provided' : data['lyrics'],
      'submitted_at':   DateTime.now().toLocal().toString(),
      'status':         'Pending',
      // NEW — payment status, always shown to admin regardless of frontend state
      'payment_status': _paymentVerified ? 'Paid' : 'Not confirmed',
    };

    try {
      final response = await http
          .post(
        Uri.parse(_notifyUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-app-secret': _appSecret,
        },
        body: jsonEncode(params),
      )
          .timeout(const Duration(seconds: 15));
      debugPrint('[Notify] status=${response.statusCode} body=${response.body}');
    } catch (e) {
      debugPrint('[Notify] ERROR: $e');
    }
  }

  // ── VALIDATION ───────────────────────────────────────────────────────────
  String? _validate() {
    if (_selectedArtists.isEmpty) return 'Please add at least one artist.';
    if (_titleCtrl.text.trim().isEmpty) return 'Release title is required.';
    if (_releaseDate == null) return 'Please select a release date.';

    // Producer name is mandatory — at least one producer with a name
    final producers = _credits['producer']!;
    if (producers.isEmpty || producers.every((p) => p.name.trim().isEmpty)) {
      return 'Please add at least one producer name.';
    }

    // version, previous-release status, and ownership agreement
    if (_version.trim().isEmpty) return 'Please select a version for this track.';
    if (_previouslyReleased.trim().isEmpty) {
      return 'Please indicate if this song has been released before.';
    }
    if (_previouslyReleased == 'Yes' && _previousReleaseDate == null) {
      return 'Please select the previous release date.';
    }
    if (!_originalOwnershipConfirmed) {
      return 'Please confirm you own this song / hold the rights to distribute it.';
    }

    if (_emailCtrl.text.trim().isEmpty) return 'Email address is required.';
    return null;
  }

  // ── SUBMIT ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _statusMsg = error);
      return;
    }

    setState(() { _submitting = true; _statusMsg = 'Submitting…'; });

    try {
      final user = FirebaseAuth.instance.currentUser;

      final data = {
        'artistName':    _selectedArtists.map((a) => a.name).join(', '),
        'releaseTitle':  _titleCtrl.text.trim(),
        'releaseType':   _releaseType,
        'genre':         _genre,
        'country':       _country,
        'language':      _languageCtrl.text.trim(),
        'releaseDate':   _releaseDate?.toIso8601String() ?? '',
        'explicit':      _explicit,
        'email':         _emailCtrl.text.trim(),
        'phone':         _phoneCtrl.text.trim(),
        'label':         _labelCtrl.text.trim(),
        'copyright':     _copyrightCtrl.text.trim(),
        'isrc':          _isrcCtrl.text.trim(),
        'upc':           _upcCtrl.text.trim(),
        'catalogNumber': _catalogCtrl.text.trim(),
        'lyrics':        _lyricsCtrl.text.trim(),
        // song details / ownership
        'version':               _version,
        'previouslyReleased':    _previouslyReleased,
        'previousReleaseDate':   _previouslyReleased == 'Yes'
            ? (_previousReleaseDate?.toIso8601String() ?? '')
            : '',
        'vocalType':             _vocalType,
        'ownershipConfirmed':    _originalOwnershipConfirmed,
        'credits': {
          'producer': _credits['producer']!
              .map((c) => {'name': c.name, 'role': c.role, 'ipi': c.ipi})
              .toList(),
          'musician': _credits['musician']!
              .map((c) => {'name': c.name, 'role': c.role, 'ipi': c.ipi})
              .toList(),
          'writer': _credits['writer']!
              .map((c) => {'name': c.name, 'role': c.role, 'ipi': c.ipi})
              .toList(),
        },
        // NEW — featured / secondary artists, structured for the admin side
        'featuredArtists': _featuredArtists.map((e) => {
          'name': e.artist.name,
          'role': e.role,
          'url':  e.url.trim(),
        }).toList(),
        // NEW — payment status, recorded on the submission itself
        'paid':             _paymentVerified ? 'Paid' : 'Unpaid',
        'paymentReference': _paymentReference ?? '',
        'userId':    user?.uid ?? '',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'status':    'Pending',
      };

      // 1 ── Save to Firestore
      await FirebaseFirestore.instance.collection('submissions').add(data);

      // 2 ── Send notification emails via our own backend
      await _sendEmails(data);

      // 3 ── NEW — mark the payment as claimed so the resume banner on
      // Pricing doesn't show it as unclaimed anymore
      if (_paymentVerified && _paymentReference != null) {
        try {
          await FirebaseFirestore.instance
              .collection('pendingPayments')
              .doc(_paymentReference)
              .update({'claimed': true});
        } catch (e) {
          debugPrint('[Payment claim] ERROR: $e');
        }
      }

      setState(() { _submitting = false; _statusMsg = ''; });
      if (mounted) Navigator.pushNamed(context, '/select');
    } catch (e) {
      debugPrint('[Submit] ERROR: $e');
      setState(() {
        _submitting = false;
        _statusMsg  = 'Something went wrong. Please try again.';
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _entranceFade,
        child: SlideTransition(
          position: _entranceSlide,
          child: Column(
            children: [
              _buildTopBar(top),
              _buildStepIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // ── Artist Info ──────────────────────────────────────
                      _sectionHeader(Icons.person_outline_rounded,
                          'Artist Information',
                          'Search and select your artist profile'),
                      _buildArtistSearch(),
                      const SizedBox(height: 16),
                      _inputField('Phone Number', _phoneCtrl,
                          '+1 000 000 0000',
                          required: false,
                          keyboardType: TextInputType.phone),
                      _buildCountryRow(),

                      // ── Featured & Secondary Artists (NEW) ───────────────
                      _sectionHeader(Icons.group_add_outlined,
                          'Featured & Secondary Artists',
                          'Optional — add other artists on this track'),
                      _radioField(
                        'Add a featured or secondary artist?',
                        _hasFeaturedArtists,
                        const ['No', 'Yes'],
                            (v) => setState(() => _hasFeaturedArtists = v),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        child: _hasFeaturedArtists == 'Yes'
                            ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: _buildFeaturedArtistsPanel(),
                        )
                            : const SizedBox(width: double.infinity),
                      ),

                      // ── Release Details ──────────────────────────────────
                      _sectionHeader(Icons.music_note_outlined,
                          'Release Details', 'Core metadata for your release'),
                      _inputField('Release Title', _titleCtrl,
                          'Name of your single, EP or album', required: true),
                      const SizedBox(height: 14),
                      _buildRow([
                        _dropdownField('Release Type', _releaseType,
                            ['Single', 'EP', 'Album'],
                                (v) => setState(() => _releaseType = v!)),
                        _dropdownField('Genre', _genre, _genres,
                                (v) => setState(() => _genre = v!),
                            required: true),
                      ]),
                      const SizedBox(height: 14),
                      _buildRow([
                        _inputField('Language', _languageCtrl,
                            'e.g. English, Twi', required: false),
                        _dropdownField('Explicit Content', _explicit,
                            ['No', 'Yes'],
                                (v) => setState(() => _explicit = v!)),
                      ]),
                      const SizedBox(height: 14),
                      _buildDateField(),

                      // ── Song Details & Ownership ─────────────────────────
                      _sectionHeader(Icons.fact_check_outlined,
                          'Song Details & Ownership',
                          'Version, prior release status, and rights'),
                      _dropdownField('Version', _version, _versionOptions,
                              (v) => setState(() => _version = v!),
                          required: true),
                      const SizedBox(height: 14),
                      _radioField(
                        'Vocals or Instrumental',
                        _vocalType,
                        const ['Vocals', 'Instrumental'],
                            (v) => setState(() => _vocalType = v),
                      ),
                      const SizedBox(height: 14),
                      _radioField(
                        'Has this song been released before?',
                        _previouslyReleased,
                        const ['No', 'Yes'],
                            (v) => setState(() {
                          _previouslyReleased = v;
                          if (v == 'No') _previousReleaseDate = null;
                        }),
                        required: true,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        child: _previouslyReleased == 'Yes'
                            ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: _buildPreviousReleaseDateField(),
                        )
                            : const SizedBox(width: double.infinity),
                      ),

                      // ── Label & Rights ───────────────────────────────────
                      _sectionHeader(Icons.business_center_outlined,
                          'Label & Rights', 'Copyright and label ownership'),
                      _buildRow([
                        _inputField('Label Name', _labelCtrl,
                            'Independent or label name', required: false),
                        _inputField('Copyright Holder', _copyrightCtrl,
                            '© 2025 Your Name', required: false),
                      ]),

                      // ── Identifiers ──────────────────────────────────────
                      _sectionHeader(Icons.barcode_reader, 'Identifiers',
                          'ISRC, UPC, and catalog codes'),
                      _buildRow([
                        _inputField('ISRC Code', _isrcCtrl,
                            'e.g. USRC17607839',
                            required: false, maxLength: 12),
                        _inputField('UPC / EAN Barcode', _upcCtrl,
                            'Leave blank to auto-assign', required: false),
                      ]),
                      const SizedBox(height: 14),
                      _inputField('Catalog Number', _catalogCtrl,
                          'e.g. LAB-001 (optional)', required: false),

                      // ── Production Credits ───────────────────────────────
                      _sectionHeader(Icons.star_outline_rounded,
                          'Production Credits',
                          'Producers, engineers, and musicians'),
                      _buildCreditsPanel(
                          'producer',
                          'Producers & Engineers',
                          Icons.tune_rounded,
                          _producerRoles,
                          required: true),
                      const SizedBox(height: 12),
                      _buildCreditsPanel(
                          'musician',
                          'Musicians & Performers',
                          Icons.headphones_rounded,
                          _musicianRoles),

                      // ── Songwriting ──────────────────────────────────────
                      _sectionHeader(Icons.edit_outlined,
                          'Songwriting', 'Writers and composers'),
                      _buildCreditsPanel('writer', 'Songwriters & Composers',
                          Icons.draw_outlined, _writerRoles, showIpi: true),

                      // ── Contact ──────────────────────────────────────────
                      _sectionHeader(Icons.alternate_email_rounded,
                          'Contact & Account',
                          'Your contact info for this release'),
                      _inputField('Email Address', _emailCtrl,
                          'your@email.com',
                          required: true,
                          keyboardType: TextInputType.emailAddress),

                      // ── Lyrics ───────────────────────────────────────────
                      _sectionHeader(Icons.format_align_left_rounded,
                          'Lyrics', 'Optional — improves discoverability'),
                      _buildLyricsField(),

                      // ── Ownership Agreement ──────────────────────────────
                      _buildAgreementCheck(),

                      const SizedBox(height: 32),
                      _buildSubmitButton(),
                      if (_statusMsg.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            _statusMsg,
                            style: GoogleFonts.inter(
                                color: _red, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildTrustStrip(),
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

  // ── TOP BAR ──────────────────────────────────────────────────────────────
  Widget _buildTopBar(double top) {
    return Container(
      padding: EdgeInsets.only(top: top),
      color: _bg,
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _border))),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _white06,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _white, size: 15),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text('Create New Release',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      color: _white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _white06,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      color: _grey, size: 10),
                  const SizedBox(width: 5),
                  Text('Secure',
                      style: GoogleFonts.outfit(
                          color: _grey,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP INDICATOR ────────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    final steps = ['Release Info', 'Select Stores', 'Review'];
    return Container(
      color: _bg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
                child: Container(height: 1, color: _border));
          }
          final idx      = i ~/ 2;
          final isActive = idx == 0;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? _white : Colors.transparent,
                  border: Border.all(
                      color: isActive ? _white : _greyDark),
                ),
                child: Center(
                  child: Text('${idx + 1}',
                      style: GoogleFonts.outfit(
                          color: isActive ? _bg : _greyDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 6),
              Text(steps[idx],
                  style: GoogleFonts.outfit(
                      color: isActive ? _white : _greyDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
            ],
          );
        }),
      ),
    );
  }

  // ── SECTION HEADER ────────────────────────────────────────────────────────
  Widget _sectionHeader(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _white06,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Icon(icon, color: _white70, size: 15),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        color: _white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Text(desc,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: _greyDark, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ARTIST SEARCH ─────────────────────────────────────────────────────────
  Widget _buildArtistSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Main Artist (Primary)', required: true),
        const SizedBox(height: 6),
        CompositedTransformTarget(
          link: _artistLayerLink,
          child: Container(
            decoration: BoxDecoration(
              color: _input,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color:
                  _artistFocus.hasFocus ? _borderFocus : _border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedArtists.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedArtists
                        .asMap()
                        .entries
                        .map((e) => _artistPill(e.value, e.key))
                        .toList(),
                  ),
                if (_selectedArtists.isNotEmpty) const SizedBox(height: 8),
                TextField(
                  controller: _artistCtrl,
                  focusNode: _artistFocus,
                  style: GoogleFonts.inter(color: _white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _selectedArtists.isEmpty
                        ? 'Search artist on Apple Music…'
                        : 'Add another artist…',
                    hintStyle:
                    GoogleFonts.inter(color: _greyDark, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 4),
                  ),
                  onChanged: _onArtistInput,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text('Results pulled from Apple Music',
            style: GoogleFonts.inter(color: _greyDark, fontSize: 11)),
      ],
    );
  }

  Widget _artistPill(ArtistResult a, int idx) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: _white10,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _white20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: _white20,
            backgroundImage: a.imageUrl.isNotEmpty
                ? NetworkImage(a.imageUrl)
                : null,
            child: a.imageUrl.isEmpty
                ? Text(a.name[0].toUpperCase(),
                style: GoogleFonts.outfit(
                    color: _white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(a.name,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    color: _white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _selectedArtists.removeAt(idx)),
            child: const Icon(Icons.close_rounded, color: _grey, size: 13),
          ),
        ],
      ),
    );
  }

  // ── FEATURED & SECONDARY ARTISTS PANEL (NEW) ──────────────────────────────
  Widget _buildFeaturedArtistsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Search Artist'),
        const SizedBox(height: 6),
        CompositedTransformTarget(
          link: _featArtistLayerLink,
          child: Container(
            decoration: BoxDecoration(
              color: _input,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _featArtistFocus.hasFocus ? _borderFocus : _border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _featArtistCtrl,
              focusNode: _featArtistFocus,
              style: GoogleFonts.inter(color: _white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search artist on Apple Music…',
                hintStyle: GoogleFonts.inter(color: _greyDark, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: _onFeatArtistInput,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text('Results pulled from Apple Music',
            style: GoogleFonts.inter(color: _greyDark, fontSize: 11)),
        if (_featuredArtists.isNotEmpty) ...[
          const SizedBox(height: 14),
          ..._featuredArtists.asMap().entries.map(
                  (e) => _featuredArtistCard(e.value, e.key)),
        ],
      ],
    );
  }

  Widget _featuredArtistCard(_FeaturedArtistEntry entry, int idx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF222222),
                backgroundImage: entry.artist.imageUrl.isNotEmpty
                    ? NetworkImage(entry.artist.imageUrl)
                    : null,
                child: entry.artist.imageUrl.isEmpty
                    ? Text(
                    entry.artist.name.isNotEmpty
                        ? entry.artist.name[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.outfit(
                        color: _white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(entry.artist.name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: _white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              GestureDetector(
                onTap: () => setState(() => _featuredArtists.removeAt(idx)),
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0x18F87171),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: const Color(0x33F87171)),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: _red, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
                color: _input,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border)),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: entry.role,
                isExpanded: true,
                dropdownColor: const Color(0xFF171717),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: _grey, size: 16),
                style: GoogleFonts.inter(color: _white, fontSize: 13),
                items: _featuredRoleOptions
                    .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(
                        () => entry.role = v ?? 'Featuring Artist'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _input,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                _MiniBrandIcon(
                    url: _spotifyIconUrl,
                    fallbackIcon: Icons.music_note_rounded),
                const SizedBox(width: 6),
                _MiniBrandIcon(
                    url: _appleMusicIconUrl,
                    fallbackIcon: Icons.apple_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (v) => entry.url = v,
                    style: GoogleFonts.inter(color: _white, fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Paste Spotify or Apple Music link (optional)',
                      hintStyle:
                      GoogleFonts.inter(color: _greyDark, fontSize: 12),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── COUNTRY ROW ───────────────────────────────────────────────────────────
  Widget _buildCountryRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _dropdownField('Country of Origin', _country, _countries,
              (v) => setState(() => _country = v!)),
    );
  }

  // ── INPUT FIELD ───────────────────────────────────────────────────────────
  Widget _inputField(
      String label,
      TextEditingController ctrl,
      String hint, {
        bool required = false,
        TextInputType? keyboardType,
        int? maxLength,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, required: required),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLength: maxLength,
          style: GoogleFonts.inter(color: _white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: _greyDark, fontSize: 13),
            counterText: '',
            filled: true,
            fillColor: _input,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _borderFocus)),
          ),
        ),
      ],
    );
  }

  // ── DROPDOWN FIELD ────────────────────────────────────────────────────────
  Widget _dropdownField(
      String label,
      String value,
      List<String> options,
      ValueChanged<String?> onChanged, {
        bool required = false,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, required: required),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _input,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF171717),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: _grey, size: 18),
              style: GoogleFonts.inter(color: _white, fontSize: 14),
              items: options
                  .map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(o, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ── RADIO FIELD ────────────────────────────────────────────────────────────
  Widget _radioField(
      String label,
      String value,
      List<String> options,
      ValueChanged<String> onChanged, {
        bool required = false,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, required: required),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((opt) {
            final selected = value == opt;
            return GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? _white : _input,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected ? _white : _border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 15,
                      color: selected ? _bg : _grey,
                    ),
                    const SizedBox(width: 7),
                    Text(opt,
                        style: GoogleFonts.inter(
                            color: selected ? _bg : _white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── PREVIOUS RELEASE DATE FIELD ─────────────────────────────────────────
  Widget _buildPreviousReleaseDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Previous Release Date', required: true),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: _previousReleaseDate ?? now,
              firstDate: DateTime(1980),
              lastDate: now,
              builder: (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                      primary: _white,
                      onPrimary: _bg,
                      surface: Color(0xFF1A1A1A)),
                ),
                child: child!,
              ),
            );
            if (d != null) setState(() => _previousReleaseDate = d);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: _input,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, color: _grey, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _previousReleaseDate != null
                        ? '${_previousReleaseDate!.day}/${_previousReleaseDate!.month}/${_previousReleaseDate!.year}'
                        : 'Select when it was originally released',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: _previousReleaseDate != null
                            ? _white
                            : _greyDark,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text('Used for prior-release / re-release documentation',
            style: GoogleFonts.inter(color: _greyDark, fontSize: 11)),
      ],
    );
  }

  // ── AGREEMENT CHECK ───────────────────────────────────────────────────────
  Widget _buildAgreementCheck() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: GestureDetector(
        onTap: () => setState(
                () => _originalOwnershipConfirmed = !_originalOwnershipConfirmed),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _originalOwnershipConfirmed ? _white40 : _border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20, height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: _originalOwnershipConfirmed
                      ? _white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: _originalOwnershipConfirmed
                          ? _white
                          : _white40),
                ),
                child: _originalOwnershipConfirmed
                    ? const Icon(Icons.check_rounded,
                    size: 14, color: _bg)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text('OWNERSHIP AGREEMENT',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                  color: _greyDark,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2)),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          width: 5, height: 5,
                          decoration: const BoxDecoration(
                              color: _white40, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'I confirm that this is an original song that I own, or that I hold full legal rights to distribute, and that it does not infringe on any third-party copyrights.',
                      style: GoogleFonts.inter(
                          color: _white70, fontSize: 12.5, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── DATE FIELD (with early-date warning) ──────────────────────────────
  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Release Date', required: true),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _releaseDate ??
                  DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 730)),
              builder: (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                      primary: _white,
                      onPrimary: _bg,
                      surface: Color(0xFF1A1A1A)),
                ),
                child: child!,
              ),
            );
            if (d != null) {
              setState(() => _releaseDate = d);
              final daysUntil = d.difference(DateTime.now()).inDays;
              if (daysUntil < 5 && mounted) {
                _showEarlyDateWarning();
              }
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: _input,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: _grey, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _releaseDate != null
                        ? '${_releaseDate!.day}/${_releaseDate!.month}/${_releaseDate!.year}'
                        : 'Select release date',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: _releaseDate != null ? _white : _greyDark,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── CREDITS PANEL ─────────────────────────────────────────────────────────
  Widget _buildCreditsPanel(
      String type,
      String title,
      IconData icon,
      List<String> roles, {
        bool showIpi    = false,
        bool required   = false,
      }) {
    final list = _credits[type]!;
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _white70, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        color: _white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3)),
              ),
              if (required)
                Container(
                  width: 5, height: 5,
                  decoration: const BoxDecoration(
                      color: _white40, shape: BoxShape.circle),
                ),
            ],
          ),
          if (list.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...list
                .asMap()
                .entries
                .map((e) =>
                _creditRow(type, e.key, e.value, roles, showIpi)),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _addCredit(type),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: _grey, size: 14),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'Add ${title.split('&').first.trim()}',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          color: _grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _creditRow(String type, int idx, CreditEntry entry,
      List<String> roles, bool showIpi) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => entry.name = v,
                  style: GoogleFonts.inter(color: _white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Full name',
                    hintStyle:
                    GoogleFonts.inter(color: _greyDark, fontSize: 13),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _removeCredit(type, idx),
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0x18F87171),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: const Color(0x33F87171)),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: _red, size: 12),
                ),
              ),
            ],
          ),
          Container(
              height: 1,
              color: _border,
              margin: const EdgeInsets.symmetric(vertical: 8)),
          Container(
            decoration: BoxDecoration(
                color: _input,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border)),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: entry.role.isEmpty ? null : entry.role,
                isExpanded: true,
                hint: Text('Select role…',
                    style:
                    GoogleFonts.inter(color: _greyDark, fontSize: 13)),
                dropdownColor: const Color(0xFF171717),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: _grey, size: 16),
                style: GoogleFonts.inter(color: _white, fontSize: 13),
                items: roles
                    .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => entry.role = v ?? ''),
              ),
            ),
          ),
          if (showIpi) ...[
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => entry.ipi = v,
              style: GoogleFonts.inter(color: _white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'IPI / CAE Number (optional)',
                hintStyle:
                GoogleFonts.inter(color: _greyDark, fontSize: 13),
                filled: true,
                fillColor: _input,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _borderFocus)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── LYRICS ────────────────────────────────────────────────────────────────
  Widget _buildLyricsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Lyrics (Optional)'),
        const SizedBox(height: 6),
        TextField(
          controller: _lyricsCtrl,
          maxLines: 6,
          style: GoogleFonts.inter(color: _white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Paste your lyrics here…',
            hintStyle:
            GoogleFonts.inter(color: _greyDark, fontSize: 14),
            filled: true,
            fillColor: _input,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _borderFocus)),
          ),
        ),
      ],
    );
  }

  // ── SUBMIT BUTTON ─────────────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _submitting ? null : _submit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: _submitting ? _surface : _white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _submitting ? _border : _white),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _submitting
              ? [
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(_grey)),
            ),
            const SizedBox(width: 10),
            Text('Submitting…',
                style: GoogleFonts.outfit(
                    color: _grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]
              : [
            const Icon(Icons.arrow_forward_rounded,
                color: _bg, size: 17),
            const SizedBox(width: 9),
            Flexible(
              child: Text('SAVE & CONTINUE TO STORES',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      color: _bg,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0)),
            ),
          ],
        ),
      ),
    );
  }

  // ── TRUST STRIP ───────────────────────────────────────────────────────────
  Widget _buildTrustStrip() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 10,
      children: [
        _trustItem(Icons.lock_outline_rounded, '256-bit SSL'),
        _trustItem(Icons.shield_outlined, 'GDPR Compliant'),
        _trustItem(Icons.verified_outlined, 'Secure Data'),
      ],
    );
  }

  Widget _trustItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _greyDark, size: 12),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.inter(color: _greyDark, fontSize: 11)),
      ],
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  Widget _fieldLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Flexible(
          child: Text(label.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  color: _greyDark,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
        ),
        if (required) ...[
          const SizedBox(width: 5),
          Container(
            width: 5, height: 5,
            decoration:
            const BoxDecoration(color: _white40, shape: BoxShape.circle),
          ),
        ],
      ],
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.asMap().entries.map((e) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key > 0 ? 12 : 0),
            child: e.value,
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  MINI BRAND ICON — small SVG icon with a safe fallback if the CDN fails
// ════════════════════════════════════════════════════════════════════════════
class _MiniBrandIcon extends StatelessWidget {
  final String url;
  final IconData fallbackIcon;
  const _MiniBrandIcon({required this.url, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: Builder(
        builder: (ctx) {
          try {
            return SvgPicture.network(
              url,
              placeholderBuilder: (_) =>
                  Icon(fallbackIcon, size: 14, color: _grey),
            );
          } catch (_) {
            return Icon(fallbackIcon, size: 14, color: _grey);
          }
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ARTIST DROPDOWN OVERLAY (shared by Main and Featured artist search)
// ════════════════════════════════════════════════════════════════════════════
class _ArtistDropdown extends StatelessWidget {
  final LayerLink              link;
  final List<ArtistResult>     results;
  final bool                   searching;
  final String                 query;
  final ValueChanged<ArtistResult> onSelect;
  final ValueChanged<String>   onAddNew;

  const _ArtistDropdown({
    required this.link,
    required this.results,
    required this.searching,
    required this.query,
    required this.onSelect,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      width: MediaQuery.of(context).size.width - 40,
      child: CompositedTransformFollower(
        link: link,
        showWhenUnlinked: false,
        offset: const Offset(0, 4),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: const Color(0xFF171717),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x33FFFFFF)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xCC000000),
                    blurRadius: 40,
                    offset: Offset(0, 10))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: searching
                  ? Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                          AlwaysStoppedAnimation(_grey)),
                    ),
                    const SizedBox(width: 10),
                    Text('Searching…',
                        style: GoogleFonts.inter(
                            color: _grey, fontSize: 13)),
                  ],
                ),
              )
                  : ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  if (results.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          14, 10, 14, 6),
                      child: Text('FOUND ON APPLE MUSIC',
                          style: GoogleFonts.outfit(
                              color: _greyDark,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2)),
                    ),
                    ...results.map((a) => _artistOption(a)),
                    Container(
                        height: 1,
                        color: const Color(0x1AFFFFFF)),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        14, 10, 14, 6),
                    child: Text('NOT LISTED?',
                        style: GoogleFonts.outfit(
                            color: _greyDark,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ),
                  _addNewOption(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _artistOption(ArtistResult a) {
    return InkWell(
      onTap: () => onSelect(a),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF222222),
              backgroundImage: a.imageUrl.isNotEmpty
                  ? NetworkImage(a.imageUrl)
                  : null,
              child: a.imageUrl.isEmpty
                  ? Text(a.name[0].toUpperCase(),
                  style: GoogleFonts.outfit(
                      color: _white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: _white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  if (a.genre.isNotEmpty)
                    Text(a.genre,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: _grey, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Text('Apple Music',
                  style: GoogleFonts.outfit(
                      color: _grey,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addNewOption() {
    return InkWell(
      onTap: () => onAddNew(query),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: const Icon(Icons.add_rounded,
                  color: _white70, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add "$query" as new artist',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: _white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  Text('Type your name exactly as it appears on stores',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: _grey, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Text('New',
                  style: GoogleFonts.outfit(
                      color: _white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}