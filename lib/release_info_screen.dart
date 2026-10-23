// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — New Release · Step 1 "Release info" (App)
//  Rebuilt to mirror the web release-info page 1:1 — iOS look,
//  same fields, same required rules, same validation order, same
//  genre / sub-genre logic, same lock rules, same saved data.
// ═══════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode, CupertinoTheme, CupertinoThemeData, CupertinoTextThemeData;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── PALETTE (same tokens as the web) ───────────────────────────────
const _bg     = Color(0xFF000000);
const _s1     = Color(0xFF1C1C1E);
const _s2     = Color(0xFF2C2C2E);
const _s3     = Color(0xFF636366);
const _sep    = Color(0x8C545458);
const _fill   = Color(0x3D787880);
const _t1     = Color(0xFFFFFFFF);
const _t2     = Color(0x99EBEBF5);
const _t3     = Color(0x4DEBEBF5);
const _blue   = Color(0xFF0A84FF);
const _yellow = Color(0xFFFDEB0D);
const _green  = Color(0xFF30D158);
const _rose   = Color(0xFFFF453A);

// ─── TYPOGRAPHY — SF on iOS, Inter elsewhere (web font stack) ───────
bool get _isApple =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

TextStyle _ts(double size, FontWeight w, Color c,
    {double em = -0.01, double? height}) {
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

// ─── CREDITS MODEL ──────────────────────────────────────────────────
class CreditEntry {
  String name;
  String role;
  String ipi;
  bool autofocus;
  CreditEntry({this.name = '', this.role = '', this.ipi = '', this.autofocus = false});
}

// ─── CONSTANTS (identical to the web lists) ─────────────────────────
const _releaseTypes = ['Single', 'EP', 'Album'];

const Map<String, List<String>> _genreSubs = {
  'Pop': ['Synth-Pop','Electropop','Indie Pop','Dream Pop','Art Pop','Dance Pop','Teen Pop'],
  'Rock': ['Alternative','Progressive','Psychedelic','Post-Rock','Garage','Grunge','Punk Rock'],
  'Hip-Hop/Rap': ['Hip-Hop','Rap','Boom Bap','Cloud Rap','Conscious','Gangsta','Lo-Fi Hip-Hop','Trap Rap','Drill Rap','Mumble Rap'],
  'R&B': ['Neo-Soul','Contemporary R&B','Quiet Storm','New Jack Swing'],
  'Electronic': ['Ambient','Dubstep','Drum & Bass','IDM','Trance','Deep House','Progressive House'],
  'Jazz': ['Smooth Jazz','Bebop','Cool Jazz','Free Jazz','Fusion'],
  'Classical': ['Baroque','Romantic','Modern Classical','Orchestral','Chamber Music'],
  'Country': ['Country Pop','Alt-Country','Bluegrass','Outlaw Country'],
  'Latin': ['Salsa','Bachata','Cumbia','Latin Pop','Latin Trap'],
  'Reggaeton': ['Reggaeton Romantico','Perreo','Dembow'],
  'K-Pop': ['K-Pop Boy Group','K-Pop Girl Group','K-R&B','K-Hip-Hop'],
  'Indie': ['Indie Rock','Indie Pop','Indie Folk','Indie Electronic'],
  'Metal': ['Heavy Metal','Death Metal','Black Metal','Nu Metal','Metalcore'],
  'Punk': ['Pop Punk','Hardcore','Post-Punk','Ska Punk'],
  'Blues': ['Delta Blues','Chicago Blues','Electric Blues','Blues Rock'],
  'Soul': ['Northern Soul','Southern Soul','Neo-Soul'],
  'Funk': ['P-Funk','Electro Funk','Go-Go'],
  'Disco': [],
  'House': ['Deep House','Tech House','Progressive House','Acid House'],
  'Techno': ['Minimal Techno','Detroit Techno','Industrial Techno'],
  'Trap': ['Trap','Melodic Trap','Hard Trap','Phonk'],
  'Drill': ['UK Drill','NY Drill','Chicago Drill'],
  'Afrobeat': ['Afrobeats','Afro-Pop','Afro-Swing','Amapiano'],
  'Dancehall': ['Dancehall','Bashment','Soca'],
  'Folk': ['Folk Rock','Acoustic Folk','Neo-Folk','World Folk'],
  'Other': [],
};

const _languages = [
  'Русский','English','Español','Français','Deutsch','Italiano','Português','日本語',
  '한국어','中文','العربية','हिन्दी','Türkçe','Nederlands','Polski','Svenska',
  'Norsk','Suomi','Dansk','Čeština','Română','Magyar','Ελληνικά','Українська',
  "O'zbek",'Қазақ','தமிழ்','తెలుగు','ไทย','Tiếng Việt','Bahasa Indonesia','Bahasa Melayu',
  'Filipino','Kiswahili','Other',
];

const _versionOptions = [
  'Original','Radio Edit','Extended Mix','Remix','Acoustic','Live','Instrumental',
  'Remastered','Cover','Sped Up','Slowed','Other',
];

const _countries = [
  'Ghana','Nigeria','Kenya','South Africa','Uganda','Tanzania','Cameroon',
  'United States of America','United Kingdom, The','Canada','Australia','France',
  'Germany','Brazil','India','Jamaica','Trinidad and Tobago','Senegal','Ethiopia',
  'Zimbabwe','Other',
];

const Map<String, List<String>> _roles = {
  'producer': ['Producer','Executive Producer','Co-Producer','Beat Maker','Mixing Engineer','Mastering Engineer','Recording Engineer','Vocal Producer','Sound Designer','Re-mixer','Programmer','Audio Editor'],
  'musician': ['Vocalist','Background Vocalist','Lead Vocalist','Rapper','Guitarist','Bassist','Drummer','Pianist','Keyboardist','DJ / Turntablist','Session Musician','String Arranger'],
  'writer':   ['Songwriter','Lyricist','Composer','Co-Writer','Melody Writer','Arranger','Top-Liner','Concept Writer'],
  'publishing': ['Publisher','Co-Publisher','Administrator'],
};
const Map<String, String> _namePlaceholder = {
  'producer': 'Full name, e.g. Metro Boomin',
  'musician': 'Full name, e.g. John Mayer',
  'writer': 'Full name, e.g. John Doe',
  'publishing': 'Publisher name',
};
const Map<String, String> _noun = {
  'producer': 'Producer', 'musician': 'Musician', 'writer': 'Songwriter', 'publishing': 'Publisher',
};
const Map<String, String> _typeLabel = {
  'main': 'Main', 'featured': 'Featured', 'secondary': 'Secondary',
};

const _notifyUrl = 'https://four44music-broadcast-backend.onrender.com/api/submissions/notify';
const _appSecret = 'e993b17f0762667e27d5298839dacff4a7409bb74e11e9ecaf0bb2bb647120a8';

// ─── SMALL HELPERS ──────────────────────────────────────────────────
String _two(int n) => n.toString().padLeft(2, '0');
String _fmtDmy(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}
String _toIso(DateTime? d) => d == null ? '' : DateTime.utc(d.year, d.month, d.day).toIso8601String();

String _makeCatalogNumber() {
  final t = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
  final tail = t.substring(max(0, t.length - 5));
  const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final r = Random();
  return '444M-$tail${chars[r.nextInt(36)]}${chars[r.nextInt(36)]}';
}

List<String> _badNameChars(String s) {
  final out = <String>[];
  for (final m in RegExp(r'[,<>{}\[\]"]').allMatches(s)) {
    final c = m.group(0)!;
    if (!out.contains(c)) out.add(c);
  }
  int depth = 0;
  bool broken = false;
  for (final ch in s.split('')) {
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
      if (depth < 0) { broken = true; break; }
    }
  }
  if (broken || depth != 0) out.add('OPEN');
  return out;
}

String _nameMsg(String name, List<String> bad) {
  final chars = bad.where((x) => x != 'OPEN').toList();
  final parts = <String>[];
  if (chars.isNotEmpty) parts.add("can't contain ${chars.join(' ')}");
  if (bad.contains('OPEN')) parts.add('has a bracket ( ) that is not closed');
  final tail = bad.contains(',') ? ' Add each artist separately instead of using commas.' : '';
  return 'Artist name "$name" ${parts.join(' and ')}.$tail';
}

class _VErr {
  final String msg, id;
  const _VErr(this.msg, this.id);
}

class _Opt {
  final String value, label;
  final bool disabled;
  const _Opt(this.value, this.label, {this.disabled = false});
}

class _Pick {
  final String value;
  const _Pick(this.value);
}

// ════════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════════
class ReleaseInfoScreen extends StatefulWidget {
  const ReleaseInfoScreen({super.key});

  @override
  State<ReleaseInfoScreen> createState() => _ReleaseInfoScreenState();
}

class _ReleaseInfoScreenState extends State<ReleaseInfoScreen> {
  // controllers
  final _titleCtrl       = TextEditingController();
  final _copyrightCtrl   = TextEditingController();
  final _copyrightConfirmCtrl = TextEditingController();
  final _isrcCtrl        = TextEditingController();
  final _upcCtrl         = TextEditingController();
  final _catalogCtrl     = TextEditingController();
  final _labelCtrl       = TextEditingController(text: '444Music Distribution');
  final _lyricsCtrl      = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _productVersionCtrl = TextEditingController();
  final _scrollCtrl      = ScrollController();
  late final TapGestureRecognizer _backLinkTap;

  // selects
  String _releaseType = 'Single';
  String _genre       = '';
  String _genreSub    = '';
  String _altGenre    = '';
  String _altGenreSub = '';
  String _language    = '';
  String _explicit    = 'No';
  String _version     = 'Original';
  String _country     = 'Ghana';
  DateTime? _releaseDate;
  DateTime? _previousReleaseDate;

  // radio groups (same defaults as web)
  final Map<String, String> _v = {
    'vocal': 'Vocals',
    'prev': 'No',
    'original': 'Yes',
    'publicDomain': 'No',
    'compilation': 'No',
    'license': 'Yes',
    'broadcast': 'Yes',
    'agSoundExchange': 'Yes',
    'agYoutubeMusic': 'Yes',
    'agContentId': 'Yes',
    'agFacebook': 'Yes',
    'agTiktok': 'Yes',
    'agLicensing': 'Yes',
    'agAvvoYoutube': 'Yes',
  };
  final Map<String, String> _savedLock = {};
  static const _lockIds = ['agContentId', 'agFacebook', 'agTiktok'];

  bool _ownershipConfirmed = false;

  // payment + upload sync
  String? _paymentReference;
  bool _paymentVerified = false;
  bool _argsLoaded = false;
  String? _coverUrl;
  List<Map<String, dynamic>> _audioFiles = [];

  final Map<String, List<CreditEntry>> _credits = {
    'producer': [CreditEntry()],
    'musician': [],
    'writer': [CreditEntry()],
    'publishing': [CreditEntry()],
  };

  // submit state
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  String _btnLabel = 'Continue to stores';
  String _statusMsg = '';
  String _statusKind = '';
  String? _invalid;

  final Map<String, GlobalKey> _keys = {};
  GlobalKey _k(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _bg,
    ));
    _backLinkTap = TapGestureRecognizer()..onTap = () => Navigator.pop(context);
    _catalogCtrl.text = _makeCatalogNumber();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && FirebaseAuth.instance.currentUser == null) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final ref = args['paymentReference'];
      if (ref is String && ref.isNotEmpty) {
        _paymentReference = ref;
        _verifyPayment(ref);
      }
      final cover = args['coverUrl'];
      if (cover is String && cover.isNotEmpty) _coverUrl = cover;

      final audio = args['audioFiles'];
      if (audio is List) {
        _audioFiles = audio.whereType<Map>().map((m) {
          final artists = <Map<String, String>>[];
          final raw = m['artists'];
          if (raw is List) {
            for (final a in raw) {
              if (a is Map) {
                artists.add({
                  'name':       (a['name'] ?? '').toString(),
                  'type':       (a['type'] ?? 'featured').toString(),
                  'spotifyUrl': (a['spotifyUrl'] ?? '').toString(),
                  'appleUrl':   (a['appleUrl'] ?? '').toString(),
                });
              }
            }
          }
          return <String, dynamic>{
            'title':   (m['title'] ?? '').toString(),
            'url':     (m['url'] ?? '').toString(),
            'artists': artists,
          };
        }).where((m) => (m['url'] as String).isNotEmpty).toList();
      }
    } else if (args is String && args.isNotEmpty) {
      _paymentReference = args;
      _verifyPayment(args);
    }

    // Same as web applyUploadSync(): prefill title for a single track
    if (_audioFiles.length == 1) {
      final t = (_audioFiles.first['title'] as String).trim();
      if (t.isNotEmpty && _titleCtrl.text.isEmpty) _titleCtrl.text = t;
    }
    // One track → Single (locked). Two or more → EP/Album only.
    if (_audioFiles.length == 1) {
      _releaseType = 'Single';
    } else if (_audioFiles.length > 1) {
      _releaseType = 'EP';
    }
    _argsLoaded = true;
  }

  Future<void> _verifyPayment(String reference) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('pendingPayments').doc(reference).get();
      if (doc.exists && doc.data()?['paid'] == true) {
        if (mounted) setState(() => _paymentVerified = true);
      }
    } catch (e) {
      debugPrint('[Payment verify] ERROR: $e');
    }
  }

  @override
  void dispose() {
    _backLinkTap.dispose();
    _scrollCtrl.dispose();
    for (final c in [
      _titleCtrl, _copyrightCtrl, _copyrightConfirmCtrl, _isrcCtrl, _upcCtrl,
      _catalogCtrl, _labelCtrl, _lyricsCtrl, _emailCtrl, _productVersionCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── DERIVED ──────────────────────────────────────────────────────────
  List<String> get _mainArtistNames {
    final names = <String>[];
    for (final t in _audioFiles) {
      for (final a in (t['artists'] as List<Map<String, String>>)) {
        final n = a['name'] ?? '';
        if (a['type'] == 'main' && n.isNotEmpty && !names.any((x) => x.toLowerCase() == n.toLowerCase())) {
          names.add(n);
        }
      }
    }
    return names;
  }

  String _formatFeaturingForEmail() {
    final lines = <String>[];
    for (int i = 0; i < _audioFiles.length; i++) {
      final t = _audioFiles[i];
      final others = (t['artists'] as List<Map<String, String>>).where((a) => a['type'] != 'main').toList();
      if (others.isEmpty) continue;
      final title = t['title'] as String;
      final names = others.map((a) => '${a['name']} (${_typeLabel[a['type']] ?? a['type']})').join(', ');
      lines.add('Track ${i + 1}${title.isNotEmpty ? ' — $title' : ''}: $names');
    }
    return lines.isEmpty ? 'None' : lines.join('\n');
  }

  List<Map<String, dynamic>> _emailArtistsPayload() {
    return _audioFiles.map((t) => {
          'track': t['title'] ?? '',
          'artists': (t['artists'] as List<Map<String, String>>).map((a) => {
                'name': a['name'] ?? '',
                'type': a['type'] ?? 'featured',
                'spotifyUrl': a['spotifyUrl'] ?? '',
                'appleUrl': a['appleUrl'] ?? '',
              }).toList(),
        }).toList();
  }

  String _formatCredits(List<CreditEntry> list) {
    final lines = list.where((c) => c.name.trim().isNotEmpty).map((c) {
      var line = '• ${c.name}';
      if (c.role.isNotEmpty) line += ' — ${c.role}';
      if (c.ipi.isNotEmpty) line += ' (IPI: ${c.ipi})';
      return line;
    }).toList();
    return lines.isEmpty ? 'None' : lines.join('\n');
  }

  Map<String, List<Map<String, String>>> _collectCredits() {
    final out = <String, List<Map<String, String>>>{};
    for (final type in ['producer', 'musician', 'writer', 'publishing']) {
      out[type] = _credits[type]!
          .where((c) => c.name.trim().isNotEmpty)
          .map((c) => {'name': c.name, 'role': c.role, 'ipi': c.ipi})
          .toList();
    }
    return out;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
  }

  // ── GENRE LOGIC (same as web GENRE LISTS ENGINE) ─────────────────────
  List<String> get _subList => _genreSubs[_genre] ?? const [];
  List<String> get _altOptions => _genreSubs.keys.where((x) => x != _genre).toList();
  List<String> get _altSubList => _genreSubs[_altGenre] ?? const [];

  void _onGenre(String v) {
    setState(() {
      _genre = v;
      _genreSub = '';
      if (_altGenre == v) _altGenre = '';
      if (!_altSubList.contains(_altGenreSub)) _altGenreSub = '';
    });
  }

  void _onAlt(String v) {
    setState(() {
      _altGenre = v;
      if (!_altSubList.contains(_altGenreSub)) _altGenreSub = '';
    });
  }

  // ── COVER / COMPILATION RULE (same as web) ───────────────────────────
  bool get _forceNo =>
      _v['publicDomain'] != 'No' ||
      _v['compilation'] == 'Yes' ||
      _v['original'] == 'No' ||
      _version == 'Cover';

  void _applyLock() {
    final force = _forceNo;
    for (final id in _lockIds) {
      if (force) {
        if (!_savedLock.containsKey(id)) _savedLock[id] = _v[id]!;
        _v[id] = 'No';
      } else if (_savedLock.containsKey(id)) {
        _v[id] = _savedLock.remove(id)!;
      }
    }
  }

  void _setV(String key, String value) {
    setState(() {
      _v[key] = value;
      if (key == 'prev' && value != 'Yes') _previousReleaseDate = null;
      _applyLock();
    });
  }

  // ── PICKERS ──────────────────────────────────────────────────────────
  Future<_Pick?> _pickOption(String title, List<_Opt> opts, String current) {
    FocusScope.of(context).unfocus();
    return showModalBottomSheet<_Pick>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _PickerSheet(title: title, opts: opts, current: current),
    );
  }

  Future<DateTime?> _pickDate(String title, DateTime min, DateTime max, DateTime initial) {
    FocusScope.of(context).unfocus();
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _DateSheet(title: title, min: min, max: max, initial: initial),
    );
  }

  Future<void> _pickReleaseDate() async {
    final today = _today();
    final min = DateTime(today.year, today.month, today.day + 3);
    final max = DateTime(today.year + 5, today.month, today.day);
    final init = (_releaseDate != null && !_releaseDate!.isBefore(min)) ? _releaseDate! : min;
    final d = await _pickDate('Release date', min, max, init);
    if (d == null || !mounted) return;
    final diff = (d.difference(today).inHours / 24).round();
    setState(() => _releaseDate = diff < 3 ? null : d);
    if (diff < 5) _showDateAdvice();
  }

  Future<void> _showDateAdvice() async {
    final change = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const _IosAlert(
        title: 'Pick a later date?',
        message: 'The earliest release date is 3 days from today. We recommend 5 days or more so stores have time to go live.',
        cancelLabel: 'Keep date',
        confirmLabel: 'Change date',
      ),
    );
    if (change == true && mounted) _pickReleaseDate();
  }

  Future<void> _pickPreviousDate() async {
    final today = _today();
    final d = await _pickDate('Original date', DateTime(1900), today, _previousReleaseDate ?? today);
    if (d != null && mounted) setState(() => _previousReleaseDate = d);
  }

  // ── CREDITS ──────────────────────────────────────────────────────────
  void _addCredit(String type) {
    setState(() => _credits[type]!.add(CreditEntry(autofocus: true)));
  }

  void _removeCredit(String type, CreditEntry e) {
    setState(() => _credits[type]!.remove(e));
  }

  Future<void> _pickRole(String type, CreditEntry e) async {
    final opts = _roles[type]!.map((r) => _Opt(r, r)).toList();
    final p = await _pickOption('Role', opts, e.role);
    if (p != null && mounted) setState(() => e.role = p.value);
  }

  // ── VALIDATION (same order + messages as web validate()) ─────────────
  _VErr? _validate() {
    final artistName = _mainArtistNames.join(', ');
    if (artistName.isEmpty) {
      return const _VErr('No Main artist found from your upload. Go back to Upload Files and tag one.', 'mainArtistWrap');
    }
    for (final t in _audioFiles) {
      for (final a in (t['artists'] as List<Map<String, String>>)) {
        final bad = _badNameChars(a['name'] ?? '');
        if (bad.isNotEmpty) {
          return _VErr('${_nameMsg(a['name'] ?? '', bad)} Go back to Upload Files and fix it.', 'mainArtistWrap');
        }
      }
    }
    if (_titleCtrl.text.trim().isEmpty) return const _VErr('Please enter a release title.', 'releaseTitle');

    if (_genre.isEmpty) return const _VErr('Please select a genre.', 'genre');
    if (_subList.isNotEmpty && _genreSub.isEmpty) {
      return const _VErr('Please select a sub genre for your genre.', 'genreSub');
    }
    if (_language.isEmpty) return const _VErr('Please select a language.', 'language');

    if (_releaseDate == null) return const _VErr('Please choose a release date.', 'releaseDate');
    final today = _today();
    final minDate = DateTime(today.year, today.month, today.day + 3);
    if (_releaseDate!.isBefore(minDate)) {
      return const _VErr('The earliest release date is 3 days from today.', 'releaseDate');
    }

    if (_v['prev'] == 'Yes' && _previousReleaseDate == null) {
      return const _VErr('Please choose the original release date.', 'previousReleaseDateWrap');
    }

    final copyright = _copyrightCtrl.text.trim();
    if (copyright.isEmpty) return const _VErr('Please enter the copyright holder.', 'copyright');
    final confirm = _copyrightConfirmCtrl.text.trim();
    if (confirm.isEmpty) return const _VErr('Please type the copyright holder again to confirm it.', 'copyrightConfirm');
    if (copyright != confirm) return const _VErr("The two copyright holder entries don't match.", 'copyrightConfirm');

    bool filled(CreditEntry c) => c.name.trim().isNotEmpty;
    if (!_credits['producer']!.any(filled)) return const _VErr('Please add at least one producer.', 'producerList');

    final writers = _credits['writer']!.where(filled).toList();
    if (writers.isEmpty) return const _VErr('Please add at least one songwriter.', 'writerList');
    bool wLyric(CreditEntry w) => RegExp(r'lyric|author|word').hasMatch(w.role.toLowerCase());
    bool wComp(CreditEntry w) => RegExp(r'compos|music|melod').hasMatch(w.role.toLowerCase());
    if (!writers.any((w) => wLyric(w) || !wComp(w))) {
      return const _VErr('Add at least one lyricist or songwriter .', 'writerList');
    }
    if (!writers.any((w) => wComp(w) || !wLyric(w))) {
      return const _VErr('Add at least one composer or songwriter (AVVO needs a composer).', 'writerList');
    }

    if (!_credits['publishing']!.any(filled)) return const _VErr('Please add at least one publisher.', 'publishingList');

    if (!_ownershipConfirmed) return const _VErr('Please confirm the ownership statement.', 'agreementBox');

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return const _VErr('Please enter your email address.', 'email');
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) return const _VErr('Please enter a valid email address.', 'email');

    return null;
  }

  void _scrollToId(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      }
    });
  }

  // ── EMAIL / NOTIFY ───────────────────────────────────────────────────
  Future<void> _sendEmails(Map<String, dynamic> data) async {
    String orElse(dynamic v, String fallback) => (v ?? '').toString().isEmpty ? fallback : v.toString();
    final params = {
      'email':          data['email'],
      'artist_name':    data['artistName'],
      'featuring':      _formatFeaturingForEmail(),
      'release_title':  data['releaseTitle'],
      'release_type':   data['releaseType'],
      'genre':          data['genre'],
      'language':       orElse(data['language'], 'Not specified'),
      'release_date':   orElse(data['releaseDate'], 'Not set'),
      'explicit':       data['explicit'],
      'country':        data['country'],
      'phone':          orElse(data['phone'], 'Not provided'),
      'label':          orElse(data['label'], 'Independent'),
      'copyright':      orElse(data['copyright'], 'Not provided'),
      'isrc':           orElse(data['isrc'], 'Not provided'),
      'upc':            orElse(data['upc'], 'Auto-assign'),
      'catalog_number': orElse(data['catalogNumber'], 'Not provided'),
      'version':                data['version'],
      'previously_released':    data['previouslyReleased'],
      'previous_release_date':  orElse(data['previousReleaseDate'], 'N/A'),
      'vocal_type':             data['vocalType'],
      'ownership_confirmed':    data['ownershipConfirmed'] == true ? 'Yes — confirmed original work' : 'Not confirmed',
      'producers':      _formatCredits(_credits['producer']!),
      'musicians':      _formatCredits(_credits['musician']!),
      'songwriters':    _formatCredits(_credits['writer']!),
      'publishers':     _formatCredits(_credits['publishing']!),
      'lyrics':         orElse(data['lyrics'], 'Not provided'),
      'submitted_at':   DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int).toLocal().toString(),
      'status':         data['status'],
      'payment_status': _paymentVerified ? 'Paid' : 'Not confirmed',
      'cover_url':      data['coverURL'] ?? '',
      'audio_files':    data['audioFiles'] ?? [],
    };
    try {
      final res = await http
          .post(
            Uri.parse(_notifyUrl),
            headers: {'Content-Type': 'application/json', 'x-app-secret': _appSecret},
            body: jsonEncode(params),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode > 299) {
        debugPrint('[Notify] failed (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      debugPrint('[Notify] ERROR (release was still saved): $e');
    }
  }

  // ── DUPLICATE GUARD (10 min window, same as web) ─────────────────────
  Future<bool> _hasRecentDuplicate(Map<String, dynamic> data, String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('submissions')
          .where('userId', isEqualTo: uid)
          .get();
      final cutoff = DateTime.now().millisecondsSinceEpoch - 10 * 60 * 1000;
      for (final d in snap.docs) {
        final e = d.data();
        if (e['releaseTitle'] == data['releaseTitle'] &&
            e['artistName'] == data['artistName'] &&
            e['createdAt'] is num &&
            (e['createdAt'] as num) >= cutoff) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('[Duplicate check] ERROR (non-fatal): $e');
    }
    return false;
  }

  Future<void> _claimPayment() async {
    if (_paymentVerified && _paymentReference != null) {
      try {
        await FirebaseFirestore.instance
            .collection('pendingPayments')
            .doc(_paymentReference)
            .update({'claimed': true});
      } catch (e) {
        debugPrint('[Payment claim] ERROR (non-fatal): $e');
      }
    }
  }

  // ── SUBMIT ───────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (_isSubmitting || _hasSubmitted || user == null) return;

    final err = _validate();
    if (err != null) {
      setState(() {
        _statusMsg = err.msg;
        _statusKind = 'error';
        _invalid = err.id;
      });
      _scrollToId(err.id);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _btnLabel = 'Checking…';
      _statusMsg = '';
      _statusKind = '';
      _invalid = null;
    });

    final prev = _v['prev']!;
    final data = <String, dynamic>{
      'artistName':   _mainArtistNames.join(', '),
      'releaseTitle': _titleCtrl.text.trim(),
      'releaseType':  _releaseType,
      'genre':        _genre,
      'country':      _country,
      'language':     _language,
      'releaseDate':  _toIso(_releaseDate),
      'explicit':     _explicit,
      'email':        _emailCtrl.text.trim(),
      'phone':        '',
      'label':        '444Music Distribution',
      'copyright':    _copyrightCtrl.text.trim(),
      'isrc':         _isrcCtrl.text.trim(),
      'upc':          _upcCtrl.text.trim(),
      'catalogNumber': _catalogCtrl.text.trim().isEmpty ? _makeCatalogNumber() : _catalogCtrl.text.trim(),
      'lyrics':       _lyricsCtrl.text.trim(),
      'version':             _version,
      'previouslyReleased':  prev,
      'previousReleaseDate': prev == 'Yes' ? _toIso(_previousReleaseDate) : '',
      'vocalType':           _v['vocal'],
      'mainGenreSub':        _genreSub,
      'alternateGenre':      _altGenre,
      'alternateGenreSub':   _altGenreSub,
      'isOriginal':          _v['original'] == 'Yes',
      'publicDomainStatus':  _v['publicDomain'],
      'isCompilation':       _v['compilation'] == 'Yes',
      'hasLicense':          _v['license'] == 'Yes',
      'hasUsBroadcastRights': _v['broadcast'] == 'Yes',
      'productVersion':      _productVersionCtrl.text.trim(),
      'agreements': {
        'soundexchange':         _v['agSoundExchange'] == 'Yes',
        'youtube_music':         _v['agYoutubeMusic'] == 'Yes',
        'youtube_content_id':    _v['agContentId'] == 'Yes',
        'facebook_monetization': _v['agFacebook'] == 'Yes',
        'tiktok_monetization':   _v['agTiktok'] == 'Yes',
        'licensing':             _v['agLicensing'] == 'Yes',
        'avvo_youtube_channel':  _v['agAvvoYoutube'] == 'Yes',
      },
      'ownershipConfirmed': _ownershipConfirmed,
      'credits':            _collectCredits(),
      'featuredArtists':    _emailArtistsPayload(),
      'paid':               _paymentVerified ? 'Paid' : 'Unpaid',
      'paymentReference':   _paymentReference ?? '',
      'coverURL':           _coverUrl ?? '',
      'officialCoverURL':   _coverUrl ?? '',
      'audioFiles':         _audioFiles,
      'userId':             user.uid,
      'createdAt':          DateTime.now().millisecondsSinceEpoch,
      'status':             _paymentVerified ? 'Review' : 'Pending',
    };

    final duplicate = await _hasRecentDuplicate(data, user.uid);
    if (!mounted) return;
    if (duplicate) {
      _hasSubmitted = true;
      setState(() {
        _btnLabel = 'Already saved';
        _statusMsg = 'This release was already submitted. Redirecting…';
        _statusKind = 'success';
      });
      unawaited(_claimPayment());
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) Navigator.pushNamed(context, '/select');
      });
      return;
    }

    setState(() => _btnLabel = 'Saving…');

    try {
      await FirebaseFirestore.instance.collection('submissions').add(data);
    } catch (e) {
      debugPrint('Submission Error (Firestore save failed): $e');
      if (!mounted) return;
      setState(() {
        _statusMsg = "Couldn't save your release. Check your connection and try again.";
        _statusKind = 'error';
        _isSubmitting = false;
        _btnLabel = 'Continue to stores';
      });
      return;
    }

    _hasSubmitted = true;
    if (mounted) {
      setState(() {
        _btnLabel = 'Saved';
        _statusMsg = 'Saved. Taking you to stores…';
        _statusKind = 'success';
      });
    }
    unawaited(_sendEmails(data));
    unawaited(_claimPayment());
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) Navigator.pushNamed(context, '/select');
    });
  }

  // ══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final narrow = MediaQuery.of(context).size.width <= 420;
    final hasFiles = _audioFiles.isNotEmpty;
    final mainNames = _mainArtistNames;
    final subDisabled = _genre.isEmpty || _subList.isEmpty;
    final typeLocked = _audioFiles.length == 1;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Listener(
            onPointerDown: (_) {
              if (_invalid != null) setState(() => _invalid = null);
            },
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(0, top + 56, 0, 150 + MediaQuery.of(context).padding.bottom),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _hero(narrow),
                        if (_paymentVerified)
                          _note('Payment verified. This release goes straight to review.',
                              Icons.check_circle_outline_rounded, _green, const Color(0x2430D158), _green),
                        if (hasFiles)
                          _note('Artist and track details were synced from your upload.',
                              Icons.check_circle_outline_rounded, _t2, _s1, _t1),

                          // ── ARTIST ────────────────────────────────────
                        _sh('Artist'),
                        _Group(children: [
                          KeyedSubtree(
                            key: _k('mainArtistWrap'),
                            child: _RowShell(
                              invalid: _invalid == 'mainArtistWrap',
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _Lbl('Main artist', invalid: _invalid == 'mainArtistWrap'),
                                  Expanded(
                                    child: !hasFiles
                                        ? const SizedBox.shrink()
                                        : mainNames.isEmpty
                                            ? Text('No Main artist found. Go back and tag one.',
                                                textAlign: TextAlign.right,
                                                style: _ts(14, FontWeight.w400, _rose))
                                            : Wrap(
                                                alignment: WrapAlignment.end,
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: mainNames.map(_artistPill).toList(),
                                              ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]),

                        if (hasFiles) ...[
                          _sh('Artists on each track'),
                          _Group(children: [
                            for (int i = 0; i < _audioFiles.length; i++) _trackCard(_audioFiles[i], i),
                          ]),
                        ],

                        if (!hasFiles)
                          _note("No artist found from your upload. Go back and add at least one Main artist.",
                              Icons.warning_amber_rounded, _rose, const Color(0x24FF453A), _rose),
                        if (hasFiles)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Text.rich(TextSpan(
                              style: _ts(13, FontWeight.w400, _t2, height: 1.4),
                              children: [
                                const TextSpan(text: 'Synced from your upload. To change anything, '),
                                TextSpan(
                                  text: 'go back to Upload Files',
                                  style: _ts(13, FontWeight.w400, _blue, height: 1.4),
                                  recognizer: _backLinkTap,
                                ),
                                const TextSpan(text: '.'),
                              ],
                            )),
                          ),

                        // ── DETAILS ───────────────────────────────────
                        _sh('Details', right: 'Required', req: true),
                        _Group(children: [
                          _InputRow(
                            rowKey: _k('releaseTitle'),
                            label: 'Title', ctrl: _titleCtrl, hint: 'Name of your release',
                            invalid: _invalid == 'releaseTitle',
                          ),
                          _selectRow(
                            id: 'releaseType', label: 'Type', value: _releaseType, placeholder: 'Select',
                            dim: typeLocked,
                            onTap: typeLocked
                                ? null
                                : () async {
                                    final multi = _audioFiles.length > 1;
                                    final p = await _pickOption(
                                      'Type',
                                      _releaseTypes.map((t) => _Opt(t, t, disabled: multi && t == 'Single')).toList(),
                                      _releaseType,
                                    );
                                    if (p != null && mounted) setState(() => _releaseType = p.value);
                                  },
                          ),
                          _selectRow(
                            id: 'genre', label: 'Genre', value: _genre, placeholder: 'Select',
                            onTap: () async {
                              final p = await _pickOption('Genre', _genreSubs.keys.map((g) => _Opt(g, g)).toList(), _genre);
                              if (p != null && mounted) _onGenre(p.value);
                            },
                          ),
                          _selectRow(
                            id: 'genreSub', label: 'Sub genre', value: _genreSub,
                            placeholder: _genre.isEmpty
                                ? 'Pick genre first'
                                : (_subList.isEmpty ? 'Not needed for this genre' : 'Select'),
                            onTap: subDisabled
                                ? null
                                : () async {
                                    final p = await _pickOption('Sub genre', _subList.map((g) => _Opt(g, g)).toList(), _genreSub);
                                    if (p != null && mounted) setState(() => _genreSub = p.value);
                                  },
                          ),
                          _selectRow(
                            id: 'altGenre', label: 'Alt. genre', value: _altGenre, placeholder: 'None (optional)',
                            onTap: () async {
                              final opts = <_Opt>[const _Opt('', 'None (optional)'), ..._altOptions.map((g) => _Opt(g, g))];
                              final p = await _pickOption('Alt. genre', opts, _altGenre);
                              if (p != null && mounted) _onAlt(p.value);
                            },
                          ),
                          if (_altGenre.isNotEmpty && _altSubList.isNotEmpty)
                            _selectRow(
                              id: 'altGenreSub', label: 'Alt. sub genre', value: _altGenreSub, placeholder: 'None (optional)',
                              onTap: () async {
                                final opts = <_Opt>[const _Opt('', 'None (optional)'), ..._altSubList.map((g) => _Opt(g, g))];
                                final p = await _pickOption('Alt. sub genre', opts, _altGenreSub);
                                if (p != null && mounted) setState(() => _altGenreSub = p.value);
                              },
                            ),
                          _selectRow(
                            id: 'language', label: 'Language', value: _language, placeholder: 'Select',
                            onTap: () async {
                              final p = await _pickOption('Language', _languages.map((g) => _Opt(g, g)).toList(), _language);
                              if (p != null && mounted) setState(() => _language = p.value);
                            },
                          ),
                          _selectRow(
                            id: 'explicit', label: 'Explicit', value: _explicit, placeholder: 'Select',
                            onTap: () async {
                              final p = await _pickOption('Explicit', const [_Opt('No', 'No'), _Opt('Yes', 'Yes')], _explicit);
                              if (p != null && mounted) setState(() => _explicit = p.value);
                            },
                          ),
                          _dateRow(
                            id: 'releaseDate', label: 'Release date', value: _releaseDate, onTap: _pickReleaseDate,
                          ),
                        ]),
                        _sf('Earliest date is 3 days from today. 5 days or more is recommended.'),

                        // ── SONG ──────────────────────────────────────
                        _sh('Song', right: 'Required', req: true),
                        _Group(children: [
                          _selectRow(
                            id: 'version', label: 'Version', value: _version, placeholder: 'Select',
                            onTap: () async {
                              final p = await _pickOption('Version', _versionOptions.map((g) => _Opt(g, g)).toList(), _version);
                              if (p != null && mounted) {
                                setState(() { _version = p.value; _applyLock(); });
                              }
                            },
                          ),
                          _segRow('Vocals', 'vocal', const ['Vocals', 'Instrumental'], minW: narrow ? 66 : 78, padH: narrow ? 10 : 14),
                          _segRow('Released before?', 'prev', const ['No', 'Yes'], minW: narrow ? 66 : 78, padH: narrow ? 10 : 14),
                          if (_v['prev'] == 'Yes')
                            _dateRow(
                              id: 'previousReleaseDateWrap', label: 'Original date',
                              value: _previousReleaseDate, onTap: _pickPreviousDate,
                            ),
                        ]),

                        // ── LABEL & RIGHTS ────────────────────────────
                        _sh('Label & rights'),
                        _Group(children: [
                          _InputRow(label: 'Label', ctrl: _labelCtrl, hint: '', readOnly: true, color: _t2),
                          _InputRow(
                            rowKey: _k('copyright'),
                            label: 'Copyright holder', ctrl: _copyrightCtrl, hint: 'Required',
                            invalid: _invalid == 'copyright',
                          ),
                          _InputRow(
                            rowKey: _k('copyrightConfirm'),
                            label: 'Confirm holder', ctrl: _copyrightConfirmCtrl, hint: 'Type it again',
                            invalid: _invalid == 'copyrightConfirm',
                          ),
                        ]),
                        _sf("Enter the owner's name exactly the same in both fields."),

                        // ── IDENTIFIERS ───────────────────────────────
                        _sh('Identifiers'),
                        _Fold(
                          label: 'ISRC, UPC, catalog no.',
                          children: [
                            _InputRow(label: 'ISRC', ctrl: _isrcCtrl, hint: 'e.g. USRC17607839', maxLength: 12),
                            _InputRow(label: 'UPC / EAN', ctrl: _upcCtrl, hint: 'Blank = auto-assign'),
                            _InputRow(label: 'Catalog no.', ctrl: _catalogCtrl, hint: 'e.g. LAB-001', readOnly: true, color: _t2),
                          ],
                        ),

                        // ── CREDITS ───────────────────────────────────
                        _sh('Producers & engineers', right: 'Required', req: true),
                        _creditsGroup('producer', 'Add producer or engineer'),
                        _sh('Songwriters & composers', right: 'Required', req: true),
                        _creditsGroup('writer', 'Add songwriter or composer'),
                        _sh('Publishers', right: 'Required', req: true),
                        _creditsGroup('publishing', 'Add publisher'),
                        _sf('No publisher? Enter your own name.'),
                        _sh('Musicians & performers', right: 'Optional'),
                        _creditsGroup('musician', 'Add musician or performer'),

                        // ── LYRICS ────────────────────────────────────
                        _sh('Lyrics'),
                        _Fold(
                          label: 'Add lyrics',
                          children: [
                            _RowShell(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                              child: TextField(
                                controller: _lyricsCtrl,
                                minLines: 6,
                                maxLines: null,
                                cursorColor: _t1,
                                keyboardType: TextInputType.multiline,
                                style: _ts(16, FontWeight.w400, _t1, height: 1.5),
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  filled: false,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  hintText: 'Paste your lyrics here',
                                  hintStyle: _ts(16, FontWeight.w400, _t3, height: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // ── CONTACT ───────────────────────────────────
                        _sh('Contact', right: 'Required', req: true),
                        _Group(children: [
                          _InputRow(
                            rowKey: _k('email'),
                            label: 'Email', ctrl: _emailCtrl, hint: 'you@email.com',
                            keyboard: TextInputType.emailAddress, invalid: _invalid == 'email',
                          ),
                          _selectRow(
                            id: 'country', label: 'Country', value: _country, placeholder: 'Select',
                            onTap: () async {
                              final p = await _pickOption('Country', _countries.map((g) => _Opt(g, g)).toList(), _country);
                              if (p != null && mounted) setState(() => _country = p.value);
                            },
                          ),
                        ]),

                        // ── YOUR SONG ─────────────────────────────────
                        _sh('Your song', right: 'Required', req: true),
                        _Group(children: [
                          _segRow('Original work', 'original', const ['Yes', 'No'], minW: narrow ? 66 : 78, padH: narrow ? 10 : 14),
                          _segRow('Cover, karaoke, tribute or sound-alike?', 'publicDomain',
                              const ['No', 'Yes', 'Not Sure'], minW: 0, padH: 10),
                          _segRow('Compilation', 'compilation', const ['No', 'Yes'], minW: narrow ? 66 : 78, padH: narrow ? 10 : 14),
                          _segRow('You hold a license', 'license', const ['Yes', 'No'], minW: narrow ? 66 : 78, padH: narrow ? 10 : 14),
                          _segRow('US broadcast rights', 'broadcast', const ['Yes', 'No'], minW: narrow ? 66 : 78, padH: narrow ? 10 : 14),
                          _InputRow(label: 'Product version', ctrl: _productVersionCtrl, hint: 'Optional'),
                        ]),
                        _sf("Choose No or Yes honestly. For a cover, a sample-based song, or a song you don't own fully, change the answers."),

                        // ── PLATFORMS ─────────────────────────────────
                        _sh('Platforms & monetization', right: 'Required', req: true),
                        _Group(children: [
                          _segRow('SoundExchange', 'agSoundExchange', const ['Yes', 'No'], minW: narrow ? 66 : 78, padH: narrow ? 10 : 14),
                          _segRow('YouTube Music', 'agYoutubeMusic', const ['Yes', 'No'], minW: narrow ? 66 : 78, padH: narrow ? 10 : 14),
                          _segRow('YouTube Content ID', 'agContentId', const ['Yes', 'No'], minW: narrow ? 66 : 78, padH: narrow ? 10 : 14, locked: _forceNo),
                          _segRow('Facebook / Instagram', 'agFacebook', const ['Yes', 'No'], minW: narrow ? 66 : 78, padH: narrow ? 10 : 14, locked: _forceNo),
                          _segRow('TikTok exclusive', 'agTiktok', const ['Yes', 'No'], minW: narrow ? 66 : 78, padH: narrow ? 10 : 14, locked: _forceNo),
                          _segRow('Licensing offers', 'agLicensing', const ['Yes', 'No'], minW: narrow ? 66 : 78, padH: narrow ? 10 : 14),
                          _segRow('444 YouTube channel', 'agAvvoYoutube', const ['Yes', 'No'], minW: narrow ? 66 : 78, padH: narrow ? 10 : 14),
                        ]),
                        _sf("All Yes by default. Change any to No if you don't want it."),

                        // ── OWNERSHIP ─────────────────────────────────
                        _sh('Ownership', right: 'Required', req: true),
                        _Group(children: [
                          KeyedSubtree(
                            key: _k('agreementBox'),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _ownershipConfirmed = !_ownershipConfirmed),
                              child: _RowShell(
                                invalid: _invalid == 'agreementBox',
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      margin: const EdgeInsets.only(top: 1),
                                      width: 24, height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _ownershipConfirmed ? _yellow : Colors.transparent,
                                        border: Border.all(color: _ownershipConfirmed ? _yellow : _t3, width: 1.5),
                                      ),
                                      child: AnimatedScale(
                                        duration: const Duration(milliseconds: 250),
                                        scale: _ownershipConfirmed ? 1 : 0.5,
                                        child: AnimatedOpacity(
                                          duration: const Duration(milliseconds: 200),
                                          opacity: _ownershipConfirmed ? 1 : 0,
                                          child: const Icon(Icons.check_rounded, color: Colors.black, size: 15),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        "I own this song or hold the rights to distribute it, and it doesn't infringe anyone's copyright.",
                                        style: _ts(15, FontWeight.w400, _t1, height: 1.45),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── TOP BAR ────────────────────────────────────────────────
          Positioned(top: 0, left: 0, right: 0, child: _topBar(top)),

          // ── DOCK ───────────────────────────────────────────────────
          Positioned(bottom: 0, left: 0, right: 0, child: _dock()),
        ],
      ),
    );
  }

  // ── TOP BAR ───────────────────────────────────────────────────────────
  Widget _topBar(double top) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 56 + top,
          padding: EdgeInsets.fromLTRB(16, top, 16, 0),
          color: Colors.black.withValues(alpha: 0.72),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(color: _fill, shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_left_rounded, color: _t1, size: 24),
                ),
              ),
              Text('New release', style: _ts(17, FontWeight.w600, _t1)),
              SizedBox(
                width: 36,
                child: Text('1 of 3', textAlign: TextAlign.right, style: _ts(13, FontWeight.w400, _t2)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(bool narrow) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Release info', style: _ts(narrow ? 30 : 34, FontWeight.w700, _t1, em: -0.04, height: 1.1)),
          const SizedBox(height: 6),
          Text('Tell us about your music.', style: _ts(17, FontWeight.w400, _t2)),
          const SizedBox(height: 20),
          Row(
            children: List.generate(3, (i) => Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(left: i > 0 ? 6 : 0),
                decoration: BoxDecoration(
                  color: i == 0 ? _yellow : _fill,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i > 0 ? 6 : 0),
                    child: Text(['Info', 'Stores', 'Review'][i],
                        style: _ts(12, FontWeight.w500, i == 0 ? _t1 : _t3)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _note(String text, IconData icon, Color fg, Color bg, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 17),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: _ts(14, FontWeight.w500, fg, height: 1.35))),
        ],
      ),
    );
  }

  Widget _sh(String title, {String? right, bool req = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(child: Text(title.toUpperCase(), style: _ts(13, FontWeight.w500, _t2, em: 0.04))),
          if (right != null) Text(right, style: _ts(13, FontWeight.w400, req ? _yellow : _t3)),
        ],
      ),
    );
  }

  Widget _sf(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(text, style: _ts(13, FontWeight.w400, _t2, height: 1.4)),
      );

  // ── ARTIST WIDGETS ────────────────────────────────────────────────────
  Widget _artistPill(String name) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 12, 4),
      decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(color: _s3, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: _ts(12, FontWeight.w600, _t1)),
          ),
          const SizedBox(width: 7),
          Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: _ts(15, FontWeight.w500, _t1))),
        ],
      ),
    );
  }

  Widget _trackCard(Map<String, dynamic> t, int i) {
    final artists = t['artists'] as List<Map<String, String>>;
    final title = t['title'] as String;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Track ${i + 1}${title.isNotEmpty ? ' · $title' : ''}',
                    overflow: TextOverflow.ellipsis, style: _ts(15, FontWeight.w600, _t1)),
              ),
              const SizedBox(width: 10),
              Text('${artists.length} artist${artists.length == 1 ? '' : 's'}',
                  style: _ts(13, FontWeight.w400, _t2)),
            ],
          ),
          const SizedBox(height: 10),
          if (artists.isEmpty)
            Text('No artists on this track.', style: _ts(14, FontWeight.w400, _t3))
          else
            for (int k = 0; k < artists.length; k++) _trackArtistChip(artists[k], last: k == artists.length - 1),
        ],
      ),
    );
  }

  Widget _trackArtistChip(Map<String, String> a, {required bool last}) {
    final type = a['type'] ?? 'featured';
    final isMain = type == 'main';
    return Container(
      margin: EdgeInsets.only(bottom: last ? 0 : 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: isMain ? const Color(0x2930D158) : _fill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(_typeLabel[type] ?? type,
                style: _ts(11, FontWeight.w600, isMain ? _green : _t2, em: 0.02)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(a['name'] ?? '', overflow: TextOverflow.ellipsis, style: _ts(15, FontWeight.w500, _t1)),
          ),
          const SizedBox(width: 10),
          _linkIcon(a['spotifyUrl'] ?? '', Icons.music_note_rounded, const Color(0xFF1DB954)),
          const SizedBox(width: 8),
          _linkIcon(a['appleUrl'] ?? '', Icons.apple_rounded, const Color(0xFFFC3C44)),
        ],
      ),
    );
  }

  Widget _linkIcon(String url, IconData icon, Color color) {
    final w = Icon(icon, size: 14, color: color);
    if (url.isEmpty) return Opacity(opacity: 0.25, child: w);
    return GestureDetector(onTap: () => _openUrl(url), child: w);
  }

  // ── ROW BUILDERS ──────────────────────────────────────────────────────
  Widget _selectRow({
    required String id,
    required String label,
    required String value,
    required String placeholder,
    required VoidCallback? onTap,
    bool dim = false,
  }) {
    final empty = value.isEmpty;
    final invalid = _invalid == id;
    return KeyedSubtree(
      key: _k(id),
      child: Opacity(
        opacity: dim ? 0.45 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: _RowShell(
            invalid: invalid,
            child: Row(
              children: [
                _Lbl(label, invalid: invalid),
                Expanded(
                  child: Text(
                    empty ? placeholder : value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(16, FontWeight.w400, empty ? _t3 : _t1),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: _t3, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateRow({
    required String id,
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final invalid = _invalid == id;
    return KeyedSubtree(
      key: _k(id),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _RowShell(
          invalid: invalid,
          child: Row(
            children: [
              _Lbl(label, invalid: invalid),
              Expanded(
                child: Text(
                  value == null ? 'dd/mm/yyyy' : _fmtDmy(value),
                  textAlign: TextAlign.right,
                  style: _ts(16, FontWeight.w400, value == null ? _t3 : _t1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segRow(String label, String key, List<String> opts,
      {double minW = 78, double padH = 14, bool locked = false}) {
    return _RowShell(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _Lbl(label),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Opacity(
                  opacity: locked ? 0.45 : 1,
                  child: AbsorbPointer(
                    absorbing: locked,
                    child: _Seg(
                      options: opts,
                      value: _v[key]!,
                      minWidth: minW,
                      padH: padH,
                      onChanged: (val) => _setV(key, val),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _creditsGroup(String type, String addLabel) {
    final list = _credits[type]!;
    final id = '${type == 'publishing' ? 'publishing' : type}List';
    final invalid = _invalid == id;
    return KeyedSubtree(
      key: _k(id),
      child: _Group(
        invalid: invalid,
        children: [
          for (int i = 0; i < list.length; i++)
            _CreditRow(
              key: ObjectKey(list[i]),
              entry: list[i],
              label: '${_noun[type]} ${i + 1}',
              namePh: _namePlaceholder[type]!,
              showIpi: type == 'writer',
              onRemove: () => _removeCredit(type, list[i]),
              onPickRole: () => _pickRole(type, list[i]),
            ),
          _AddCreditButton(label: addLabel, onTap: () => _addCredit(type)),
        ],
      ),
    );
  }

  // ── DOCK ──────────────────────────────────────────────────────────────
  Widget _dock() {
    final bottom = MediaQuery.of(context).padding.bottom;
    final busy = _btnLabel == 'Checking…' || _btnLabel == 'Saving…';
    final done = _btnLabel == 'Saved' || _btnLabel == 'Already saved';
    final statusColor = _statusKind == 'error' ? _rose : (_statusKind == 'success' ? _green : _t2);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            border: const Border(top: BorderSide(color: _sep, width: 0.5)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_statusMsg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(_statusMsg,
                          textAlign: TextAlign.center,
                          style: _ts(14, FontWeight.w500, statusColor, height: 1.35)),
                    ),
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submit,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isSubmitting && !done && !busy ? 0.4 : (_isSubmitting ? 1 : 1),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(color: _yellow, borderRadius: BorderRadius.circular(999)),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (busy) ...[
                              const SizedBox(
                                width: 17, height: 17,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (done) ...[
                              const Icon(Icons.check_rounded, color: Colors.black, size: 17),
                              const SizedBox(width: 8),
                            ],
                            Text(_btnLabel, style: _ts(17, FontWeight.w600, Colors.black)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ════════════════════════════════════════════════════════════════════
class _GroupBox extends StatelessWidget {
  final Widget child;
  final bool invalid;
  const _GroupBox({required this.child, this.invalid = false});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: _s1,
          borderRadius: BorderRadius.circular(16),
          boxShadow: invalid ? const [BoxShadow(color: _rose, spreadRadius: 1.5)] : const [],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
      );
}

List<Widget> _withSeps(List<Widget> c, {bool leading = false}) {
  final out = <Widget>[];
  for (int i = 0; i < c.length; i++) {
    if (i > 0 || leading) {
      out.add(Container(height: 0.5, margin: const EdgeInsets.only(left: 16), color: _sep));
    }
    out.add(c[i]);
  }
  return out;
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  final bool invalid;
  const _Group({required this.children, this.invalid = false});
  @override
  Widget build(BuildContext context) => _GroupBox(
        invalid: invalid,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _withSeps(children)),
      );
}

class _RowShell extends StatelessWidget {
  final Widget child;
  final bool invalid;
  final EdgeInsets padding;
  const _RowShell({
    required this.child,
    this.invalid = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 52),
        padding: padding,
        alignment: Alignment.centerLeft,
        color: invalid ? const Color(0x1FFF453A) : Colors.transparent,
        child: child,
      );
}

class _Lbl extends StatelessWidget {
  final String text;
  final bool invalid;
  const _Lbl(this.text, {this.invalid = false});
  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width <= 420;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: narrow ? 96 : 114,
        child: Text(text, style: _ts(narrow ? 15 : 16, FontWeight.w400, invalid ? _rose : _t1)),
      ),
    );
  }
}

class _InputRow extends StatefulWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final TextInputType? keyboard;
  final int? maxLength;
  final bool readOnly;
  final Color? color;
  final bool invalid;
  final Key? rowKey;
  const _InputRow({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.keyboard,
    this.maxLength,
    this.readOnly = false,
    this.color,
    this.invalid = false,
    this.rowKey,
  });
  @override
  State<_InputRow> createState() => _InputRowState();
}

class _InputRowState extends State<_InputRow> {
  final _focus = FocusNode();
  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: widget.rowKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.readOnly ? null : _focus.requestFocus,
        child: _RowShell(
          invalid: widget.invalid,
          child: Row(
            children: [
              _Lbl(widget.label, invalid: widget.invalid),
              Expanded(
                child: TextField(
                  controller: widget.ctrl,
                  focusNode: _focus,
                  readOnly: widget.readOnly,
                  enableInteractiveSelection: !widget.readOnly,
                  keyboardType: widget.keyboard,
                  textAlign: TextAlign.right,
                  cursorColor: _t1,
                  inputFormatters: widget.maxLength != null ? [LengthLimitingTextInputFormatter(widget.maxLength)] : null,
                  style: _ts(16, FontWeight.w400, widget.color ?? _t1),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    hintText: widget.hint,
                    hintStyle: _ts(16, FontWeight.w400, _t3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final List<String> options;
  final String value;
  final double minWidth, padH;
  final ValueChanged<String> onChanged;
  const _Seg({
    required this.options,
    required this.value,
    required this.onChanged,
    this.minWidth = 78,
    this.padH = 14,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(9)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((o) {
          final sel = o == value;
          return GestureDetector(
            onTap: () => onChanged(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              constraints: BoxConstraints(minWidth: minWidth),
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? _s3 : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                boxShadow: sel
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
                    : const [],
              ),
              child: Text(o, style: _ts(14, FontWeight.w500, _t1)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Fold extends StatefulWidget {
  final String label;
  final List<Widget> children;
  const _Fold({required this.label, required this.children});
  @override
  State<_Fold> createState() => _FoldState();
}

class _FoldState extends State<_Fold> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    return _GroupBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: _RowShell(
              child: Row(
                children: [
                  Expanded(child: Text(widget.label, style: _ts(16, FontWeight.w400, _t1))),
                  Text('Optional', style: _ts(14, FontWeight.w400, _t3)),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 350),
                    curve: const Cubic(0.32, 0.72, 0, 1),
                    child: const Icon(Icons.chevron_right_rounded, color: _t3, size: 20),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: const Cubic(0.32, 0.72, 0, 1),
            alignment: Alignment.topCenter,
            child: _open
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _withSeps(widget.children, leading: true),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _CreditRow extends StatefulWidget {
  final CreditEntry entry;
  final String label, namePh;
  final bool showIpi;
  final VoidCallback onRemove, onPickRole;
  const _CreditRow({
    super.key,
    required this.entry,
    required this.label,
    required this.namePh,
    required this.showIpi,
    required this.onRemove,
    required this.onPickRole,
  });
  @override
  State<_CreditRow> createState() => _CreditRowState();
}

class _CreditRowState extends State<_CreditRow> {
  late final TextEditingController _name = TextEditingController(text: widget.entry.name);
  late final TextEditingController _ipi  = TextEditingController(text: widget.entry.ipi);

  @override
  void dispose() { _name.dispose(); _ipi.dispose(); super.dispose(); }

  InputDecoration _dec(String hint) => InputDecoration(
        isCollapsed: true,
        filled: true,
        fillColor: _s2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        hintText: hint,
        hintStyle: _ts(16, FontWeight.w400, _t3),
      );

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: const Cubic(0.32, 0.72, 0, 1),
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, -6 * (1 - v)), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.label, style: _ts(13, FontWeight.w500, _t2)),
                GestureDetector(
                  onTap: widget.onRemove,
                  child: Container(
                    width: 26, height: 26,
                    decoration: const BoxDecoration(color: _fill, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: _t2, size: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              autofocus: e.autofocus,
              cursorColor: _t1,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => e.name = v,
              style: _ts(16, FontWeight.w400, _t1),
              decoration: _dec(widget.namePh),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPickRole,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.role.isEmpty ? 'Role' : e.role,
                          overflow: TextOverflow.ellipsis,
                          style: _ts(16, FontWeight.w400, e.role.isEmpty ? _t3 : _t1)),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: _t3, size: 20),
                  ],
                ),
              ),
            ),
            if (widget.showIpi) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _ipi,
                cursorColor: _t1,
                onChanged: (v) => e.ipi = v,
                style: _ts(16, FontWeight.w400, _t1),
                decoration: _dec('IPI / CAE number (optional)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddCreditButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _AddCreditButton({required this.label, required this.onTap});
  @override
  State<_AddCreditButton> createState() => _AddCreditButtonState();
}

class _AddCreditButtonState extends State<_AddCreditButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: _pressed ? const Color(0x0FFFFFFF) : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(color: _yellow, shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded, color: Colors.black, size: 14),
              ),
              const SizedBox(width: 10),
              Flexible(child: Text(widget.label, style: _ts(16, FontWeight.w500, _yellow))),
            ],
          ),
        ),
      );
}

// ── PICKER SHEET (iOS-style list) ───────────────────────────────────────
class _PickerSheet extends StatelessWidget {
  final String title, current;
  final List<_Opt> opts;
  const _PickerSheet({required this.title, required this.opts, required this.current});

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.7;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: _s1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            Container(
              width: 36, height: 5,
              decoration: BoxDecoration(color: const Color(0x4DEBEBF5), borderRadius: BorderRadius.circular(3)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(title, style: _ts(17, FontWeight.w600, _t1)),
            ),
            Container(height: 0.5, color: _sep),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: opts.length,
                separatorBuilder: (_, __) => Container(height: 0.5, margin: const EdgeInsets.only(left: 16), color: _sep),
                itemBuilder: (ctx, i) {
                  final o = opts[i];
                  final sel = o.value == current;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: o.disabled ? null : () => Navigator.pop(ctx, _Pick(o.value)),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 50),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(o.label,
                                style: _ts(17, sel ? FontWeight.w600 : FontWeight.w400,
                                    o.disabled ? _t3 : (o.value.isEmpty ? _t2 : _t1))),
                          ),
                          if (sel) const Icon(Icons.check_rounded, color: _blue, size: 20),
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
    );
  }
}

// ── DATE SHEET (iOS wheel) ──────────────────────────────────────────────
class _DateSheet extends StatefulWidget {
  final String title;
  final DateTime min, max, initial;
  const _DateSheet({required this.title, required this.min, required this.max, required this.initial});
  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _s1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            Container(
              width: 36, height: 5,
              decoration: BoxDecoration(color: const Color(0x4DEBEBF5), borderRadius: BorderRadius.circular(3)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text('Cancel', style: _ts(17, FontWeight.w400, _blue)),
                  ),
                  Text(widget.title, style: _ts(17, FontWeight.w600, _t1)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, DateTime(_value.year, _value.month, _value.day)),
                    child: Text('Done', style: _ts(17, FontWeight.w600, _blue)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 216,
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  brightness: Brightness.dark,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(color: Colors.white, fontSize: 21),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: widget.initial,
                  minimumDate: widget.min,
                  maximumDate: widget.max,
                  onDateTimeChanged: (d) => _value = d,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── iOS ALERT (release-date advice) ─────────────────────────────────────
class _IosAlert extends StatelessWidget {
  final String title, message, cancelLabel, confirmLabel;
  const _IosAlert({
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    Widget action(String label, bool primary, bool result) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context, result),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              child: Text(label, style: _ts(17, primary ? FontWeight.w600 : FontWeight.w400, _blue, em: -0.02)),
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
                        Text(title, textAlign: TextAlign.center, style: _ts(17, FontWeight.w600, _t1, em: -0.02)),
                        const SizedBox(height: 5),
                        Text(message,
                            textAlign: TextAlign.center,
                            style: _ts(13, FontWeight.w400, const Color(0xD9FFFFFF), height: 1.4)),
                      ]),
                    ),
                    Container(height: 0.5, color: _sep),
                    Row(children: [
                      action(cancelLabel, false, false),
                      Container(width: 0.5, height: 48, color: _sep),
                      action(confirmLabel, true, true),
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
