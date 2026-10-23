// ═══════════════════════════════════════════════════════════════════
//  444MUSIC — Fix & Resubmit (App)
//  Reached from: ReleasesScreen → "Check Reasons & Fix"
//  Route: '/rejection', arguments: the full submission map (with '_id')
//
//  Rebuilt to mirror the web rejection-fix page 1:1 — iOS look,
//  same two modes, same fields, same file rules (WAV / 4000×4000 JPG /
//  PDF), same validation order, same uploads (Cloudinary + R2),
//  same Firestore update, same admin email.
// ═══════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode, CupertinoTheme, CupertinoThemeData, CupertinoTextThemeData;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_selector/file_selector.dart';
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

// ─── ENDPOINTS (same as web) ────────────────────────────────────────
const _cloudinaryUrl    = 'https://api.cloudinary.com/v1_1/dlbgqtvqg/auto/upload';
const _cloudinaryPreset = 'glmamp2y';
const _notifyUrl  = 'https://four44music-broadcast-backend.onrender.com/api/submissions/notify';
const _appSecret  = 'e993b17f0762667e27d5298839dacff4a7409bb74e11e9ecaf0bb2bb647120a8';
const _backendUrl = 'https://four44music-broadcast-backend.onrender.com';

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

// ─── LISTS (same as Release Info / web) ─────────────────────────────
const _types = ['Single', 'EP', 'Album'];

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

const Map<String, List<String>> _roles = {
  'producer': ['Producer','Executive Producer','Co-Producer','Beat Maker','Mixing Engineer','Mastering Engineer','Recording Engineer','Vocal Producer','Sound Designer','Re-mixer','Programmer','Audio Editor'],
  'writer':   ['Songwriter','Lyricist','Composer','Co-Writer','Melody Writer','Arranger','Top-Liner','Concept Writer'],
  'publishing': ['Publisher','Co-Publisher','Administrator'],
};
const Map<String, String> _noun = {'producer': 'Producer', 'writer': 'Songwriter', 'publishing': 'Publisher'};
const Map<String, String> _placeholder = {
  'producer': 'Full name, e.g. Metro Boomin',
  'writer': 'Full name, e.g. John Doe',
  'publishing': 'Publisher name',
};
const Map<String, String> _foldTitle = {
  'producer': 'Producers & engineers',
  'writer': 'Songwriters & composers',
  'publishing': 'Publishers',
};
const Map<String, String> _addLabel = {
  'producer': 'Add producer or engineer',
  'writer': 'Add songwriter or composer',
  'publishing': 'Add publisher',
};
const _creditTypes = ['producer', 'writer', 'publishing'];

// ─── MODELS ─────────────────────────────────────────────────────────
class CreditEntry {
  String name;
  String role;
  String ipi;
  bool autofocus;
  CreditEntry({this.name = '', this.role = '', this.ipi = '', this.autofocus = false});
}

class _Feat {
  String name;
  String spotifyUrl;
  String appleUrl;
  bool autofocus;
  _Feat({this.name = '', this.spotifyUrl = '', this.appleUrl = '', this.autofocus = false});
}

class _Picked {
  final File file;
  final String name;
  final int size;
  const _Picked(this.file, this.name, this.size);
}

class _Track {
  final Map<String, dynamic> orig;
  String title;
  String url;
  bool required;
  _Picked? picked;
  String? newUrl;
  String error = '';
  List<_Feat> others;
  final TextEditingController titleCtrl;
  _Track({
    required this.orig,
    required this.title,
    required this.url,
    required this.required,
    required this.others,
  }) : titleCtrl = TextEditingController(text: title);
}

class _Asset {
  String url;
  bool required;
  _Picked? picked;
  String? newUrl;
  String error = '';
  _Asset({this.url = '', this.required = false});
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

class _Problem {
  final String msg, el;
  final String? fold;
  const _Problem(this.msg, this.el, {this.fold});
}

// ─── HELPERS ────────────────────────────────────────────────────────
String _two(int n) => n.toString().padLeft(2, '0');
String _ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
String _fmtDmy(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
String _fmtBytes(int b) => b < 1024 * 1024 ? '${(b / 1024).toStringAsFixed(1)} KB' : '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

bool _isYes(dynamic v) =>
    v == true || ['yes', 'true'].contains((v ?? '').toString().trim().toLowerCase());
String _ynVal(dynamic v, String def) =>
    (v == null || v == '') ? def : (_isYes(v) ? 'Yes' : 'No');
String _pickIn(List<String> list, dynamic v) {
  final s = (v ?? '').toString().trim().toLowerCase();
  for (final o in list) {
    if (o.toLowerCase() == s) return o;
  }
  return '';
}

bool _meetsAudio(String u) => RegExp(r'\.wav(\?|#|$)', caseSensitive: false).hasMatch(u);
bool _meetsCover(String u) => RegExp(r'\.jpe?g(\?|#|$)', caseSensitive: false).hasMatch(u);
bool _isCopyright(dynamic c) {
  final s = (c ?? '').toString().toLowerCase();
  return s.contains('copyright') || s.contains('license');
}

String _toDate10(dynamic v) {
  if (v is Timestamp) {
    final d = v.toDate().toUtc();
    return _ymd(d);
  }
  final s = (v ?? '').toString().trim();
  if (s.isEmpty) return '';
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) return s.substring(0, 10);
  final d = DateTime.tryParse(s);
  return d == null ? '' : _ymd(d.toUtc());
}

DateTime? _parseYmd(String s) {
  if (s.length < 10) return null;
  final y = int.tryParse(s.substring(0, 4)), m = int.tryParse(s.substring(5, 7)), d = int.tryParse(s.substring(8, 10));
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String _toIsoOrEmpty(String ymd) {
  final d = _parseYmd(ymd);
  return d == null ? ymd : DateTime.utc(d.year, d.month, d.day).toIso8601String();
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

String _nameMsg(String name, List<String> bad, [String label = 'Artist name']) {
  final chars = bad.where((x) => x != 'OPEN').toList();
  final parts = <String>[];
  if (chars.isNotEmpty) parts.add("can't contain ${chars.join(' ')}");
  if (bad.contains('OPEN')) parts.add('has a bracket ( ) that is not closed');
  final tail = bad.contains(',') ? ' Add each artist separately instead of using commas.' : '';
  return '$label "$name" ${parts.join(' and ')}.$tail';
}

// ─── FILE CHECKS (same rules as web) ────────────────────────────────
String _checkCover(Uint8List b, String name) {
  if (!RegExp(r'\.jpe?g$', caseSensitive: false).hasMatch(name)) return 'Cover art must be a JPG file.';
  if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return 'This is not a valid JPG file.';
  int p = 2;
  while (p + 4 <= b.length) {
    if (b[p] != 0xFF) { p++; continue; }
    final m = b[p + 1];
    if (m == 0xFF) { p++; continue; }
    if (m == 0xDA) break;
    if (m == 0xD8 || m == 0x01 || (m >= 0xD0 && m <= 0xD7)) { p += 2; continue; }
    final len = (b[p + 2] << 8) | b[p + 3];
    if (m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC) {
      if (p + 10 > b.length) break;
      final h = (b[p + 5] << 8) | b[p + 6];
      final w = (b[p + 7] << 8) | b[p + 8];
      final comps = b[p + 9];
      if (w != 4000 || h != 4000) return 'Cover art must be exactly 4000 × 4000 px. Yours is $w × $h.';
      if (comps != 3) return 'Cover art must be RGB. CMYK and grayscale images are not accepted.';
      return '';
    }
    p += 2 + len;
  }
  return 'Could not read this image. Please export it again as a JPG.';
}

Future<String> _checkWav(File file) async {
  Uint8List b;
  try {
    final raf = await file.open();
    b = await raf.read(65536);
    await raf.close();
  } catch (_) {
    return 'Could not read this WAV file. Please re-export it and try again.';
  }
  String tag(int o) => String.fromCharCodes(b.sublist(o, o + 4));
  if (b.length < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') return 'This is not a valid WAV file.';
  final v = ByteData.sublistView(b);
  int pos = 12;
  while (pos + 8 <= b.length) {
    final id = tag(pos);
    final size = v.getUint32(pos + 4, Endian.little);
    if (id == 'fmt ' && pos + 24 <= b.length) {
      final channels = v.getUint16(pos + 10, Endian.little);
      final rate = v.getUint32(pos + 12, Endian.little);
      final bits = v.getUint16(pos + 22, Endian.little);
      if (bits < 16) return 'Audio must be 16-bit or higher. Re-export at 16-bit or 24-bit.';
      if (rate < 44100) return 'Audio must be 44.1 kHz or higher. Re-export at 44.1 kHz or 48 kHz.';
      if (channels != 2) return 'Audio must be stereo. Mono files are not accepted.';
      return '';
    }
    pos += 8 + size + (size % 2);
  }
  return 'Could not read this WAV file. Please re-export it and try again.';
}

// ─── UPLOADS ────────────────────────────────────────────────────────
class _ProgressMultipartRequest extends http.MultipartRequest {
  final void Function(int sent, int total) onProgress;
  _ProgressMultipartRequest(super.method, super.url, {required this.onProgress});

  @override
  http.ByteStream finalize() {
    final total = contentLength;
    int sent = 0;
    final stream = super.finalize();
    return http.ByteStream(stream.transform(StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        sent += data.length;
        onProgress(sent, total);
        sink.add(data);
      },
    )));
  }
}

String _errText(Object e) => e.toString().replaceFirst('Exception: ', '');

Future<String> _uploadToCloudinary(File file, String folder, void Function(int) onProgress) async {
  const generic = 'Upload failed. Check your connection and try again.';
  try {
    final req = _ProgressMultipartRequest('POST', Uri.parse(_cloudinaryUrl), onProgress: (s, t) {
      if (t > 0) onProgress((s * 100 / t).round());
    });
    req.fields['upload_preset'] = _cloudinaryPreset;
    req.fields['folder'] = folder;
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(generic);
    }
    if (streamed.statusCode >= 200 && streamed.statusCode < 300 && json['secure_url'] != null) {
      return json['secure_url'] as String;
    }
    final err = json['error'];
    throw Exception((err is Map ? err['message'] : null) ?? generic);
  } on SocketException {
    throw Exception('Network error during upload. Check your connection and try again.');
  }
}

Future<String> _uploadWavToR2(File file, void Function(int) onProgress) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Please sign in again.');
  final token = await user.getIdToken();
  final size = await file.length();
  final res = await http.post(
    Uri.parse('$_backendUrl/api/audio/upload-url'),
    headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    body: jsonEncode({'contentType': 'audio/wav', 'size': size}),
  );
  Map<String, dynamic> out = {};
  try { out = jsonDecode(res.body) as Map<String, dynamic>; } catch (_) {}
  if (res.statusCode < 200 || res.statusCode > 299 || out['success'] != true) {
    throw Exception((out['message'] ?? 'Could not start the upload.').toString());
  }
  try {
    final req = http.StreamedRequest('PUT', Uri.parse(out['uploadUrl'].toString()));
    req.headers['Content-Type'] = 'audio/wav';
    req.contentLength = size;
    final sendFuture = req.send();
    int sent = 0;
    await for (final chunk in file.openRead()) {
      req.sink.add(chunk);
      sent += chunk.length;
      onProgress((sent * 100 / size).round());
    }
    await req.sink.close();
    final put = await sendFuture;
    if (put.statusCode < 200 || put.statusCode > 299) {
      throw Exception('Upload was refused (HTTP ${put.statusCode}).');
    }
  } on SocketException {
    throw Exception('Network error during upload. Check your connection and try again.');
  }
  return out['key'].toString();
}

Future<String> _resolvePlayUrl(String url) async {
  if (!url.startsWith('r2:')) return url;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return '';
  final token = await user.getIdToken();
  final res = await http.get(
    Uri.parse('$_backendUrl/api/audio/play-url?key=${Uri.encodeQueryComponent(url.substring(3))}'),
    headers: {'Authorization': 'Bearer $token'},
  );
  try {
    final out = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300 && out['success'] == true) return out['url'].toString();
  } catch (_) {}
  return '';
}

// ════════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════════
class RejectionFixScreen extends StatefulWidget {
  const RejectionFixScreen({super.key});
  @override
  State<RejectionFixScreen> createState() => _RejectionFixScreenState();
}

class _RejectionFixScreenState extends State<RejectionFixScreen> {
  Map<String, dynamic> _data = {};
  bool _argsLoaded = false;
  String _stateTitle = '', _stateSub = '';
  bool _showState = false;

  bool _copyrightMode = false;
  bool _isSingle = true;
  List<_Track> _tracks = [];
  _Asset _cover = _Asset();
  _Picked? _licensePicked;
  String? _licenseNewUrl;
  String _licenseError = '';
  final Map<String, List<CreditEntry>> _credits = {'producer': [], 'writer': [], 'publishing': []};
  String _minDate = '';
  String _origDate = '';
  bool _dateTooSoon = false;
  DateTime? _releaseDate;

  // fields
  final _artistCtrl     = TextEditingController();
  final _titleCtrl      = TextEditingController();
  final _versionCtrl    = TextEditingController();
  final _copyrightCtrl  = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  final _productCtrl    = TextEditingController();
  final _scrollCtrl     = ScrollController();

  String _releaseType = '';
  String _genre = '', _genreSub = '', _altGenre = '', _altGenreSub = '';
  String _language = '';
  String _explicit = 'No';

  final Map<String, String> _v = {};
  final Map<String, String> _savedLock = {};
  static const _lockIds = ['agContentId', 'agFacebook', 'agTiktok'];
  bool _lastForce = false;
  bool _copyChanged = false;
  final Map<String, bool> _foldOpen = {};

  bool _busy = false;
  bool _done = false;
  bool _notifyOk = true;
  int _notifyStatus = 0;
  String _btnLabel = 'Resubmit for review';
  String _status = '';
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
    _copyrightCtrl.addListener(() {
      final changed = _copyrightCtrl.text.trim() != (_data['copyright'] ?? '').toString().trim();
      if (changed != _copyChanged) {
        setState(() {
          _copyChanged = changed;
          if (!changed) _confirmCtrl.clear();
        });
      }
    });
    _versionCtrl.addListener(() {
      if (_forceNo != _lastForce) setState(_applyLock);
    });
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
    _argsLoaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) _data = Map<String, dynamic>.from(args);
    if ((_data['_id'] ?? '').toString().isEmpty) {
      _showState = true;
      _stateTitle = 'Release not found';
      _stateSub = "We couldn't find this release. Go back and try again.";
      return;
    }
    final status = (_data['status'] ?? '').toString().trim().toLowerCase();
    if (status.isNotEmpty && status != 'rejected') {
      _showState = true;
      _stateTitle = 'Nothing to fix';
      _stateSub = "This release isn't waiting for changes right now.";
      return;
    }
    _buildState();
  }

  @override
  void dispose() {
    for (final c in [_artistCtrl, _titleCtrl, _versionCtrl, _copyrightCtrl, _confirmCtrl, _productCtrl]) {
      c.dispose();
    }
    for (final t in _tracks) {
      t.titleCtrl.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  String get _id => (_data['_id'] ?? '').toString();

  // ── BUILD WORKING STATE FROM THE SUBMISSION (same as web buildState) ──
  void _buildState() {
    final d = _data;
    _copyrightMode = _isCopyright(d['rejectionCategory']);
    final artistName = (d['artistName'] ?? '').toString().trim();
    final raw = d['audioFiles'] is List
        ? (d['audioFiles'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];
    final base = raw.isNotEmpty
        ? raw
        : [
            <String, dynamic>{
              'title': d['releaseTitle'] ?? '',
              'url': '',
              'artists': artistName.isNotEmpty
                  ? [<String, dynamic>{'name': artistName, 'type': 'main', 'spotifyUrl': '', 'appleUrl': ''}]
                  : <dynamic>[],
            }
          ];
    _tracks = base.map((t) {
      final url = (t['url'] ?? '').toString();
      final artists = t['artists'] is List ? (t['artists'] as List) : const [];
      return _Track(
        orig: t,
        title: (t['title'] ?? '').toString().trim(),
        url: url,
        required: !_meetsAudio(url),
        others: artists
            .whereType<Map>()
            .where((a) => (a['type'] ?? '') != 'main' && (a['name'] ?? '').toString().trim().isNotEmpty)
            .map((a) => _Feat(
                  name: a['name'].toString(),
                  spotifyUrl: (a['spotifyUrl'] ?? '').toString(),
                  appleUrl: (a['appleUrl'] ?? '').toString(),
                ))
            .toList(),
      );
    }).toList();
    _isSingle = _tracks.length == 1;

    final coverUrl = (d['officialCoverURL'] ?? d['coverURL'] ?? '').toString();
    _cover = _Asset(url: coverUrl, required: !_meetsCover(coverUrl));

    final c = d['credits'] is Map ? d['credits'] as Map : const {};
    List<CreditEntry> clone(dynamic arr) => (arr is List ? arr : const [])
        .whereType<Map>()
        .where((x) => (x['name'] ?? '').toString().trim().isNotEmpty)
        .map((x) => CreditEntry(
              name: x['name'].toString(),
              role: (x['role'] ?? '').toString(),
              ipi: (x['ipi'] ?? '').toString(),
            ))
        .toList();
    _credits['producer'] = clone(c['producer']);
    _credits['writer'] = clone(c['writer']);
    _credits['publishing'] = clone(c['publishing']);

    final t = _today();
    _minDate = _ymd(DateTime(t.year, t.month, t.day + 3));
    _origDate = _toDate10(d['releaseDate']);
    _dateTooSoon = _origDate.isEmpty || _origDate.compareTo(_minDate) < 0;
    _releaseDate = _dateTooSoon ? null : _parseYmd(_origDate);

    if (_copyrightMode) return;

    _artistCtrl.text = (d['artistName'] ?? '').toString();
    _titleCtrl.text = (d['releaseTitle'] ?? '').toString();
    _versionCtrl.text = (d['version'] ?? '').toString();
    _copyrightCtrl.text = (d['copyright'] ?? '').toString().trim();
    _productCtrl.text = (d['productVersion'] ?? '').toString();

    _releaseType = _pickIn(_types, d['releaseType']);
    if (_tracks.length == 1) {
      _releaseType = 'Single';
    } else if (_tracks.length > 1) {
      if (_releaseType.isEmpty || _releaseType == 'Single') _releaseType = 'EP';
    }
    _genre = _pickIn(_genreSubs.keys.toList(), d['genre']);
    final subs = _genreSubs[_genre] ?? const [];
    final mgs = (d['mainGenreSub'] ?? '').toString();
    _genreSub = subs.contains(mgs) ? mgs : '';
    final alt = (d['alternateGenre'] ?? '').toString();
    _altGenre = (alt != _genre && _genreSubs.containsKey(alt)) ? alt : '';
    final altSubs = _genreSubs[_altGenre] ?? const [];
    final ags = (d['alternateGenreSub'] ?? '').toString();
    _altGenreSub = altSubs.contains(ags) ? ags : '';
    _language = _pickIn(_languages, d['language']);
    _explicit = _isYes(d['explicit']) ? 'Yes' : 'No';

    final ag = d['agreements'] is Map ? d['agreements'] as Map : const {};
    _v['vocal'] = RegExp('instrumental', caseSensitive: false).hasMatch((d['vocalType'] ?? '').toString()) ? 'Instrumental' : 'Vocals';
    _v['original'] = _ynVal(d['isOriginal'], 'Yes');
    final pd = (d['publicDomainStatus'] ?? '').toString();
    _v['publicDomain'] = ['No', 'Yes', 'Not Sure'].contains(pd) ? pd : 'No';
    _v['compilation'] = _ynVal(d['isCompilation'], 'No');
    _v['license2'] = _ynVal(d['hasLicense'], 'Yes');
    _v['broadcast'] = _ynVal(d['hasUsBroadcastRights'], 'Yes');
    _v['agSoundExchange'] = _ynVal(ag['soundexchange'], 'Yes');
    _v['agYoutubeMusic'] = _ynVal(ag['youtube_music'], 'Yes');
    _v['agContentId'] = _ynVal(ag['youtube_content_id'], 'Yes');
    _v['agFacebook'] = _ynVal(ag['facebook_monetization'], 'Yes');
    _v['agTiktok'] = _ynVal(ag['tiktok_monetization'], 'Yes');
    _v['agLicensing'] = _ynVal(ag['licensing'], 'Yes');
    _v['agAvvoYoutube'] = _ynVal(ag['avvo_youtube_channel'], 'Yes');

    for (final type in _creditTypes) {
      _foldOpen[type] = !_credits[type]!.any((c) => c.name.trim().isNotEmpty);
    }
    for (int i = 0; i < _tracks.length; i++) {
      _foldOpen['feat-$i'] = _tracks[i].others.isNotEmpty;
    }
    _applyLock();
  }

  // ── COVER / COMPILATION RULE (same as web applyCoverLock) ────────────
  bool get _forceNo =>
      _v['publicDomain'] != 'No' ||
      _v['compilation'] == 'Yes' ||
      _v['original'] == 'No' ||
      RegExp('cover', caseSensitive: false).hasMatch(_versionCtrl.text);

  void _applyLock() {
    final force = _forceNo;
    _lastForce = force;
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
      _applyLock();
    });
  }

  // ── GENRE LOGIC ──────────────────────────────────────────────────────
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

  // ── PICKER SHEETS ────────────────────────────────────────────────────
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

  Future<void> _pickReleaseDate() async {
    FocusScope.of(context).unfocus();
    final today = _today();
    final min = DateTime(today.year, today.month, today.day + 3);
    final max = DateTime(today.year + 5, today.month, today.day);
    final init = (_releaseDate != null && !_releaseDate!.isBefore(min)) ? _releaseDate! : min;
    final d = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _DateSheet(title: 'Release date', min: min, max: max, initial: init),
    );
    if (d != null && mounted) setState(() => _releaseDate = d);
  }

  // ── FILE PICKERS ─────────────────────────────────────────────────────
  Future<void> _pickAudio(int i) async {
    if (_busy) return;
    const group = XTypeGroup(
      label: 'WAV',
      extensions: ['wav'],
      mimeTypes: ['audio/wav', 'audio/x-wav', 'audio/wave', 'audio/vnd.wave'],
    );
    final XFile? x = await openFile(acceptedTypeGroups: [group]);
    if (x == null || !mounted) return;
    final t = _tracks[i];
    final ext = x.name.split('.').last.toLowerCase();
    final size = await x.length();
    String problem = '';
    if (ext != 'wav') {
      problem = '.$ext files are not accepted. Please select a WAV file only.';
    } else if (size > 100 * 1024 * 1024) {
      problem = 'File exceeds the 100 MB limit.';
    } else {
      problem = await _checkWav(File(x.path));
    }
    if (!mounted) return;
    setState(() {
      if (problem.isNotEmpty) {
        t.error = problem;
      } else {
        t.picked = _Picked(File(x.path), x.name, size);
        t.error = '';
        t.newUrl = null;
      }
    });
  }

  Future<void> _pickCover() async {
    if (_busy) return;
    const group = XTypeGroup(
      label: 'JPG',
      extensions: ['jpg', 'jpeg'],
      mimeTypes: ['image/jpeg'],
    );
    final XFile? x = await openFile(acceptedTypeGroups: [group]);
    if (x == null || !mounted) return;
    final size = await x.length();
    final bytes = await x.readAsBytes();
    String problem = _checkCover(bytes, x.name);
    if (problem.isEmpty && size > 40 * 1024 * 1024) problem = 'Cover art is too large. Keep it under 40 MB.';
    if (!mounted) return;
    setState(() {
      if (problem.isNotEmpty) {
        _cover.error = problem;
      } else {
        _cover.picked = _Picked(File(x.path), x.name, size);
        _cover.error = '';
        _cover.newUrl = null;
      }
    });
  }

  Future<void> _pickLicense() async {
    if (_busy) return;
    const group = XTypeGroup(label: 'PDF', extensions: ['pdf'], mimeTypes: ['application/pdf']);
    final XFile? x = await openFile(acceptedTypeGroups: [group]);
    if (x == null || !mounted) return;
    if (!RegExp(r'\.pdf$', caseSensitive: false).hasMatch(x.name)) {
      setState(() => _licenseError = 'Only PDF files are accepted.');
      return;
    }
    final size = await x.length();
    if (!mounted) return;
    setState(() {
      _licensePicked = _Picked(File(x.path), x.name, size);
      _licenseError = '';
      _licenseNewUrl = null;
    });
  }

  Future<void> _playCurrent(_Track t) async {
    try {
      final u = await _resolvePlayUrl(t.url);
      if (u.isEmpty) return;
      final uri = Uri.tryParse(u);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  // ── VALIDATION (same order + messages as web) ────────────────────────
  List<String> _currentMains() {
    final out = <String>[];
    for (final t in _tracks) {
      final artists = t.orig['artists'];
      if (artists is! List) continue;
      for (final a in artists) {
        if (a is Map && a['type'] == 'main' && (a['name'] ?? '').toString().isNotEmpty) {
          final n = a['name'].toString();
          if (!out.any((x) => x.toLowerCase() == n.toLowerCase())) out.add(n);
        }
      }
    }
    return out;
  }

  // Renaming the artist also renames the Main artist on every track.
  ({Map<String, String> map, String? error}) _computeRename(String newName) {
    if (newName == (_data['artistName'] ?? '').toString().trim()) return (map: <String, String>{}, error: null);
    final mains = _currentMains();
    if (mains.isEmpty) return (map: <String, String>{}, error: null);
    if (mains.length == 1) return (map: {mains[0].toLowerCase(): newName}, error: null);
    final parts = newName.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.length != mains.length) {
      return (
        map: <String, String>{},
        error: 'This release has ${mains.length} main artists. Keep ${mains.length} names separated by commas.'
      );
    }
    final map = <String, String>{};
    for (int i = 0; i < mains.length; i++) {
      map[mains[i].toLowerCase()] = parts[i];
    }
    return (map: map, error: null);
  }

  List<CreditEntry> _named(String type) => _credits[type]!.where((c) => c.name.trim().isNotEmpty).toList();

  _Problem? _validateFix() {
    if (_cover.required && _cover.picked == null) {
      return _Problem(
        _cover.url.isNotEmpty ? "Your current cover isn't a JPG. Please upload a 4000 × 4000 JPG." : 'Cover art is required.',
        'coverHero',
      );
    }
    for (int i = 0; i < _tracks.length; i++) {
      if (_tracks[i].required && _tracks[i].picked == null) {
        return _Problem(_isSingle ? 'Please choose a WAV file.' : 'Please choose a WAV file for track ${i + 1}.', 'trkAudio-$i');
      }
    }
    if (!_isSingle) {
      for (int i = 0; i < _tracks.length; i++) {
        if (_tracks[i].titleCtrl.text.trim().isEmpty) return _Problem('Track ${i + 1} needs a title.', 'trkTitle-$i');
      }
    }
    final artistName = _artistCtrl.text.trim();
    if (artistName.isEmpty) return const _Problem('Artist name is required.', 'artistName');
    final nameParts = _currentMains().length > 1 ? artistName.split(',').map((s) => s.trim()).toList() : [artistName];
    for (final p in nameParts) {
      final bad = _badNameChars(p);
      if (bad.isNotEmpty) return _Problem(_nameMsg(p, bad, 'Artist name'), 'artistName');
    }
    final rename = _computeRename(artistName);
    if (rename.error != null) return _Problem(rename.error!, 'artistName');
    if (_titleCtrl.text.trim().isEmpty) return const _Problem('Release title is required.', 'releaseTitle');

    final mainNow = <String>{};
    for (final t in _tracks) {
      final artists = t.orig['artists'];
      if (artists is! List) continue;
      for (final a in artists) {
        if (a is Map && a['type'] == 'main' && (a['name'] ?? '').toString().isNotEmpty) {
          final n = a['name'].toString();
          mainNow.add((rename.map[n.toLowerCase()] ?? n).trim().toLowerCase());
        }
      }
    }
    for (int i = 0; i < _tracks.length; i++) {
      final seen = <String>{};
      for (final a in _tracks[i].others) {
        final n = a.name.trim().toLowerCase();
        if (n.isEmpty) continue;
        final badF = _badNameChars(a.name);
        if (badF.isNotEmpty) return _Problem(_nameMsg(a.name.trim(), badF, 'Featured artist'), 'fold-feat-$i', fold: 'feat-$i');
        final where = _isSingle ? '' : ' on track ${i + 1}';
        if (mainNow.contains(n)) {
          return _Problem('"${a.name.trim()}" is already a main artist$where. Remove it from featured artists.', 'fold-feat-$i', fold: 'feat-$i');
        }
        if (seen.contains(n)) return _Problem('"${a.name.trim()}" is listed twice$where.', 'fold-feat-$i', fold: 'feat-$i');
        seen.add(n);
      }
    }

    if (_genre.isEmpty) return const _Problem('Please select a genre.', 'genre');
    if (_subList.isNotEmpty && _genreSub.isEmpty) return const _Problem('Please select a sub genre for your genre.', 'genreSub');
    if (_tracks.length > 1 && _releaseType == 'Single') {
      return const _Problem('A release with more than one track must be an EP or Album.', 'releaseType');
    }
    if (_tracks.length == 1 && _releaseType != 'Single') {
      return const _Problem('A release with one track must be a Single.', 'releaseType');
    }
    if (_language.isEmpty) return const _Problem('Please select a language.', 'language');
    if (_releaseDate == null) return const _Problem('Please choose a release date.', 'releaseDate');
    if (_ymd(_releaseDate!).compareTo(_minDate) < 0) {
      return const _Problem('The earliest release date is 3 days from today.', 'releaseDate');
    }
    final copyright = _copyrightCtrl.text.trim();
    if (copyright.isEmpty) return const _Problem('Please enter the copyright holder.', 'copyright');
    if (copyright != (_data['copyright'] ?? '').toString().trim()) {
      final confirm = _confirmCtrl.text.trim();
      if (confirm.isEmpty) return const _Problem('Please type the copyright holder again to confirm it.', 'copyrightConfirm');
      if (copyright != confirm) return const _Problem("The two copyright holder entries don't match.", 'copyrightConfirm');
    }
    if (_named('producer').isEmpty) return const _Problem('Please add at least one producer.', 'fold-producer', fold: 'producer');
    final writers = _named('writer');
    if (writers.isEmpty) return const _Problem('Please add at least one songwriter.', 'fold-writer', fold: 'writer');
    bool isLyric(CreditEntry w) => RegExp(r'lyric|author|word').hasMatch(w.role.toLowerCase());
    bool isComp(CreditEntry w) => RegExp(r'compos|music|melod').hasMatch(w.role.toLowerCase());
    if (!writers.any((w) => isLyric(w) || !isComp(w))) {
      return const _Problem('Add at least one lyricist or songwriter.', 'fold-writer', fold: 'writer');
    }
    if (!writers.any((w) => isComp(w) || !isLyric(w))) {
      return const _Problem('Add at least one composer or songwriter.', 'fold-writer', fold: 'writer');
    }
    if (_named('publishing').isEmpty) return const _Problem('Please add at least one publisher.', 'fold-publishing', fold: 'publishing');
    return null;
  }

  _Problem? _validateLicense() {
    for (int i = 0; i < _tracks.length; i++) {
      if (_tracks[i].required && _tracks[i].picked == null) {
        return _Problem(_isSingle ? 'Please choose a WAV file.' : 'Please choose a WAV file for track ${i + 1}.', 'trkAudio-$i');
      }
    }
    if (_licensePicked == null) return const _Problem('Please upload your license / proof document.', 'licenseGroup');
    return null;
  }

  void _showProblem(_Problem p) {
    setState(() {
      _status = p.msg;
      if (p.fold != null) _foldOpen[p.fold!] = true;
      _invalid = p.el;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[p.el]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      }
    });
  }

  // ── ADMIN EMAIL (same endpoint + field names as web) ─────────────────
  String _fmtCreditList(dynamic list) {
    if (list is! List) return 'None';
    final filtered = list.whereType<Map>().where((c) => (c['name'] ?? '').toString().trim().isNotEmpty).toList();
    if (filtered.isEmpty) return 'None';
    return filtered.map((c) {
      var line = '• ${c['name']}';
      if ((c['role'] ?? '').toString().isNotEmpty) line += ' — ${c['role']}';
      if ((c['ipi'] ?? '').toString().isNotEmpty) line += ' (IPI: ${c['ipi']})';
      return line;
    }).join('\n');
  }

  String _featuringText(Map<String, dynamic> d) {
    const label = {'featured': 'Featured', 'secondary': 'Secondary'};
    final lines = <String>[];
    final files = d['audioFiles'] is List ? d['audioFiles'] as List : const [];
    for (int i = 0; i < files.length; i++) {
      final t = files[i];
      if (t is! Map) continue;
      final artists = t['artists'] is List ? t['artists'] as List : const [];
      final others = artists.whereType<Map>().where((a) => a['type'] != 'main' && (a['name'] ?? '').toString().isNotEmpty).toList();
      if (others.isNotEmpty) {
        final title = (t['title'] ?? '').toString();
        lines.add('Track ${i + 1}${title.isNotEmpty ? ' — $title' : ''}: ${others.map((a) => '${a['name']} (${label[a['type']] ?? a['type']})').join(', ')}');
      }
    }
    if (lines.isNotEmpty) return lines.join('\n');
    final fa = d['featuredArtists'];
    if (fa is List && fa.whereType<Map>().any((f) => (f['name'] ?? '').toString().isNotEmpty)) {
      return fa.whereType<Map>().where((f) => (f['name'] ?? '').toString().isNotEmpty).map((f) {
        var line = '${f['name']}';
        if ((f['role'] ?? '').toString().isNotEmpty) line += ' (${f['role']})';
        if ((f['url'] ?? '').toString().trim().isNotEmpty) line += ' — ${f['url']}';
        return line;
      }).join('\n');
    }
    final f = (d['featuring'] ?? '').toString().trim();
    return f.isNotEmpty ? f : 'None';
  }

  String _or(dynamic v, String fallback) => (v ?? '').toString().isEmpty ? fallback : v.toString();

  Future<Map<String, dynamic>> _notifyAdmin(Map<String, dynamic> d, String kind, [String? licenseUrl]) async {
    final credits = d['credits'] is Map ? d['credits'] as Map : const {};
    final audioFiles = (d['audioFiles'] is List ? d['audioFiles'] as List : const [])
        .whereType<Map>()
        .map((m) => {'title': (m['title'] ?? d['releaseTitle'] ?? '').toString(), 'url': (m['url'] ?? '').toString()})
        .where((m) => m['url']!.isNotEmpty)
        .toList();
    final body = {
      'type': 'resubmission',
      'submissionId': d['_id'],
      'is_resend': true,
      'email': _or(d['email'], ''),
      'artist_name': _or(d['artistName'], ''),
      'release_title': _or(d['releaseTitle'], ''),
      'featuring': _featuringText(d),
      'release_type': _or(d['releaseType'], ''),
      'genre': _or(d['genre'], ''),
      'language': _or(d['language'], 'Not specified'),
      'release_date': _or(d['releaseDate'], 'Not set'),
      'explicit': _or(d['explicit'], ''),
      'country': _or(d['country'], ''),
      'phone': _or(d['phone'], 'Not provided'),
      'label': _or(d['label'], 'Independent'),
      'copyright': _or(d['copyright'], 'Not provided'),
      'isrc': _or(d['isrc'], 'Not provided'),
      'upc': _or(d['upc'], 'Auto-assign'),
      'catalog_number': _or(d['catalogNumber'], 'Not provided'),
      'version': _or(d['version'], ''),
      'previously_released': _or(d['previouslyReleased'], ''),
      'previous_release_date': _or(d['previousReleaseDate'], 'N/A'),
      'vocal_type': _or(d['vocalType'], ''),
      'ownership_confirmed': d['ownershipConfirmed'] == true ? 'Yes — confirmed original work' : 'Not confirmed',
      'producers': _fmtCreditList(credits['producer']),
      'musicians': _fmtCreditList(credits['musician']),
      'songwriters': _fmtCreditList(credits['writer']),
      'publishers': _fmtCreditList(credits['publishing']),
      'lyrics': _or(d['lyrics'], 'Not provided'),
      'payment_status': (d['paid'] ?? '').toString().toLowerCase() == 'paid' ? 'Paid' : 'Not confirmed',
      'category': _or(d['rejectionCategory'], 'Other').trim(),
      'previous_reason': (d['rejectionReason'] ?? '').toString().trim(),
      'fix_kind': kind,
      if (licenseUrl != null) 'fix_license_url': licenseUrl,
      'cover_url': _or(d['officialCoverURL'], _or(d['coverURL'], '')),
      'audio_files': audioFiles,
      'status': 'Review',
      'submitted_at': DateTime.now().toString(),
    };
    try {
      final res = await http
          .post(
            Uri.parse(_notifyUrl),
            headers: {'Content-Type': 'application/json', 'x-app-secret': _appSecret},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      debugPrint('[Notify resubmit] status=${res.statusCode} body=${res.body}');
      return {'ok': res.statusCode >= 200 && res.statusCode < 300, 'status': res.statusCode};
    } catch (e) {
      debugPrint('[Notify resubmit] ERROR: $e');
      return {'ok': false, 'status': 0};
    }
  }

  void _cleanupOldAudio() {
    final oldKeys = _tracks
        .where((t) => t.newUrl != null && t.url.startsWith('r2:'))
        .map((t) => t.url.substring(3))
        .toList();
    if (oldKeys.isEmpty) return;
    FirebaseAuth.instance.currentUser?.getIdToken().then((token) => http.post(
          Uri.parse('$_backendUrl/api/audio/cleanup'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({'submissionId': _id, 'keys': oldKeys}),
        )).catchError((_) => http.Response('', 500));
  }

  void _setBtn(String s) {
    if (mounted) setState(() => _btnLabel = s);
  }

  Future<void> _uploadNewAudio() async {
    for (int i = 0; i < _tracks.length; i++) {
      final t = _tracks[i];
      if (t.picked != null && t.newUrl == null) {
        final label = _isSingle ? 'audio' : 'track ${i + 1}';
        _setBtn('Uploading $label…');
        final key = await _uploadWavToR2(t.picked!.file, (p) => _setBtn('Uploading $label… $p%'));
        t.newUrl = 'r2:$key';
      }
    }
  }

  // ── SUBMIT: LICENSE MODE ─────────────────────────────────────────────
  Future<Map<String, dynamic>> _submitLicense() async {
    if (_licenseNewUrl == null) {
      _setBtn('Uploading…');
      _licenseNewUrl = await _uploadToCloudinary(_licensePicked!.file, 'license-proofs', (p) => _setBtn('Uploading… $p%'));
    }
    await _uploadNewAudio();

    final audioFiles = <Map<String, dynamic>>[];
    for (int i = 0; i < _tracks.length; i++) {
      final t = _tracks[i];
      final o = Map<String, dynamic>.from(t.orig);
      if (!_isSingle && t.titleCtrl.text.trim().isNotEmpty) o['title'] = t.titleCtrl.text.trim();
      o['url'] = t.newUrl ?? t.url;
      if (o['url'].toString().startsWith('r2:')) {
        o['key'] = o['url'].toString().substring(3);
      } else {
        o.remove('key');
      }
      audioFiles.add(o);
    }
    _setBtn('Saving…');
    await FirebaseFirestore.instance.collection('submissions').doc(_id).update({
      'status': 'Review',
      'rejectionReason': FieldValue.delete(),
      'rejectionCategory': FieldValue.delete(),
      'resubmittedAt': FieldValue.serverTimestamp(),
      'licenseURL': _licenseNewUrl,
      'audioFiles': audioFiles,
      'audioDeleted': FieldValue.delete(),
    });
    _cleanupOldAudio();
    return _notifyAdmin({..._data, 'audioFiles': audioFiles}, 'license', _licenseNewUrl);
  }

  // ── SUBMIT: FIX MODE ─────────────────────────────────────────────────
  Map<String, dynamic> _answers() {
    bool yes(String k) => _v[k] == 'Yes';
    return {
      'vocalType': _v['vocal'],
      'isOriginal': yes('original'),
      'publicDomainStatus': _v['publicDomain'],
      'isCompilation': yes('compilation'),
      'hasLicense': yes('license2'),
      'hasUsBroadcastRights': yes('broadcast'),
      'agreements': {
        'soundexchange': yes('agSoundExchange'),
        'youtube_music': yes('agYoutubeMusic'),
        'youtube_content_id': yes('agContentId'),
        'facebook_monetization': yes('agFacebook'),
        'tiktok_monetization': yes('agTiktok'),
        'licensing': yes('agLicensing'),
        'avvo_youtube_channel': yes('agAvvoYoutube'),
      },
    };
  }

  Future<Map<String, dynamic>> _submitFix() async {
    final artistName = _artistCtrl.text.trim();
    final releaseTitle = _titleCtrl.text.trim();
    final copyright = _copyrightCtrl.text.trim();
    final rename = _computeRename(artistName).map;

    if (_cover.picked != null && _cover.newUrl == null) {
      _setBtn('Uploading cover…');
      _cover.newUrl = await _uploadToCloudinary(_cover.picked!.file, 'covers', (p) => _setBtn('Uploading cover… $p%'));
    }
    await _uploadNewAudio();

    final audioFiles = <Map<String, dynamic>>[];
    for (int i = 0; i < _tracks.length; i++) {
      final t = _tracks[i];
      final o = Map<String, dynamic>.from(t.orig);
      o['title'] = _isSingle ? releaseTitle : t.titleCtrl.text.trim();
      o['url'] = t.newUrl ?? t.url;
      if (o['url'].toString().startsWith('r2:')) {
        o['key'] = o['url'].toString().substring(3);
      } else {
        o.remove('key');
      }
      if (t.orig['artists'] is List) {
        o['artists'] = (t.orig['artists'] as List)
            .whereType<Map>()
            .where((a) => a['type'] == 'main')
            .map((a) {
          final n = (a['name'] ?? '').toString().isNotEmpty ? rename[a['name'].toString().toLowerCase()] : null;
          final m = Map<String, dynamic>.from(a);
          if (n != null) m['name'] = n;
          return m;
        }).toList();
      }
      final mains = o['artists'] is List ? List<dynamic>.from(o['artists'] as List) : <dynamic>[];
      final extras = t.others
          .where((a) => a.name.trim().isNotEmpty)
          .map((a) => <String, dynamic>{
                'name': a.name.trim(),
                'type': 'featured',
                'spotifyUrl': a.spotifyUrl.trim(),
                'appleUrl': a.appleUrl.trim(),
              })
          .toList();
      if (mains.isEmpty && extras.isNotEmpty) {
        mains.add({'name': artistName, 'type': 'main', 'spotifyUrl': '', 'appleUrl': ''});
      }
      if (mains.isNotEmpty || extras.isNotEmpty) o['artists'] = [...mains, ...extras];
      audioFiles.add(o);
    }

    List<Map<String, String>> trim(String type, bool withIpi) => _named(type)
        .map((c) => withIpi
            ? {'name': c.name.trim(), 'role': c.role, 'ipi': c.ipi.trim()}
            : {'name': c.name.trim(), 'role': c.role})
        .toList();
    final old = _data['credits'] is Map ? Map<String, dynamic>.from(_data['credits'] as Map) : <String, dynamic>{};
    final credits = {
      ...old,
      'producer': trim('producer', false),
      'musician': old['musician'] is List ? old['musician'] : [],
      'writer': trim('writer', true),
      'publishing': trim('publishing', false),
    };

    final answers = _answers();
    final payload = <String, dynamic>{
      'status': 'Review',
      'rejectionReason': FieldValue.delete(),
      'rejectionCategory': FieldValue.delete(),
      'resubmittedAt': FieldValue.serverTimestamp(),
      'artistName': artistName,
      'releaseTitle': releaseTitle,
      'genre': _genre,
      'language': _language,
      'explicit': _explicit,
      'copyright': copyright,
      'credits': credits,
      'audioFiles': audioFiles,
      'releaseType': _releaseType,
      'mainGenreSub': _genreSub,
      'alternateGenre': _altGenre,
      'alternateGenreSub': _altGenreSub,
      'version': _versionCtrl.text.trim(),
      'productVersion': _productCtrl.text.trim(),
      ...answers,
      'featuredArtists': audioFiles
          .map((t) => {
                'track': t['title'] ?? '',
                'artists': (t['artists'] is List ? t['artists'] as List : const [])
                    .whereType<Map>()
                    .map((a) => {
                          'name': a['name'] ?? '',
                          'type': a['type'] ?? 'featured',
                          'spotifyUrl': a['spotifyUrl'] ?? '',
                          'appleUrl': a['appleUrl'] ?? '',
                        })
                    .toList(),
              })
          .toList(),
    };
    final newDate = _ymd(_releaseDate!);
    if (newDate != _origDate) payload['releaseDate'] = _toIsoOrEmpty(newDate);
    if (_cover.newUrl != null) {
      payload['resubmittedCoverURL'] = _cover.newUrl;
      payload['coverURL'] = _cover.newUrl;
      payload['officialCoverURL'] = _cover.newUrl;
    }
    final firstNew = _tracks.where((t) => t.newUrl != null).toList();
    if (firstNew.isNotEmpty) payload['resubmittedAudioURL'] = firstNew.first.newUrl;

    _setBtn('Saving…');
    await FirebaseFirestore.instance.collection('submissions').doc(_id).update(payload);
    _cleanupOldAudio();

    final merged = <String, dynamic>{
      ..._data,
      'artistName': artistName,
      'releaseTitle': releaseTitle,
      'genre': _genre,
      'language': _language,
      'explicit': _explicit,
      'copyright': copyright,
      'credits': credits,
      'audioFiles': audioFiles,
      'releaseType': _releaseType,
      'version': _versionCtrl.text.trim(),
      'vocalType': answers['vocalType'],
    };
    if (payload['releaseDate'] != null) merged['releaseDate'] = payload['releaseDate'];
    if (_cover.newUrl != null) {
      merged['coverURL'] = _cover.newUrl;
      merged['officialCoverURL'] = _cover.newUrl;
    }
    return _notifyAdmin(merged, 'audio_and_cover');
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _status = '');
    final problem = _copyrightMode ? _validateLicense() : _validateFix();
    if (problem != null) {
      _showProblem(problem);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _btnLabel = 'Submitting…';
      _invalid = null;
    });
    try {
      final result = _copyrightMode ? await _submitLicense() : await _submitFix();
      if (!mounted) return;
      final ok = result['ok'] == true;
      setState(() {
        _done = true;
        _notifyOk = ok;
        _notifyStatus = (result['status'] as int?) ?? 0;
      });
      await Future.delayed(Duration(milliseconds: ok ? 1400 : 3200));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[Resubmit] ERROR: $e');
      if (!mounted) return;
      final msg = _errText(e);
      setState(() {
        _busy = false;
        _btnLabel = 'Resubmit for review';
        _status = msg.isEmpty ? 'Something went wrong saving your fix. Please try again.' : msg;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final narrow = MediaQuery.of(context).size.width <= 420;

    Widget body;
    if (_showState) {
      body = _stateView();
    } else if (_done) {
      body = _successView();
    } else {
      body = _form(narrow);
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          body,
          Positioned(top: 0, left: 0, right: 0, child: _topBar(top)),
          if (!_showState && !_done) Positioned(bottom: 0, left: 0, right: 0, child: _dock(bottom)),
        ],
      ),
    );
  }

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
              Text('Fix release', style: _ts(17, FontWeight.w600, _t1)),
              const SizedBox(width: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stateView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: _fill, shape: BoxShape.circle),
              child: const Icon(Icons.info_outline_rounded, color: _t1, size: 30),
            ),
            const SizedBox(height: 18),
            Text(_stateTitle, style: _ts(22, FontWeight.w700, _t1, em: -0.03)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(_stateSub, textAlign: TextAlign.center, style: _ts(15, FontWeight.w400, _t2, height: 1.4)),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(999)),
                child: Text('Go back', style: _ts(16, FontWeight.w600, _t1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _successView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: Color(0x2930D158), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: _green, size: 30),
            ),
            const SizedBox(height: 18),
            Text('Sent for review', style: _ts(22, FontWeight.w700, _t1, em: -0.03)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                _notifyOk
                    ? "We'll take another look. No payment needed."
                    : "Your fix was saved, but we couldn't reach the admin notification service (status $_notifyStatus). The team may not see it until that's checked.",
                textAlign: TextAlign.center,
                style: _ts(15, FontWeight.w400, _t2, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(bool narrow) {
    final top = MediaQuery.of(context).padding.top;
    final title = (_data['releaseTitle'] ?? 'Your release').toString();
    final artist = (_data['artistName'] ?? '').toString();
    final reason = (_data['rejectionReason'] ?? '').toString().trim();
    return Listener(
      onPointerDown: (_) {
        if (_invalid != null || _status.isNotEmpty) setState(() { _invalid = null; _status = ''; });
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fix & resubmit', style: _ts(narrow ? 30 : 34, FontWeight.w700, _t1, em: -0.04, height: 1.1)),
                        const SizedBox(height: 6),
                        Text('$title${artist.isNotEmpty ? ' by $artist' : ''}', style: _ts(17, FontWeight.w400, _t2)),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0x1FFF453A), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.info_outline_rounded, color: _rose, size: 18),
                          const SizedBox(width: 8),
                          Text(_copyrightMode ? 'License needed' : 'Needs a fix', style: _ts(15, FontWeight.w600, _rose)),
                        ]),
                        if (reason.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(reason, style: _ts(16, FontWeight.w400, _t1, height: 1.45)),
                        ],
                      ],
                    ),
                  ),
                  ..._copyrightMode ? _licenseSections() : _fixSections(narrow),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── LICENSE MODE ─────────────────────────────────────────────────────
  List<Widget> _licenseSections() {
    return [
      _sh(_isSingle ? 'Audio' : 'Tracks', right: _tracks.any((t) => t.required) ? 'Required' : 'Optional', req: _tracks.any((t) => t.required)),
      for (int i = 0; i < _tracks.length; i++) _trackShell(i),
      _sh('License or proof', right: 'Required', req: true),
      KeyedSubtree(
        key: _k('licenseGroup'),
        child: _Group(invalid: _invalid == 'licenseGroup', children: [
          _zone(
            icon: Icons.description_outlined,
            picked: _licensePicked,
            title: 'Choose PDF',
            sub: 'PDF only',
            error: _licenseError,
            onTap: _pickLicense,
          ),
        ]),
      ),
      _sf('A license, purchase receipt, or written permission for the beat. PDF only.'),
      _sf('No proof yet? You can leave this and come back. Your release stays Rejected until you upload it.'),
    ];
  }

  // ── FIX MODE ─────────────────────────────────────────────────────────
  List<Widget> _fixSections(bool narrow) {
    final anyAudioReq = _tracks.any((t) => t.required);
    final typeLocked = _tracks.length == 1;
    final subDisabled = _genre.isEmpty || _subList.isEmpty;
    final minW = narrow ? 66.0 : 78.0;
    final padH = narrow ? 10.0 : 14.0;
    return [
      _sh('Cover art', right: _cover.required ? 'Required' : 'Optional', req: _cover.required),
      KeyedSubtree(key: _k('coverHero'), child: _coverHero()),
      if (_cover.error.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: _rose, size: 14),
              const SizedBox(width: 6),
              Flexible(child: Text(_cover.error, style: _ts(13, FontWeight.w500, _rose, height: 1.35))),
            ],
          ),
        ),
      _sf("${_cover.required && _cover.url.isNotEmpty ? "Your current cover isn't a JPG. " : ''}Use a 4000 × 4000 px RGB JPG. The artist name and title on the cover must match the details below."),

      _sh(_isSingle ? 'Audio' : 'Tracks', right: anyAudioReq ? 'Required' : 'Optional', req: anyAudioReq),
      for (int i = 0; i < _tracks.length; i++) _trackShell(i),

      _sh('Featured artists', right: 'Optional'),
      for (int i = 0; i < _tracks.length; i++) _featFold(i),
      _sf('Add anyone featured on a track. Main artists come from the Artist field below.'),

      _sh('Release', right: 'Required', req: true),
      _Group(children: [
        _InputRow(rowKey: _k('artistName'), label: 'Artist', ctrl: _artistCtrl, hint: 'Artist name', invalid: _invalid == 'artistName'),
        _InputRow(rowKey: _k('releaseTitle'), label: 'Title', ctrl: _titleCtrl, hint: 'Name of your release', invalid: _invalid == 'releaseTitle'),
        _selectRow(
          id: 'releaseType', label: 'Type', value: _releaseType, placeholder: 'Select', dim: typeLocked,
          onTap: typeLocked
              ? null
              : () async {
                  final multi = _tracks.length > 1;
                  final p = await _pickOption('Type', _types.map((t) => _Opt(t, t, disabled: multi && t == 'Single')).toList(), _releaseType);
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
          placeholder: _genre.isEmpty ? 'Pick genre first' : (_subList.isEmpty ? 'Not needed for this genre' : 'Select'),
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
        _InputRow(label: 'Version', ctrl: _versionCtrl, hint: 'e.g. Original, Remix, Cover'),
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
        _dateRow(),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(
          _dateTooSoon
              ? 'Your original date has passed or is too close. Choose a new one, at least 3 days from today.'
              : 'Earliest date is 3 days from today. 14 days or more is recommended.',
          style: _ts(13, FontWeight.w400, _dateTooSoon ? _rose : _t2, height: 1.4),
        ),
      ),

      _sh('Copyright', right: 'Required', req: true),
      _Group(children: [
        _InputRow(rowKey: _k('copyright'), label: 'Copyright holder', ctrl: _copyrightCtrl, hint: 'Required', invalid: _invalid == 'copyright'),
        if (_copyChanged)
          _InputRow(rowKey: _k('copyrightConfirm'), label: 'Confirm holder', ctrl: _confirmCtrl, hint: 'Type it again', invalid: _invalid == 'copyrightConfirm'),
      ]),

      _sh('Your song', right: 'Required', req: true),
      _Group(children: [
        _segRow('Vocals', 'vocal', const ['Vocals', 'Instrumental'], minW, padH),
        _segRow('Original work', 'original', const ['Yes', 'No'], minW, padH),
        _segRow('Cover, karaoke, tribute or sound-alike?', 'publicDomain', const ['No', 'Yes', 'Not Sure'], 0, 10),
        _segRow('Compilation', 'compilation', const ['No', 'Yes'], minW, padH),
        _segRow('You hold a license', 'license2', const ['Yes', 'No'], minW, padH),
        _segRow('US broadcast rights', 'broadcast', const ['Yes', 'No'], minW, padH),
        _InputRow(label: 'Product version', ctrl: _productCtrl, hint: 'Optional'),
      ]),
      _sf("Answer honestly. For a cover, a sample-based song or a song you don't fully own, change the answers."),

      _sh('Platforms & monetization', right: 'Required', req: true),
      _Group(children: [
        _segRow('SoundExchange', 'agSoundExchange', const ['Yes', 'No'], minW, padH),
        _segRow('YouTube Music', 'agYoutubeMusic', const ['Yes', 'No'], minW, padH),
        _segRow('YouTube Content ID', 'agContentId', const ['Yes', 'No'], minW, padH, locked: _forceNo),
        _segRow('Facebook / Instagram', 'agFacebook', const ['Yes', 'No'], minW, padH, locked: _forceNo),
        _segRow('TikTok exclusive', 'agTiktok', const ['Yes', 'No'], minW, padH, locked: _forceNo),
        _segRow('Licensing offers', 'agLicensing', const ['Yes', 'No'], minW, padH),
        _segRow('444 YouTube channel', 'agAvvoYoutube', const ['Yes', 'No'], minW, padH),
      ]),
      _sf('Content ID, Facebook and TikTok switch to No automatically for covers, samples and compilations.'),

      _sh('Credits', right: 'Required', req: true),
      for (final type in _creditTypes) _creditFold(type),
      _sf('No publisher? Enter your own name.'),
    ];
  }

  // ── SECTION BITS ─────────────────────────────────────────────────────
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

  Widget _ferr(String msg) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.error_outline_rounded, color: _rose, size: 14)),
            const SizedBox(width: 6),
            Expanded(child: Text(msg, style: _ts(13, FontWeight.w500, _rose, height: 1.35))),
          ],
        ),
      );

  // ── COVER HERO ───────────────────────────────────────────────────────
  Widget _coverHero() {
    final c = _cover;
    final hasSrc = c.picked != null || c.url.isNotEmpty;
    final badgeText = c.picked != null ? 'New' : (c.required ? 'Required' : 'Current');
    final badgeColor = c.picked != null ? _green : (c.required ? _yellow : _t2);
    final invalid = _invalid == 'coverHero';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: AspectRatio(
            aspectRatio: 1,
            child: GestureDetector(
              onTap: _pickCover,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: _s1,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    if (invalid) const BoxShadow(color: _rose, spreadRadius: 2),
                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 50, offset: const Offset(0, 18)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (c.picked != null)
                        Image.file(c.picked!.file, fit: BoxFit.cover)
                      else if (c.url.isNotEmpty)
                        _netCover(c.url)
                      else
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: const BoxDecoration(color: _yellow, shape: BoxShape.circle),
                                child: const Icon(Icons.add_rounded, color: Colors.black, size: 22),
                              ),
                              const SizedBox(height: 14),
                              Text('Add cover art', style: _ts(17, FontWeight.w600, _t1)),
                              const SizedBox(height: 4),
                              Text('4000 × 4000 px, JPG', style: _ts(13, FontWeight.w400, _t2)),
                            ],
                          ),
                        ),
                      Positioned(
                        top: 12, right: 12,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              color: Colors.black.withValues(alpha: 0.55),
                              child: Text(badgeText, style: _ts(12, FontWeight.w600, badgeColor)),
                            ),
                          ),
                        ),
                      ),
                      if (hasSrc)
                        Positioned(
                          bottom: 12, left: 0, right: 0,
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                  color: const Color(0xB31C1C1E),
                                  child: Text('Replace', style: _ts(14, FontWeight.w600, _t1)),
                                ),
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
        ),
      ),
    );
  }

  Widget _netCover(String url) {
    if (url.startsWith('data:image')) {
      try {
        return Image.memory(base64Decode(url.split(',').last), fit: BoxFit.cover);
      } catch (_) {
        return const SizedBox.shrink();
      }
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: _s1),
      errorWidget: (_, __, ___) => Container(color: _s1),
    );
  }

  // ── TRACK AUDIO ──────────────────────────────────────────────────────
  Widget _trackShell(int i) {
    final t = _tracks[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KeyedSubtree(
        key: _k('trkAudio-$i'),
        child: _Group(
          invalid: _invalid == 'trkAudio-$i',
          children: [
            if (!_isSingle)
              _InputRow(
                rowKey: _k('trkTitle-$i'),
                label: 'Track ${i + 1}',
                ctrl: t.titleCtrl,
                hint: 'Track title',
                invalid: _invalid == 'trkTitle-$i',
              ),
            _audioBlock(i),
          ],
        ),
      ),
    );
  }

  Widget _audioBlock(int i) {
    final t = _tracks[i];
    final needs = t.required && t.picked == null;
    final hasSrc = t.picked != null || t.url.isNotEmpty;
    final name = t.picked != null ? t.picked!.name : (t.url.isNotEmpty ? 'Current file' : 'No file yet');
    final sub = t.picked != null
        ? '${_fmtBytes(t.picked!.size)} · new file'
        : needs
            ? (t.url.isNotEmpty ? "This isn't a WAV. Replace it with a WAV: 16-bit+, 44.1 kHz+, stereo." : 'WAV, 16-bit+, 44.1 kHz+, stereo')
            : 'Tap Replace to upload a new WAV';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: t.error.isNotEmpty ? const Color(0x1FFF453A) : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ts(16, FontWeight.w500, _t1)),
                        const SizedBox(height: 2),
                        Text(sub, style: _ts(13, FontWeight.w400, _t2, height: 1.35)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _pickAudio(i),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: needs ? _yellow : _fill, borderRadius: BorderRadius.circular(999)),
                      child: Text(hasSrc ? 'Replace' : 'Choose WAV',
                          style: _ts(14, FontWeight.w600, needs ? Colors.black : _blue)),
                    ),
                  ),
                ],
              ),
              if (t.url.isNotEmpty && t.picked == null) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _playCurrent(t),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_fill_rounded, color: _blue, size: 22),
                      const SizedBox(width: 8),
                      Text('Play current file', style: _ts(15, FontWeight.w500, _blue)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (t.error.isNotEmpty) _ferr(t.error),
      ],
    );
  }

  Widget _zone({
    required IconData icon,
    required _Picked? picked,
    required String title,
    required String sub,
    required String error,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            color: error.isNotEmpty ? const Color(0x1FFF453A) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: picked != null ? _yellow : _t2, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(picked != null ? picked.name : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _ts(16, FontWeight.w500, picked != null ? _t1 : _yellow)),
                      const SizedBox(height: 2),
                      Text(picked != null ? '${_fmtBytes(picked.size)} · new file' : sub,
                          style: _ts(13, FontWeight.w400, _t2, height: 1.35)),
                    ],
                  ),
                ),
                if (picked != null) Text('Replace', style: _ts(14, FontWeight.w500, _blue)),
              ],
            ),
          ),
        ),
        if (error.isNotEmpty) _ferr(error),
      ],
    );
  }

  // ── FEATURED ARTISTS + CREDITS FOLDS ─────────────────────────────────
  Widget _featFold(int i) {
    final t = _tracks[i];
    final n = t.others.where((a) => a.name.trim().isNotEmpty).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KeyedSubtree(
        key: _k('fold-feat-$i'),
        child: _Fold(
          label: _isSingle ? 'Featured artists' : 'Track ${i + 1}',
          trailing: n > 0 ? '$n added' : 'Optional',
          trailingColor: _t3,
          open: _foldOpen['feat-$i'] ?? false,
          invalid: _invalid == 'fold-feat-$i',
          onToggle: () => setState(() => _foldOpen['feat-$i'] = !(_foldOpen['feat-$i'] ?? false)),
          children: [
            for (int k = 0; k < t.others.length; k++)
              _FeatRow(
                key: ObjectKey(t.others[k]),
                entry: t.others[k],
                label: 'Artist ${k + 1}',
                onRemove: () => setState(() => t.others.removeAt(k)),
                onCountChange: () => setState(() {}),
              ),
            _AddCreditButton(
              label: 'Add featured artist',
              onTap: () => setState(() => t.others.add(_Feat(autofocus: true))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _creditFold(String type) {
    final list = _credits[type]!;
    final n = list.where((c) => c.name.trim().isNotEmpty).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KeyedSubtree(
        key: _k('fold-$type'),
        child: _Fold(
          label: _foldTitle[type]!,
          trailing: n > 0 ? '$n added' : 'Required',
          trailingColor: n > 0 ? _t3 : _yellow,
          open: _foldOpen[type] ?? false,
          invalid: _invalid == 'fold-$type',
          onToggle: () => setState(() => _foldOpen[type] = !(_foldOpen[type] ?? false)),
          children: [
            for (int i = 0; i < list.length; i++)
              _CreditRow(
                key: ObjectKey(list[i]),
                entry: list[i],
                label: '${_noun[type]} ${i + 1}',
                namePh: _placeholder[type]!,
                showIpi: type == 'writer',
                onRemove: () => setState(() => list.removeAt(i)),
                onCountChange: () => setState(() {}),
                onPickRole: () async {
                  final base = _roles[type]!.toList();
                  if (list[i].role.isNotEmpty && !base.contains(list[i].role)) base.add(list[i].role);
                  final p = await _pickOption('Role', base.map((r) => _Opt(r, r)).toList(), list[i].role);
                  if (p != null && mounted) setState(() => list[i].role = p.value);
                },
              ),
            _AddCreditButton(
              label: _addLabel[type]!,
              onTap: () => setState(() => list.add(CreditEntry(autofocus: true))),
            ),
          ],
        ),
      ),
    );
  }

  // ── ROW BUILDERS ─────────────────────────────────────────────────────
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

  Widget _dateRow() {
    final invalid = _invalid == 'releaseDate';
    return KeyedSubtree(
      key: _k('releaseDate'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _pickReleaseDate,
        child: _RowShell(
          invalid: invalid,
          child: Row(
            children: [
              _Lbl('Release date', invalid: invalid),
              Expanded(
                child: Text(
                  _releaseDate == null ? 'dd/mm/yyyy' : _fmtDmy(_releaseDate!),
                  textAlign: TextAlign.right,
                  style: _ts(16, FontWeight.w400, _releaseDate == null ? _t3 : _t1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segRow(String label, String key, List<String> opts, double minW, double padH, {bool locked = false}) {
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
                    child: _Seg(options: opts, value: _v[key] ?? opts.first, minWidth: minW, padH: padH, onChanged: (val) => _setV(key, val)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── DOCK ─────────────────────────────────────────────────────────────
  Widget _dock(double bottom) {
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
                  if (_status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(_status, textAlign: TextAlign.center, style: _ts(14, FontWeight.w500, _rose, height: 1.35)),
                    ),
                  GestureDetector(
                    onTap: _busy ? null : _submit,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _busy ? 0.5 : 1,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _yellow, borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_busy)
                              const SizedBox(
                                width: 17, height: 17,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                              )
                            else
                              const Icon(Icons.check_rounded, color: Colors.black, size: 17),
                            const SizedBox(width: 8),
                            Flexible(child: Text(_btnLabel, overflow: TextOverflow.ellipsis, style: _ts(17, FontWeight.w600, Colors.black))),
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
  final bool invalid;
  final Key? rowKey;
  const _InputRow({required this.label, required this.ctrl, required this.hint, this.invalid = false, this.rowKey});
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
        onTap: _focus.requestFocus,
        child: _RowShell(
          invalid: widget.invalid,
          child: Row(
            children: [
              _Lbl(widget.label, invalid: widget.invalid),
              Expanded(
                child: TextField(
                  controller: widget.ctrl,
                  focusNode: _focus,
                  textAlign: TextAlign.right,
                  cursorColor: _t1,
                  style: _ts(16, FontWeight.w400, _t1),
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
  const _Seg({required this.options, required this.value, required this.onChanged, this.minWidth = 78, this.padH = 14});
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
                boxShadow: sel ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))] : const [],
              ),
              child: Text(o, style: _ts(14, FontWeight.w500, _t1)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Fold extends StatelessWidget {
  final String label, trailing;
  final Color trailingColor;
  final bool open, invalid;
  final VoidCallback onToggle;
  final List<Widget> children;
  const _Fold({
    required this.label,
    required this.trailing,
    required this.trailingColor,
    required this.open,
    required this.onToggle,
    required this.children,
    this.invalid = false,
  });

  @override
  Widget build(BuildContext context) {
    return _GroupBox(
      invalid: invalid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: _RowShell(
              child: Row(
                children: [
                  Expanded(child: Text(label, style: _ts(16, FontWeight.w400, _t1))),
                  Text(trailing, style: _ts(14, FontWeight.w400, trailingColor)),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: open ? 0.25 : 0,
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
            child: open
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _withSeps(children, leading: true))
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

InputDecoration _creditDec(String hint) => InputDecoration(
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

Widget _removeBtn(VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26, height: 26,
        decoration: const BoxDecoration(color: _fill, shape: BoxShape.circle),
        child: const Icon(Icons.close_rounded, color: _t2, size: 12),
      ),
    );

class _CreditRow extends StatefulWidget {
  final CreditEntry entry;
  final String label, namePh;
  final bool showIpi;
  final VoidCallback onRemove, onPickRole, onCountChange;
  const _CreditRow({
    super.key,
    required this.entry,
    required this.label,
    required this.namePh,
    required this.showIpi,
    required this.onRemove,
    required this.onPickRole,
    required this.onCountChange,
  });
  @override
  State<_CreditRow> createState() => _CreditRowState();
}

class _CreditRowState extends State<_CreditRow> {
  late final TextEditingController _name = TextEditingController(text: widget.entry.name);
  late final TextEditingController _ipi = TextEditingController(text: widget.entry.ipi);
  @override
  void dispose() { _name.dispose(); _ipi.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.label, style: _ts(13, FontWeight.w500, _t2)),
              _removeBtn(widget.onRemove),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            autofocus: e.autofocus,
            cursorColor: _t1,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              final was = e.name.trim().isEmpty;
              e.name = v;
              if (was != v.trim().isEmpty) widget.onCountChange();
            },
            style: _ts(16, FontWeight.w400, _t1),
            decoration: _creditDec(widget.namePh),
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
              decoration: _creditDec('IPI / CAE number (optional)'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatRow extends StatefulWidget {
  final _Feat entry;
  final String label;
  final VoidCallback onRemove, onCountChange;
  const _FeatRow({super.key, required this.entry, required this.label, required this.onRemove, required this.onCountChange});
  @override
  State<_FeatRow> createState() => _FeatRowState();
}

class _FeatRowState extends State<_FeatRow> {
  late final TextEditingController _name = TextEditingController(text: widget.entry.name);
  late final TextEditingController _sp = TextEditingController(text: widget.entry.spotifyUrl);
  late final TextEditingController _ap = TextEditingController(text: widget.entry.appleUrl);
  @override
  void dispose() { _name.dispose(); _sp.dispose(); _ap.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.label, style: _ts(13, FontWeight.w500, _t2)),
              _removeBtn(widget.onRemove),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            autofocus: e.autofocus,
            cursorColor: _t1,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              final was = e.name.trim().isEmpty;
              e.name = v;
              if (was != v.trim().isEmpty) widget.onCountChange();
            },
            style: _ts(16, FontWeight.w400, _t1),
            decoration: _creditDec('Artist name'),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Expanded(child: Text('Featured', style: _ts(16, FontWeight.w400, _t1))),
                const Icon(Icons.keyboard_arrow_down_rounded, color: _t3, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _sp,
            cursorColor: _t1,
            keyboardType: TextInputType.url,
            onChanged: (v) => e.spotifyUrl = v,
            style: _ts(16, FontWeight.w400, _t1),
            decoration: _creditDec('Spotify artist link (optional)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ap,
            cursorColor: _t1,
            keyboardType: TextInputType.url,
            onChanged: (v) => e.appleUrl = v,
            style: _ts(16, FontWeight.w400, _t1),
            decoration: _creditDec('Apple Music artist link (optional)'),
          ),
        ],
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
      decoration: const BoxDecoration(color: _s1, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
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
            Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(title, style: _ts(17, FontWeight.w600, _t1))),
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
      decoration: const BoxDecoration(color: _s1, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
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
                  textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: TextStyle(color: Colors.white, fontSize: 21)),
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
