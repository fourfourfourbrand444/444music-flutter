// 444MUSIC — Upload Files screen (step 1 of 3)
// Mirrors upload files.html: iOS grouped rows, large title, 3-step progress,
// 4000x4000 JPG cover check, WAV header check, R2 audio upload via backend,
// Cloudinary cover upload, artist sheet (Main on Track 1 only, Featured).
//
// pubspec needs: firebase_auth, google_fonts, http, image_picker, url_launcher

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── CONFIG ──────────────────────────────────────────────────────────
const _cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dlbgqtvqg/auto/upload';
const _cloudinaryPreset = 'glmamp2y';
const _backendUrl = 'https://four44music-broadcast-backend.onrender.com';

// ─── PALETTE (same tokens as the web page) ───────────────────────────
class _C {
  static const bg = Color(0xFF000000);
  static const s1 = Color(0xFF1C1C1E);
  static const s2 = Color(0xFF2C2C2E);
  static const s3 = Color(0xFF636366);
  static const sep = Color(0x8C545458);
  static const fill = Color(0x3D787880);
  static const t1 = Color(0xFFFFFFFF);
  static const t2 = Color(0x99EBEBF5);
  static const t3 = Color(0x4DEBEBF5);
  static const blue = Color(0xFF0A84FF);
  static const yellow = Color(0xFFFDEB0D);
  static const green = Color(0xFF30D158);
  static const rose = Color(0xFFFF453A);
  static const green14 = Color(0x2430D158);
  static const green16 = Color(0x2930D158);
  static const rose12 = Color(0x1FFF453A);
  static const rose14 = Color(0x24FF453A);
  static const bar = Color(0xB8000000);
}

TextStyle _ts(double s, FontWeight w, Color c, {double? ls, double? h}) =>
    GoogleFonts.inter(
      fontSize: s,
      fontWeight: w,
      color: c,
      letterSpacing: ls ?? -s * 0.011,
      height: h,
    );

// ─── MODELS ──────────────────────────────────────────────────────────
class ArtistEntry {
  String name;
  String type; // 'main' | 'featured'
  String spotifyUrl;
  String appleUrl;
  ArtistEntry({
    required this.name,
    this.type = 'featured',
    this.spotifyUrl = '',
    this.appleUrl = '',
  });

  Map<String, String> toMap() => {
        'name': name,
        'type': type,
        'spotifyUrl': spotifyUrl,
        'appleUrl': appleUrl,
      };
}

class TrackModel {
  final String id;
  final TextEditingController titleCtrl = TextEditingController();
  final List<ArtistEntry> artists = [];
  File? wavFile;
  String? wavName;
  int wavSize = 0;
  double progress = 0;
  String status = 'idle'; // idle | uploading | success | error
  String errorMsg = '';
  final Map<String, String> errors = {}; // title | artists | wav
  String? fileKey;
  TrackModel(this.id);
}

class _UpRow {
  final String name;
  final String status; // uploading | done | error
  final int pct;
  const _UpRow(this.name, this.status, this.pct);
}

// ─── SHARED HELPERS ──────────────────────────────────────────────────
String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

List<String> _badNameChars(String s) {
  final out = <String>[];
  for (final m in RegExp(r'[,<>{}\[\]"]').allMatches(s)) {
    final ch = m.group(0)!;
    if (!out.contains(ch)) out.add(ch);
  }
  var depth = 0;
  var broken = false;
  for (final ch in s.split('')) {
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
      if (depth < 0) {
        broken = true;
        break;
      }
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
  final tail = bad.contains(',')
      ? ' Add each artist separately instead of using commas.'
      : '';
  return 'Artist name "$name" ${parts.join(' and ')}.$tail';
}

String _fmtBytes(int b) => b < 1024 * 1024
    ? '${(b / 1024).toStringAsFixed(1)} KB'
    : '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';

Future<void> _openUrl(String url) async {
  var u = url.trim();
  if (u.isEmpty) return;
  if (!u.startsWith('http')) u = 'https://$u';
  final uri = Uri.tryParse(u);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

// Grouped iOS surface with inset hairline separators between rows.
Widget _group(List<Widget> rows,
    {Color color = _C.s1, Border? border}) {
  final items = <Widget>[];
  for (var i = 0; i < rows.length; i++) {
    if (i > 0) items.add(const _Sep());
    items.add(rows[i]);
  }
  return Container(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: border,
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
  );
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(left: 16),
        child: SizedBox(
          height: 0.5,
          width: double.infinity,
          child: ColoredBox(color: _C.sep),
        ),
      );
}

Widget _sh(String title, {String? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title.toUpperCase(),
              style: _ts(13, FontWeight.w500, _C.t2, ls: 0.52)),
          if (trailing != null)
            Text(trailing, style: _ts(13, FontWeight.w400, _C.t3)),
        ],
      ),
    );

Widget _ferr(String msg,
        {bool center = false,
        EdgeInsets pad = const EdgeInsets.fromLTRB(16, 8, 16, 10)}) =>
    Padding(
      padding: pad,
      child: Row(
        mainAxisAlignment:
            center ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline_rounded, size: 14, color: _C.rose),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(msg,
                style: _ts(13, FontWeight.w500, _C.rose, h: 1.3)),
          ),
        ],
      ),
    );

Widget _tnote(String msg, {required bool ok}) => Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: ok ? _C.green14 : _C.rose14,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(
            ok ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
            size: 17,
            color: ok ? _C.green : _C.rose),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg,
              style: _ts(14, FontWeight.w500, ok ? _C.green : _C.rose, h: 1.35)),
        ),
      ]),
    );

Widget _bareField({
  required TextEditingController c,
  required String hint,
  bool enabled = true,
  ValueChanged<String>? onChanged,
  TextInputType? type,
  bool autofocus = false,
}) =>
    TextField(
      controller: c,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType: type,
      autofocus: autofocus,
      autocorrect: type == null,
      textAlign: TextAlign.right,
      cursorColor: _C.yellow,
      style: _ts(16, FontWeight.w400, enabled ? _C.t1 : _C.t2),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: _ts(16, FontWeight.w400, _C.t3),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );

// Press feedback: gentle scale and/or row highlight, like iOS.
class _Tap extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final bool highlight;
  final double scale;
  const _Tap({
    required this.onTap,
    required this.child,
    this.highlight = false,
    this.scale = 1,
  });
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
          color: (widget.highlight && _down)
              ? const Color(0x0FFFFFFF)
              : const Color(0x00000000),
          child: widget.child,
        ),
      ),
    );
  }
}

// Small round icon button used for edit / remove.
Widget _roundBtn(IconData icon, VoidCallback onTap, {double size = 28}) =>
    _Tap(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: size,
        height: size,
        decoration:
            const BoxDecoration(color: _C.fill, shape: BoxShape.circle),
        child: Icon(icon, size: 13, color: _C.t2),
      ),
    );

// ─── BRAND GLYPHS (drawn, so no SVG package is needed) ───────────────
class _Brand extends StatelessWidget {
  final bool spotify;
  final double size;
  final double opacity;
  const _Brand({required this.spotify, this.size = 14, this.opacity = 1});

  @override
  Widget build(BuildContext context) {
    final w = spotify
        ? CustomPaint(size: Size.square(size), painter: _SpotifyPainter())
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFFFC3C44),
              borderRadius: BorderRadius.circular(size * 0.26),
            ),
            child: Icon(Icons.music_note_rounded,
                size: size * 0.74, color: Colors.white),
          );
    return Opacity(opacity: opacity, child: w);
  }
}

class _SpotifyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas.drawCircle(Offset(w / 2, w / 2), w / 2,
        Paint()..color = const Color(0xFF1DB954));
    final p = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    void arc(double y, double half, double peak, double sw) {
      p.strokeWidth = sw;
      final path = Path()
        ..moveTo(w / 2 - half, y)
        ..quadraticBezierTo(w / 2, y - peak * 2, w / 2 + half, y);
      canvas.drawPath(path, p);
    }

    arc(w * 0.40, w * 0.28, w * 0.10, w * 0.085);
    arc(w * 0.55, w * 0.23, w * 0.08, w * 0.07);
    arc(w * 0.68, w * 0.17, w * 0.06, w * 0.06);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
        child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: _C.yellow, shape: BoxShape.circle)),
      );
}

// ════════════════════════════════════════════════════════════════════
//  UPLOAD SCREEN
// ════════════════════════════════════════════════════════════════════
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ScrollController _scroll = ScrollController();

  File? _coverFile;
  String? _coverError;
  String? _coverUrl;

  int _idSeq = 0;
  late final List<TrackModel> _tracks = [TrackModel('t${++_idSeq}')];
  late final Set<String> _expanded = {_tracks.first.id};

  bool _uploading = false;
  bool _allDone = false;
  String _globalError = '';
  bool _rulesOpen = false;

  final Map<String, _UpRow> _up = {};

  String? _paymentReference;
  bool _argLoaded = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _C.bg,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) _paymentReference = args;
      _argLoaded = true;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final t in _tracks) {
      t.titleCtrl.dispose();
    }
    super.dispose();
  }

  int get _completed => _tracks.where((t) => t.status == 'success').length;

  // ── COVER ──────────────────────────────────────────────────────────
  // AVVO rule: JPG, exactly 4000 x 4000, RGB. Read from the file header.
  Future<String> _checkCover(File file, String name) async {
    if (!RegExp(r'\.jpe?g$', caseSensitive: false).hasMatch(name)) {
      return 'Cover art must be a JPG file.';
    }
    final len = await file.length();
    final raf = await file.open();
    final Uint8List b;
    try {
      b = await raf.read(math.min(len, 2 * 1024 * 1024));
    } finally {
      await raf.close();
    }
    final v = ByteData.sublistView(b);
    if (v.lengthInBytes < 4 || v.getUint16(0) != 0xFFD8) {
      return 'This is not a valid JPG file.';
    }
    var p = 2;
    while (p + 4 <= v.lengthInBytes) {
      if (v.getUint8(p) != 0xFF) {
        p++;
        continue;
      }
      final m = v.getUint8(p + 1);
      if (m == 0xFF) {
        p++;
        continue;
      }
      if (m == 0xDA) break;
      if (m == 0xD8 || m == 0x01 || (m >= 0xD0 && m <= 0xD7)) {
        p += 2;
        continue;
      }
      final segLen = v.getUint16(p + 2);
      if (m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC) {
        if (p + 10 > v.lengthInBytes) break;
        final h = v.getUint16(p + 5);
        final w = v.getUint16(p + 7);
        final comps = v.getUint8(p + 9);
        if (w != 4000 || h != 4000) {
          return 'Cover art must be exactly 4000 × 4000 px. Yours is $w × $h.';
        }
        if (comps != 3) {
          return 'Cover art must be RGB. CMYK and grayscale images are not accepted.';
        }
        return '';
      }
      p += 2 + segLen;
    }
    return 'Could not read this image. Please export it again as a JPG.';
  }

  Future<void> _pickCover() async {
    if (_uploading) return;
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final file = File(picked.path);
      final problem = await _checkCover(file, picked.name);
      if (!mounted) return;
      setState(() {
        if (problem.isNotEmpty) {
          _coverError = problem;
        } else {
          _coverFile = file;
          _coverUrl = null;
          _coverError = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _coverError = 'Could not pick the image. Try again.');
    }
  }

  // ── WAV ────────────────────────────────────────────────────────────
  // AVVO rule: WAV, 16-bit+, 44.1 kHz+, stereo. Read from the real header.
  Future<String> _checkWav(File file) async {
    final len = await file.length();
    final raf = await file.open();
    final Uint8List b;
    try {
      b = await raf.read(math.min(len, 65536));
    } finally {
      await raf.close();
    }
    final v = ByteData.sublistView(b);
    String tag(int o) => String.fromCharCodes(
        [v.getUint8(o), v.getUint8(o + 1), v.getUint8(o + 2), v.getUint8(o + 3)]);
    if (v.lengthInBytes < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
      return 'This is not a valid WAV file.';
    }
    var pos = 12;
    while (pos + 8 <= v.lengthInBytes) {
      final id = tag(pos);
      final size = v.getUint32(pos + 4, Endian.little);
      if (id == 'fmt ' && pos + 24 <= v.lengthInBytes) {
        final channels = v.getUint16(pos + 10, Endian.little);
        final rate = v.getUint32(pos + 12, Endian.little);
        final bits = v.getUint16(pos + 22, Endian.little);
        if (bits < 16) {
          return 'Audio must be 16-bit or higher. Re-export at 16-bit or 24-bit.';
        }
        if (rate < 44100) {
          return 'Audio must be 44.1 kHz or higher. Re-export at 44.1 kHz or 48 kHz.';
        }
        if (channels != 2) {
          return 'Audio must be stereo. Mono files are not accepted.';
        }
        return '';
      }
      pos += 8 + size + (size % 2);
    }
    return 'Could not read this WAV file. Please re-export it and try again.';
  }

  Future<void> _pickWav(TrackModel t) async {
    try {
      final result = await ImagePicker().pickMedia();
      if (result == null) return;
      final name = result.name.isNotEmpty ? result.name : result.path;
      final ext = name.split('.').last.toLowerCase();
      if (ext != 'wav') {
        setState(() => t.errors['wav'] =
            '.$ext files are not accepted. Please select a WAV file only.');
        return;
      }
      final file = File(result.path);
      final size = await file.length();
      if (size > 100 * 1024 * 1024) {
        setState(() => t.errors['wav'] = 'File exceeds the 100 MB limit.');
        return;
      }
      final problem = await _checkWav(file);
      if (!mounted) return;
      if (problem.isNotEmpty) {
        setState(() => t.errors['wav'] = problem);
        return;
      }
      setState(() {
        t.wavFile = file;
        t.wavName = name;
        t.wavSize = size;
        t.errors.remove('wav');
      });
    } catch (_) {
      if (mounted) {
        setState(() => t.errors['wav'] = 'Could not pick the file. Try again.');
      }
    }
  }

  // ── TRACK HELPERS ──────────────────────────────────────────────────
  void _addTrack() {
    final t = TrackModel('t${++_idSeq}');
    setState(() {
      _tracks.add(t);
      _expanded.add(t.id);
    });
  }

  void _removeTrack(TrackModel t) {
    setState(() {
      _tracks.remove(t);
      _expanded.remove(t.id);
      _normalize();
    });
    t.titleCtrl.dispose();
  }

  void _toggle(String id) => setState(() {
        if (!_expanded.remove(id)) _expanded.add(id);
      });

  // Only Track 1 may hold a Main artist.
  void _normalize() {
    for (var i = 1; i < _tracks.length; i++) {
      for (final a in _tracks[i].artists) {
        if (a.type == 'main') a.type = 'featured';
      }
    }
  }

  Future<ArtistEntry?> _artistSheet(
      {ArtistEntry? existing, required bool first, required bool hasMain}) {
    return showModalBottomSheet<ArtistEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x80000000),
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (_) =>
          _ArtistSheet(existing: existing, first: first, hasMain: hasMain),
    );
  }

  Future<void> _addArtist(TrackModel t, bool first) async {
    final r = await _artistSheet(
        first: first, hasMain: t.artists.any((a) => a.type == 'main'));
    if (r != null && mounted) {
      setState(() {
        t.errors.remove('artists');
        t.artists.add(r);
        _normalize();
      });
    }
  }

  Future<void> _editArtist(TrackModel t, int idx, bool first) async {
    final r = await _artistSheet(
        existing: t.artists[idx],
        first: first,
        hasMain: t.artists.any((a) => a.type == 'main'));
    if (r != null && mounted) {
      setState(() {
        t.artists[idx] = r;
        _normalize();
      });
    }
  }

  // ── VALIDATION ─────────────────────────────────────────────────────
  bool _validateAll() {
    var valid = true;
    if (_coverFile == null) {
      _coverError = 'Cover art is required.';
      valid = false;
    }
    for (var i = 0; i < _tracks.length; i++) {
      final t = _tracks[i];
      t.errors.clear();
      if (t.titleCtrl.text.trim().isEmpty) {
        t.errors['title'] = 'Required';
        valid = false;
      }
      if (t.artists.isEmpty) {
        t.errors['artists'] = 'Add at least one artist.';
        valid = false;
      } else if (i == 0 && !t.artists.any((a) => a.type == 'main')) {
        t.errors['artists'] = 'Track 1 must have one artist tagged Main.';
        valid = false;
      }
      if (t.wavFile == null) {
        t.errors['wav'] = 'Please select a WAV file.';
        valid = false;
      }
      if (t.errors.isNotEmpty) _expanded.add(t.id);
    }
    setState(() {});
    if (!valid && _coverFile == null && _scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic);
    }
    return valid;
  }

  // ── UPLOADS ────────────────────────────────────────────────────────
  String _friendlyUploadError(String m) {
    if (RegExp('preset', caseSensitive: false).hasMatch(m)) {
      return 'Cover art could not be uploaded. Please close this page, reopen it and try again.';
    }
    if (RegExp('network', caseSensitive: false).hasMatch(m)) {
      return 'Network error while uploading. Check your connection and try again.';
    }
    return m.isEmpty ? 'Upload failed. Please try again.' : m;
  }

  // Cloudinary (cover only) — up to 3 tries for preset / network errors.
  Future<String> _uploadCover(File file) async {
    var last = '';
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final req = http.MultipartRequest('POST', Uri.parse(_cloudinaryUrl));
        req.fields['upload_preset'] = _cloudinaryPreset;
        req.fields['folder'] = 'covers';
        req.files.add(await http.MultipartFile.fromPath('file', file.path));
        final streamed = await req.send();
        final body = await streamed.stream.bytesToString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        if (streamed.statusCode >= 200 &&
            streamed.statusCode < 300 &&
            json['secure_url'] is String) {
          return json['secure_url'] as String;
        }
        last = (json['error']?['message'] ?? 'Upload failed.').toString();
      } on SocketException {
        last = 'Network error during upload.';
      } catch (e) {
        last = 'Upload failed — invalid response.';
      }
      final retryable =
          RegExp('preset must be specified|network', caseSensitive: false)
              .hasMatch(last);
      if (!retryable || attempt == 3) break;
      await Future.delayed(Duration(milliseconds: 800 * attempt));
    }
    throw Exception(_friendlyUploadError(last));
  }

  // R2 (audio) — private bucket, signed upload link comes from our backend.
  Future<String> _uploadWavToR2(File file, void Function(int) onProgress) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Please sign in again.');
    final token = await user.getIdToken();
    final size = await file.length();

    final res = await http.post(
      Uri.parse('$_backendUrl/api/audio/upload-url'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'contentType': 'audio/wav', 'size': size}),
    );
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode < 200 || res.statusCode >= 300 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Could not start the upload.');
    }

    final client = HttpClient();
    try {
      final req = await client.putUrl(Uri.parse(data['uploadUrl'] as String));
      req.headers.set(HttpHeaders.contentTypeHeader, 'audio/wav');
      req.contentLength = size;
      var sent = 0;
      await for (final chunk in file.openRead()) {
        req.add(chunk);
        sent += chunk.length;
        onProgress(((sent / size) * 100).round());
        await req.flush();
      }
      final resp = await req.close();
      await resp.drain();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Upload was refused (HTTP ${resp.statusCode}).');
      }
    } on SocketException {
      throw Exception('Network error during upload.');
    } finally {
      client.close();
    }
    return data['key'] as String;
  }

  void _setUp(String id, String name, String status, int pct) {
    if (!mounted) return;
    setState(() => _up[id] = _UpRow(name, status, pct));
  }

  Future<void> _uploadAll() async {
    if (_uploading || _allDone) return;
    setState(() => _globalError = '');
    if (!_validateAll()) return;

    setState(() {
      _uploading = true;
      _up.clear();
    });

    try {
      if (_coverUrl == null) {
        _setUp('cover', 'Cover art', 'uploading', 0);
        try {
          _coverUrl = await _uploadCover(_coverFile!);
        } catch (e) {
          _setUp('cover', 'Cover art', 'error', 0);
          rethrow;
        }
      }
      _setUp('cover', 'Cover art', 'done', 100);

      var anyError = false;
      for (final t in List<TrackModel>.of(_tracks)) {
        if (t.status == 'success') continue;
        final title = t.titleCtrl.text.trim();
        final label = title.isEmpty ? 'Track' : title;
        setState(() {
          t.status = 'uploading';
          t.progress = 0;
          t.errorMsg = '';
        });
        _setUp(t.id, label, 'uploading', 0);
        try {
          t.fileKey = await _uploadWavToR2(t.wavFile!, (p) {
            if (!mounted || p == t.progress.round()) return;
            setState(() {
              t.progress = p.toDouble();
              _up[t.id] = _UpRow(label, 'uploading', p);
            });
          });
          if (!mounted) return;
          setState(() {
            t.status = 'success';
            t.progress = 100;
          });
          _setUp(t.id, label, 'done', 100);
        } catch (e) {
          anyError = true;
          if (!mounted) return;
          setState(() {
            t.status = 'error';
            t.errorMsg = _msg(e).isEmpty
                ? 'Upload failed. Check connection and retry.'
                : _msg(e);
          });
          _setUp(t.id, label, 'error', 0);
        }
      }

      if (!mounted) return;
      setState(() => _uploading = false);

      if (!anyError) {
        setState(() => _allDone = true);
        await Future.delayed(const Duration(milliseconds: 1800));
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          '/release-info',
          arguments: {
            'paymentReference': _paymentReference,
            'coverUrl': _coverUrl,
            'audioFiles': _tracks
                .where((t) => t.fileKey != null)
                .map((t) => {
                      'title': t.titleCtrl.text.trim(),
                      'artists': t.artists.map((a) => a.toMap()).toList(),
                      'key': t.fileKey,
                      'url': 'r2:${t.fileKey}',
                    })
                .toList(),
          },
        );
      } else {
        setState(() =>
            _globalError = 'Some tracks failed. Check errors and retry.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _globalError = _msg(e).isEmpty
            ? 'Upload failed. Please try again.'
            : _msg(e);
      });
    }
  }

  // ════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;
    final bottom = mq.padding.bottom;
    final keyboardOpen = mq.viewInsets.bottom > 0;

    return PopScope(
      canPop: !_uploading,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Stack(children: [
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, top + 56, 16, 130 + bottom),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _content(),
                ),
              ),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _topBar(top)),
          if (!keyboardOpen)
            Positioned(bottom: 0, left: 0, right: 0, child: _dock(bottom)),
        ]),
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hero(),
        _cover(),
        if (_coverError != null)
          _ferr(_coverError!,
              center: true, pad: const EdgeInsets.fromLTRB(16, 12, 16, 0)),
        _sh('Cover rules'),
        _rulesFold(),
        _sh('Tracklist', trailing: '$_completed of ${_tracks.length} ready'),
        for (var i = 0; i < _tracks.length; i++) _trackCard(_tracks[i], i),
        if (!_uploading && !_allDone) _addTrackButton(),
        if (_up.isNotEmpty) ..._uploadPanel(),
        if (_allDone) _successBanner(),
        if (_globalError.isNotEmpty) _globalErrBox(),
      ],
    );
  }

  // ── TOP BAR ────────────────────────────────────────────────────────
  Widget _topBar(double top) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 56 + top,
          color: _C.bar,
          padding: EdgeInsets.fromLTRB(16, top, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Tap(
                onTap: _uploading ? null : () => Navigator.maybePop(context),
                scale: 0.92,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                      color: _C.fill, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 15, color: _C.t1),
                ),
              ),
              Text('Upload release', style: _ts(17, FontWeight.w600, _C.t1)),
              SizedBox(
                width: 36,
                child: Text('1 of 3',
                    textAlign: TextAlign.right,
                    style: _ts(13, FontWeight.w400, _C.t2)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HERO ───────────────────────────────────────────────────────────
  Widget _hero() {
    Widget seg(bool on) => Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: on ? _C.yellow : _C.fill,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
    Widget name(String s, bool on) => Expanded(
          child: Text(s,
              style: _ts(12, FontWeight.w500, on ? _C.t1 : _C.t3)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Upload files',
            style: _ts(34, FontWeight.w700, _C.t1, ls: -1.36, h: 1.1)),
        const SizedBox(height: 6),
        Text('Add your cover art and tracks.',
            style: _ts(17, FontWeight.w400, _C.t2)),
        const SizedBox(height: 20),
        Row(children: [
          seg(true),
          const SizedBox(width: 6),
          seg(false),
          const SizedBox(width: 6),
          seg(false),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          name('Files', true),
          const SizedBox(width: 6),
          name('Info', false),
          const SizedBox(width: 6),
          name('Stores', false),
        ]),
      ]),
    );
  }

  // ── COVER ──────────────────────────────────────────────────────────
  Widget _cover() {
    final has = _coverFile != null;
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: AspectRatio(
            aspectRatio: 1,
            child: _Tap(
              onTap: _uploading ? null : _pickCover,
              scale: 0.98,
              child: Container(
                decoration: BoxDecoration(
                  color: _C.s1,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: const Color(0x14FFFFFF), width: 0.5),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x80000000),
                        blurRadius: 50,
                        offset: Offset(0, 18)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(fit: StackFit.expand, children: [
                  if (has)
                    Image.file(_coverFile!, fit: BoxFit.cover, cacheWidth: 900)
                  else
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                                color: _C.yellow, shape: BoxShape.circle),
                            child: const Icon(Icons.add_rounded,
                                size: 22, color: Colors.black),
                          ),
                          const SizedBox(height: 10),
                          Text('Add cover art',
                              style: _ts(17, FontWeight.w600, _C.t1)),
                          const SizedBox(height: 4),
                          Text('4000 × 4000 px, JPG',
                              style: _ts(13, FontWeight.w400, _C.t2)),
                        ],
                      ),
                    ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x8C000000),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(has ? 'Added' : 'Required',
                          style: _ts(12, FontWeight.w600,
                              has ? _C.green : _C.yellow)),
                    ),
                  ),
                  if (has)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xB31C1C1E),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('Change',
                              style: _ts(14, FontWeight.w600, _C.t1)),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── COVER RULES FOLD ───────────────────────────────────────────────
  Widget _rulesFold() {
    Widget rule(String s) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                      color: _C.yellow, shape: BoxShape.circle)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(s, style: _ts(14, FontWeight.w400, _C.t2, h: 1.45)),
            ),
          ]),
        );

    return _group([
      _Tap(
        onTap: () => setState(() => _rulesOpen = !_rulesOpen),
        highlight: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
              child: Text('Before you upload',
                  style: _ts(16, FontWeight.w400, _C.t1)),
            ),
            Text('Read', style: _ts(14, FontWeight.w400, _C.t3)),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: _rulesOpen ? 0.25 : 0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: const Icon(Icons.chevron_right_rounded,
                  size: 20, color: _C.t3),
            ),
          ]),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: _rulesOpen
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(children: [
                  rule(
                      'The artist name and release title on your cover must exactly match what you enter in the next step.'),
                  rule(
                      'No third-party logos, such as Spotify, Apple Music or YouTube, and no social handles or website URLs.'),
                  rule(
                      "Artwork that doesn't match or includes any of these is rejected during review."),
                ]),
              )
            : const SizedBox(width: double.infinity),
      ),
    ]);
  }

  // ── TRACK CARD ─────────────────────────────────────────────────────
  Widget _trackCard(TrackModel t, int i) {
    final first = i == 0;
    final open = _expanded.contains(t.id);
    final done = t.status == 'success';
    final busy = t.status == 'uploading';
    final hasErr =
        t.errors.values.any((e) => e.isNotEmpty) || t.errorMsg.isNotEmpty;
    final locked = _uploading || done;

    ArtistEntry? main;
    for (final a in t.artists) {
      if (a.type == 'main') {
        main = a;
        break;
      }
    }
    final title = t.titleCtrl.text.trim();
    final display = title.isNotEmpty ? title : (main?.name ?? 'Track ${i + 1}');
    final hasName = title.isNotEmpty || main != null;
    final sub = t.wavName ??
        (busy ? 'Uploading ${t.progress.round()}%…' : 'Tap to add details');

    final numColor = done ? _C.green : (hasErr ? _C.rose : _C.t1);
    final numBg = done ? _C.green16 : (hasErr ? const Color(0x29FF453A) : _C.fill);

    final header = _Tap(
      onTap: () => _toggle(t.id),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: numBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: done
                ? const Icon(Icons.check_rounded, size: 17, color: _C.green)
                : Text('${i + 1}',
                    style: _ts(13, FontWeight.w600, numColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ts(16, FontWeight.w500, hasName ? _C.t1 : _C.t3)),
              const SizedBox(height: 2),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ts(13, FontWeight.w400, busy ? _C.yellow : _C.t2)),
            ]),
          ),
          if (_tracks.length > 1 && !locked) ...[
            const SizedBox(width: 8),
            _roundBtn(Icons.close_rounded, () => _removeTrack(t)),
          ],
          const SizedBox(width: 8),
          AnimatedRotation(
            turns: open ? 0.25 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: const Icon(Icons.chevron_right_rounded,
                size: 20, color: _C.t3),
          ),
        ]),
      ),
    );

    final body = <Widget>[];
    if (open) {
      body.add(const _Sep());

      // Title row
      final titleBad = t.errors.containsKey('title');
      body.add(Container(
        color: titleBad ? _C.rose12 : Colors.transparent,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          SizedBox(
            width: 96,
            child: Text('Title',
                style: _ts(16, FontWeight.w400, titleBad ? _C.rose : _C.t1)),
          ),
          Expanded(
            child: _bareField(
              c: t.titleCtrl,
              hint: 'e.g. Abundance',
              enabled: !locked,
              onChanged: (_) => setState(() => t.errors.remove('title')),
            ),
          ),
        ]),
      ));

      // Artists
      body.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text('ARTISTS',
            style: _ts(13, FontWeight.w500, _C.t2, ls: 0.52)),
      ));
      if (!first) {
        body.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('Main artist is set on Track 1. Add Featured artists here.',
              style: _ts(13, FontWeight.w400, _C.t2, h: 1.4)),
        ));
      }
      for (var ai = 0; ai < t.artists.length; ai++) {
        body.add(const _Sep());
        body.add(_artistRow(t, ai, first, locked));
      }
      if (!locked) {
        if (t.artists.isNotEmpty) body.add(const _Sep());
        body.add(_Tap(
          onTap: () => _addArtist(t, first),
          highlight: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                    color: _C.yellow, shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded,
                    size: 14, color: Colors.black),
              ),
              const SizedBox(width: 10),
              Text('Add artist', style: _ts(16, FontWeight.w500, _C.yellow)),
            ]),
          ),
        ));
      }
      if (t.errors['artists'] != null) body.add(_ferr(t.errors['artists']!));

      // Audio zone
      final wavBad = t.errors.containsKey('wav');
      body.add(const _Sep());
      body.add(_Tap(
        onTap: locked ? null : () => _pickWav(t),
        highlight: true,
        child: Container(
          color: wavBad ? _C.rose12 : Colors.transparent,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: _C.s2, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.music_note_rounded,
                  size: 20, color: t.wavName != null ? _C.yellow : _C.t2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: t.wavName != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.wavName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _ts(16, FontWeight.w500, _C.t1)),
                        const SizedBox(height: 2),
                        Text(_fmtBytes(t.wavSize),
                            style: _ts(13, FontWeight.w400, _C.t2)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Choose WAV',
                            style: _ts(16, FontWeight.w500, _C.yellow)),
                        const SizedBox(height: 2),
                        Text('WAV, 16-bit+, 44.1 kHz+, stereo',
                            style: _ts(13, FontWeight.w400, _C.t2)),
                      ],
                    ),
            ),
            if (t.wavName != null && !locked)
              Text('Replace', style: _ts(14, FontWeight.w500, _C.blue)),
          ]),
        ),
      ));
      if (t.errors['wav'] != null) body.add(_ferr(t.errors['wav']!));

      if (t.errorMsg.isNotEmpty) body.add(_tnote(t.errorMsg, ok: false));
      if (done) body.add(_tnote('Track uploaded', ok: true));

      if (!done) {
        body.add(const _Sep());
        body.add(_Tap(
          onTap: () => _toggle(t.id),
          highlight: true,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            child: Text('Done', style: _ts(16, FontWeight.w500, _C.blue)),
          ),
        ));
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.s1,
        borderRadius: BorderRadius.circular(16),
        border: hasErr ? Border.all(color: _C.rose, width: 1.5) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        if (busy)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (t.progress / 100).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: _C.fill,
                valueColor: const AlwaysStoppedAnimation<Color>(_C.yellow),
              ),
            ),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
        ),
      ]),
    );
  }

  Widget _artistRow(TrackModel t, int idx, bool first, bool locked) {
    final a = t.artists[idx];
    final isMain = a.type == 'main';

    Widget link(bool spotify, String url) {
      final glyph = _Brand(
          spotify: spotify, size: 14, opacity: url.isEmpty ? 0.25 : 1);
      if (url.isEmpty) return glyph;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openUrl(url),
        child: glyph,
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isMain ? _C.green16 : _C.fill,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(isMain ? 'Main' : 'Featured',
              style: _ts(12, FontWeight.w600, isMain ? _C.green : _C.t2)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(a.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _ts(16, FontWeight.w500, _C.t1)),
        ),
        const SizedBox(width: 10),
        link(true, a.spotifyUrl),
        const SizedBox(width: 8),
        link(false, a.appleUrl),
        if (!locked) ...[
          const SizedBox(width: 10),
          _roundBtn(Icons.edit_outlined, () => _editArtist(t, idx, first)),
          const SizedBox(width: 8),
          _roundBtn(Icons.close_rounded, () {
            setState(() => t.artists.removeAt(idx));
          }),
        ],
      ]),
    );
  }

  Widget _addTrackButton() {
    return _Tap(
      onTap: _addTrack,
      scale: 0.98,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: _C.s1, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration:
                const BoxDecoration(color: _C.yellow, shape: BoxShape.circle),
            child: const Icon(Icons.add_rounded, size: 14, color: Colors.black),
          ),
          const SizedBox(width: 10),
          Text('Add another track',
              style: _ts(16, FontWeight.w500, _C.yellow)),
        ]),
      ),
    );
  }

  // ── UPLOAD PANEL / BANNERS ─────────────────────────────────────────
  List<Widget> _uploadPanel() {
    final rows = _up.values.map((r) {
      final color = r.status == 'done'
          ? _C.green
          : r.status == 'error'
              ? _C.rose
              : _C.t2;
      final label = r.status == 'done'
          ? 'Done'
          : r.status == 'error'
              ? 'Failed'
              : '${r.pct}%';
      final dot = r.status == 'uploading'
          ? const _PulseDot()
          : Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: r.status == 'done' ? _C.green : _C.rose,
                  shape: BoxShape.circle),
            );
      return Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          dot,
          const SizedBox(width: 12),
          Expanded(
            child: Text(r.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ts(16, FontWeight.w400, _C.t1)),
          ),
          Text(label, style: _ts(14, FontWeight.w500, color)),
        ]),
      );
    }).toList();

    return [
      _sh('Uploading'),
      _group(rows),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text('Please keep this page open until it finishes.',
            style: _ts(13, FontWeight.w400, _C.t2, h: 1.4)),
      ),
    ];
  }

  Widget _successBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _C.green14,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_outline_rounded,
            size: 22, color: _C.green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('All tracks uploaded',
                style: _ts(16, FontWeight.w600, _C.green)),
            const SizedBox(height: 1),
            Text('Taking you to the next step…',
                style: _ts(13, FontWeight.w400, _C.green)),
          ]),
        ),
      ]),
    );
  }

  Widget _globalErrBox() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.rose14,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.warning_amber_rounded, size: 17, color: _C.rose),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_globalError,
              style: _ts(14, FontWeight.w500, _C.rose, h: 1.35)),
        ),
      ]),
    );
  }

  // ── BOTTOM DOCK ────────────────────────────────────────────────────
  Widget _dock(double bottom) {
    final n = _tracks.length;
    final disabled = _uploading || _allDone;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
          decoration: const BoxDecoration(
            color: _C.bar,
            border: Border(top: BorderSide(color: _C.sep, width: 0.5)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _Tap(
                onTap: disabled ? null : _uploadAll,
                scale: 0.98,
                child: AnimatedOpacity(
                  opacity: disabled ? 0.4 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: _C.yellow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_uploading)
                          const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                              backgroundColor: Color(0x33000000),
                            ),
                          )
                        else
                          const Icon(Icons.file_upload_outlined,
                              size: 19, color: Colors.black),
                        const SizedBox(width: 8),
                        Text('Upload $n track${n > 1 ? 's' : ''}',
                            style: _ts(17, FontWeight.w600, Colors.black)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  ADD / EDIT ARTIST SHEET
// ════════════════════════════════════════════════════════════════════
class _ArtistSheet extends StatefulWidget {
  final ArtistEntry? existing;
  final bool first;
  final bool hasMain;
  const _ArtistSheet({
    required this.existing,
    required this.first,
    required this.hasMain,
  });
  @override
  State<_ArtistSheet> createState() => _ArtistSheetState();
}

class _ArtistSheetState extends State<_ArtistSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _spotify =
      TextEditingController(text: widget.existing?.spotifyUrl ?? '');
  late final TextEditingController _apple =
      TextEditingController(text: widget.existing?.appleUrl ?? '');
  late String _type;
  bool _invalid = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.type ??
        ((widget.first && !widget.hasMain) ? 'main' : 'featured');
    if (!widget.first && _type == 'main') _type = 'featured';
    if (_type == 'secondary') _type = 'featured';
  }

  @override
  void dispose() {
    _name.dispose();
    _spotify.dispose();
    _apple.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() {
        _invalid = true;
        _err = null;
      });
      return;
    }
    final bad = _badNameChars(name);
    if (bad.isNotEmpty) {
      setState(() {
        _invalid = true;
        _err = _nameMsg(name, bad);
      });
      return;
    }
    var type = _type;
    if (!widget.first && type == 'main') type = 'featured';
    Navigator.pop(
      context,
      ArtistEntry(
        name: name,
        type: type,
        spotifyUrl: _spotify.text.trim(),
        appleUrl: _apple.text.trim(),
      ),
    );
  }

  Widget _pill(String value, String label) {
    final sel = _type == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _C.s3 : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: sel
              ? const [
                  BoxShadow(
                      color: Color(0x4D000000),
                      blurRadius: 6,
                      offset: Offset(0, 2))
                ]
              : null,
        ),
        child: Text(label, style: _ts(14, FontWeight.w500, _C.t1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: const Color(0xF71C1C1E),
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, 24 + (mq.viewInsets.bottom > 0 ? 0 : mq.padding.bottom)),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 56,
                    child: Row(children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _Tap(
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text('Cancel',
                                  style: _ts(17, FontWeight.w400, _C.blue)),
                            ),
                          ),
                        ),
                      ),
                      Text(widget.existing == null ? 'Add artist' : 'Edit artist',
                          style: _ts(17, FontWeight.w600, _C.t1)),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _Tap(
                            onTap: _save,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text('Save',
                                  style: _ts(17, FontWeight.w600, _C.yellow)),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  _group(color: _C.s2, [
                    Container(
                      color: _invalid ? _C.rose12 : Colors.transparent,
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        SizedBox(
                          width: 70,
                          child: Text('Name',
                              style: _ts(16, FontWeight.w400,
                                  _invalid ? _C.rose : _C.t1)),
                        ),
                        Expanded(
                          child: _bareField(
                            c: _name,
                            hint: 'e.g. Wizkid',
                            autofocus: true,
                            onChanged: (_) {
                              if (_invalid || _err != null) {
                                setState(() {
                                  _invalid = false;
                                  _err = null;
                                });
                              }
                            },
                          ),
                        ),
                      ]),
                    ),
                    Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        SizedBox(
                          width: 70,
                          child: Text('Type',
                              style: _ts(16, FontWeight.w400, _C.t1)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: _C.fill,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (widget.first) _pill('main', 'Main'),
                            _pill('featured', 'Featured'),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                  if (_err != null)
                    _ferr(_err!,
                        pad: const EdgeInsets.fromLTRB(16, 8, 16, 0)),
                  if (!widget.first)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                          'Main artist is set on Track 1. This track can only have Featured artists.',
                          style: _ts(13, FontWeight.w400, _C.t2, h: 1.4)),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: _sh('Profiles', trailing: 'Optional'),
                  ),
                  _group(color: _C.s2, [
                    Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        const _Brand(spotify: true, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _bareField(
                              c: _spotify,
                              hint: 'Spotify profile URL',
                              type: TextInputType.url),
                        ),
                      ]),
                    ),
                    Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        const _Brand(spotify: false, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _bareField(
                              c: _apple,
                              hint: 'Apple Music profile URL',
                              type: TextInputType.url),
                        ),
                      ]),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
